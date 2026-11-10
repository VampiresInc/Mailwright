# Mailwright 0.2.8 - Saved contact removal

- Replace the To-field-dependent Remove contact action with a picker of saved contacts.
- Remove the selected saved record directly, including records stored under older keys and contacts unavailable for mailing on the current ruleset.
- Keep other clients' contacts, automatically listed alts, friends, and recent recipients unchanged.
- Paginate long removal lists and reuse the existing translated menu labels.

Automated regression tests passed, including blank/unrelated To fields, older saved keys, client isolation, and lists longer than 25 contacts. This change has not yet been tested in-game.

Packages: Retail 12.1.5, Classic Era 1.15.9, Mists Classic 5.5.4,
Burning Crusade Anniversary 2.5.6, and Forever 1.60.1.

All Rights Reserved. See LICENSE for permitted use and earlier MIT grants.
