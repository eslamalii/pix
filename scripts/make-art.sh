#!/bin/sh
# Regenerates the art in Art/ from the art contract, in the Glass style. Overwrites existing files,
# including any you've replaced with your own drawings. --check only type-checks the generator (CI runs it).
set -e
cd "$(dirname "$0")/.."
SOURCES="scripts/art/main.swift Sources/AmbientCore/ArtContract.swift Sources/AmbientCore/Spot.swift Sources/AmbientCore/Hat.swift
    scripts/art/halloween.swift Sources/AmbientCore/Halloween.swift"
if [ "$1" = "--check" ]; then
    swiftc -typecheck $SOURCES
    exit
fi
TOOL="$(mktemp -d)/make-art"
swiftc -O -whole-module-optimization $SOURCES -o "$TOOL"
"$TOOL" Art
