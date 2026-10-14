# Manual end-to-end verification

Run the app, grant Screen Recording and notifications, then `open Demo/index.html`. Use small rectangles around individual status text so controls are outside the watched area. Wait until Last successful check and the preview update before changing the test page.

## Six MVP scenarios

1. **Text Disappears:** Select “Processing.” Set Text Disappears = `Processing`, default two confirmations. Wait at least two checks while it is present; press Complete on the page. Two reliable “Completed” checks should add one event and deliver one notification. The one-shot becomes Triggered and its capture stream stops.
2. **Text Appears:** Select “Out of stock.” Set Text Appears = `In stock`. Start, wait for successful checks, press Restock. Expect one event/notification after the configured confirmation count.
3. **Visual Change:** Select the silver visual panel. Set Any Visual Change. Wait for a baseline, then Change image. Expect an event. Small color/antialiasing noise should not continually alert at default sensitivity.
4. **Background/multiple watches:** Create two watches with different rules. Close Dashboard. Change both statuses. The menu bar remains available and both rules fire. Notification clicks open the right watch's details.
5. **Restart:** Quit and reopen PixelWatch. Saved rules and history remain; Paused/Triggered rules remain stopped. Active rules resume only with a permitted available source. Picker-only authorization may require persistent permission or reselection. Recovery gets a new baseline.
6. **Stop resources:** Pause a watch. Check no additional successful-check increments or events. Pause all watches: the macOS capture indicator should disappear after the last shared owner stops. Resume resets references; delete also releases capture. Quit removes the status item and all streams.

## Reliability matrix

- Continuous Text Appears: leave target visible for a minute; expect one event. Return to the opposite text for two checks, then restore target; expect a new event after cooldown.
- Text Disappears: start while target is absent; expect no event. Confirm it first. Blank the area; expect no event. Replace with readable text; expect an event after confirmations.
- Text Changes: Pending → Approved, then Approved → Completed in continuous mode. Each new stable value should trigger once; random flickering text should not.
- Stability: run animation before baseline stabilization; expect no events. Stop it and wait the stable-duration setting, then change the image; expect an event.
- Cover a Screen Region with another window: preview follows visible pixels and can legitimately change. Cover/move a Window Mode source: it should continue where macOS provides a desktop-independent frame.
- Minimize/restore/close the source window; quit/relaunch its app. Loss should never become a successful rule event. Reselect new app instances explicitly.
- Sleep/wake and lock/unlock the Mac. Monitoring should stop and later reestablish baselines. Events that happened during a gap are not reconstructed.
- Disconnect/reconnect an external display, rearrange monitors, test one monitor left/below primary (negative origins), change resolution and test 1×/2× Retina scaling. Resolution changes should request reselection.
- Stop sharing from the macOS capture control. A user-stopped stream should become Paused and stay stopped until explicit Resume/reselection.
- Revoke Screen Recording or notification permission. Screen loss should suspend evaluation; notification denial should retain detected events locally.
- Deny onboarding permission, cancel the system picker, press Escape in overlay, cancel the editor. No watch should start from these actions.
- Verify Light and Dark appearances in the SHOEV metallic palette, Russian/English switching without restart, localized menu items/event history/notifications, and resizing Dashboard, all list actions, defaults, login registration, test notifications, Finder location, history deletion and full data removal.

Use real notifications for this checklist. The unit tests only prove deterministic detection and state/resource behavior, not an OS permission grant or delivery under Focus.
