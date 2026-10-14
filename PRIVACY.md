# Privacy

PixelWatch 0.1.0 processes only sources deliberately selected by the user. Onboarding, an empty dashboard and the test suite never start screen recognition. Persisted active watches resume only with macOS authorization and an available matching source.

All capture, image analysis and Vision text recognition run locally. The app contains no networking client, external API, cloud backend, telemetry, analytics, account or subscription. It never captures system audio or the microphone. ScreenCaptureKit's source authorization is controlled by macOS.

Frames and preview images exist only in memory. A stream retains one latest complete cropped image; the dashboard retains one latest preview per watch. Those previews are released when a watch is deleted or all local data is removed. Images are never saved in JSON, logs or diagnostic files. App-generated diagnostic counters contain only timings and counts.

Saved files live at:

```text
~/Library/Application Support/SHOEV PixelWatch/pixelwatch.json
```

The JSON contains settings, source identifiers, region geometry, rules, status/timestamps and up to 500 textual events. Text events may contain recognized contents of the selected region when required by the rule. PixelWatch does not save whole-screen OCR transcripts. OS notifications can also display event text and are subject to macOS notification retention. Rules/event text are plain local JSON, readable by your user account; the application support folder uses mode 0700 and the file uses 0600.

**Settings → Privacy → Clear Event History** removes saved textual events. **Delete All Local Data** stops monitoring, removes all rules/settings/history, clears in-memory previews and app-owned window preferences, and removes PixelWatch pending/delivered notifications. It does not change the OS Screen Recording or notification grants, uninstall the app or unregister Launch at Login; these are managed separately in System Settings/General. macOS backups and OS-managed logs/notification artifacts are outside PixelWatch's storage control.

Source/permission loss never becomes a detected change. Blank OCR is inconclusive. Uniform black capture is conservatively rejected; macOS does not expose an infallible signal for every protected-content case. Screen Region follows visible pixels and can include another application's content if it covers that area. Select a small region and use Window Mode when you want one particular window.
