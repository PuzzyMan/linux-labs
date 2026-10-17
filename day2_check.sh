#!/bin/bash
# Day 2 checker:  bash day2_check.sh
# Lab A vi · Lab B shell scripts · Lab C hardware · Lab D process · Lab E system logs
LAB="$HOME/lab2"
B="$HOME/bin"
pass=0; total=0
ok(){ total=$((total+1)); if eval "$2"; then pass=$((pass+1)); echo "[ OK ] $1"; else echo "[ -- ] $1"; fi; }

echo "== Day 2 check for $(whoami)@$(hostname) =="

# Lab A: vi
want="23422ac60a0b895f4f4e51b5a14fa9bc"
got=$(md5sum "$LAB/server_notes.txt" 2>/dev/null | cut -d' ' -f1)
ok "Lab A: server_notes.txt fixed with vi"            '[ "$got" = "$want" ]'

# Lab B: shell scripts (any wording is fine, only the behaviour is checked)
for s in sysinfo backup guess; do
  ok "Lab B: ~/bin/$s.sh exists and is executable"    "[ -x \"$B/$s.sh\" ]"
done
ok "Lab B: sysinfo.sh shows the host name"            '"$B/sysinfo.sh" 2>/dev/null | grep -q "$(hostname)"'
before=$(ls "$HOME/backups" 2>/dev/null | wc -l)
[ -x "$B/backup.sh" ] && "$B/backup.sh" "$LAB" >/dev/null 2>&1
after=$(ls "$HOME/backups" 2>/dev/null | wc -l)
ok "Lab B: backup.sh <folder> makes a new file in ~/backups"  '[ "$after" -gt "$before" ]'
nope_out=""
if [ -x "$B/backup.sh" ]; then nope_out=$("$B/backup.sh" /nope 2>&1); fi
after2=$(ls "$HOME/backups" 2>/dev/null | wc -l)
ok "Lab B: backup.sh /nope makes no file and shows a message" '[ -x "$B/backup.sh" ] && [ "$after2" -eq "$after" ] && [ -n "$nope_out" ]'
# feed the numbers 1..100; a working game stops by itself (output capped so a runaway loop cannot fill the disk)
guess_out=""; guess_rc=1
if [ -x "$B/guess.sh" ]; then
  gtmp=$(mktemp)
  seq 1 100 | timeout 5 "$B/guess.sh" 2>/dev/null | head -c 20000 > "$gtmp"
  guess_rc=${PIPESTATUS[1]}
  guess_out=$(cat "$gtmp"); rm -f "$gtmp"
fi
ok "Lab B: guess.sh uses read + a loop and finishes"  'grep -qw read "$B/guess.sh" 2>/dev/null && grep -qwE "while|until|for" "$B/guess.sh" && [ "$guess_rc" -ne 124 ] && [ "$guess_rc" -ne 141 ] && [ -n "$guess_out" ]'

# Lab C: hardware
ok "Lab C: hw.txt has lscpu and free output"          'grep -q "Architecture" "$LAB/hw.txt" 2>/dev/null && grep -q "^Mem:" "$LAB/hw.txt"'

# Lab D: process
ok "Lab D: jobs.txt shows 2 background sleep jobs"    '[ "$(grep -c sleep "$LAB/jobs.txt" 2>/dev/null)" -ge 2 ] 2>/dev/null'
ok "Lab D: ps_top.txt has a ps table sorted by memory" 'head -1 "$LAB/ps_top.txt" 2>/dev/null | grep -q PID && [ "$(wc -l < "$LAB/ps_top.txt")" -ge 2 ]'
ok "Lab D: no sleep 888888 or ping left running"      '! pgrep -u "$(id -u)" -f "sleep 888888" >/dev/null && ! pgrep -u "$(id -u)" -x ping >/dev/null'

# Lab E: system logs
ok "Lab E: my_failed.txt has your failed ssh logins"  'grep -q "Failed password" "$LAB/my_failed.txt" 2>/dev/null'
ok "Lab E: answers.txt saved (grep practice)"         '[ -s "$LAB/answers.txt" ]'

if [ "$got" != "$want" ] && [ -f "$LAB/server_notes.txt" ]; then
  echo
  echo "Hint for Lab A (lines that still differ):"
  printf '%s\n' "Server Notes" "============" "Hostname: web01" "OS: Ubuntu Server 24.04" \
    "Role: web server (nginx)" "Admin: student" "Backup: every night at 02:00" \
    "Status: running" "Contact: admin@example.com" "Note: Ubuntu updates are automatic" \
    | diff "$LAB/server_notes.txt" - | grep '^[<>]'
fi
echo "----------------------------------"
echo "Score: $pass / $total"
