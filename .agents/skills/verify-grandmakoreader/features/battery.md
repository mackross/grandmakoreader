# Low battery

The usual reading footer stays hidden. A persistent message at the bottom shows the percentage while charge is below 10%.

## Sub-features

- `battery-threshold` leaves the footer hidden at 10% and displays the warning at 9%.
- `battery-recovery` removes the warning when charge goes back above the threshold.

## How to get to it (user POV)

- Read a book with the Kindle below 10%. The warning appears automatically at the bottom of the page.

## Driving it with SDL

Preconditions: the doctor passes. The harness supplies simulated battery percentages through KOReader's power-device interface.

- Run `tools/review-koreader "$evidence"`. Compare `02-reading.png` and `06-low-battery.png`. The low-battery image must show “This Kindle needs to be charged. 9% battery remaining.” The test checks the footer at 10%, at 9%, and after restoring the healthy level.
- For an interactive Mac preview, run `KO_DEV_BATTERY_PERCENT=9 tools/koreader run oasis3` and open **Oasis Sample**.

## Gotchas

- The preview variable is fixed for one app launch. Use the automated run to verify the transition.
