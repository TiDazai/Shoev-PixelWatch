# Release build and distribution

From the project directory:

```sh
./scripts/build-release.sh
./scripts/create-dmg.sh
```

This creates `dist/SHOEV PixelWatch.app` and `dist/SHOEV-PixelWatch-0.1.4.dmg` using tools shipped with Xcode/macOS. The app contains arm64 and x86_64 slices and targets macOS 26.0. Native XCTest execution is verified on the current Apple Silicon host; Intel hardware testing is separate.

Equivalent manual build:

```sh
xcodebuild -project PixelWatch.xcodeproj -scheme PixelWatch \
  -configuration Release -derivedDataPath build-release \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- build
```

The provided artifacts use local ad-hoc signing. They are not Developer ID signed or notarized, because no publishing credentials were supplied. For public GitHub Releases or the official website, build using your Apple Developer team and a real Developer ID Application identity, with hardened runtime enabled. In Xcode configure Signing & Capabilities for that team and archive the PixelWatch scheme; export using Developer ID. The project uses no audio, microphone or network entitlements.

Alternatively sign the Release app using your own certificate name (replace the placeholder), then package it:

```sh
codesign --force --options runtime --timestamp \
  --sign 'Developer ID Application: YOUR ACTUAL CERTIFICATE NAME' \
  'dist/SHOEV PixelWatch.app'
./scripts/create-dmg.sh
```

Submit the DMG using a Keychain-stored notarization profile you have configured, then staple and validate:

```sh
xcrun notarytool submit dist/SHOEV-PixelWatch-0.1.4.dmg \
  --keychain-profile YOUR_PROFILE --wait
xcrun stapler staple dist/SHOEV-PixelWatch-0.1.4.dmg
xcrun stapler validate dist/SHOEV-PixelWatch-0.1.4.dmg
codesign --verify --deep --strict 'dist/SHOEV PixelWatch.app'
spctl --assess --type execute --verbose 'dist/SHOEV PixelWatch.app'
```

Keep signing credentials out of source control. Verify the signed/notarized build on another Mac with fresh Screen Recording/notification permissions before publishing. Do not change the bundle ID (`systems.shoev.pixelwatch`) between upgrades if existing grants/data are to remain associated with the same product.

The committed Xcode project needs no generator. `scripts/generate-project.py` is an optional maintenance utility for adding/removing source files; it requires Python only when regenerating the project, never at app runtime or for normal builds. Regenerate the app icon and documentation preview with `./scripts/create-icon.sh` (AppKit vector source: `scripts/create-icon.swift`); these are maintenance tools, not runtime dependencies.
