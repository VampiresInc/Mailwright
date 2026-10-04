# Mailwright 0.2.4 - Settings and optional attachment tabs

- Add a Mailwright panel to the game AddOns settings, accessible away from a mailbox.
- Add a saved Show attachment tabs option. Tabs remain visible by default; Quick attach remains available when they are hidden.
- Add an All settings shortcut to the mailbox options menu.
- Keep the panel and mailbox option toggles synchronized, with immediate changes.
- Apply the Block trades setting only while a mailbox is open.
- Include the Forever split-surname alt recording fix from 0.2.3.
- Clarify /mw behavior and configuration instructions in the README.

Packages: Retail 12.1.0, Classic Era 1.15.9, Mists Classic 5.5.4,
Burning Crusade Anniversary 2.5.6, and Forever 1.60.1.
The settings panel was checked in-game on Forever; automated regression tests
cover modern and legacy settings APIs. Retail PTR 12.1.5 remains unverified.

Download the ZIP for your client and extract Mailwright into Interface/AddOns.
Disable Postal while using Mailwright. Log into each Forever character again
if it was missing from the alt list before the surname fix.

All Rights Reserved. See LICENSE for permitted use and earlier MIT grants.
