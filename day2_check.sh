#!/bin/bash
# Day 2 checker:  bash day2_check.sh
# Lab A vi · Lab B shell script · Lab C hardware · Lab D process · Lab E system logs
LAB="$HOME/lab2"
B="$HOME/bin"
pass=0; total=0
ok(){ total=$((total+1)); if eval "$2"; then pass=$((pass+1)); echo "[ OK ] $1"; else echo "[ -- ] $1"; fi; }

echo "== Day 2 check for $(whoami)@$(hostname) =="

# Lab A: vi
want="23422ac60a0b895f4f4e51b5a14fa9bc"
got=$(md5sum "$LAB/server_notes.txt" 2>/dev/null | cut -d' ' -f1)
ok "Lab A: server_notes.txt fixed with vi"            '[ "$got" = "$want" ]'

# Lab B: shell script (any wording is fine, only the behaviour is checked)
ok "Lab B: ~/bin/sysinfo.sh exists and is executable"  '[ -x "$B/sysinfo.sh" ]'
ok "Lab B: sysinfo.sh shows the host name"            '"$B/sysinfo.sh" 2>/dev/null | grep -q "$(hostname)"'

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
