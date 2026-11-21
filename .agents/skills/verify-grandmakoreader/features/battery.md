# Low battery

The usual reading footer stays hidden. A persistent message at the bottom shows the percentage while charge is below 10%.

## Sub-features

- `battery-threshold` leaves the footer hidden at 10% and displays the warning at 9%.
- `battery-recovery` removes the warning when charge goes back above the threshold.
- `battery-settings` names the battery level in the Settings title, as **Settings · Battery 75%**, or **Settings · Charging 75%** while plugged in. It is read when Settings opens and again on plugging in, unplugging, and waking. Advanced and Report a problem keep their own titles.

## How to get to it (user POV)

- Read a book with the Kindle below 10%. The warning appears automatically at the bottom of the page.
- Tap **Settings** to see the battery level at any charge.

## Driving it with SDL

Preconditions: the doctor passes. The harness supplies simulated battery percentages through KOReader's power-device interface.

- Run `tools/review-koreader "$evidence"`. Compare `02-reading.png` and `06-low-battery.png`. The low-battery image must show “This Kindle needs to be charged. 9% battery remaining.” The test checks the footer at 10%, at 9%, and after restoring the healthy level. The Settings part of the run checks the title **Settings · Battery 75%**, and **Settings · Charging 75%** after a Charging event; see `01-settings-charging.png`.
- For an interactive Mac preview, run `KO_DEV_BATTERY_PERCENT=9 tools/koreader run oasis3` and open **Oasis Sample**.

## Gotchas

- The preview variable is fixed for one app launch. Use the automated run to verify the transition.
