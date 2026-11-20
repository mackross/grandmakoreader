# Decisions for Andrew to review

## Pin the Orb to a public KOReader release

Orbs use the released Linux KOReader `v2026.07.1` on x86-64 or ARM64. The existing Mac environment keeps `v2026.07.2-339-g21cc368`. This lets Amp prepare its snapshot before GitHub credentials are available. Both runtimes run the same Lua patches and verification flow. A future change that depends on a newer KOReader API needs to pass on both pins or move them forward together. Review the final runtime against the version you run on the Kindle. [Linux release](https://github.com/koreader/koreader/releases/tag/v2026.07.1)

## Base Orb verification on the real reader in headless SDL

The Orb runs KOReader with disposable copies of sample books and captures its framebuffer. The feature map checks persisted reading position, completion status, and removal alongside the screens. Touch and page inputs travel through SDL, while battery, frontlight, and sleep use the simulator. Physical buttons, light output, suspend, and e-ink rendering still need a pass on the Oasis.

## Keep the GitHub repository private

Andrew chose `mackross/grandmakoreader` as the GitHub repository. Use private visibility so access to the reader and its development setup stays under Andrew’s control. An Amp project can clone it through Andrew’s GitHub connection. [Amp project setup](https://ampcode.com/docs/orbs/getting-started)
