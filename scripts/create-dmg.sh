#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/dist/SHOEV PixelWatch.app"
if [ ! -d "$app" ]; then echo 'Build Release first: ./scripts/build-release.sh'; exit 1; fi
stage="$(mktemp -d /tmp/pixelwatch-dmg.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/SHOEV PixelWatch.app"
cp "$root/LICENSE" "$stage/LICENSE.txt"
ln -s /Applications "$stage/Applications"
hdiutil create -volname 'SHOEV PixelWatch' -srcfolder "$stage" -ov -format UDZO "$root/dist/SHOEV-PixelWatch-0.1.2.dmg"
