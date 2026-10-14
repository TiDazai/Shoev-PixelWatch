# User guide

1. Launch PixelWatch and finish onboarding. Grant Screen Recording for persistent monitoring when prompted.
2. Click its menu bar icon and choose **New Watch**.
3. Choose **Screen Region** or **Application Window**. In the macOS picker select one display/window. Requires macOS 26.0 or newer.
4. For Screen Region, drag a rectangle. Drag inside to move it; drag outside to redraw/resize it. Press Return to confirm, Escape to cancel. The dimensions are in display points; Retina scaling happens automatically.
5. Name the watch and choose a rule. Click **Start Watching**. Notifications can be enabled after starting; event history works even if they are denied.

## Choose a rule

| Rule | Recommended use | Initial state |
| --- | --- | --- |
| Any Visual Change | A picture, chart or status area changes | First usable frame becomes reference |
| Text Appears | “In stock” or “Completed” appears | Target must match on consecutive reliable checks |
| Text Disappears | “Processing” becomes “Completed” | Target presence must first be confirmed |
| Text Changes | “Pending” becomes “Approved” | A stable initial text value must first be confirmed |
| Visual Change After Stability | A loader settles before a meaningful change | The area must stay stable for the configured duration |

Use higher sensitivity to detect smaller changes, a longer interval to reduce capture/analysis work, and more confirmations for noisy content. The minimum is two confirmations. Cooldown is the minimum time between events. Continuous rules rearm only after an opposite condition (or a new accepted reference state) is established; they do not repeatedly alert for the same value.

“Match the entire recognized text” requires the normalized entire selected region to equal the target. The default substring search is better when there are labels such as “Status: Completed.” Matching ignores case and normalizes whitespace. English and Cyrillic recognition happens locally.

## Control watches

Open Dashboard from the menu. Select a watch to see its latest preview, rule, current status, last successful check, metrics and event history. Pause/Resume and Edit work from both the list and detail area. Delete removes that rule and its events. **Select a new source** edits the existing watch while retaining its name, rule and history; it is useful after resolution changes, app restarts or expired picker authorization.

Pause All and Resume All act on all rules. Resume starts a new baseline, including for a previously Triggered one-shot. Close Dashboard to keep working; monitoring continues from the menu bar. Quit stops capture and exits.

## Settings

General controls launch at login, start minimized and menu bar counts. The full UI supports Russian and English; switching language updates windows/menu items immediately. Russian is the default for fresh installs. Monitoring sets defaults for new rules. Notifications controls app delivery, sound and permission/testing. Privacy shows screen permission, data location, history deletion and full local-data removal. About contains verified product information without invented external links.

For launch at login, keep the app in a stable installed location such as `/Applications`. macOS may require enabling the login item in System Settings. A development app moved between build folders can need re-registration.

## Sources

Screen Region watches visible pixels at a fixed rectangle on one monitor. Covering that rectangle changes what it sees. Window Mode uses a desktop-independent source; moving that window does not change its identity. Minimized, closed or protected windows may not provide frames. PixelWatch waits for a usable source rather than treating that loss as a match.

A disconnected display can recover using its UUID. Resolution changes require reselection. A source app restart requires selecting its new window. After sleep/unlock or source loss, pending confirmations and baselines reset; Text Disappears must observe its target again. This favors avoiding false events during gaps.
