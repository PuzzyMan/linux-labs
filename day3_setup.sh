#!/bin/bash
# Day 3 lab setup (Lab 14-18): network, users and groups, permissions, special permissions, links
# Run as your normal user:   bash day3_setup.sh
#   Creates ~/lab3 (old ~/lab3 is deleted and rebuilt). Write your answers on the answer sheet.
# Start the user part again:  bash day3_setup.sh --reset
#   Uses sudo to delete what the lab created outside ~/lab3:
#   users manee mana piti chujai, groups account it tech, /srv/dropbox, /srv/itteam,
#   and the labserver line in /etc/hosts.

if [ "$1" = "--reset" ]; then
  echo "== Reset: removing lab users, groups and folders (needs sudo) =="
  sudo -v || exit 1
  for u in manee mana piti chujai; do
    if getent passwd "$u" >/dev/null; then
      sudo pkill -u "$u" 2>/dev/null; sleep 0.5
      sudo userdel -r "$u" 2>/dev/null; echo "  deleted user $u"
    fi
  done
  for g in account it tech manee mana piti chujai; do
    getent group "$g" >/dev/null && sudo groupdel "$g" 2>/dev/null && echo "  deleted group $g"
  done
  sudo rm -rf /srv/dropbox /srv/itteam && echo "  deleted /srv/dropbox /srv/itteam"
  if grep -qw labserver /etc/hosts; then
    sudo sed -i '/[[:space:]]labserver\([[:space:]]\|$\)/d' /etc/hosts && echo "  removed labserver from /etc/hosts"
  fi
  echo "Done. Now run:  bash day3_setup.sh"
  exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "Please run this as your normal user (without sudo):  bash day3_setup.sh"
  exit 1
fi

LAB="$HOME/lab3"
echo "== Setting up $LAB =="
rm -rf "$LAB" 2>/dev/null
if [ -e "$LAB" ]; then
  echo "Cannot delete the old $LAB (files owned by another user)."
  echo "Run:  sudo rm -rf $LAB   then run this script again."
  exit 1
fi
mkdir -p "$LAB/perm/private" "$LAB/perm/web" "$LAB/links"

# ---------- Lab C: files with permissions to read and fix ----------
cd "$LAB/perm" || exit 1
echo "Q3 sales report: 1,250,000 baht" > report.txt
printf '%s\n' '#!/bin/bash' 'echo "Hello from $(whoami) on $(hostname)"' > hello.sh
echo "My notes: change the router password on Friday" > notes.txt
echo "Private plans" > private/plan.txt
printf '%s\n' '<h1>Lab 3 web page</h1>' > web/index.html
chmod 640 report.txt
chmod 644 hello.sh
chmod 666 notes.txt
chmod 777 private
chmod 700 web
chmod 600 web/index.html

# ---------- Lab D: links ----------
cd "$LAB/links" || exit 1
echo "Linux links lab" > original.txt
stat -c %i original.txt > .inode          # used by day3_check.sh

echo
echo "Done. Created:"
echo "  $LAB/perm/         (Lab C: files to read and fix)"
echo "  $LAB/links/        (Lab D: original.txt for links)"

# Tools used in Lab A and Lab B
missing=""; pkgs=""
need(){ command -v "$1" >/dev/null 2>&1 || { missing="$missing $1"; case " $pkgs " in *" $2 "*) ;; *) pkgs="$pkgs $2";; esac; }; }
need ifconfig net-tools
need netstat  net-tools
need dig      bind9-dnsutils
need host     bind9-dnsutils
need last     wtmpdb
[ -x /usr/sbin/sshd ] || { missing="$missing sshd"; pkgs="$pkgs openssh-server"; }
if [ -n "$missing" ]; then
  echo
  echo "NOTE: missing:$missing  -> install with:  sudo apt install$pkgs"
fi
old=""
for u in manee mana piti chujai; do getent passwd "$u" >/dev/null && old="$old $u"; done
for g in account it tech; do getent group "$g" >/dev/null && old="$old $g"; done
if [ -n "$old" ]; then
  echo
  echo "NOTE: already on this machine:$old"
  echo "      To start Lab B again from zero:  bash day3_setup.sh --reset"
fi
