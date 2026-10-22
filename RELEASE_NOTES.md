# Mailwright 0.2.6 - Open All queue fix

- Fix Open All stopping with "Inbox changed before the next operation" when inbox rows or cached attachment details change.
- Refresh eligible mail between confirmed operations so collection continues without repeated clicks.
- Preserve COD and GM exclusions, collection filters, server acknowledgement checks, and the configured free-bag-slot reserve.
- Keep strict message checks for selected mail, returns, and forwarding.

Confirmed in-game on Retail by Arametheus. Regression tests cover changing inbox
rows, attachment cache updates, COD skipping, and bag-space limits.
Set Free bag slots to 0 to allow collection to fill all available slots.

Packages: Retail 12.1.5, Classic Era 1.15.9, Mists Classic 5.5.4,
Burning Crusade Anniversary 2.5.6, and Forever 1.60.1.
Download the ZIP for your client and extract Mailwright into Interface/AddOns.
Disable Postal while using Mailwright.

All Rights Reserved. See LICENSE for permitted use and earlier MIT grants.
