---
name: verify-grandmakoreader
description: Drive GrandmaKOReader in KOReader's desktop SDL simulator to verify Kindle Oasis bookshelf, page input, font, frontlight, battery, sleep, or end-of-book changes and capture portrait and landscape PNG evidence.
---

# Verify GrandmaKOReader

## Launch

Run from the repository root. Prepare a fresh Amp Orb with `.agents/setup`, or an Apple Silicon Mac with `tools/setup-koreader`. The headless review launches KOReader on demand, seeds two books in separate portrait and landscape profiles, and opens **Books** through the normal startup path. No display server, port, or login is involved during review. The initial Books screenshot and shelf assertion establish readiness.

## Doctor

```sh
tools/setup-koreader --doctor
```

Require exit status zero and `KOReader ready:` with the host's pinned revision and a successful dummy SDL initialization. A native app already open on the Mac is independent of this run.

## Drive

Read the relevant entry in the [feature map](features/README.md). Start a fresh review and save its path for inspection.

```sh
mkdir -p .koreader/review
evidence=$(mktemp -d "$PWD/.koreader/review/verify.XXXXXX")
tools/review-koreader "$evidence"
```

The [SDL driver](../../../tools/reader-review.lua) sends real touch and page-key events through KOReader. It sets fixture preconditions directly for battery level, brightness extremes, and arrival at the last page. It uses disposable copies when testing removal. For an input failure, repeat in a fresh evidence directory with `KO_REVIEW_DEBUG=1 tools/review-koreader "$evidence"` to include gesture and key dispatch in the logs.

For a path absent from the driver, extend the run with the relevant inputs or use the interactive Mac preview. Run `tools/koreader run oasis3` for portrait or `tools/koreader run oasis3 landscape` for landscape. Open **Oasis Sample**, use Page Up or Page Down for the hardware buttons, and press F2 to wake from the simulator screensaver. Quit the preview when finished. Verify removal through the automated fixture library.

## Evidence

Require both `Reader review passed` lines at 1264 × 1680 and 1680 × 1264. Inspect the relevant before and after PNGs in `$evidence/portrait/` and `$evidence/landscape/`. Each directory also contains `run.log`. Pair visual checks with assertions for durable effects, such as reopening at the saved position or verifying a removed fixture is absent. On failure, link the log and any screenshots the run reached, and report which orientation and step failed.

The SDL simulator exercises the real reader and patches, with simulated battery, frontlight, and sleep. Physical key dispatch, frontlight output, e-ink refresh, and Kindle suspend need a check on the device.

## Cleanup

The command exits KOReader and removes its temporary fixture profiles at the end of the run. The logs and PNGs remain in the chosen evidence directory. When checking teardown, compare the entries under `.koreader/review-runs/` before and after the run. Leave other runs and the native profile alone.

## Helpers

- `tools/setup-koreader --doctor` verifies the installed revision and SDL.
- `tools/review-koreader "$evidence"` drives the full feature map in both orientations.
- `tools/review-auto-update "$evidence/auto-update"` drives the updater against a stand-in for GitHub. It takes about ten minutes; see [automatic updates](features/auto-update.md).
- `tools/koreader smoke oasis3` checks the desktop plugin entry point and produces a separate PNG. Use the full review for reader changes.
