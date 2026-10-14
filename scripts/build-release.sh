#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$root/PixelWatch.xcodeproj" -scheme PixelWatch -configuration Release -derivedDataPath "$root/build-release" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- build
mkdir -p "$root/dist"
ditto "$root/build-release/Build/Products/Release/SHOEV PixelWatch.app" "$root/dist/SHOEV PixelWatch.app"
codesign --verify --deep --strict "$root/dist/SHOEV PixelWatch.app"
lipo -archs "$root/dist/SHOEV PixelWatch.app/Contents/MacOS/SHOEV PixelWatch"
