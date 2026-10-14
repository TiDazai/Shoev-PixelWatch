# Changelog

## 0.1.2 — 2026-10-14

- Simplify the central cat-eye mark to a smaller gold almond outline and slim vertical pupil.
- Remove iris fibers, reflections, dark fill and the extra border; keep the SHOEV platinum/silver frame.

## 0.1.1 — 2026-10-14

- Require macOS 26.0 or newer across the app, test targets and core package.
- Remove the macOS 15 legacy source list and availability branches; retain the native ScreenCaptureKit picker.
- Move CI to macOS 26 with Xcode 26.3, keeping rule, OCR, capture and localization regression tests.
- Replace the central icon pixel with a distinct gold feline iris, vertical pupil and platinum highlights; preserve the SHOEV metal frame and palette.

## 0.1.0 — 2026-10-14

Initial native macOS implementation for SHOEV PRODUCTS.

- ScreenCaptureKit display/window selection, screen-region overlay and persistent capture sessions.
- Five independent detection modes with confirmation, rearming, cooldown, one-shot and continuous operation.
- Local English/Russian Vision OCR and Accelerate grayscale image comparison.
- Menu bar operation, dashboard/details/editor, native notifications, settings and onboarding.
- Codable atomic local persistence, explicit lifecycle transitions and source recovery.
- Privacy controls, bounded diagnostics/history, launch at login and light/dark appearance.
- Shared Xcode application/XCTest scheme, standalone core Swift package, deterministic tests and offline HTML test lab.
- Universal Release and DMG packaging scripts.

### SHOEV branding and Russian UI

- Adopted the SHOEV platinum/gold/silver palette from existing SHOEV products; regenerated the native icon and offline test page.
- Added complete Russian/English localization, immediate language switching, native menu/window/overlay translations and localized notifications/history.
- Added backwards-compatible event presentation metadata, localization catalog/format audits and compiled resource regression coverage.
- Prepared a dedicated public GitHub repository and automated macOS build/test workflow.

### 0.2.0 candidates

- Broader localization coverage beyond Russian and English.
- Editable ignore masks for timestamps, cursors and animated subregions.
- Adaptive capture cadence and measured energy/CPU profiling on Intel and Apple Silicon hardware.
- Optional encrypted event history and per-watch retention controls.
- Better tiny-text image signatures and semantic text-change comparisons.
- Dedicated capture integration test machines for TCC, source picker, sleep, monitor hotplug and notification routing.
- Optional explicit window rebind suggestions after a source application restarts, always confirmed by the user.
