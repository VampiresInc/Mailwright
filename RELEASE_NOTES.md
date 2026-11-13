# Mailwright 0.2.10 - Remember last recipient

- Remember the last successfully mailed recipient per character.
- Restore the recipient when the To field is empty after sending or reopening the mailbox, without overwriting a name already entered.
- Add Remember last recipient to AddOns settings and mailbox options, enabled by default, with translations for all supported languages.
- Keep recipient history separate between characters and Forever rulesets. Failed sends do not replace the saved recipient.

Confirmed working in-game on Retail by Arametheus. Automated regression tests passed, including successful sends, failed sends, opt-out, manual recipient preservation, saved-data reload, and character/ruleset isolation. Other clients have not received a new in-game validation for this feature.

Packages: Retail 12.1.5, Classic Era 1.15.9, Mists Classic 5.5.4,
Burning Crusade Anniversary 2.5.6, and Forever 1.60.1.

All Rights Reserved. See LICENSE for permitted use and earlier MIT grants.
