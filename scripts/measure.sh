#!/bin/sh
# Measures how light Pix is, sampling once a second so every stroll and fidget is caught: its CPU
# (average and peak), its memory footprint (start, end, peak — the number Activity Monitor shows, not
# RSS, which also counts shared system frameworks), its energy impact and idle wakeups per second, plus
# the CPU of TouchBarServer, the macOS process that draws the Touch Bar (it works harder the more Pix
# animates).
#   scripts/measure.sh [seconds] [label]      defaults: 300 seconds, "measurement"
# Set the scene first (an app in front, battery or charger, the window in December, Pix hidden for a
# baseline), keep your hands off the Mac, and paste the row it prints into the README's table.
set -e
DURATION="${1:-300}"
LABEL="${2:-measurement}"

pid() { pgrep -x "$1" | head -1; }
PIX="$(pid Pix)"
[ -n "$PIX" ] || { echo "Pix isn't running: open it first." >&2; exit 1; }
TBS="$(pid TouchBarServer)"

echo "Measuring for $DURATION s ($LABEL). Hands off the Mac…" >&2
# top's first sample has no CPU baseline, so take one extra and skip it.
top -l $((DURATION + 1)) -s 1 -pid "$PIX" ${TBS:+-pid "$TBS"} -stats pid,cpu,mem,idlew,power |
awk -v pix="$PIX" -v tbs="$TBS" -v label="$LABEL" '
  function mb(m,   u, v) { u = substr(m, length(m)); v = m + 0
    return u == "G" ? v * 1024 : u == "K" ? v / 1024 : u == "B" ? v / 1048576 : v }
  $1 == "PID" { sample++ }
  sample < 2 || ($1 != pix && $1 != tbs) { next }
  $1 == tbs { tcpu += $2; next }
  { n++; cpu += $2; if ($2 > peak) peak = $2; power += $5
    gsub(/[+-]$/, "", $3); m = mb($3); if (n == 1) { first = m; wake0 = $4 + 0 }
    last = m; if (m > maxm) maxm = m; wake1 = $4 + 0 }
  END {
    if (!n) { print "No samples: did Pix quit?" > "/dev/stderr"; exit 1 }
    t = "n/a"; if (tbs != "") t = sprintf("%.2f%%", tcpu / n)
    w = n > 1 ? (wake1 - wake0) / (n - 1) : 0
    print "| Scene | Pix CPU (avg / peak) | Pix memory (start → end, peak) | Pix energy impact | Pix idle wakeups/s | TouchBarServer CPU |"
    print "|---|---|---|---|---|---|"
    printf "| %s | %.2f%% / %.1f%% | %.1f → %.1f MB, %.1f MB | %.2f | %.2f | %s |\n", label, cpu / n, peak,
      first, last, maxm, power / n, w, t
  }'
