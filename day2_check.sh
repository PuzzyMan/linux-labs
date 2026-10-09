#!/bin/bash
# Day 2 checker:  bash day2_check.sh
LAB="$HOME/lab2"
B="$HOME/bin"
pass=0; total=0
ok(){ total=$((total+1)); if eval "$2"; then pass=$((pass+1)); echo "[ OK ] $1"; else echo "[ -- ] $1"; fi; }

echo "== Day 2 check for $(whoami)@$(hostname) =="
# Lab A
ok "Lab A: conf_list.txt and conf_err.txt created"   '[ -s "$LAB/conf_list.txt" ] && [ -f "$LAB/conf_err.txt" ]'
ok "Lab A: conf_list.txt ends with === end ==="     '[ "$(tail -1 "$LAB/conf_list.txt" 2>/dev/null)" = "=== end ===" ]'
ok "Lab A: all.txt created (stdout + stderr)"        '[ -s "$LAB/all.txt" ]'
ok "Lab A: users.txt is sorted user names"           '[ -s "$LAB/users.txt" ] && sort -c "$LAB/users.txt" 2>/dev/null && grep -qx root "$LAB/users.txt"'
ok "Lab A: big5.txt has 6 lines"                     '[ -f "$LAB/big5.txt" ] && [ "$(wc -l < "$LAB/big5.txt")" = "6" ]'
ok "Lab A: users_upper.txt is upper case"            'grep -qx ROOT "$LAB/users_upper.txt" 2>/dev/null'
# Lab B
ok "Lab B: answers.txt saved"                        '[ -s "$LAB/answers.txt" ]'
# Lab C
want="23422ac60a0b895f4f4e51b5a14fa9bc"
got=$(md5sum "$LAB/server_notes.txt" 2>/dev/null | cut -d' ' -f1)
ok "Lab C: server_notes.txt fixed with vi"           '[ "$got" = "$want" ]'
# Lab D
for s in sysinfo backup guess failreport; do
  ok "Lab D: ~/bin/$s.sh exists and is executable"   "[ -x \"$B/$s.sh\" ]"
done
ok "Lab D: sysinfo.sh prints the host name"          '"$B/sysinfo.sh" 2>/dev/null | grep -q "$(hostname)"'
before=$(ls "$HOME/backups" 2>/dev/null | wc -l)
"$B/backup.sh" "$LAB" >/dev/null 2>&1
after=$(ls "$HOME/backups" 2>/dev/null | wc -l)
ok "Lab D: backup.sh makes a new file in ~/backups"  '[ "$after" -gt "$before" ]'
ok "Lab D: backup.sh rejects a non-folder"           '[ -x "$B/backup.sh" ] && ! "$B/backup.sh" /nope >/dev/null 2>&1'
ok "Lab D: guess.sh says Correct"                    'seq 1 10 | timeout 5 "$B/guess.sh" 2>/dev/null | grep -qi "correct"'
ok "Mini project: failreport.sh shows root 10"       '"$B/failreport.sh" 2>/dev/null | grep -qE "^root[: ]+10$"'

if [ "$got" != "$want" ] && [ -f "$LAB/server_notes.txt" ]; then
  echo
  echo "Hint for Lab C (lines that still differ):"
  printf '%s\n' "Server Notes" "============" "Hostname: web01" "OS: Ubuntu Server 24.04" \
    "Role: web server (nginx)" "Admin: student" "Backup: every night at 02:00" \
    "Status: running" "Contact: admin@example.com" "Note: Ubuntu updates are automatic" \
    | diff "$LAB/server_notes.txt" - | grep '^[<>]'
fi
echo "----------------------------------"
echo "Score: $pass / $total"
