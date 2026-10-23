#!/bin/bash
# Day 3 lab setup (Lab 14-18): network, users and groups, permissions, special permissions, links
# Run as your normal user:   bash day3_setup.sh
#   Creates ~/lab3 (old ~/lab3 is deleted and rebuilt) with answers.txt to fill in.
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

# ---------- answer file ----------
cat > "$LAB/answers.txt" <<'EOF'
# Day 3 answers: write each answer right after the = sign, then save.
# Example:  A3=192.168.1.1     Answers are short: a name, a number, yes or no.
# Check your score any time:  bash day3_check.sh

# ===== Lab A: network (Lab 14) =====
# A1 name of your network card (not lo)
A1=
# A2 your IPv4 address with the prefix, e.g. 192.168.1.10/24
A2=
# A3 default gateway (router) IP
A3=
# A4 nameserver written in /etc/resolv.conf
A4=
# A5 real DNS server from resolvectl status
A5=
# A6 IP address of github.com from your dig_github.txt
A6=
# A7 TCP port that ssh listens on (ss -tln)
A7=
# A8 key type shown the first time you ssh to localhost (e.g. RSA)
A8=
# A9 how your card gets its IP in netplan: dhcp or static
A9=

# ===== Lab B: users and groups (Lab 15-16) =====
# B1 your UID
B1=
# B2 login shell of the user www-data
B2=
# B3 first 3 characters of your password hash in /etc/shadow
B3=
# B4 default SHELL from useradd -D
B4=
# B5 can you su - piti after piti is locked? yes or no
B5=

# ===== Lab C: owner and permissions (Lab 17) =====
# C1 octal permissions of perm/report.txt BEFORE you change it
C1=
# C2 first character of ls -l /etc/localtime
C2=
# C3 your umask
C3=
# C4 octal permissions of a new file you create with touch
C4=
# C5 after chown, can you (not manee) add a line to report.txt? yes or no
C5=

# ===== Lab D: special permissions and links (Lab 18) =====
# D1 octal permissions of /usr/bin/passwd
D1=
# D2 how many setuid programs are in /usr/bin
D2=
# D3 group owner of /usr/bin/chage (it has setgid)
D3=
# D4 octal permissions of /tmp
D4=
# D5 can mana delete manee.txt in /srv/dropbox? yes or no
D5=
# D6 link count of original.txt after you make hard.txt
D6=
# D7 do original.txt and hard.txt have the same inode? yes or no
D7=
# D8 after rm original.txt, which file still shows the text: hard or soft
D8=
EOF

echo
echo "Done. Created:"
echo "  $LAB/answers.txt   (write your answers here, e.g. nano ~/lab3/answers.txt)"
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
