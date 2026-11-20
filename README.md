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

In the interactive simulator, Home lists the books in `.koreader/run/<profile>/books/`. On a Kindle the folder is `books` at the root of USB storage. Open **Oasis Sample** and use **Page Up** and **Page Down** to simulate the page-turn buttons. In the desktop window, click the page to open the reading controls, or drag left or right to turn a page. To preview the battery warning, run `KO_DEV_BATTERY_PERCENT=9 tools/koreader run oasis3`.

The smoke command opens the sample document, invokes the plugin’s menu callback, asserts the framebuffer dimensions and DPI, and prints the PNG path. The KOReader log is in the same test directory as the screenshots folder. Kindle firmware, actual e-ink refresh, and physical button behavior still need verification on the Oasis.

For a full reading-flow check and screenshots at the 7-inch Oasis resolution, run:

```sh
tools/review-koreader .koreader/screenshots
```

The review creates disposable portrait and landscape libraries and sends touch and page-turn events through SDL. It checks the bookshelf, its lettered shelves and Look up a book, the battery threshold, reading controls, and all four end-of-book choices, then saves PNGs and a `run.log` per orientation. The fixture profiles are cleaned up at the end of the run. Amp and Codex can use the [verify-grandmakoreader skill](.agents/skills/verify-grandmakoreader/SKILL.md) and its feature map to inspect the evidence.

## Update the Kindle over Wi-Fi

[The updater](patches/1-auto-update.lua) keeps the Kindle's `koreader/patches` folder identical to `patches/` on `main`, subfolders included. Patches and the resources they load, such as `patches/icons/`, arrive together, and a file removed from the branch is removed from the Kindle. Files whose names start with a dot are ignored. Every push to `main` reaches the Kindle within about an hour of its next wake, so run the review before pushing:

```sh
tools/review-koreader .koreader/screenshots
git push origin main
```

Keep unfinished work on another branch. Only `patches/` matters to the Kindle; a push that leaves it unchanged downloads nothing.

Set the Kindle up once over USB:

1. Copy the contents of `patches/`, with its subfolders, into `koreader/patches/`.
2. Save `koreader/auto-update.lua` containing `return {}`. Without this file the updater does nothing, which is how the simulator runs it. Do this only once `main` on GitHub contains `patches/1-auto-update.lua`; the Kindle copies `main` exactly, so before then its first update would remove the updater.
3. Join the Wi-Fi network the Kindle will use from the Kindle's own settings. The updater switches the radio on and off but cannot enter a password.

The Kindle checks 90 seconds after KOReader starts and then at most once an hour while awake, so in practice on waking. It skips a check while the battery is below 10%. Each check asks the Wi-Fi module (`patches/2-wifi.lua`) for a connection and gives it back afterwards; if that module is missing, the updater switches the radio itself. Turning Wi-Fi off in the module also stops updates until it lifts.

A new release is downloaded in the background, only the files that changed are fetched, each file is compared with GitHub's hash, each Lua file is parsed, and only a complete release is staged. KOReader restarts to apply it straight away when the shelf is the front screen and nothing else is using Wi-Fi. With a book or any other screen open it waits for the next wake, and a book reopens at the same page.

A release whose patch fails to load, or that takes KOReader down in its first minute, is replaced by the previous one and is not downloaded again; publish a different commit to retry. A patch that loads but misbehaves is not detected, so publish a fix. The updater is itself a patch and updates with the rest, but a release that breaks the updater cannot be undone remotely. `koreader/crash.log` on the Kindle records every check on a line starting `Auto-update:`.

To check without waiting, tap **Settings**, then **Check for updates**. The line under the button says how the check went, which is also the quickest way to see why an update is not arriving.

Run `tools/review-auto-update .koreader/review/auto-update` after changing the updater, the Settings button, or the Wi-Fi module. It drives download, restart, rollback, the check from Settings, and the Wi-Fi hand-off against a stand-in for GitHub and takes about twelve minutes.

The repository is public, so the Kindle holds no credential. GitHub allows 60 anonymous requests an hour from one network; a check is one request and an update adds one per changed file. For a private repository, add `token = "github_pat_…"` with a fine-grained token limited to this repository and **Contents: Read-only**.

Other optional keys in `auto-update.lua` are `ref` (the branch to follow, default `"main"`), `repo` (default `"mackross/grandmakoreader"`), and `interval` in seconds (default `3600`).

## Restore the runtime

Run `tools/setup-koreader` if the local runtime is missing. On macOS, a fresh fetch requires an authenticated GitHub CLI, and extraction requires `7zz` from `brew install sevenzip`. The upstream macOS CI artifact expires in February 2027, so keep the cached archive for future reinstalls. [Official KOReader CI build](https://github.com/koreader/koreader/actions/runs/44446883254)
