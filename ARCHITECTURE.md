# Architecture

PixelWatch has two boundaries: a deterministic analysis core and a native platform shell. The same core sources are compiled into the app's module and the dependency-free `PixelWatchCore` Swift package so logic can be tested without app permissions.

## Data and state

`WatchConfiguration` contains the source identity, display-local geometry, validated rule parameters, status and timestamps. `WatchRule` defines the five modes, text condition, full/partial matching, sensitivity, interval, confirmation count, cooldown, one-shot/continuous behavior, reference mode and stable duration. `WatchStatus.transitioning` defines explicit user/lifecycle transitions. A pause or completed one-shot cannot become Active from a late analysis result.

`WatchEvent` stores a watch UUID, date, reason and textual before/after state. No event contains an image. History is limited to 500 events globally. `WatchRepository` atomically writes versioned Codable JSON and uses owner-only directory/file permissions. Corrupt or future-version data is preserved and never overwritten by a subsequent save.

## Capture and scheduling

`SourceSelectionController` uses `SCContentSharingPicker` for one display or one window, reading persistent source metadata from `includedDisplays`/`includedWindows`. The app supports macOS 26.0 and newer; no legacy source-selection path is retained. Display identity uses a Core Graphics UUID. Window identity includes window ID, application bundle and process ID; no heuristic substitutes a new window after the source app restarts.

`AreaSelectionController` owns an AppKit panel on the selected `NSScreen`. Selection geometry is local to that screen, so desktop origins and monitor ordering cannot affect saved coordinates. `RegionGeometry` converts bottom-left AppKit coordinates to top-left capture coordinates. The panel closes and leaves WindowServer before a preview is requested. It is never a monitoring source.

`CaptureService` owns a registry of persistent `CaptureSession`s, shared when source, rectangle and interval match. Each registry entry tracks its owner watch UUIDs. Window resizing updates stream output dimensions without constructing a stream for every check. Source geometry is validated even for reused streams, so display resolution changes are detected. Removing the last owner stops capture, removes the stream output and releases the retained image. One screenshot-manager request creates the configuration thumbnail; subsequent checks use a retained stream.

Each stream uses BGRA, no cursor, no audio/microphone, queue depth 3 and the rule's minimum frame interval. Region crops are in points; output respects Retina density while capping the longest edge at 2048 pixels. A single latest complete image replaces the previous one on a utility queue; no unbounded frame queue exists. Idle frames refresh source health without changing the retained image. Incomplete, blank, stale or stopped frames cannot enter the rule engine.

`MonitoringCoordinator` owns one serialized task. It obtains a shareable-source snapshot only when checks are due, resolves availability, acquires streams and sends analysis to a utility-priority detached task. After every suspension point, a per-watch generation and current status check reject stale results after pause/edit/delete/sleep. No two analyses accumulate for a watch. Successful OCR is cached for the same stream frame sequence, avoiding repeated Vision work on an unchanged idle frame. No stream is constructed once per check.

Existing monitoring is suspended during source selection, so a selection overlay cannot become a false event for another watch. A user-stopped stream becomes Paused and requires explicit Resume; a declined source grant is not automatically retried until Resume/reselection.

Workspace sleep and display-sleep notifications and the distributed screen lock/unlock notifications suspend capture. Recovery and stream errors clear baselines and pending confirmation counts. External monitor loss and minimized/closed windows become Waiting for source. A resolution change requires reselection. Paused and Triggered watches remain stopped until the user resumes them.

## Analysis

`ImageComparisonService` renders a 64×64 grayscale signature and uses Accelerate to calculate mean absolute difference with a 0.025 per-pixel dead band. Sensitivity maps to a threshold from 0.005 to 0.185. This suppresses small brightness, antialiasing and color noise; grayscale intentionally ignores changes consisting only of equal-luminance color shifts. It is an MVP perceptual signal, not a semantic image model.

`OCRService` uses a local accurate Vision request with supported English/Russian languages. It runs outside the main actor. Empty results or any recognized line below 0.55 confidence are inconclusive. Text normalization uses canonical Unicode, lowercase and collapsed whitespace.

`RuleEvaluationEngine` owns baseline images/text, candidate text, stable-time gating, confirmation/rearm counters and last-trigger time. Text Disappears first confirms target presence; missing frames, empty OCR or low confidence do not count as absence. A continuous text appears/disappears rule needs a confirmed opposite state before rearming. Text Changes promotes each newly confirmed value to the reference. Visual rules can compare against the original frame or last accepted stable state. Cooldown delays otherwise confirmed events; one-shot stops after its first event.

## Platform/UI

`WatchStore` handles observable local data and user actions. `AppDelegate` owns menu bar and window lifecycle. Closing a window cannot terminate monitoring. SwiftUI renders the dashboard, details, editor, onboarding and settings. Appearance uses semantic AppKit colors and the SHOEV platinum/gold/silver palette. `NotificationService` handles current authorization, native alerts, foreground banners and watch UUID navigation. Launch at login uses `SMAppService.mainApp`.

Swift language mode is 5 with complete concurrency diagnostics. `SCContentFilter` crosses the framework's callback boundary through `@preconcurrency import ScreenCaptureKit`, then stays main-actor-owned; it is read-only during selection/capture. `CaptureSession` is `@unchecked Sendable` with all frame state protected by `NSLock`; stream construction is main-actor-isolated and callbacks use one serial queue. CGImages are immutable and only handed to analysis tasks through a small explicit Sendable wrapper.

## Diagnostics and testing

Per-watch diagnostics expose successful checks, average analysis milliseconds, overwritten/skipped frames and capture retry/error count. They contain no images or recognized text and are not logged to the system console. No CPU/energy targets are claimed without measurement.

XCTest tests cover rule behavior, all debounce/rearm/cooldown cases, unavailable-source recovery, state transitions, deterministic image comparisons, Retina geometry, persistence, native capture lifecycle and local Vision fixtures. Hosted tests set `PIXELWATCH_TESTING=1` and suppress normal app startup. No actual permission grants are required. Manual tests remain necessary for Apple's picker, TCC, notifications, monitor hotplug and sleep.

## Localization and brand

Russian and English are complete app languages. New installations default to Russian; saved preferences are retained. `LocalizedRoot` observes the store and updates the environment locale for existing windows without discarding editor state. AppKit menus/window titles and selection hints use explicit language arguments through `L10n`. Events carry optional mode/target/difference metadata for language-independent presentation; older JSON events remain decodable and known legacy event messages are translated without modifying recognized text.

`Resources/Translations.json` is the authoritative dictionary for native strings. `scripts/generate-localization.py` creates the matching SwiftUI string catalog; `check-localization.py` validates key coverage and printf argument compatibility. Permission explanations use a proper InfoPlist.strings localization variant group, so incremental builds retain both compiled Localizable tables. A hosted regression test verifies every compiled Russian/English key.

Theme colors come from the existing SHOEV SYSTEMS website: platinum #E6E6EC, silver #969AA8 and gold #A98C57. Light controls use #856B3F for contrast; dark controls use #C2A366. Semantic green/yellow/red status colors are retained. The icon and offline test lab share this palette.

## Apple API references

- [ScreenCaptureKit overview](https://developer.apple.com/documentation/screencapturekit)
- [SCContentSharingPicker](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker)
- [SCContentFilter includedWindows](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/includedwindows)
- [SCContentFilter includedDisplays](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/includeddisplays)
- [SCStreamConfiguration](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration)
- [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)

Availability and imported signatures were checked against the installed macOS SDK headers and confirmed by compiling both architectures.
