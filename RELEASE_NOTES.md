# Mailwright 0.2.16 - Controller UI recipient selection and autofill

- Recipient menus fill To on the open Send Mail tab while preserving controller focus.
- Remember last recipient works again in Controller UI. Autofill waits until Send Mail is visible and leaves an existing recipient untouched.

Thanks to **fitsimmons6**, developer of [Controller Companion](https://www.curseforge.com/wow/addons/controllercompanion), for the recipient picker approach that inspired this fix.

Verified in-game on Forever by Arametheus. Automated regression tests cover both Controller UI and the normal interface.

Packages: Retail, Classic Era, Mists Classic, Burning Crusade Anniversary, and Forever.
