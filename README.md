# Mailwright

A World of Warcraft mail addon by **Arametheus**, inspired by Postal and built into the game's mailbox.

## Features

- Open all mail, collect money, or open and return selected messages.
- Contacts, recent recipients, alts, friends, and guild menus.
- Hover menus with class colors and level details for alts and guild members.
- Quick attachments, Alt-click item attachment, and optional Express sending.
- AddOns settings panel and optional attachment side tabs.
- Copy mail text and prepare forwarding drafts.
- Export and import contacts for backups.
- Forever first and last names, with Normal/PvP ruleset grouping.

## Installation

Place the **Mailwright** folder in your client's `Interface/AddOns` folder, restart WoW, and enable it. Disable Postal while using Mailwright.

Open a mailbox to get started. The arrow beside **To** opens contacts; the title-bar arrow opens options.

## Options

Configure Mailwright through the game Settings > AddOns > Mailwright panel (Interface > AddOns on older clients), or choose **All settings...** in the mailbox options menu. Turn off **Show attachment tabs** to hide the side icons; Quick attach remains available in the mailbox menu. Changes are saved immediately; no reload is required. Attachment tabs are visible by default.

## Compatibility

**Release:** Retail 12.1.0, Classic Era 1.15.9, Mists Classic 5.5.4, and Burning Crusade Anniversary 2.5.6. Download the ZIP for your client. Forever 1.60.1 is also supported. Version 0.2.4 provides separate packages for all five clients. Retail PTR 12.1.5 is not yet verified.

**Forever:** Native saved-data loading passed a full restart test on build 1.60.1.70009 with the local forced-load workaround disabled. The release uses normal SavedVariables loading; no workaround is included.

## Slash commands

- `/mw` - Show Mailwright's options while a mailbox is open; otherwise, print version and saved-data status.
- `/mwstatus` - Show version and saved-data status.
- `/mw export` - Export contacts.
- `/mw import` - Import contacts.

[Report an issue](https://github.com/VampiresInc/Mailwright/issues) | [Usage and development guide](https://github.com/VampiresInc/Mailwright/blob/main/GUIDE.md)

## Credits

Inspired by Postal, with thanks to its original authors and maintainers. Mailwright is an independent project, released under the [All Rights Reserved license](LICENSE).
