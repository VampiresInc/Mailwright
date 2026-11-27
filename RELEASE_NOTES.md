# Mailwright 0.2.15 - Controller UI safeguard and issue reports

## Controller UI: remembered recipient limitation

Remember last recipient is temporarily suspended while Blizzard's Controller UI is enabled, even if its checkbox is checked. The saved name and preference are retained, and autofill still works in the normal interface. This prevents the reproduced blocked-action error when leaving Send Mail in Forever's Controller UI. A notice now appears beside the setting and in the mailbox options menu in all supported languages.

This is a targeted safeguard, not a claim of complete gamepad compatibility. A controller-safe autofill approach remains under investigation. Mailwright's inbox controls are retained. Mailbox controls are prepared while the mailbox is closed to avoid first-open frame construction in active controller navigation.

## Issue log

Use `/mw issues`, or select Issue log in Mailwright options, to open a copyable diagnostic report. Copy all selects the report; press Ctrl+C to copy it. Reports include Mailwright version, game version/build/interface, client, locale, and available controller state. Saved entries retain their original game/build information and repeated issues are combined, with a 50-entry limit.

Run checks inspects initialization and APIs without sending, collecting or deleting mail. Clear log erases recorded history. Reports capture Mailwright-related errors, attributed blocked actions, selected operation failures, and controller errors near mailbox use (marked as cause unknown). No contact lists or mail content are collected. Capture may be incomplete when another error handler takes over.

Confirmed in-game on Forever: disabling remembered-recipient restoration in Controller UI stops the reproduced close error. Automated regression tests passed, including normal-interface restoration, controller suppression, issue-log persistence, and error-handler forwarding.

Packages: Retail 12.1.5, Classic Era 1.15.9, Mists Classic 5.5.4,
Burning Crusade Anniversary 2.5.6, and Forever 1.60.1.

All Rights Reserved. See LICENSE for permitted use and earlier MIT grants.
