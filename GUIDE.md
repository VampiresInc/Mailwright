# Mailwright

Created by **Arametheus**.

Mailwright 0.2.0-alpha.7 is an independently implemented mailbox addon inspired
by Postal's workflow. It uses its own Lua modules and account-wide MailwrightDB;
no Postal source or bundled libraries are included in the Mailwright package.

Features in this alpha:

- Open all, money-only collection, attachment/money/auction filters, free-slot
  reserve, server acknowledgement, operation timeout and cancellation.
- Message selection, Shift ranges, Ctrl same-sender selection, collect/return
  selected messages, expiry indicators, paging, confirmed empty-message deletion.
- Contacts, recent recipients, alts, friends, guild and clickable autocomplete.
- Forever first/last names and Normal/PvP ruleset groups; incompatible known alts
  are disabled and excluded from autocomplete. Unknown contacts are not guessed.
- Multiline contact export/import at the bottom of the Contacts menu. Backups
  preserve client, realm and ruleset information. Plain one-name-per-line imports
  support moving existing contacts from the previous local Postal build.
- Quick attach by category, minimum quality and bag, with category recipients.
- Alt-click attachment, Alt+Ctrl-click matching stacks and optional Express send.
- Copy/read mail, safe forward drafts, money subjects, collected-money summary,
  and temporary trade blocking with restoration of the previous setting.

## Installation

Extract the Mailwright folder into the target client's Interface/AddOns folder.
Fully restart WoW, disable Postal, and enable Mailwright on each character.
The addon refuses concurrent mailbox automation while Postal is loaded.

Mailwright adds controls directly to the game's mailbox. Checkboxes beside inbox
rows select mail; Open and Return act on that selection. The small arrow beside
To opens Contacts. The title-bar arrow opens options, and the category icons down the right edge provide Quick attach.
Right-click a category icon for attachment options. Copy and Forward appear on the native opened-message frame.
Normal mail clicks and page buttons retain the game's own behavior. Shift-click
a native mail icon to collect; Ctrl-click to return. Click an expiry label to
return a message or confirm deletion of an empty one. There is no companion inbox
window. Copy and contact import/export open a text dialog only when requested.

Commands: /mw, /mwstatus, /mw export, /mw import.

## Client targets and limits

Manifests target Retail 12.1.0, Classic Mists 5.5.4 and Forever 1.60.1. Separate
legacy Classic manifests are also supplied. Retail, Forever, Era, Mists, and Anniversary have been tested
in game by the author. Manifest
declarations and mocked tests are not certification of compatibility.
The Camelot manifest explicitly marks Forever, whose project ID resembles Retail.

COD and GM mail are never collected automatically. Mailwright does not automatically
delete empty letters. Forwarding leaves a draft for review and supports text and
distinct, cached, non-stackable attachments that are not already in your bags.
Other attachments must be collected and attached manually. Quick attach skips
uncached, locked or bound items. On legacy clients without binding information,
items with binding rules are conservatively excluded from bulk attachment.
Normal backpack/bag slots are scanned; bank and reagent-only bag slots are excluded.

Automatic Express sending is off by default and does not send money or COD drafts.
Cross-ruleset checks apply to Mailwright's recipient selection and automatic send;
they cannot validate unknown recipients or change the game's native Send behavior.

The database initializes at the addon's ADDON_LOADED event. /mwstatus distinguishes
loaded data from a new database. If a beta client fails to load SavedVariables,
an addon cannot guarantee persistence. Export contacts before closing the game
until reload/logout tests pass on your build. No personal contacts are hardcoded.

### Forever saved-data validation

Build 1.60.1.69913 previously failed to reload saved variables. On September 25,
2026, Arametheus confirmed native loading and full-restart persistence on installed
build 1.60.1.70009 with all local forced-load entries disabled. Forever 0.2.2 is
released without the workaround. Older affected clients should be updated.
The local backup remains available for recovery; public ZIPs contain no personal data.

See TESTING.md for migration steps and the in-game retest checklist.

## Development

Run tests/run.py with Python and lupa.lua51 available. The workspace test runner
also finds the local .tools installation in the repository root. Run tools/package.py
to build a verified ZIP in the repository dist folder. tools/install.ps1 installs only
Mailwright files into a specified AddOns folder, backing up existing Mailwright
first and leaving Postal and SavedVariables untouched.

## License and acknowledgement

Mailwright uses the All Rights Reserved license in LICENSE. Players may install and use unmodified releases; code modification, reuse, and redistribution require prior written permission, subject to the exceptions in that license. Earlier MIT grants remain in effect for previously published code.
Postal inspired the feature goals. Thanks to its original authors and maintainers,
and in remembrance of the community members who kept it working over the years.
Mailwright is an independent project, not an official Postal continuation.
The license covers Mailwright's original files only; it does not relicense Postal.

Recipient lists use hover submenus and Part groups for long lists. Alt and guild
entries show available level/class details in class colors, plus guild ranks.
Move away to dismiss the menus, or click a name to address your draft.

## Automated releases

Retail and Forever use separate version tags and packages. Update the corresponding
client TOC version and RELEASE_NOTES.md, then push a matching tag. Retail v0.2.0
is stable; Forever v0.2.2 is stable following native persistence validation. Era, Mists, and Anniversary are tested and included in v0.2.1. Wrath and Cataclysm are excluded.
The release builder selects all client manifests matching the tag. It embeds
that client version in Core.lua inside the ZIP and includes only that client's TOCs.
Artifacts are in dist/release/<tag>/. Tests run before publication.
Do not reuse tags or manually create a release while its workflow is running.

Wago GitHub automation can ingest the client-specific assets using Multiple game
versions. Leave Always publish for latest game patch unchecked. Verify classification
and patch mapping after the first run. CurseForge uploads use the CF_API_KEY GitHub Actions repository secret and project 1706898. Keep native CurseForge packaging disabled. The uploader derives the exact game patch from the packaged interface number and the release channel from the tag. Failed uploads are not retried automatically; inspect the project before retrying to avoid duplicates.
The legacy tools/package.py creates a combined development archive; do not publish
that archive as the stable Retail release.
