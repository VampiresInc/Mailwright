# Mailwright 0.2.9 - Forwarding and contact menus

- Forward multiple identical non-stackable attachments, including caged pets. Match generic inbox cage links with bag pet links while leaving existing bag copies untouched.
- Check space for every attachment plus the configured free-slot reserve before collecting anything. Explain how many free slots are required when space is insufficient.
- Open Remove contact as a directly clickable saved-contact list instead of a flyout.
- Filter Retail and Classic Alts by current server; Forever Alts by current ruleset. All Alts retains all recorded alts for that client.
- Translate the new bag-space message across supported languages.

Retail in-game checks confirmed duplicate-item forwarding, pet forwarding, contact removal, and the bag-space check. Automated regression tests passed for all supported client modes, including alt filtering. The updated alt filter and other clients have not received a new in-game validation for this release.

Forwarding creates a draft for review and never sends automatically. Stackable attachments remain unsupported. Avoid moving or sorting bag items during forwarding.

Packages: Retail 12.1.5, Classic Era 1.15.9, Mists Classic 5.5.4,
Burning Crusade Anniversary 2.5.6, and Forever 1.60.1.

All Rights Reserved. See LICENSE for permitted use and earlier MIT grants.
