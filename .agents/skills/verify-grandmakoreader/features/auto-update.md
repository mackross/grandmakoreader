# Automatic updates

The Kindle keeps its `koreader/patches` folder identical to `patches/` on `main`, subfolders included, so patches and resources such as `patches/icons/` arrive together. It checks quietly over Wi‑Fi, downloads in the background, and applies a release by restarting KOReader. Nothing is shown to the reader, unless they ask for a check with **Check for updates** in Settings.

Status: [`patches/1-auto-update.lua`](../../../../patches/1-auto-update.lua) is built. It does nothing unless `auto-update.lua` exists in KOReader's data directory, so the reader review runs with it inert. The repository is public, so no token is needed. Setup and publishing are in the [README](../../../../README.md#update-the-kindle-over-wi-fi).

## Sub-features

- `update-check` checks 90 seconds after KOReader starts and then at most once an hour while awake. An unchanged release downloads nothing.
- `update-battery` skips a check while the battery is below 10%.
- `update-check-now` runs a check at once when **Check for updates** is tapped in Settings, and says in the row under it how it is going and how it ended. Check for updates is greyed out while a check runs. A check already running is joined, not repeated. The message stays until Settings is left.
- `update-switched-off` greys Check for updates out and says so when `auto-update.lua` is missing, as in the reader review.
- `update-wifi` registers the `auto-update` need with the [Wi‑Fi module](wifi.md) for each check, releases it afterwards, and reports whether the internet answered with `Wifi:report`. A refused need (`"off"`, `"unreachable"`, `"asleep"`, `"ended"`) is logged and retried at the next check. Without the module the updater switches the radio itself.
- `update-mirror` installs every file under `patches/`, creates subfolders, and removes files that left the branch. Dot files and links are ignored on both sides.
- `update-download` fetches only the files that changed and stages a release only when every file matches GitHub's hash and every Lua file parses. An altered file, a syntax error, a rejected token, or no answer leaves the Kindle as it was.
- `update-restart-shelf` restarts KOReader at once when the home screen (the shelf, Book Shop, or Settings) is the front screen and nothing else needs Wi‑Fi. After a check from Settings that is within five seconds of the message.
- `update-restart-wake` waits for the next wake when a book or any other screen is open, or something else holds Wi‑Fi. A book reopens at the same page.
- `update-trial` keeps the previous release and treats the first minute of a new one as a trial.
- `update-rollback` returns to the previous release when a patch fails to load or KOReader dies during the trial, and does not download that release again.

## How to get to it (user POV)

- Nothing to do. On the shelf the screen redraws once as KOReader restarts. During a book the restart happens as the Kindle wakes.
- To check now, tap **Settings**, then **Check for updates**.

## How it works

```lua
local Update = package.loaded["grandma/update"] -- nil when updates are switched off
Update:check(function(state, reason) ... end)
```

- The callback hears `"connecting"`, then `"checking"` once Wi‑Fi is up, then one ending: `"up to date"`, `"downloaded"`, `"rolled back"`, `"no internet"`, `"failed"`, `"low battery"`, or `"no wifi"` with the Wi‑Fi module's reason.
- `"no internet"` means Wi‑Fi connected but nothing answered, which includes a failed name lookup. `"failed"` means something answered but the release could not be listed or downloaded intact.
- A callback that throws is logged and ignored, so the screen cannot stop the updater.

## Driving it with SDL

Preconditions: the doctor passes and `python3` is available. [`tools/auto-update-stub.py`](../../../../tools/auto-update-stub.py) stands in for GitHub on a local port, and the run relaunches KOReader by hand where Kindle's launcher would on exit code 85.

- Run `tools/review-auto-update "$evidence/auto-update"`. It takes about ten minutes and publishes the working tree's patches as a series of fixture releases. Require `Auto-update review passed`. Each launch writes a log named after its step, such as `reading-2-reopen.log`, with `Auto-update:` lines from the updater and `REVIEW` lines from [the driver](../../../../tools/auto-update-review.lua).
- The Wi‑Fi checks run when `patches/2-wifi.lua` is present. Without it the run checks that the updater switches the radio itself.
- The run also opens Settings and presses **Check for updates** against the real updater: a download and restart from Settings, an unchanged release, a low battery, a rolled-back release, a rejected token, no answer, and no Wi‑Fi. Those launches print `REVIEW SETTINGS` and the message whenever it changes.
- `tools/review-koreader` covers the screen itself with a stand-in for the updater: every message, the greyed-out row, a refresh, and leaving Settings. See `01-settings.png`, `01-settings-connecting.png`, `01-settings-no-wifi.png`, `01-settings-rolled-back.png`, `01-settings-up-to-date.png`, and `01-settings-updates-off.png` in each orientation.
- Run it after changing the updater, the Settings button, the Wi‑Fi module's `need`, `release`, `isNeeded`, or `report`, or the shelf's widget name `books_home`.

## Device-only checks

- The real GitHub download, over HTTPS with certificate checks.
- That Kindle's launcher relaunches KOReader on exit code 85, and that a crashed KOReader is launched again so the rollback can run.
- That the wake is detected, and that the radio joins the saved network and turns off afterwards.
- `koreader/crash.log` on the Kindle records every check on a line starting `Auto-update:`.

## Copy (drafted for Andrew’s approval; the Wi‑Fi lines follow the [approved book store copy](wifi.md))

| Where | String |
| --- | --- |
| Settings, row | Check for updates |
| Waiting for Wi‑Fi | Looking for the Wi‑Fi… this might take a minute. |
| Connected, checking | Checking for an update… |
| Nothing new | This Kindle is up to date. |
| Downloaded | Found an update. The Kindle will restart in a moment. |
| Release rolled back before | The newest update didn’t work on this Kindle, so it is keeping the one it has. |
| `unreachable` | The Kindle couldn’t find the Wi‑Fi. Check the internet is on at home, then try again. |
| `off` | Updates need Wi‑Fi, but Wi‑Fi is turned off on this Kindle. |
| Connected but no internet | The Kindle is on the Wi‑Fi but can’t reach the internet. Please try again later. |
| Download failed | Updates aren’t working right now. Please try again later. |
| Battery below 10% | The battery is too low to update. Charge the Kindle, then try again. |
| `asleep` or `ended` | No message. |
| Updater switched off | Updates are switched off on this Kindle. |

## Gotchas

- The headless simulator reports a 0% battery, so the driver sets 75%.
- A release that loads but misbehaves is not detected. A release that breaks the updater itself cannot be undone remotely.
- The trial is one minute, so the first-launch step waits it out.
