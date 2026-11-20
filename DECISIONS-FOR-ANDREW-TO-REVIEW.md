# Decisions for Andrew to review

## Pin the Orb to a public KOReader release

Orbs use the released Linux KOReader `v2026.07.1` on x86-64 or ARM64. The existing Mac environment keeps `v2026.07.2-339-g21cc368`. This lets Amp prepare its snapshot before GitHub credentials are available. Both runtimes run the same Lua patches and verification flow. A future change that depends on a newer KOReader API needs to pass on both pins or move them forward together. Review the final runtime against the version you run on the Kindle. [Linux release](https://github.com/koreader/koreader/releases/tag/v2026.07.1)

## Base Orb verification on the real reader in headless SDL

The Orb runs KOReader with disposable copies of sample books and captures its framebuffer. The feature map checks persisted reading position, completion status, and removal alongside the screens. Touch and page inputs travel through SDL, while battery, frontlight, and sleep use the simulator. Physical buttons, light output, suspend, and e-ink rendering still need a pass on the Oasis.

## Keep the GitHub repository private

Andrew chose `mackross/grandmakoreader` as the GitHub repository. Use private visibility so access to the reader and its development setup stays under Andrew’s control. An Amp project can clone it through Andrew’s GitHub connection. [Amp project setup](https://ampcode.com/docs/orbs/getting-started)

## Use icon-pack icons in the reading menu

The reading menu uses Material Symbols for Change Font and the light, Phosphor for Stop for now, and Tabler for Open another book. The SVGs and their licenses (Apache 2.0 and MIT) live in `patches/icons/`, and the patch loads them from the `icons` folder next to itself. Copy that folder along with the patches to `koreader/patches/` on the Kindle; a missing folder shows KOReader’s icon-not-found picture. Tabler’s and Phosphor’s icons used `currentColor`, which KOReader’s SVG renderer draws as gray, so the copies use plain black. [Material Symbols](https://github.com/google/material-design-icons) [Phosphor](https://github.com/phosphor-icons/core) [Tabler Icons](https://github.com/tabler/tabler-icons)
