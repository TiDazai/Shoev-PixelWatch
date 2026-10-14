#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
stage="$(mktemp -d /tmp/pixelwatch-icon.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/PixelWatch.iconset" "$root/docs/assets"
swift "$root/scripts/create-icon.swift" "$stage/master.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$stage/master.png" --out "$stage/PixelWatch.iconset/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$stage/master.png" --out "$stage/PixelWatch.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$stage/PixelWatch.iconset" -o "$root/PixelWatch/Resources/PixelWatch.icns"
cp "$stage/master.png" "$root/docs/assets/PixelWatch-icon.png"
