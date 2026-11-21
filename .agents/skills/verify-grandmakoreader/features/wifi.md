# Wi‑Fi

Wi‑Fi is off unless something needs it. The automatic updater and the book store each register a need. The Kindle connects quietly and disconnects once nothing needs it. Only the book store tells the reader about the connection. The settings area can show a problem, and network setup belongs to the setup area, which is not for the reader.

Status: the need tracking in [`patches/2-wifi.lua`](../../../../patches/2-wifi.lua) is built. The book store, the settings line, and the setup network screen are planned.

## Sub-features

- `wifi-takeover` turns off Wi‑Fi left on by the Kindle at startup, after the grace period, when nothing needs it.
- `wifi-need-connects` turns Wi‑Fi on when the first need arrives and answers `true` once the Kindle is connected.
- `wifi-needs-overlap` keeps the connection while any need remains, whatever order the needs end in.
- `wifi-need-extends` extends a need when it is registered again under the same name before it times out.
- `wifi-need-timeout` drops a need when its time runs out, even if nothing releases it.
- `wifi-idle-disconnect` turns Wi‑Fi off 10 seconds after the last need ends.
- `wifi-connect-failure` answers `false` with `"unreachable"` when a need has waited 60 seconds without a connection, and ends that need. Each need has its own 60 seconds, so a failing background attempt does not shorten the book store's wait. Nothing is shown on screen.
- `wifi-problem-report` remembers whether the last request reached the internet. An unreachable connection records a problem, and the updater or store reports each request's result with `Wifi:report(reached)`. Settings reads `Wifi:hasProblem()`.
- `wifi-sleep` ends every need when the Kindle sleeps. Tasks swap files atomically, so an interrupted download leaves nothing behind.
- `wifi-off-setting` refuses every need, including updates, for 24 hours after `Wifi:setOff(true)`, then lifts by itself. The time survives restarts. Turning it on ends the needs already running and turns the radio off.
- `wifi-airplane-mode` is the off setting's row in Settings. It reads **Airplane mode: Off**; a tap turns Wi‑Fi off for 24 hours and the row reads **Airplane mode: On until 9:12 am tomorrow** (`today` once the day has turned). Another tap turns it off early.
- `wifi-store-status` (planned) shows a message while the book store connects or cannot connect.
- `wifi-settings-problem` (planned) shows in settings when Wi‑Fi has not been working.
- `wifi-setup-network` (planned) lists networks in the setup area, asks for a password, and can forget a network.

## How to get to it (user POV)

- Automatic: nothing to do. Updates connect and disconnect without any sign.
- Airplane mode: tap **Settings**, then **Airplane mode: Off**. Tap the row again to end it early.
- Book store (planned): opening the store connects and shows a message only if that takes a while or fails.
- Setup (planned): set up for the family member, not the reader.

## How it works

```lua
local Wifi = require("grandma/wifi") -- available once every patch has loaded
Wifi:need("book-store", 120, function(connected) ... end)
Wifi:release("book-store")
```

- The callback runs once, possibly inside `need`, with `true` when connected or with `false` and a reason: `"off"` (the off setting), `"unreachable"` (no connection within 60 seconds of this need), `"asleep"` (the Kindle slept), or `"ended"` (the need ended first). `release` is safe for a need that has already ended.
- `Wifi:isNeeded(except)` tells the updater whether anything else holds Wi‑Fi, so it can avoid restarting during a download.
- The updater calls `need("auto-update", 180, …)` when the module is loaded, and switches the radio itself only when it is missing.
- Callers decide whether to connect at all, for example by checking the battery first.
- On a Kindle, the module turns the radio on with `NetworkMgr:restoreWifiAsync()`, and Amazon's `wifid` joins a saved network on its own. It never calls `turnOnWifi`, which on a Kindle freezes the screen for up to 20 seconds to scan and shows popups. It turns the radio off with `NetworkMgr:disableWifi()`.
- The module turns off KOReader's own `auto_restore_wifi` and `auto_disable_wifi`.
- "Connected" means the Kindle has an IP address. A network without internet access still answers `true`, so the caller's request fails and handles that itself.

## Driving it with SDL

Preconditions: the doctor passes. The simulator's fake network manager connects as soon as the radio turns on and cannot scan.

- Run `tools/review-koreader "$evidence"`. The portrait run shortens the timers and checks the takeover, overlapping needs, the grace period, extension, timeout, forced connection failures with separate timeouts, the problem report, and the off setting. It prints `PASS wifi`. The Settings part of the run, in both orientations, turns Airplane mode on and off from its row; see `01-settings-airplane-mode.png`. Both orientations register a need before **Stop for now** and check that sleep ends it and turns the radio off.
- The planned screens need fake scan results in the review harness, because the simulator cannot scan.

## Device-only checks

- That `restoreWifiAsync` joins her saved network within 60 seconds, and that a failure is silent.
- That the radio is off after sleeping and waking, and after startup with Wi‑Fi left on.
- Scanning, password entry, and forgetting a network once the setup screen exists.

## Copy (approved by Andrew; the failure messages may be customized later)

| Where | String |
| --- | --- |
| Book store, connecting | Connecting to the book store… this might take a minute while we find the Wi‑Fi. |
| Book store, `unreachable` | The Kindle couldn’t find the Wi‑Fi. Check the internet is on at home, then try again. |
| Book store, `off` | The book store needs Wi‑Fi, but Wi‑Fi is turned off on this Kindle. |
| Book store, connected but no internet | The Kindle is on the Wi‑Fi but can’t reach the internet. Please try again later. |
| Book store, store not responding | The book store isn’t working right now. Please try again later. |
| Book store, `asleep` or `ended` | No message. |
| Book store, dismiss | OK |
| Settings, problem | The Kindle can’t reach the internet. |
| Settings, fine | The Kindle is connected to the internet when it needs to be. |
| Settings, Airplane mode off (draft) | Airplane mode: Off |
| Settings, Airplane mode on (draft) | Airplane mode: On until %1 %2 (`9:12 am`, `today` or `tomorrow`) |
| Setup, title | Wi‑Fi |
| Setup, looking | Looking for Wi‑Fi networks… |
| Setup, none found | No Wi‑Fi networks found. |
| Setup, password prompt | Password for %1 |
| Setup, connect | Connect |
| Setup, wrong password | Couldn’t connect to %1. Check the password and try again. |
| Setup, connected | Connected to %1 |
| Setup, forget | Forget this network |
| Setup, off setting | Wi‑Fi is turned off on this Kindle. |
