# Mailwright 0.2.14 - Mailbox options visibility and TSM compatibility

- Move the top Mailwright options button left when TradeSkillMaster is loaded so both buttons remain accessible.
- Keep the options button above mailbox artwork on Inbox and Send Mail, including when TSM is not installed.
- Use actual mailbox frame levels instead of a fixed high offset, and refresh the layout when the mailbox reopens or TSM loads later.
- Built-in compatibility replaces the need for the separate MailwrightTSMSupport addon; disable that workaround when using this version.

Thanks to Odysseas68 for reporting the overlap and testing a workaround.
Confirmed working in-game on Forever by Arametheus. Automated regression tests passed.

Packages: Retail 12.1.5, Classic Era 1.15.9, Mists Classic 5.5.4,
Burning Crusade Anniversary 2.5.6, and Forever 1.60.1.

All Rights Reserved. See LICENSE for permitted use and earlier MIT grants.
