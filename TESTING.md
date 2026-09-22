# Mailwright retest checklist

Build: 0.2.0-alpha.6. Test Forever first, then Retail and Classic. Offline tests use
mocked APIs; they cannot establish compatibility with the actual client or server.

## Setup and existing contacts

1. While the old Postal is still enabled, export contacts to a text file.
2. Fully exit WoW after installing the new Mailwright folder.
3. Start WoW. Disable Postal and enable Mailwright on every test character.
4. At the mailbox open Contacts > Import contacts, paste the old contact name
   list, click Check import, then Import contacts. The new addon has its own
   database; it does not modify or automatically read Postal's data.

## Contacts, alts and persistence

- Click Add contact with an empty To field: a helpful message must appear.
- Forever: save First Last; a first name alone must be rejected. Save two
  different surnames with the same first name; both must remain.
- Retail/Classic: Character and Character-Realm must work.
- Add a contact, /reload, then /mwstatus: it must say loaded and show an increased
  session count. Also test a complete logout/login.
- Visit each alt with Mailwright enabled. Compatible alts should appear; All alts
  should show ruleset groups and disable incompatible entries.
- Known PvP alts must not appear in Normal autocomplete. Unknown manually typed
  contacts remain unclassified because their ruleset is not available to the addon.
- Export, copy into an external text file, remove a contact, import and verify it.
  Importing twice must preserve existing entries without creating duplicates.
- Check Friends and Guild after their rosters have loaded.

## Collect, return, copy and delete

- Begin with inexpensive test items and small amounts of money.
- Open all: collect money/attachments; skip COD and GM mail; leave text messages.
- Test each filter, Money only, selected messages, Shift-checkbox ranges and
  Ctrl-checkbox same-sender selection.
- Shift-click a native mail icon to collect; Ctrl-click an icon to return.
- Fill bags to the configured reserve. Collection must stop with a message.
- Cancel during collection and close the mailbox during collection.
- Test more than one server inbox batch when available. Refresh is throttled by
  the server; manual refresh can be used if the server does not expose a new batch.
- Copy/read includes sender, subject, body, attachments and available invoice data.
- Delete must require confirmation and refuse messages containing items or money.
- Check expiry labels and mousewheel paging.
- No separate Mailwright inbox window should appear. Verify checkboxes beside
  native inbox rows, wide Open/Return controls (Open becomes Stop while collecting), and the title-bar options
  arrow. Normal clicks must still open Blizzard's mail reader. Copy and Forward
  must appear there. Change pages and verify selection targets the displayed mail.
- The To arrow must open a compact anchored menu, with Export and Import at the
  bottom of its main list. Category icons run down the right edge of Send Mail; right-click for options.

## Sending and forwarding

- Alt-click a bag item; Alt+Ctrl-click matching stacks. Verify no duplicate hooks
  after reopening the mailbox. Test both standard and any replacement bag UI.
- Quick attach: test category, minimum quality, bag filter and category recipient.
- Forward a text message, then a message containing a unique non-stackable item.
  Stacked/ambiguous items must request manual forwarding. Existing drafts must
  never be overwritten. Forwarding must not send automatically.
- Automatic Express sending is OFF by default. If testing it, use an empty draft
  and a valid recipient/subject. Money and COD drafts must require manual Send.
- Recently mailed updates only after MAIL_SEND_SUCCESS.
- Blank subject gets the money amount; a custom subject is preserved.
- Confirm trade blocking restores the prior setting and collected-money summary
  appears when closing the mailbox.

## Reporting a failure

Include the client/build, what you clicked, /mwstatus output and complete Lua error.
Use /console scriptErrors 1 to display errors. If Forever still says new database
after /reload, keep an exported backup. Earlier beta builds reportedly failed to
load SavedVariables; passing the offline reload test does not prove that client
issue has been resolved.

## Friends and menu paging (alpha.5)

Check ordinary character friends and Battle.net friends currently playing the same
WoW project/region. Battle.net entries require a visible character and realm;
offline Battle.net accounts without a current character are not mail addresses.
Hover a long Guild/Friends list and its Part submenus. Selecting a
recipient should fill To and close the menu immediately.

## Hover menus (alpha.6)

Hover Alts, All Alts, Friends or Guild to open a submenu beside Contacts. Lists
longer than 25 characters use hoverable Part groups; no Next/Previous or mouse
wheel is needed. Moving across menus must keep the menu tree open. Moving away
for about half a second must close it. Selecting a name or Close must dismiss all
levels. Check class-colored level/class details, guild ranks and All Alts realm/
faction labels. Missing metadata should simply be omitted. Confirm the To field
contains only the recipient address, never its class, rank or color markup.
