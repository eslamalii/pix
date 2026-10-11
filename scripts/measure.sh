#!/bin/sh
# Measures how light Pix is: its average CPU over a stretch of time and its memory, plus the CPU of
# TouchBarServer, the macOS process that draws the Touch Bar (it works harder the more Pix animates).
#   scripts/measure.sh [seconds] [label]      defaults: 120 seconds, "measurement"
# Set the scene first (an app in front, battery or charger, the window in December, Pix hidden for a
# baseline), keep your hands off the Mac, and paste the row it prints into the README's table.
set -e
DURATION="${1:-120}"
LABEL="${2:-measurement}"

pid() { pgrep -x "$1" | head -1; }
# Total CPU time a process has used, in seconds (ps prints [hh:]mm:ss.cc).
cpu_seconds() { ps -o time= -p "$1" | awk -F: '{ s = 0; for (i = 1; i <= NF; i++) s = s * 60 + $i; print s }'; }
rss_mb() { ps -o rss= -p "$1" | awk '{ printf "%.1f", $1 / 1024 }'; }
percent() { awk -v a="$1" -v b="$2" -v t="$3" 'BEGIN { printf "%.2f%%", (b - a) / t * 100 }'; }

PIX="$(pid Pix)"
[ -n "$PIX" ] || { echo "Pix isn't running: open it first." >&2; exit 1; }
TBS="$(pid TouchBarServer)"

echo "Measuring for $DURATION s ($LABEL). Hands off the Mac…" >&2
start=$(date +%s)
pix_before=$(cpu_seconds "$PIX")
[ -n "$TBS" ] && tbs_before=$(cpu_seconds "$TBS")
sleep "$DURATION"
elapsed=$(( $(date +%s) - start ))
pix_after=$(cpu_seconds "$PIX")
[ -n "$TBS" ] && tbs_after=$(cpu_seconds "$TBS")

pix_cpu=$(percent "$pix_before" "$pix_after" "$elapsed")
tbs_cpu="n/a"
[ -n "$TBS" ] && tbs_cpu=$(percent "$tbs_before" "$tbs_after" "$elapsed")

echo "| Scene | Pix CPU | Pix memory | TouchBarServer CPU |"
echo "|---|---|---|---|"
echo "| $LABEL | $pix_cpu | $(rss_mb "$PIX") MB | $tbs_cpu |"
