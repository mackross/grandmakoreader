# Decisions for Andrew to review

## Pin the Orb to a public KOReader release

Orbs use the released Linux KOReader `v2026.07.1` on x86-64 or ARM64. The existing Mac environment keeps `v2026.07.2-339-g21cc368`. This lets Amp prepare its snapshot before GitHub credentials are available. Both runtimes run the same Lua patches and verification flow. A future change that depends on a newer KOReader API needs to pass on both pins or move them forward together. Review the final runtime against the version you run on the Kindle. [Linux release](https://github.com/koreader/koreader/releases/tag/v2026.07.1)

## Base Orb verification on the real reader in headless SDL

The Orb runs KOReader with disposable copies of sample books and captures its framebuffer. The feature map checks persisted reading position, completion status, and removal alongside the screens. Touch and page inputs travel through SDL, while battery, frontlight, and sleep use the simulator. Physical buttons, light output, suspend, and e-ink rendering still need a pass on the Oasis.

## Keep the GitHub repository private

Andrew chose `mackross/grandmakoreader` as the GitHub repository. Use private visibility so access to the reader and its development setup stays under Andrew’s control. An Amp project can clone it through Andrew’s GitHub connection. [Amp project setup](https://ampcode.com/docs/orbs/getting-started)

## Use icon-pack icons in the reading menu

The reading menu uses Material Symbols for Change Font and the light, Phosphor for Stop for now, and Tabler for Open another book. The SVGs and their licenses (Apache 2.0 and MIT) live in `patches/icons/`, and the patch loads them from the `icons` folder next to itself. Copy that folder along with the patches to `koreader/patches/` on the Kindle; a missing folder shows KOReader’s icon-not-found picture. Tabler’s and Phosphor’s icons used `currentColor`, which KOReader’s SVG renderer draws as gray, so the copies use plain black. [Material Symbols](https://github.com/google/material-design-icons) [Phosphor](https://github.com/phosphor-icons/core) [Tabler Icons](https://github.com/tabler/tabler-icons)

## Keep Wi‑Fi on only while something needs it

`patches/2-wifi.lua` owns the Wi‑Fi radio. The updater and the future book store register named needs with timeouts. Wi‑Fi turns off 10 seconds after the last need ends and when the Kindle sleeps. A need gives up after 60 seconds without a connection, counted separately for each need. Needs form a set rather than a stack, because downloads and timeouts end in any order. At startup, the module turns off Wi‑Fi left on by the Kindle. On a Kindle it connects through `wifid` with `restoreWifiAsync`, which joins saved networks without KOReader’s 20-second blocking scan and popups. So the reader’s home network must be saved, either through the stock Kindle UI or the planned setup screen. A failed connection shows nothing unless the book store asked for it. Turning Wi‑Fi off blocks everything, updates included, and lifts by itself after 24 hours, so a Kindle can never be cut off from fixes for longer than a day. The updater uses `Wifi:need` and switches the radio itself only when this module is missing.
