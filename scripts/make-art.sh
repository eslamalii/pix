#!/bin/sh
# Regenerates the art in Art/ from the art contract, in the Glass style. Overwrites existing files,
# including any you've replaced with your own drawings.
set -e
cd "$(dirname "$0")/.."
TOOL="$(mktemp -d)/make-art"
swiftc -O scripts/art/main.swift Sources/AmbientCore/ArtContract.swift Sources/AmbientCore/Spot.swift \
    scripts/art/halloween.swift Sources/AmbientCore/Halloween.swift -o "$TOOL"
"$TOOL" Art
