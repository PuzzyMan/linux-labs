#!/bin/bash
# Day 3 checker:  bash day3_check.sh
# Lab A network · Lab B users and groups · Lab C permissions · Lab D special permissions and links · final team folder
# Checks only what you did on THIS machine (files, users, groups, permissions, links).
# Short answers go on the answer sheet, not in a file.

U="$(id -un)"; [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ] && U="$SUDO_USER"   # run with sudo: still check your own lab3
H="$(getent passwd "$U" | cut -d: -f6)"
LAB="$H/lab3"
pass=0; total=0
ok(){ total=$((total+1)); if eval "$2" >/dev/null 2>&1; then pass=$((pass+1)); echo "[ OK ] $1"; else echo "[ -- ] $1"; fi; }
S(){ if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo -n "$@"; fi; }
st(){ stat -c "$1" "$2" 2>/dev/null || S stat -c "$1" "$2" 2>/dev/null; }   # sudo only when needed
mode(){ st %a "$1"; }
grp(){ st %G "$1"; }
own(){ st %U "$1"; }
pw(){ S getent shadow "$1" 2>/dev/null | cut -d: -f"$2"; }
ingrp(){ id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; }

echo "== Day 3 check for $U@$(hostname) =="
if [ "$(id -u)" -ne 0 ]; then
  echo "(some checks read /etc/shadow, so sudo may ask for your password)"
  sudo -v || echo "WARNING: no sudo, the checks for passwords and other users' files will fail"
fi
[ -d "$LAB" ] || echo "WARNING: $LAB not found. Run day3_setup.sh first."

# ---------- Lab A: network ----------
GW=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
IF=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
IP=$(ip -4 -o addr show dev "$IF" 2>/dev/null | awk '{print $4; exit}'); IP=${IP%/*}
ok "ping_gw.txt: ping -c 3 to the gateway"      'grep -q "^PING $GW " "$LAB/ping_gw.txt" && grep -q "^3 packets transmitted" "$LAB/ping_gw.txt"'
DIGF="$LAB/dig_github.txt"
ok "dig_github.txt: dig github.com saved"       'grep -q "status: NOERROR" "$DIGF" && grep -qE "^github\.com\.[[:space:]].*[[:space:]]A[[:space:]]" "$DIGF"'
ok "/etc/hosts: labserver -> $IP"               '[ -n "$IP" ] && [ "$(getent ahostsv4 labserver | awk "{print \$1; exit}")" = "$IP" ]'
ok "ssh to localhost: host key saved"           '[ -n "$(ssh-keygen -F localhost -f "$H/.ssh/known_hosts" 2>/dev/null | grep -v "^#")" ]'

# ---------- Lab B: users and groups ----------
userok(){ # name uid comment
  [ "$(getent passwd "$1" | cut -d: -f3)" = "$2" ] && [ "$(getent passwd "$1" | cut -d: -f5)" = "$3" ] &&
  [ "$(getent passwd "$1" | cut -d: -f7)" = "/bin/bash" ] && [ "$(getent passwd "$1" | cut -d: -f6)" = "/home/$1" ] &&
  [ "$(own "/home/$1")" = "$1" ]; }
ok "group account has GID 3000"                 '[ "$(getent group account | cut -d: -f3)" = "3000" ]'
ok "group it has GID 3100 (tech renamed)"       '[ "$(getent group it | cut -d: -f3)" = "3100" ] && ! getent group tech'
ok "manee: UID 3001, home, bash, Manee Meesuk"  'userok manee 3001 "Manee Meesuk"'
ok "mana:  UID 3002, home, bash, Mana Rakrian"  'userok mana 3002 "Mana Rakrian"'
ok "piti:  UID 3003, home, bash, Piti Jaidee"   'userok piti 3003 "Piti Jaidee"'
ok "manee and mana have passwords"              '[ "$(pw manee 2 | cut -c1)" = "\$" ] && [ "$(pw mana 2 | cut -c1)" = "\$" ]'
ok "groups: manee=account, mana=it+account, piti=it only" 'ingrp manee account && ingrp mana it && ingrp mana account && ingrp piti it && ! ingrp piti account'
ok "manee: password max 90 days, warn 7 days"   '[ "$(pw manee 5)" = "90" ] && [ "$(pw manee 6)" = "7" ]'
ok "piti locked with usermod -L (had a password)" '[ "$(pw piti 2 | cut -c1-2)" = "!\$" ]'
deleted(){ { S journalctl -q --no-pager -t userdel 2>/dev/null; S cat /var/log/auth.log 2>/dev/null; } | grep -q "delete user '$1'"; }
ok "chujai deleted together with the home folder" '! getent passwd chujai && ! S test -e /home/chujai && deleted chujai'
ok "hello.txt made by manee (su - manee)"       '[ "$(own /home/manee/hello.txt)" = "manee" ]'

# ---------- Lab C: owner and permissions ----------
P="$LAB/perm"
ok "hello.sh is 744 and runs"                   '[ "$(mode "$P/hello.sh")" = "744" ] && "$P/hello.sh" | grep -q Hello'
ok "notes.txt is 600"                           '[ "$(mode "$P/notes.txt")" = "600" ]'
ok "private/ is 700"                            '[ "$(mode "$P/private")" = "700" ]'
ok "web/ is 755 and web/index.html is 644"      '[ "$(mode "$P/web")" = "755" ] && [ "$(mode "$P/web/index.html")" = "644" ]'
ok "report.txt is 664, owner manee, group account" '[ "$(mode "$P/report.txt")" = "664" ] && [ "$(own "$P/report.txt")" = "manee" ] && [ "$(grp "$P/report.txt")" = "account" ]'
ok "web/ and web/index.html group it (chgrp -R)" '[ "$(grp "$P/web")" = "it" ] && [ "$(grp "$P/web/index.html")" = "it" ]'

# ---------- Lab D: special permissions and links ----------
ok "/srv/dropbox is 1777, manee.txt by manee still there" '[ "$(mode /srv/dropbox)" = "1777" ] && [ "$(own /srv/dropbox/manee.txt)" = "manee" ]'
L="$LAB/links"
ok "hard.txt: hard link kept after rm original.txt" '[ ! -e "$L/original.txt" ] && [ -f "$L/hard.txt" ] && [ ! -L "$L/hard.txt" ] && [ "$(stat -c %i "$L/hard.txt")" = "$(cat "$L/.inode")" ]'
ok "soft.txt: soft link to original.txt (now broken)" '[ -L "$L/soft.txt" ] && [ "$(readlink "$L/soft.txt")" = "original.txt" ]'
ok "links/netplan -> /etc/netplan"              '[ -L "$L/netplan" ] && [ "$(readlink "$L/netplan" | sed "s:/*$::")" = "/etc/netplan" ]'

# ---------- final: IT team folder ----------
ok "/srv/itteam: root, group it, mode 3770"     '[ "$(own /srv/itteam)" = "root" ] && [ "$(grp /srv/itteam)" = "it" ] && [ "$(mode /srv/itteam)" = "3770" ]'
ok "mana.txt in /srv/itteam: owner mana, group it" '[ "$(own /srv/itteam/mana.txt)" = "mana" ] && [ "$(grp /srv/itteam/mana.txt)" = "it" ]'
ok "/home/mana/itteam -> /srv/itteam"           'S test -L /home/mana/itteam && [ "$(S readlink /home/mana/itteam | sed "s:/*$::")" = "/srv/itteam" ]'

echo "----------------------------------"
echo "Score: $pass / $total"
