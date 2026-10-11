#!/bin/sh
# Records the real Touch Bar as a GIF, for the README and release posts: screencapture -b snaps the Touch Bar,
# over and over, and ffmpeg (brew install ffmpeg) turns the frames into a crisp, palette-exact GIF.
#   scripts/record-gif.sh [seconds] [out.gif]          defaults: 10 seconds, media/pix-touch-bar.gif
#   scripts/record-gif.sh --agent [out.gif]            plays the AI-agent story: working, asking, done (about 14 s)
# Show Pix on the Touch Bar first, and keep your hands off it while recording.
set -e
cd "$(dirname "$0")/.."
command -v ffmpeg >/dev/null || { echo "Needs ffmpeg: brew install ffmpeg" >&2; exit 1; }

AGENT=""
[ "$1" = "--agent" ] && { AGENT=1; shift; set -- 14 "${1:-media/pix-agent.gif}"; }
DURATION="${1:-10}"
OUT="${2:-media/pix-touch-bar.gif}"
FRAMES="$(mktemp -d)"
trap 'rm -rf "$FRAMES"' EXIT

if [ -n "$AGENT" ]; then  # the agent's hooks, on a timer, in the background
    ( open -g pix://agent/working; sleep 6; open -g pix://agent/waiting; sleep 4; open -g pix://agent/done ) &
fi

echo "Recording the Touch Bar for $DURATION s…" >&2
end=$(( $(date +%s) + DURATION )); n=0
while [ "$(date +%s)" -lt "$end" ]; do
    n=$((n + 1))
    screencapture -x -b "$FRAMES/$(printf %05d "$n").png"
done
fps=$(( n / DURATION )); [ "$fps" -ge 1 ] || fps=1
echo "$n frames (about $fps a second); making the GIF…" >&2

# One palette for the whole clip, no dithering: pixel art stays pixel-exact.
ffmpeg -loglevel error -y -framerate "$fps" -i "$FRAMES/%05d.png" \
    -vf "split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=none" -loop 0 "$OUT"
echo "Wrote $OUT ($(du -h "$OUT" | cut -f1))"
