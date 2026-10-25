# Mailwright 0.2.7 - Languages and forwarding fixes

- Add automatic WoW-language matching, English fallback, and a manual language selector with Reload UI in AddOns settings and the mailbox menu.
- Translate addon menus, tooltips, help, validation, status, and error messages into German, French, Spanish (Spain/Latin America), Italian, Brazilian Portuguese, Russian, Korean, and Simplified/Traditional Chinese.
- Make AddOns settings scrollable with room for longer translated labels. Game-provided names and mail content retain the client language.
- Fix forwarding stopping after an emptied auction-house message disappears.
- Wait for collected items to become available in bags before attaching them.
- Forward the newly collected copy when an identical item is already owned, leaving existing copies alone.
- Support both legacy and newer mail-body editors and preserve existing drafts.
- Use compact C (Copy) and F (Forward) buttons beside Reply, with hover tooltips.
- Keep the Open All options dropdown anchored to the arrow that opened it.

Forwarding tested in-game on Retail by Arametheus. Regression tests cover auction
mail removal, delayed and locked bag data, changed links, existing copies,
ambiguous inventory changes, timeouts, and dropdown behavior.
Forwarding creates a draft for review; it never sends automatically. Avoid moving
or sorting items during forwarding. Stackable attachments remain unsupported.

Packages: Retail 12.1.5, Classic Era 1.15.9, Mists Classic 5.5.4,
Burning Crusade Anniversary 2.5.6, and Forever 1.60.1.

All Rights Reserved. See LICENSE for permitted use and earlier MIT grants.
