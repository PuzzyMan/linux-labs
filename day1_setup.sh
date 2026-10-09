#!/bin/bash
# Day 1 lab setup (Lab 5-9)
# Run as your normal user:  bash day1_setup.sh
# Creates ~/lab1 (old ~/lab1 is deleted and rebuilt)

LAB="$HOME/lab1"
echo "== Setting up $LAB =="
rm -rf "$LAB"
mkdir -p "$LAB"
cd "$LAB" || exit 1

# ---------- Lab C: treasure hunt ----------
for d in north south east west; do
  for s in cave forest river; do
    mkdir -p "hunt/$d/$s"
    echo "Nothing here. Keep looking." > "hunt/$d/$s/note.txt"
  done
done
mkdir -p hunt/south/forest/.secret/deep
echo "FLAG-1: LINUX"  > hunt/north/cave/.flag
echo "FLAG-2: IS"     > hunt/east/river/.flag
echo "FLAG-3: FUN"    > hunt/south/forest/.secret/deep/.flag
echo "FLAG-4: TO"     > hunt/west/.flag
echo "FLAG-5: LEARN"  > hunt/.flag
echo "FAKE FLAG - not hidden, does not count" > hunt/north/river/flag
echo "FAKE FLAG - backup copy, does not count" > hunt/east/cave/.flag.bak
cat > hunt/README.txt <<'EOF'
TREASURE HUNT
There are 5 hidden files named .flag inside this folder.
One of them is inside a hidden folder.
Put the 5 words in order FLAG-1 to FLAG-5 into ~/lab1/flags.txt
Example:  echo "WORD1 WORD2 WORD3 WORD4 WORD5" > ~/lab1/flags.txt
EOF

# ---------- Lab D: messy folder ----------
mkdir -p messy
cd messy || exit 1
for i in $(seq -w 1 15); do head -c 20000 /dev/urandom > "photo$i.jpg"; done
for i in 2001 2002 2003 2004 2005; do head -c 20000 /dev/urandom > "IMG_$i.JPG"; done
for m in jan feb mar apr may jun jul aug sep oct nov dec; do
  for n in $(seq 1 200); do echo "Monthly report $m line $n: all systems normal"; done > "report_$m.txt"
done
for i in 1 2 3 4 5; do
  for n in $(seq 1 100); do echo "Meeting notes $i item $n"; done > "notes$i.txt"
done
for i in 1 2 3 4 5 6; do
  for n in $(seq 1 300); do echo "2026-10-09 10:00:$((n % 60)) app$i INFO request $n ok"; done > "app$i.log"
done
for i in 1 2 3; do
  for n in $(seq 1 100); do echo "2026-10-09 11:00:$((n % 60)) ERROR code $i$n"; done > "error_$i.log"
done
for i in $(seq 1 8); do echo "temporary file $i" > "temp$i.tmp"; done
cd "$LAB" || exit 1

# ---------- Lab A/B/quiz helper files ----------
echo "This is a notes file for the quiz." > "$LAB/notes.txt"

# ---------- check tools used today ----------
missing=""
for c in man locate zip unzip bzip2 xz; do
  command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
done
echo
echo "Done. Created:"
echo "  $LAB/hunt   (Lab C: treasure hunt)"
echo "  $LAB/messy  (Lab D: 54 files to organize)"
if [ -n "$missing" ]; then
  echo
  echo "WARNING: missing commands:$missing"
  echo "Run this once on your VM, then run day1_setup.sh again:"
  echo "  sudo apt update && sudo apt install -y man-db plocate zip unzip bzip2 xz-utils && sudo updatedb"
fi
