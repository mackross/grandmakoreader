# Frontlight and sleep

The reading menu toggles the frontlight and lets the reader put the Kindle to sleep.

## Sub-features

- `light-toggle` opens the brightness controls when switching on and switches off on the next use of the menu.
- `light-limits` hides the unavailable direction at each brightness limit while keeping **Done** in place.
- `sleep` saves the book state and puts the reader to sleep.

## How to get to it (user POV)

- From a book, swipe inward. Tap **Turn on light**, make any adjustment, and tap **Done**. Reopen the menu to use **Turn off light**.
- Swipe inward and select **Stop for now**. Use the power button to wake a Kindle, or F2 in the desktop preview.

## Driving it with SDL

Preconditions: the doctor passes. The simulator starts with the frontlight off.

- Run `tools/review-koreader "$evidence"`. Inspect `05-light-controls.png` for **Darker**, **Brighter**, and **Done**. The test sets the simulated hardware one step from each limit, then taps the relevant control to reach the limit and verifies a second tap in that position leaves brightness and the panel unchanged.
- Inspect `07-stop-for-now.png` for the desktop sleep message. The run checks that the screensaver becomes active and that the reader resumes.

## Gotchas

- Screenshots and SDL state verify the controls. The frontlight’s physical luminance and the Kindle’s actual suspend behavior need a device check.
