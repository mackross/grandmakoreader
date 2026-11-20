# GrandmaKOReader

GrandmaKOReader is a set of Lua user patches for KOReader on Kindle Oasis. Edit `patches/` for the reader and bookshelf. `plugins/devcheck.koplugin/` and `fixtures/` support desktop verification.

## Reader behavior

- Launch into a single `books` folder at the root of Kindle storage. A tap on a title opens the book.
- While reading, the page buttons turn pages. Swiping inward from any edge opens the same reading menu. An ordinary tap leaves the page alone. The only persistent footer is the battery warning below 10%.
- Shelving from the reading menu saves the current place. Shelving from the end-of-book dialog marks the book read and resets it to the beginning. Removal requires confirmation, and Cancel returns to the end-of-book choices.
- Keep the user’s chosen labels and copy when changing layouts. Check portrait and landscape when changing any reader surface.

## Verification

- Use [verify-grandmakoreader](.agents/skills/verify-grandmakoreader/SKILL.md) to drive the running application and capture screenshots. Start with the feature map when checking a specific behavior.
- When using [pstack’s generator](.agents/skills/create-verification-skill/SKILL.md) in this repository, create skills under `.agents/skills/` so Amp and Codex can discover them.
- Run `.agents/setup` in an Amp Orb or `tools/setup-koreader` on Apple Silicon macOS when the runtime is missing. See [README](README.md) for the native launcher and headless commands.
- Verification runs against disposable fixture libraries. Keep downloaded runtimes, profiles, logs, and screenshots under the ignored `.koreader/` directory. Distinguish simulator results from physical Kindle checks.
- Record consequential changes to the project’s direction in [DECISIONS-FOR-ANDREW-TO-REVIEW.md](DECISIONS-FOR-ANDREW-TO-REVIEW.md).
