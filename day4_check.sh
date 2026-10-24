#!/bin/bash
# Day 4 checker:  bash day4_check.sh
# Lab A boot and kernel · Lab B partitions and fstab · Lab C LVM · Lab D RAID · Lab E services, cron, packages
# Lab F firewall · final reboot test
# Checks only what you did on THIS machine. Short answers go on the answer sheet, not in a file.

U="$(id -un)"; [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ] && U="$SUDO_USER"   # run with sudo: still check your own lab4
H="$(getent passwd "$U" | cut -d: -f6)"
LAB="$H/lab4"
pass=0; total=0
ok(){ total=$((total+1)); if eval "$2" >/dev/null 2>&1; then pass=$((pass+1)); echo "[ OK ] $1"; else echo "[ -- ] $1"; fi; }
S(){ if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo -n "$@"; fi; }
AS(){ local who="$1"; shift; if [ "$who" = "$(id -un)" ]; then "$@"; elif [ "$(id -u)" -eq 0 ]; then runuser -u "$who" -- "$@"; else sudo -n -u "$who" "$@"; fi; }
src(){ findmnt -no SOURCE "$1" 2>/dev/null | head -1; }
fst(){ findmnt -no FSTYPE "$1" 2>/dev/null | head -1; }
uuid(){ S blkid -s UUID -o value "$1" 2>/dev/null; }
# a line in /etc/fstab for mount point $1 whose first field is one of the names given after it
inftab(){ local mp="$1"; shift; local f; for f in "$@"; do
  [ -n "$f" ] && awk -v d="$f" -v m="$mp" '$1 !~ /^#/ { gsub(/"/, "", $1); sub(/\/$/, "", $2); if ($1 == d && $2 == m) found = 1 } END { exit !found }' /etc/fstab && return 0
  done; return 1; }
mdof(){ local s; s=$(src "$1"); case "$s" in /dev/md*) echo "$s";; esac; }

echo "== Day 4 check for $U@$(hostname) =="
if [ "$(id -u)" -ne 0 ]; then
  echo "(many checks need root, so sudo may ask for your password)"
  sudo -v || echo "WARNING: no sudo, most checks will fail"
fi
[ -d "$LAB" ] || echo "WARNING: $LAB not found. Run day4_setup.sh first."

# ---------- Lab A: boot and kernel ----------
ok "A1 GRUB waits 5 seconds and update-grub was run" 'grep -Eq "^GRUB_TIMEOUT=\"?5\"?$" /etc/default/grub && S grep -q "set timeout=5" /boot/grub/grub.cfg'
ok "A2 module dummy is loaded"                    'lsmod | grep -q "^dummy "'
ok "A3 dummy loads at boot (/etc/modules-load.d)" 'cat /etc/modules-load.d/*.conf 2>/dev/null | sed "s/#.*//" | grep -qw dummy'

# ---------- Lab B: partitions, filesystems, fstab ----------
SZ1=$(lsblk -bdno SIZE /dev/sdb1 2>/dev/null)
ok "B1 sdb: GPT with 2 partitions, sdb1 about 500 MiB" '[ "$(S blkid -o value -s PTTYPE /dev/sdb)" = "gpt" ] && [ -b /dev/sdb2 ] && [ ! -b /dev/sdb3 ] && [ "$SZ1" -ge 480000000 ] && [ "$SZ1" -le 560000000 ]'
ok "B2 sdb1 is ext4, mounted on /srv/data"        '[ "$(src /srv/data)" = "/dev/sdb1" ] && [ "$(fst /srv/data)" = "ext4" ]'
ok "B3 sdb2 is xfs, mounted on /srv/archive"      '[ "$(src /srv/archive)" = "/dev/sdb2" ] && [ "$(fst /srv/archive)" = "xfs" ]'
ok "B4 /etc/fstab mounts /srv/data and /srv/archive by UUID" 'inftab /srv/data "UUID=$(uuid /dev/sdb1)" && inftab /srv/archive "UUID=$(uuid /dev/sdb2)"'

# ---------- Lab C: LVM ----------
LV=/dev/lab_vg/web_lv
ok "C1 sdc: MBR from fdisk, sdc1 is a PV in volume group lab_vg" '[ "$(S blkid -o value -s PTTYPE /dev/sdc)" = "dos" ] && [ "$(S pvs --noheadings -o vg_name /dev/sdc1 | tr -d " ")" = "lab_vg" ]'
ok "C2 web_lv is 600 MiB (lvcreate 400M, then lvextend +200M)" '[ "$(S lvs --noheadings --units m -o lv_size lab_vg/web_lv | tr -d " ")" = "600.00m" ]'
ok "C3 /srv/web: ext4 on web_lv, filesystem grown too" '[ "$(readlink -f "$(src /srv/web)")" = "$(readlink -f $LV)" ] && [ "$(fst /srv/web)" = "ext4" ] && [ "$(findmnt -bno SIZE /srv/web)" -gt 550000000 ]'
ok "C4 /etc/fstab mounts /srv/web"                'inftab /srv/web $LV /dev/mapper/lab_vg-web_lv "UUID=$(uuid $LV)"'

# ---------- Lab D: RAID ----------
rtype(){ case "$(lsblk -no PARTTYPE "$1" 2>/dev/null)" in a19d880f-05fc-4d3b-a006-743f0f84911e|0xfd) return 0;; esac; return 1; }
MD=$(mdof /srv/backup); [ -n "$MD" ] || MD=$(lsblk -lnpo NAME,TYPE /dev/sdd1 2>/dev/null | awk '$2=="raid1"{print $1; exit}')
mdok(){ local d; d=$(S mdadm --detail "$MD" 2>/dev/null); echo "$d" | grep -q "Raid Level : raid1" && echo "$d" | grep -q "Active Devices : 2" && echo "$d" | grep -q "/dev/sdd1" && echo "$d" | grep -q "/dev/sde1"; }
# the kernel log keeps "Disk failure on sde1" from the --fail step (also across reboots)
KLOG=$( { S journalctl _TRANSPORT=kernel -o cat --no-pager; S cat /var/log/kern.log /var/log/kern.log.1; } 2>/dev/null | grep -E "md/raid1:md[0-9]+: Disk failure on sd[de]1" )
ok "D1 sdd1 and sde1 are Linux RAID partitions"   'rtype /dev/sdd1 && rtype /dev/sde1'
ok "D2 RAID 1 of sdd1 + sde1, both disks active"  '[ -n "$MD" ] && mdok'
ok "D3 a disk was failed, removed and added back (both active again)" 'echo "$KLOG" | grep -q "Disk failure on sd[de]1" && [ -n "$MD" ] && mdok'
ok "D4 /srv/backup: ext4 on the RAID, in fstab by UUID" '[ -n "$(mdof /srv/backup)" ] && [ "$(fst /srv/backup)" = "ext4" ] && inftab /srv/backup "UUID=$(uuid "$(mdof /srv/backup)")"'
MDU=$(S mdadm --detail --export "$MD" 2>/dev/null | sed -n "s/^MD_UUID=//p")
ok "D5 /etc/mdadm/mdadm.conf has the ARRAY line of this array" '[ -n "$MDU" ] && grep -E "^ARRAY" /etc/mdadm/mdadm.conf | grep -q "$MDU"'
BT=$(awk '/^btime/ {print $2}' /proc/stat)
ok "D6 rebooted after saving mdadm.conf, the array is still /dev/md0" '[ "$BT" -gt "$(stat -c %Y /etc/mdadm/mdadm.conf)" ] && [ "$MD" = "/dev/md0" ]'

# ---------- Lab E: services, cron, at, packages ----------
ok "E1 datasync (the CPU hog) stopped and disabled" '[ -e /etc/systemd/system/datasync.service ] && ! systemctl is-active -q datasync && ! systemctl is-enabled -q datasync'
ok "E2 nginx enabled and running"                 'systemctl is-enabled -q nginx && systemctl is-active -q nginx'
ok "E3 web page shows: Lab 4 by $U"               'curl -s --max-time 5 http://localhost/ | grep -q "Lab 4 by $U"'
CT=$(AS "$U" crontab -l 2>/dev/null)
ok "E4 crontab: every 2 minutes, date >> ~/lab4/cron.log" 'echo "$CT" | grep -Eq "^[[:space:]]*\*/2[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]].*date.*>>.*lab4/cron\.log"'
ok "E5 cron.log has lines (cron really ran it)"   '[ -s "$LAB/cron.log" ]'
ok "E6 at: one-time job made ~/lab4/at_done.txt"  '[ -f "$LAB/at_done.txt" ] && [ "$(stat -c %U "$LAB/at_done.txt")" = "$U" ]'
ok "E7 sl installed from the .deb in ~/lab4/pkg"  'ls "$LAB"/pkg/sl_*.deb && dpkg -s sl 2>/dev/null | grep -q "^Status: install ok installed"'

# ---------- Lab F: firewall ----------
FW="$LAB/fw.rules"
ok "F1 fw.rules (iptables-save): policy DROP, lo and ESTABLISHED,RELATED allowed" 'grep -q "^:INPUT DROP" "$FW" && grep -q "^-A INPUT -i lo -j ACCEPT" "$FW" && grep -Eq "^-A INPUT -m (conntrack --ctstate|state --state) (RELATED,ESTABLISHED|ESTABLISHED,RELATED) -j ACCEPT" "$FW"'
ok "F2 fw.rules: tcp 22 and tcp 80 allowed"       'grep -Eq "^-A INPUT -p tcp (-m tcp )?--dport 22 -j ACCEPT" "$FW" && grep -Eq "^-A INPUT -p tcp (-m tcp )?--dport 80 -j ACCEPT" "$FW"'
UFW=$(S ufw status 2>/dev/null)
ok "F3 ufw active, allows 22/tcp and 80/tcp"      'echo "$UFW" | grep -q "^Status: active" && echo "$UFW" | grep -Eq "^(22/tcp|22|OpenSSH) +ALLOW" && echo "$UFW" | grep -Eq "^(80/tcp|80|Nginx (HTTP|Full)) +ALLOW"'

# ---------- final: reboot test ----------
FT=$(stat -c %Y /etc/fstab)
ok "G1 rebooted after the last fstab change, all 4 mounts came back" '[ "$BT" -gt "$FT" ] && findmnt /srv/data && findmnt /srv/archive && findmnt /srv/web && findmnt /srv/backup'

echo "----------------------------------"
echo "Score: $pass / $total"
