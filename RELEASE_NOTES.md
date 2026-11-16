# Mailwright 0.2.12 - Remember offline friend characters

- Keep previously observed Battle.net WoW characters in the Friends menu after they log off.
- Save remembered character identities across reloads and logins, separate by WoW client.
- Capture online character updates even while the mailbox is closed.
- Preserve existing compatibility checks and keep remembered friends separate from manually saved contacts.

Only characters actually observed online can be remembered. Remembered names currently remain even if the Battle.net friendship is later removed.

Confirmed working in-game on Forever by Arametheus. Automated regression tests passed, including offline retention, saved-data reload, and client isolation.

Packages: Retail 12.1.5, Classic Era 1.15.9, Mists Classic 5.5.4,
Burning Crusade Anniversary 2.5.6, and Forever 1.60.1.

All Rights Reserved. See LICENSE for permitted use and earlier MIT grants.
