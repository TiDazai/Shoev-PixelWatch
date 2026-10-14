# Troubleshooting

| Symptom | Action / explanation |
| --- | --- |
| Permission required after restart | Grant persistent Screen Recording, or select the source again. Picker authorization can be session-only. |
| Permission was granted but capture still fails | Quit and reopen PixelWatch. macOS may require this when changing TCC grants. Keep the app at a stable path. |
| Waiting for source | Restore the window, wake/reconnect the display, check screen permission or use Select a new source. |
| Resolution changed | Reselect the rectangle. PixelWatch refuses to silently monitor the wrong physical area. |
| Window app restarted | Select its new window. The old ID/PID is deliberately not rebound automatically. |
| Blank or protected content | No condition is evaluated for uniform black/invalid frames. Capture access depends on macOS and the source application. |
| Text Disappears never fires on blank area | Blank OCR is inconclusive. Use readable replacement text and ensure the target was confirmed before changing it. |
| OCR is inconclusive | Select readable text with better contrast/larger font and fewer irrelevant lines. A low-confidence recognized line can invalidate the result. |
| No banner but history has an event | Check PixelWatch Notifications settings, OS authorization, Focus and system banner configuration. Detection works without permission. |
| Notification test does nothing | Enable app notifications and OS permission. Test Notification reports denied permission; Focus can still suppress presentation. |
| Too many visual changes | Lower sensitivity, increase confirmations, select a smaller region or use Change After Stability. Screen Region sees overlapping apps. |
| Equal-brightness color changes are missed | The grayscale comparator prioritizes shape/brightness and intentionally reduces color noise. |
| Source disappears during sleep | Expected. Capture stops; recovery establishes a fresh baseline rather than inventing an event. |
| Launch at Login does not work | Keep the app in `/Applications`; inspect System Settings → General → Login Items. Toggle registration again after moving it. |
| Saved JSON is corrupt | PixelWatch preserves it and refuses to overwrite it. Inspect/back up the shown local path. Delete All Local Data explicitly resets storage. |
| App isn't trusted on another Mac | Local artifacts are ad-hoc-signed. For public distribution use your Developer ID signing certificate and notarization; see RELEASE.md. |
| CPU/energy seems high | Increase the interval, reduce watched area and pause unused watches. Compare analysis time and skipped frames in details. No arbitrary CPU guarantee is made. |

For development, build and test with the exact commands in README. The initial local Vision model load can be much slower than subsequent calls, and the OS framework can emit internal model diagnostics while tests still pass. PixelWatch itself does not log captured text or images.
