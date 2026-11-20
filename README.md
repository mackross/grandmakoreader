# KOReader development for Kindle Oasis

GrandmaKOReader runs in KOReader’s SDL simulator and targets Kindle Oasis. The macOS runtime uses the official Apple Silicon build `v2026.07.2-339-g21cc368`. Linux uses the public `v2026.07.1` release for x86-64 or ARM64.

## Apple Silicon Mac

Run `tools/setup-koreader` once to prepare the runtime. Open the native window or run the plugin smoke check.

```sh
tools/koreader run oasis3
tools/koreader run oasis3 landscape
tools/koreader smoke oasis3
```

The tools default to `oasis3`. Use `oasis1` for 1072 × 1448 or `oasis2` or `oasis3` for 1264 × 1680. All three use 300 DPI. macOS can shorten the native window to fit the display. Use a headless check for exact dimensions. The macOS window assumes a Retina display. On a 1× display, launch with `KO_WINDOW_SCALE=1`.

## Amp Orb or Debian Linux

Point an Amp project at a Git repository containing this checkout. Amp runs the executable `.agents/setup` when it prepares the Orb snapshot. In an existing Orb or a Debian checkout, the same bootstrap can be run directly. [Amp Orb setup docs](https://ampcode.com/docs/orbs/customizing)

```sh
.agents/setup
tools/setup-koreader --doctor
```

The bootstrap checks the download’s SHA-256, extracts the KOReader AppImage without FUSE, and checks SDL in headless mode. Re-running setup reuses the installed runtime. The release download works without GitHub credentials. [KOReader release](https://github.com/koreader/koreader/releases/tag/v2026.07.1)

## Work on a plugin

Put your `*.koplugin` directory under [plugins](plugins) and quit and relaunch KOReader after editing Lua. The launcher links that folder into each profile. The fixture library and KOReader settings are scoped to `.koreader/` in the workspace.

In the interactive simulator, Home lists the books in `.koreader/run/<profile>/books/`. On a Kindle the folder is `books` at the root of USB storage. Open **Oasis Sample** and use **Page Up** and **Page Down** to simulate the page-turn buttons. In the desktop window, click near any edge and drag inward to open the reading controls. To preview the battery warning, run `KO_DEV_BATTERY_PERCENT=9 tools/koreader run oasis3`.

The smoke command opens the sample document, invokes the plugin’s menu callback, asserts the framebuffer dimensions and DPI, and prints the PNG path. The KOReader log is in the same test directory as the screenshots folder. Kindle firmware, actual e-ink refresh, and physical button behavior still need verification on the Oasis.

For a full reading-flow check and screenshots at the 7-inch Oasis resolution, run:

```sh
tools/review-koreader .koreader/screenshots
```

The review creates disposable portrait and landscape libraries and sends touch and page-turn events through SDL. It checks the bookshelf, battery threshold, reading controls, and all four end-of-book choices, then saves PNGs and a `run.log` per orientation. The fixture profiles are cleaned up at the end of the run. Amp and Codex can use the [verify-grandmakoreader skill](.agents/skills/verify-grandmakoreader/SKILL.md) and its feature map to inspect the evidence.

## Restore the runtime

Run `tools/setup-koreader` if the local runtime is missing. On macOS, a fresh fetch requires an authenticated GitHub CLI, and extraction requires `7zz` from `brew install sevenzip`. The upstream macOS CI artifact expires in February 2027, so keep the cached archive for future reinstalls. [Official KOReader CI build](https://github.com/koreader/koreader/actions/runs/44446883254)
