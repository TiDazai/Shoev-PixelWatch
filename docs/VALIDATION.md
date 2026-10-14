# Validation — 2026-10-15

Verification was performed on the available Apple Silicon macOS host using Xcode 26.3 (17C529), Swift 6.2.4 and the macOS 26.2 SDK, with a macOS 26.0 deployment target. Version 0.1.6 adopts the approved logo throughout the app, uses SHOEV SYSTEMS as the sole company brand and removes sentence-ending periods from interface copy. The native suite passed 55 tests during logo integration; the final copy changes passed 8 targeted native localization tests and the standalone core tests: 44/46 passed initially, then all three OCR tests passed in an isolated retry after two transient Apple e5rt compute-operation failures. The universal Release, embedded PNG/ICNS, signature and DMG were rebuilt and verified after the final changes.

| Check | Result |
| --- | --- |
| Xcode Debug compilation | Passed |
| Xcode hosted XCTest, arm64 | **55 tests passed; final localization follow-up: 8 tests passed, 0 failures** |
| Standalone Swift package XCTest | 44/46 passed initially; **all 3 OCR tests passed on retry**, covering the two initial e5rt error 13 failures |
| Release compilation | Passed for **arm64 and x86_64** |
| Universal executable verification | `lipo -archs` reports `x86_64 arm64` |
| Local code signature | `codesign --verify --deep --strict` passed (ad-hoc) |
| DMG creation | Passed; app, Applications shortcut and MIT license included |
| DMG checksum validation | `hdiutil verify` passed |
| Minimum OS in packaged app | Both Mach-O slices and Info.plist require macOS 26.0 |
| Icon transparency | PNG background samples have alpha 0; all 10 extracted ICNS sizes retain alpha 0 at the canvas corners |
| Info.plist / Xcode project | `plutil -lint` passed |
| Shared scheme / localization catalog | XML / JSON parsing passed; 173 translations audited |
| Incremental localization regression | Compiled Russian/English tables verified after a repeated build |
| Shell packaging scripts | `bash -n` passed |
| Debug startup and onboarding | Original flow inspected; all onboarding strings now have Russian/English translations |
| Native UI smoke check | Russian dashboard/settings and language switching verified in 0.1.0; 0.1.6 launched; primary logo verified on Dashboard and About, sole SHOEV SYSTEMS brand verified, Russian Dashboard copy verified without sentence-ending periods |
| Settings keyboard shortcut | Command-comma opens real functional settings |
| Russian/English interface switching | Verified without restart, including the Russian dashboard and rule parameters |
| Release startup | 0.1.6 packaged app launched, Dashboard and Settings inspected, then restarted to verify the final company name and copy |
| Real screen/window monitoring with permission | **Not verified in this environment** |
| Native notification delivery/click routing | Implemented, **not manually verified with an OS permission grant** |
| Sleep/lock/hotplug/protected source matrix | Implemented safeguards; **hardware/manual verification pending** |
| GitHub Actions macOS 26 runner | Configured for Xcode 26.3; see the repository Actions page for the new run result |
| Physical monitor/sleep checks on Intel/macOS 26 | **Not manually tested** |
| Developer ID signing / notarization | **Not performed**; no publishing credentials were provided |

The app's own Privacy screen reports Screen Recording permission required. No Screen Recording or notification permission was granted during this task. Real screen capture and notification delivery require the user's OS grant; unit tests do not substitute for the six permission-dependent manual acceptance scenarios. Use [MANUAL-TESTING.md](MANUAL-TESTING.md) to finish that acceptance pass.

The tests exercise all five detection modes, text normalization, confirmation/rearm/cooldown behavior, one-shot and continuous operation, OCR errors/empty text, source gaps, explicit lifecycle transitions, negative-origin monitor geometry, Retina output sizing, deterministic grayscale image differences, persistence/corruption/deletion and actual capture-buffer handling. The native frame tests verify blank/missing metadata invalidation, latest-frame backpressure, stopped-frame rejection and user-stop/permission-decline classification. Vision tests recognize locally rendered English and Russian text without any capture permissions.

No application Swift compilation errors or concurrency warnings remain. Xcode emits its standard AppIntents metadata notice for an app without an AppIntents dependency. Hosted tests can emit OS framework diagnostics for local Vision models or system services; these did not cause test failures. macOS on this host also reports that `hdiutil create` is deprecated, but creation/verification pass and that command remains compatible with the target macOS baseline.

Build/test logs are available in the ignored local directory `build/verification/`. The final XCTest result bundle is `build/Logs/Test/Test-PixelWatch-2026.10.15_00-52-41-+0400.xcresult`.

GitHub Actions verification for the final application code: [macOS build and tests](https://github.com/TiDazai/Shoev-PixelWatch/actions/runs/38635983897). The later documentation-only commit records the local Vision retry and does not change the verified application sources.

## Delivered artifact

`dist/SHOEV-PixelWatch-0.1.6.dmg` — SHA-256:

```text
ee24386ce3fcfa2c9982742bc229bb19070c1d54049d81f847cd214ab00b9d74
```

The app and DMG are ad-hoc-signed preview artifacts. Source code is published at https://github.com/TiDazai/Shoev-PixelWatch. [RELEASE.md](RELEASE.md) documents Developer ID signing and Apple notarization for public distribution. No CPU or energy-use limits are asserted without profiling.
