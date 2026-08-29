#!/usr/bin/env bash
set -euo pipefail

SOURCE=${1:?SVG source is required}
SIZE=${2:?icon size is required}
OUTPUT=${3:?PNG output is required}

mkdir -p "$(dirname "$OUTPUT")"
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert --width "$SIZE" --height "$SIZE" --output "$OUTPUT" "$SOURCE"
elif command -v inkscape >/dev/null 2>&1; then
  inkscape_output=${OUTPUT}.render.$$.png
  inkscape "$SOURCE" --export-type=png --export-width="$SIZE" --export-height="$SIZE" \
    --export-filename="$inkscape_output" >/dev/null 2>&1
  mv -f "$inkscape_output" "$OUTPUT"
elif command -v convert >/dev/null 2>&1; then
  convert "$SOURCE" -resize "${SIZE}x${SIZE}" "$OUTPUT"
else
  echo 'No SVG renderer found (need rsvg-convert, Inkscape, or ImageMagick).' >&2
  exit 1
fi
test -s "$OUTPUT"
