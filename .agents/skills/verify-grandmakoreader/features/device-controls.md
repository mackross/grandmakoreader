# Frontlight and sleep

The reading menu adjusts the frontlight and lets the reader put the Kindle to sleep.

## Sub-features

- `light-adjust` opens the brightness grid from **Turn on light** or **Adjust light**. **Turn off** in the grid switches the light off.
- `light-limits` hides the unavailable direction at each brightness limit while keeping **Done** in place.
- `sleep` saves the book state and puts the reader to sleep.

## How to get to it (user POV)

- From a book, tap the page. Tap **Turn on light**, make any adjustment, and tap **Done**. Reopen the menu and tap **Adjust light**, then **Turn off**.
- Tap the page and select **Stop for now**. Use the power button to wake a Kindle, or F2 in the desktop preview.

## Driving it with SDL

Preconditions: the doctor passes. The simulator starts with the frontlight off.

- Run `tools/review-koreader "$evidence"`. Inspect `05-light-controls.png` for **Darker** and **Brighter** above **Turn off** and **Done**, and `05-adjust-light-menu.png` for **Adjust light**. The test sets the simulated hardware one step from each limit, then taps the relevant control to reach the limit and verifies a second tap in that position leaves brightness and the panel unchanged.
- Inspect `07-stop-for-now.png` for the desktop sleep message. The run checks that the screensaver becomes active and that the reader resumes.

## Gotchas

- Screenshots and SDL state verify the controls. The frontlight’s physical luminance and the Kindle’s actual suspend behavior need a device check.
