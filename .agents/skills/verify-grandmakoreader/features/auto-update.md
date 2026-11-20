# Automatic updates

The Kindle keeps its `koreader/patches` folder identical to `patches/` on `main`, subfolders included, so patches and resources such as `patches/icons/` arrive together. It checks quietly over Wi‑Fi, downloads in the background, and applies a release by restarting KOReader. Nothing is shown to the reader.

Status: [`patches/1-auto-update.lua`](../../../../patches/1-auto-update.lua) is built. It does nothing unless `auto-update.lua` exists in KOReader's data directory, so the reader review runs with it inert. The repository is public, so no token is needed. Setup and publishing are in the [README](../../../../README.md#update-the-kindle-over-wi-fi).

## Sub-features

- `update-check` checks 90 seconds after KOReader starts and then at most once an hour while awake. An unchanged release downloads nothing.
- `update-battery` skips a check while the battery is below 10%.
- `update-wifi` registers the `auto-update` need with the [Wi‑Fi module](wifi.md) for each check, releases it afterwards, and reports whether the internet answered with `Wifi:report`. A refused need (`"off"`, `"unreachable"`, `"asleep"`, `"ended"`) is logged and retried at the next check. Without the module the updater switches the radio itself.
- `update-mirror` installs every file under `patches/`, creates subfolders, and removes files that left the branch. Dot files and links are ignored on both sides.
- `update-download` fetches only the files that changed and stages a release only when every file matches GitHub's hash and every Lua file parses. An altered file, a syntax error, a rejected token, or no answer leaves the Kindle as it was.
- `update-restart-shelf` restarts KOReader at once when the shelf is the front screen and nothing else needs Wi‑Fi.
- `update-restart-wake` waits for the next wake when a book or any other screen is open, or something else holds Wi‑Fi. A book reopens at the same page.
- `update-trial` keeps the previous release and treats the first minute of a new one as a trial.
- `update-rollback` returns to the previous release when a patch fails to load or KOReader dies during the trial, and does not download that release again.

## How to get to it (user POV)

- Nothing to do. On the shelf the screen redraws once as KOReader restarts. During a book the restart happens as the Kindle wakes.

## Driving it with SDL

Preconditions: the doctor passes and `python3` is available. [`tools/auto-update-stub.py`](../../../../tools/auto-update-stub.py) stands in for GitHub on a local port, and the run relaunches KOReader by hand where Kindle's launcher would on exit code 85.

- Run `tools/review-auto-update "$evidence/auto-update"`. It takes about ten minutes and publishes the working tree's patches as a series of fixture releases. Require `Auto-update review passed`. Each launch writes a log named after its step, such as `reading-2-reopen.log`, with `Auto-update:` lines from the updater and `REVIEW` lines from [the driver](../../../../tools/auto-update-review.lua).
- The Wi‑Fi checks run when `patches/2-wifi.lua` is present. Without it the run checks that the updater switches the radio itself.
- Run it after changing the updater, the Wi‑Fi module's `need`, `release`, `isNeeded`, or `report`, or the shelf's widget name `books_home`.

## Device-only checks

- The real GitHub download, over HTTPS with certificate checks.
- That Kindle's launcher relaunches KOReader on exit code 85, and that a crashed KOReader is launched again so the rollback can run.
- That the wake is detected, and that the radio joins the saved network and turns off afterwards.
- `koreader/crash.log` on the Kindle records every check on a line starting `Auto-update:`.

## Gotchas

- The headless simulator reports a 0% battery, so the driver sets 75%.
- A release that loads but misbehaves is not detected. A release that breaks the updater itself cannot be undone remotely.
- The trial is one minute, so the first-launch step waits it out.
