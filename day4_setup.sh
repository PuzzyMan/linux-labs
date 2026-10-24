#!/bin/bash
# Day 4 lab setup (CompTIA Linux+ Domain 1: boot, disks, LVM, RAID, services, cron, packages + firewall)
# Run as your normal user:   bash day4_setup.sh
#   Creates ~/lab4 (an old ~/lab4 is deleted and rebuilt) and the datasync service (needs sudo).
#   Installs the tools this lab needs if they are missing (parted gdisk xfsprogs lvm2 mdadm at nginx).
#   Needs the 4 empty practice disks sdb sdc sdd sde (1 GB each) from the VM setup slides.
# Start everything again:    bash day4_setup.sh --reset
#   Uses sudo to remove what this lab (and the practice slides) left behind:
#   everything on sdb sdc sdd sde (partitions, LVM, RAID, mounts, their /etc/fstab and mdadm.conf lines),
#   iptables rules and ufw rules (firewall off), /etc/modules-load.d/dummy.conf, the datasync service,
#   at jobs that would shut the machine down, sl and ncdu, the lab4 cron line,
#   the Lab 4 web page (nginx is stopped and disabled). GRUB settings are kept.
#   Your own files outside ~/lab4 are not touched. Disks bigger than 2 GB and the system disk are never touched.

DISKS="sdb sdc sdd sde"
MAXSIZE=$((2 * 1024 * 1024 * 1024))        # never touch a disk bigger than 2 GB
LABMNT="/srv/data /srv/archive /srv/web /srv/backup /srv/files /srv/raid /data"

if [ "$(id -u)" -eq 0 ]; then
  echo "Please run this as your normal user (without sudo):  bash day4_setup.sh"
  exit 1
fi
echo "(this script uses sudo, so it may ask for your password)"
sudo -v || { echo "This lab needs sudo."; exit 1; }

# practice disks that are safe to wipe: exist, at most 2 GB, not holding / /boot or swap
safe_disks(){
  for d in $DISKS; do
    [ -b "/dev/$d" ] || continue
    [ "$(lsblk -bdno SIZE "/dev/$d")" -le "$MAXSIZE" ] || { echo "  skip /dev/$d: bigger than 2 GB" >&2; continue; }
    if lsblk -lno MOUNTPOINTS "/dev/$d" | grep -qxE '/|/boot|/boot/efi|\[SWAP\]'; then
      echo "  skip /dev/$d: system disk" >&2; continue
    fi
    echo "/dev/$d"
  done
}

wipe_disks(){
  local disks; disks=$(safe_disks)
  [ -n "$disks" ] || { echo "  no practice disks found"; return; }
  # 1) unmount everything on them (deepest first)
  lsblk -lnpo MOUNTPOINTS $disks | grep -v '^$' | sort -ru | while read -r m; do
    sudo umount -l "$m" 2>/dev/null && echo "  unmounted $m"
  done
  lsblk -lnpo NAME,TYPE $disks | awk '$2=="part"||$2=="disk"{print $1}' | while read -r p; do sudo swapoff "$p" 2>/dev/null; done
  # 2) /etc/fstab: drop lines that point at them (by UUID, device name, LV name or lab mount point)
  sudo cp /etc/fstab /etc/fstab.lab4-backup
  local pat="" u n vg lv
  for u in $(lsblk -lnpo UUID $disks | grep -v '^$' | sort -u); do pat="$pat|$u"; done
  for n in $(lsblk -lnpo NAME $disks | sort -u); do pat="$pat|^$n[[:space:]]"; done
  for vg in $(sudo pvs --noheadings -o vg_name $(lsblk -lnpo NAME,TYPE $disks | awk '$2=="part"||$2=="disk"{print $1}') 2>/dev/null | sort -u); do
    for lv in $(sudo lvs --noheadings -o lv_name "$vg" 2>/dev/null); do pat="$pat|^/dev/$vg/$lv[[:space:]]|^/dev/mapper/$vg-$lv[[:space:]]"; done
  done
  for m in $LABMNT; do pat="$pat|^[^#][^[:space:]]*[[:space:]]+$m/?[[:space:]]"; done
  pat="${pat#|}"
  if grep -Eq "$pat" /etc/fstab; then
    grep -E "$pat" /etc/fstab | sed 's/^/  removed from fstab: /'
    grep -Ev "$pat" /etc/fstab | sudo tee /etc/fstab.new >/dev/null && sudo mv /etc/fstab.new /etc/fstab
  fi
  sudo systemctl daemon-reload
  # 3) wipe the filesystems inside LVs and RAID arrays first, so nothing is left in the data area
  for v in $(lsblk -lnpo NAME,TYPE $disks | awk '$2=="lvm" || $2 ~ /^raid/ {print $1}' | sort -u); do
    sudo wipefs -a "$v" >/dev/null 2>&1
  done
  # 4) LVM volume groups that live on them (only these: the system VG is on another disk)
  for vg in $(sudo pvs --noheadings -o vg_name $(lsblk -lnpo NAME,TYPE $disks | awk '$2=="part"||$2=="disk"{print $1}') 2>/dev/null | sort -u); do
    sudo vgchange -an "$vg" >/dev/null 2>&1; sudo vgremove -ff -y "$vg" >/dev/null 2>&1 && echo "  removed volume group $vg"
  done
  # 5) RAID arrays built from them, and their ARRAY lines in mdadm.conf
  for md in $(lsblk -lnpo NAME,TYPE $disks | awk '$2 ~ /^raid/{print $1}' | sort -u); do
    uu=$(sudo mdadm --detail --export "$md" 2>/dev/null | sed -n 's/^MD_UUID=//p')
    sudo mdadm --stop "$md" >/dev/null 2>&1 && echo "  stopped RAID $md"
    if [ -n "$uu" ] && [ -f /etc/mdadm/mdadm.conf ] && grep -q "$uu" /etc/mdadm/mdadm.conf; then
      sudo sed -i "/$uu/d" /etc/mdadm/mdadm.conf; echo "  removed its ARRAY line from /etc/mdadm/mdadm.conf"
    fi
  done
  # 6) wipe signatures on partitions, then the disks (and zero the first 8 MB of each)
  for p in $(lsblk -lnpo NAME,TYPE $disks | awk '$2=="part"{print $1}'); do
    sudo mdadm --zero-superblock --force "$p" >/dev/null 2>&1
    sudo pvremove -ff -y "$p" >/dev/null 2>&1
    sudo wipefs -a "$p" >/dev/null 2>&1
    sudo dd if=/dev/zero of="$p" bs=1M count=8 status=none 2>/dev/null
  done
  for d in $disks; do
    sudo mdadm --zero-superblock --force "$d" >/dev/null 2>&1
    sudo pvremove -ff -y "$d" >/dev/null 2>&1
    sudo wipefs -a "$d" >/dev/null 2>&1
    sudo dd if=/dev/zero of="$d" bs=1M count=8 status=none 2>/dev/null && echo "  wiped $d"
  done
  sudo partprobe $disks 2>/dev/null; sudo udevadm settle 2>/dev/null
  for m in $LABMNT; do [ -d "$m" ] && sudo rmdir "$m" 2>/dev/null; done
}

if [ "$1" = "--reset" ]; then
  echo "== Reset: removing what Lab 4 and the practice slides left (needs sudo) =="
  wipe_disks
  # firewall: iptables rules from the slides, then ufw
  if command -v iptables >/dev/null; then
    sudo iptables -P INPUT ACCEPT; sudo iptables -P FORWARD ACCEPT; sudo iptables -P OUTPUT ACCEPT
    sudo iptables -F; sudo iptables -X 2>/dev/null
  fi
  if command -v ufw >/dev/null; then sudo ufw --force reset >/dev/null 2>&1; fi
  echo "  firewall rules cleared (iptables and ufw, firewall off)"
  if [ -f /etc/modules-load.d/dummy.conf ]; then sudo rm -f /etc/modules-load.d/dummy.conf; echo "  removed /etc/modules-load.d/dummy.conf"; fi
  sudo modprobe -r dummy 2>/dev/null
  sudo systemctl disable --now datasync 2>/dev/null
  sudo rm -f /etc/systemd/system/datasync.service /usr/local/bin/datasync; sudo systemctl daemon-reload
  # at jobs that would shut the machine down (the at example in the slides)
  if command -v atq >/dev/null; then
    for j in $(sudo atq 2>/dev/null | awk '{print $1}'); do
      if sudo at -c "$j" 2>/dev/null | grep -Eq '(shutdown|poweroff|halt|reboot)'; then sudo atrm "$j"; echo "  removed at job $j (it would shut the machine down)"; fi
    done
  fi
  for p in sl ncdu; do dpkg -s "$p" >/dev/null 2>&1 && sudo apt-get remove -y -qq "$p" >/dev/null 2>&1 && echo "  removed package $p"; done
  if crontab -l 2>/dev/null | grep -q 'lab4/cron.log'; then
    crontab -l | grep -v 'lab4/cron.log' | crontab -; echo "  removed the lab4 line from your crontab"
  fi
  if [ -f /var/www/html/index.html ] && grep -q "Lab 4 by" /var/www/html/index.html; then sudo rm -f /var/www/html/index.html; fi
  sudo systemctl disable --now nginx >/dev/null 2>&1 && echo "  nginx stopped and disabled"
  echo "Done. Now run:  bash day4_setup.sh"
  exit 0
fi

# ---------- tools: install what is missing ----------
pkgs=""
need(){ command -v "$1" >/dev/null 2>&1 || [ -x "/usr/sbin/$1" ] || [ -x "/sbin/$1" ] || pkgs="$pkgs $2"; }
need parted   parted
need gdisk    gdisk
need mkfs.xfs xfsprogs
need pvcreate lvm2
need mdadm    mdadm
need at       at
need nginx    nginx
need curl     curl
need ufw      ufw
need iptables iptables
if [ -n "$pkgs" ]; then
  echo "== Installing tools this lab needs:$pkgs =="
  sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkgs >/dev/null \
    && echo "  installed:$pkgs" || echo "  could not install:$pkgs  (check the internet, then run this again)"
fi
# start state for Lab E: nginx installed but off (the package turns it on when installed)
sudo systemctl disable --now nginx >/dev/null 2>&1
sudo systemctl enable --now atd >/dev/null 2>&1

LAB="$HOME/lab4"
echo "== Setting up $LAB =="
rm -rf "$LAB" 2>/dev/null
if [ -e "$LAB" ]; then
  echo "Cannot delete the old $LAB (files owned by another user)."
  echo "Run:  sudo rm -rf $LAB   then run this script again."
  exit 1
fi
mkdir -p "$LAB/pkg"

# ---------- Lab E: a service that wastes CPU ----------
printf '%s\n' '#!/bin/bash' '# datasync: pretends to sync data, really just burns CPU (Lab 4)' 'while :; do :; done' \
  | sudo tee /usr/local/bin/datasync >/dev/null
sudo chmod 755 /usr/local/bin/datasync
sudo tee /etc/systemd/system/datasync.service >/dev/null <<'EOF'
[Unit]
Description=Data sync agent (lab 4)

[Service]
ExecStart=/usr/local/bin/datasync
Restart=always
RestartSec=2
CPUQuota=60%

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now datasync >/dev/null 2>&1

echo
echo "Done. Created:"
echo "  $LAB/        (Lab E and F save files here)"
echo "  $LAB/pkg/    (Lab E: put the .deb file here)"
echo "  datasync.service (Lab E: it is running now and uses a lot of CPU)"

# ---------- check the practice disks and the firewall ----------
echo
miss=""; busy=""
for d in $DISKS; do
  if [ ! -b "/dev/$d" ]; then miss="$miss $d"; continue; fi
  if [ -n "$(lsblk -no FSTYPE,PTTYPE,MOUNTPOINTS "/dev/$d" | tr -d '[:space:]')" ] || [ "$(lsblk -lno NAME "/dev/$d" | wc -l)" -gt 1 ]; then busy="$busy $d"; fi
done
if [ -n "$miss" ]; then
  echo "NOTE: disk missing:$miss  -> add 1 GB SCSI disks in VMware (see the VM setup slides), then run this again"
elif [ -n "$busy" ]; then
  echo "NOTE: not empty:$busy  (left from the practice slides?)  -> clean them with:  bash day4_setup.sh --reset"
else
  echo "Disks: sdb sdc sdd sde are empty and ready"
fi
if sudo ufw status 2>/dev/null | grep -q "^Status: active" || [ -n "$(sudo iptables -S INPUT 2>/dev/null | grep -v '^-P INPUT ACCEPT')" ]; then
  echo "NOTE: firewall rules are already set (left from the slides?)  -> clear them with:  bash day4_setup.sh --reset"
fi
