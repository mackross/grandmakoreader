# GrandmaKOReader

GrandmaKOReader is a set of Lua user patches for KOReader on Kindle Oasis. Edit `patches/` for the reader and bookshelf. `plugins/devcheck.koplugin/` and `fixtures/` support desktop verification.

## Reader behavior

- Launch into a single `books` folder at the root of Kindle storage. A tap on a title opens the book.
- The home screen has three places along the bottom: Book Shop, Book Shelf, and Settings. Book Shop holds one button, Find a new book, in the place the shelf puts Look up a book; it loads the vendored Z-library plugin directly and opens its search, and asks `grandma/wifi` for the radio under the `zlibrary` need. Settings lists Check for updates, with a row under it saying how the check went, and Advanced, whose Exit to Kindle asks before leaving KOReader. The shelf names each book by the title inside it, with its author on a smaller line below, and files titles in library order through `patches/library.lua`. With more than one shelf, the title names the open shelf’s letters, such as “Books B–L” in landscape and “B–L” alone in portrait, and an arrow on each side names its neighbour. Look up a book offers a letter, Read lately, or a typed title or author.
- While reading, the page buttons turn pages, and so do left and right swipes. A tap anywhere opens the reading menu. Up and down swipes do nothing. The only persistent footer is the battery warning below 10%.
- Turning past a book’s last page shows a full-screen note from Andrew; turning forward from it, or a tap, offers the end-of-book choices, and turning back returns to the last page. Open another book, in the reading menu, saves the current place. Put back on shelf, in the end-of-book dialog, marks the book read and resets it to the beginning. Removal requires confirmation, and Cancel returns to the end-of-book choices.
- Keep the user’s chosen labels and copy when changing layouts. Check portrait and landscape when changing any reader surface.

## Releases

- The Kindle installs whatever `patches/` holds on `main` through [the updater](patches/1-auto-update.lua), so a push to `main` is a release to the Kindle. Push to `main` only when Andrew asks, after the review passes, and keep unfinished work on another branch. See [README](README.md#update-the-kindle-over-wi-fi).
- Every file under `patches/` ships, subfolders included. Put a resource a patch needs, such as an icon, in a subfolder of `patches/` and load it relative to the patch, as `2-reading-controls.lua` does. Keep development-only code in `tools/` and `plugins/`.
- A bad reader patch rolls back on the device, and so does an updater that is missing or fails as it loads or starts. An updater that starts but stops checking cannot be fixed remotely, so change `1-auto-update.lua` rarely and never rename it.
- Run `tools/review-auto-update` after changing the updater, the Wi-Fi module's `need`, `release`, `isNeeded`, or `report`, or the shelf's widget name. Run it too after changing the Settings button or `grandma/update`. A new full-screen feature needs no change: the updater restarts at once only from the home screen, which is the shelf, Book Shop, or Settings.

## Verification

- Use [verify-grandmakoreader](.agents/skills/verify-grandmakoreader/SKILL.md) to drive the running application and capture screenshots. Start with the feature map when checking a specific behavior.
- When using [pstack’s generator](.agents/skills/create-verification-skill/SKILL.md) in this repository, create skills under `.agents/skills/` so Amp and Codex can discover them.
- Run `.agents/setup` in an Amp Orb or `tools/setup-koreader` on Apple Silicon macOS when the runtime is missing. See [README](README.md) for the native launcher and headless commands.
- Verification runs against disposable fixture libraries. Keep downloaded runtimes, profiles, logs, and screenshots under the ignored `.koreader/` directory. Distinguish simulator results from physical Kindle checks.
- Record consequential changes to the project’s direction in [DECISIONS-FOR-ANDREW-TO-REVIEW.md](DECISIONS-FOR-ANDREW-TO-REVIEW.md).
