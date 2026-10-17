#!/bin/bash
# Day 2 lab setup: vi, shell script, hardware, process, system logs
# Run as your normal user:  bash day2_setup.sh
# Creates ~/lab2 (old ~/lab2 is deleted and rebuilt), ~/bin and ~/backups

LAB="$HOME/lab2"
echo "== Setting up $LAB =="
rm -rf "$LAB"
mkdir -p "$LAB" "$HOME/bin" "$HOME/backups"
cd "$LAB" || exit 1

# ---------- Lab E part 2: sample auth log for grep practice ----------
cat > auth_sample.log <<'EOF'
2026-10-09 08:01:12 sshd[1201]: Accepted password for alice from 192.168.1.15 port 52100 ssh2
2026-10-09 08:03:40 sshd[1202]: Failed password for root from 203.0.113.99 port 40122 ssh2
2026-10-09 08:03:44 sshd[1202]: Failed password for root from 203.0.113.99 port 40123 ssh2
2026-10-09 08:03:49 sshd[1202]: Failed password for root from 203.0.113.99 port 40124 ssh2
2026-10-09 08:05:00 CRON[2201]: (root) CMD (/usr/local/bin/backup.sh)
2026-10-09 08:12:05 sshd[1210]: Failed password for bob from 192.168.1.22 port 51000 ssh2
2026-10-09 08:12:15 sshd[1210]: Accepted password for bob from 192.168.1.22 port 51001 ssh2
2026-10-09 08:20:31 sudo: bob : TTY=pts/1 ; PWD=/home/bob ; USER=root ; COMMAND=/usr/bin/apt update
2026-10-09 08:41:02 sshd[1230]: Failed password for admin from 198.51.100.23 port 33001 ssh2
2026-10-09 08:41:06 sshd[1230]: Failed password for admin from 198.51.100.23 port 33002 ssh2
2026-10-09 08:55:19 sshd[1241]: Failed password for user101 from 10.0.0.8 port 45010 ssh2
2026-10-09 08:55:25 sshd[1241]: Accepted password for user101 from 10.0.0.8 port 45011 ssh2
2026-10-09 09:00:00 CRON[2302]: (root) CMD (/usr/local/bin/cleanup.sh)
2026-10-09 09:02:14 sshd[1250]: Failed password for root from 203.0.113.99 port 40200 ssh2
2026-10-09 09:02:18 sshd[1250]: Failed password for root from 203.0.113.99 port 40201 ssh2
2026-10-09 09:10:44 sshd[1255]: Accepted password for charlie from 10.0.0.12 port 46000 ssh2
2026-10-09 09:15:02 sudo: charlie : TTY=pts/2 ; PWD=/home/charlie ; USER=root ; COMMAND=/usr/bin/systemctl restart nginx
2026-10-09 09:21:37 sshd[1262]: Failed password for guest999 from 203.0.113.50 port 39000 ssh2
2026-10-09 09:21:41 sshd[1262]: Failed password for guest999 from 203.0.113.50 port 39001 ssh2
2026-10-09 09:21:45 sshd[1262]: Failed password for guest999 from 203.0.113.50 port 39002 ssh2
2026-10-09 09:33:10 sshd[1270]: Failed password for alice from 192.168.1.15 port 52300 ssh2
2026-10-09 09:33:16 sshd[1270]: Accepted password for alice from 192.168.1.15 port 52301 ssh2
2026-10-09 09:47:55 sshd[1281]: Failed password for root from 198.51.100.23 port 33100 ssh2
2026-10-09 09:48:01 sshd[1281]: Failed password for admin from 198.51.100.23 port 33101 ssh2
2026-10-09 10:00:00 CRON[2403]: (root) CMD (/usr/local/bin/backup.sh)
2026-10-09 10:05:12 sshd[1290]: Failed password for root from 203.0.113.99 port 40300 ssh2
2026-10-09 10:05:16 sshd[1290]: Failed password for root from 203.0.113.99 port 40301 ssh2
2026-10-09 10:05:20 sshd[1290]: Failed password for root from 203.0.113.99 port 40302 ssh2
2026-10-09 10:18:33 sshd[1301]: Accepted password for bob from 10.0.0.21 port 47000 ssh2
2026-10-09 10:25:09 sudo: alice : TTY=pts/0 ; PWD=/home/alice ; USER=root ; COMMAND=/usr/bin/tail /var/log/syslog
2026-10-09 10:31:48 sshd[1312]: Failed password for test from 203.0.113.50 port 39100 ssh2
2026-10-09 10:31:52 sshd[1312]: Failed password for test from 203.0.113.50 port 39101 ssh2
2026-10-09 10:44:05 sshd[1320]: Failed password for user101 from 10.0.0.8 port 45100 ssh2
2026-10-09 10:52:30 sshd[1325]: Accepted password for admin from 192.168.1.5 port 50500 ssh2
2026-10-09 10:58:00 sshd[1330]: Failed password for root from 203.0.113.99 port 40400 ssh2
2026-10-09 10:59:59 sshd[1331]: Connection closed by 203.0.113.99 port 40401 [preauth]
EOF

# ---------- Lab A: broken file for vi ----------
cat > server_notes.txt <<'EOF'
Server Notes
============
Hostname: old web01
OS: Windows Server 24.04
Role: web server (nginx)
Role: web server (nginx)
Backup: every night at 02:00
Admin: student
Statuss: running
Note: Windows updates are automatic
EOF
cp server_notes.txt server_notes.orig

echo
echo "Done. Created:"
echo "  $LAB/server_notes.txt  (Lab A: fix this file with vi)"
echo "  $HOME/bin and $HOME/backups (Lab B: shell scripts)"
echo "  $LAB/auth_sample.log   (Lab E: grep practice)"

# Lab C and Lab D need these commands (Ubuntu Server may not have them yet)
missing=""
for c in lspci lsusb killall; do command -v "$c" >/dev/null 2>&1 || missing="$missing $c"; done
if [ -n "$missing" ]; then
  echo; echo "NOTE: missing:$missing  -> install with:  sudo apt install pciutils usbutils psmisc"
fi
case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) echo; echo "NOTE: ~/bin is not in PATH yet. Run:  source ~/.profile   (or log out and in)";;
esac
