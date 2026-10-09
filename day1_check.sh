#!/bin/bash
# Day 1 checker:  bash day1_check.sh
LAB="$HOME/lab1"
M="$LAB/messy"
pass=0; total=0
ok(){ total=$((total+1)); if eval "$2"; then pass=$((pass+1)); echo "[ OK ] $1"; else echo "[ -- ] $1"; fi; }
cnt(){ ls -1 "$1" 2>/dev/null | grep -c .; }

echo "== Day 1 check for $(whoami)@$(hostname) =="
ok "Lab C: flags.txt has the 5 words in order" \
   '[ -f "$LAB/flags.txt" ] && [ "$(tr a-z A-Z < "$LAB/flags.txt" | tr -s " " | sed "s/ *$//")" = "LINUX IS FUN TO LEARN" ]'
ok "Lab D: images/ has 20 files (.jpg + .JPG)"   '[ "$(cnt "$M/images")" -eq 20 ]'
ok "Lab D: docs/ has 17 .txt files"              '[ "$(cnt "$M/docs")" -eq 17 ]'
ok "Lab D: logs/ has 9 .log files"               '[ "$(cnt "$M/logs")" -eq 9 ]'
ok "Lab D: no .tmp files left"                   '! ls "$M"/*.tmp >/dev/null 2>&1'
ok "Lab D: no loose files left in messy/"        '[ -z "$(find "$M" -maxdepth 1 -type f 2>/dev/null)" ]'
ok "Lab D: notes1.txt renamed to meeting_notes.txt" '[ -f "$M/docs/meeting_notes.txt" ] && [ ! -e "$M/docs/notes1.txt" ]'
ok "Lab D: docs_backup/ copy has 17 files"       '[ "$(cnt "$M/docs_backup")" -eq 17 ]'
ok "Lab E: messy_backup.tar.gz contains messy/images" \
   'tar -tzf "$LAB/messy_backup.tar.gz" 2>/dev/null | grep -q "messy/images/"'
ok "Lab E: logs1.tar.gz / logs2.tar.bz2 / logs3.tar.xz exist" '[ -f "$LAB/logs1.tar.gz" ] && [ -f "$LAB/logs2.tar.bz2" ] && [ -f "$LAB/logs3.tar.xz" ]'
ok "Lab E: messy.zip exists"                     '[ -f "$LAB/messy.zip" ]'
ok "Lab E: restored copy in restore/messy"       '[ "$(cnt "$LAB/restore/messy/images")" -eq 20 ]'
ok "Quiz: day1_history.txt saved"                '[ -s "$LAB/day1_history.txt" ]'
echo "----------------------------------"
echo "Score: $pass / $total"
