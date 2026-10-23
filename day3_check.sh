#!/bin/bash
# Day 3 checker:  bash day3_check.sh
# Lab A network · Lab B users and groups · Lab C permissions · Lab D special permissions and links · final team folder
# Answers in ~/lab3/answers.txt are compared with the real values on THIS machine.

U="${SUDO_USER:-$(id -un)}"
H="$(getent passwd "$U" | cut -d: -f6)"
LAB="$H/lab3"
A="$LAB/answers.txt"
pass=0; total=0
ok(){ total=$((total+1)); if eval "$2" >/dev/null 2>&1; then pass=$((pass+1)); echo "[ OK ] $1"; else echo "[ -- ] $1"; fi; }
S(){ if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo -n "$@"; fi; }
ans(){ grep -m1 "^$1=" "$A" 2>/dev/null | cut -d= -f2- | sed 's/#.*//' | tr -d ' \t\r' | tr 'A-Z' 'a-z'; }
yes_(){ case "$(ans "$1")" in yes|y) return 0;; esac; return 1; }
no_(){ case "$(ans "$1")" in no|n) return 0;; esac; return 1; }
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
[ -f "$A" ] || echo "WARNING: $A not found. Run day3_setup.sh first."

# ---------- Lab A: network ----------
IF=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
GW=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
IPP=$(ip -4 -o addr show dev "$IF" 2>/dev/null | awk '{print $4; exit}')
IP=${IPP%/*}
NS=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)
UP=$(resolvectl status 2>/dev/null | grep -E 'DNS Servers?:' | sed 's/.*: //' | tr ' ' '\n' | grep -v '^$')
ok "A1 network card name"                       '[ -n "$IF" ] && [ "$(ans A1)" = "$(echo "$IF" | tr A-Z a-z)" ]'
ok "A2 IP address with prefix"                  '[ -n "$IPP" ] && [ "$(ans A2)" = "$IPP" ]'
ok "A3 default gateway"                         '[ -n "$GW" ] && [ "$(ans A3)" = "$GW" ]'
ok "A4 A5 DNS servers (resolv.conf, resolvectl)" '[ "$(ans A4)" = "$NS" ] && [ -n "$(ans A5)" ] && echo "$UP" | grep -qxF "$(ans A5)"'
ok "ping_gw.txt: ping -c 3 to the gateway"      'grep -q "^PING $GW " "$LAB/ping_gw.txt" && grep -q "^3 packets transmitted" "$LAB/ping_gw.txt"'
DIGF="$LAB/dig_github.txt"
ok "dig_github.txt saved and A6 matches it"     'grep -q "status: NOERROR" "$DIGF" && [ -n "$(ans A6)" ] && grep -E "^github\.com\.[[:space:]]" "$DIGF" | awk "{print \$NF}" | grep -qxF "$(ans A6)"'
ok "A7 ssh port"                                '[ "$(ans A7)" = "22" ] && ss -tln | grep -q ":22 "'
if S grep -qhE "^[[:space:]]*dhcp4:[[:space:]]*(true|yes)" /etc/netplan/*.yaml; then NP=dhcp; else NP=static; fi
ok "A9 netplan: dhcp or static"                 '[ "$(ans A9)" = "$NP" ] || [ "$(ans A9)" = "${NP}4" ]'
ok "/etc/hosts: labserver -> $IP"               '[ -n "$IP" ] && [ "$(getent ahostsv4 labserver | awk "{print \$1; exit}")" = "$IP" ]'
# the first key saved for localhost is the one ssh showed at the first connect (it adds the others after login)
KT=$(ssh-keygen -F localhost -f "$H/.ssh/known_hosts" 2>/dev/null | awk '!/^#/{print $2; exit}' | sed 's/^ssh-//; s/-.*//' | tr A-Z a-z)
ok "ssh to localhost: key saved, A8 key type"   '[ -n "$KT" ] && echo "$KT" | grep -qx "$(ans A8 | sed "s/^ssh-//")"'

# ---------- Lab B: users and groups ----------
userok(){ # name uid comment
  [ "$(getent passwd "$1" | cut -d: -f3)" = "$2" ] && [ "$(getent passwd "$1" | cut -d: -f5)" = "$3" ] &&
  [ "$(getent passwd "$1" | cut -d: -f7)" = "/bin/bash" ] && [ "$(getent passwd "$1" | cut -d: -f6)" = "/home/$1" ] &&
  [ "$(own "/home/$1")" = "$1" ]; }
WS=$(getent passwd www-data | cut -d: -f7)
ok "B1 B2 your UID, shell of www-data"          '[ "$(ans B1)" = "$(id -u "$U")" ] && { [ "$(ans B2)" = "$WS" ] || [ "$(ans B2)" = "${WS##*/}" ]; }'
HP=$(pw "$U" 2 | cut -c1-3)
DS=$(useradd -D 2>/dev/null | awk -F= '/^SHELL=/{print $2}')
ok "B3 B4 hash type, useradd default shell"     '[ -n "$HP" ] && [ "$(ans B3 | tr -d "\$")" = "$(echo "$HP" | tr -d "\$")" ] && [ "$(ans B4)" = "$DS" ]'
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
ok "hello.txt made by manee (su - manee), B5"   '[ "$(own /home/manee/hello.txt)" = "manee" ] && no_ B5'

# ---------- Lab C: owner and permissions ----------
P="$LAB/perm"
if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ]; then M=$(su - "$U" -c umask 2>/dev/null | tail -1); else M=$(umask); fi
NEW=$(printf "%o" $(( 0666 & ~0$M )))
ok "C1 C2 reading ls -l"                        '{ [ "$(ans C1)" = "640" ] || [ "$(ans C1)" = "0640" ]; } && [ "$(ans C2)" = "l" ]'
ok "C3 C4 umask and a new file"                 '[ "$(ans C3 | sed "s/^0*//")" = "$(echo "$M" | sed "s/^0*//")" ] && [ "$(ans C4)" = "$NEW" ]'
ok "hello.sh is 744 and runs"                   '[ "$(mode "$P/hello.sh")" = "744" ] && "$P/hello.sh" | grep -q Hello'
ok "notes.txt is 600"                           '[ "$(mode "$P/notes.txt")" = "600" ]'
ok "private/ is 700"                            '[ "$(mode "$P/private")" = "700" ]'
ok "web/ is 755 and web/index.html is 644"      '[ "$(mode "$P/web")" = "755" ] && [ "$(mode "$P/web/index.html")" = "644" ]'
ok "report.txt is 664, manee:account, C5"       '[ "$(mode "$P/report.txt")" = "664" ] && [ "$(own "$P/report.txt")" = "manee" ] && [ "$(grp "$P/report.txt")" = "account" ] && no_ C5'
ok "web/ and web/index.html group it (chgrp -R)" '[ "$(grp "$P/web")" = "it" ] && [ "$(grp "$P/web/index.html")" = "it" ]'

# ---------- Lab D: special permissions and links ----------
NSU=$(find /usr/bin -maxdepth 1 -type f -perm -4000 2>/dev/null | wc -l)
ok "D1 D2 setuid: passwd, how many in /usr/bin" '[ "$(ans D1)" = "$(stat -c %a /usr/bin/passwd)" ] && [ "$(ans D2)" = "$NSU" ]'
ok "D3 D4 setgid chage, sticky /tmp"            '[ "$(ans D3)" = "$(stat -c %G /usr/bin/chage)" ] && [ "$(ans D4)" = "$(stat -c %a /tmp)" ]'
ok "/srv/dropbox is 1777, manee.txt by manee, D5" '[ "$(mode /srv/dropbox)" = "1777" ] && [ "$(own /srv/dropbox/manee.txt)" = "manee" ] && no_ D5'
L="$LAB/links"
ok "hard.txt: hard link kept after rm, D6 D7"   '[ ! -e "$L/original.txt" ] && [ ! -L "$L/hard.txt" ] && [ "$(stat -c %i "$L/hard.txt")" = "$(cat "$L/.inode")" ] && [ "$(ans D6)" = "2" ] && yes_ D7'
ok "soft.txt: broken soft link to original.txt, D8" '[ -L "$L/soft.txt" ] && [ "$(readlink "$L/soft.txt")" = "original.txt" ] && { [ "$(ans D8)" = "hard" ] || [ "$(ans D8)" = "hard.txt" ]; }'
ok "links/netplan -> /etc/netplan"              '[ -L "$L/netplan" ] && [ "$(readlink "$L/netplan" | sed "s:/*$::")" = "/etc/netplan" ]'

# ---------- final: IT team folder ----------
ok "/srv/itteam: root, group it, mode 3770"     '[ "$(own /srv/itteam)" = "root" ] && [ "$(grp /srv/itteam)" = "it" ] && [ "$(mode /srv/itteam)" = "3770" ]'
ok "mana.txt in /srv/itteam: owner mana, group it" '[ "$(own /srv/itteam/mana.txt)" = "mana" ] && [ "$(grp /srv/itteam/mana.txt)" = "it" ]'
ok "/home/mana/itteam -> /srv/itteam"           'S test -L /home/mana/itteam && [ "$(S readlink /home/mana/itteam | sed "s:/*$::")" = "/srv/itteam" ]'

echo "----------------------------------"
echo "Score: $pass / $total"
