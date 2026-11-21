# End of book

Turning forward from the last page shows a note from Andrew on a page of its own, then the four choices. Portrait stacks the choices and landscape uses a 2×2 grid.

## Sub-features

- `love-note`: the note reads “Dear Grandma, I hope you enjoyed this book. With love, Andrew ♥”. A forward page key, a left swipe, or a tap turns to the choices. A back page key or a right swipe returns to the last page.
- `note-double-tap`: when a tap turns the note, the choices ignore taps for half a second, so an impatient second tap chooses nothing. Choices opened by a key or swipe take taps at once. Turning past the last page also closes Find a place, so the note is never drawn under its bar.
- `finish-shelve` marks the book read, saves exactly zero progress, and returns to Books.
- `finish-restart` immediately opens the first page.
- `finish-stay` dismisses the choices and leaves the last page open.
- `finish-keys`: page back dismisses the choices on the last page, and page forward leaves them open.
- `finish-remove` replaces the choices with a same-size confirmation. Cancel restores the choices. **Yes, it's rubbish** removes the fixture from the library.

## How to get to it (user POV)

- Continue to the last page and press the forward page button again to see Andrew's note, then once more for the choices.
- Choose **Put back on shelf**, **Read again now**, **Go back to last page**, or **Throw away**.

## Driving it with SDL

Preconditions: the doctor passes and the review uses its own fixture copies. The test places the reader on the last page, then uses the forward key to enter the dialog.

- Run `tools/review-koreader "$evidence"`. Check `08-love-note.png` for the note. The test turns back from it by key and by right swipe, and reaches the choices by tap, left swipe, and forward key. Right after the tap it taps **Put back on shelf** and checks the choices stay open and the book is not marked read. Compare `08-end-of-book.png` and `09-removal-confirmation.png` in each orientation. The confirmation must replace the first dialog at equal bounds and ask **Are you sure?**.
- The test taps **Cancel**, verifies the book still exists, and checks that the original choices return. It checks the last-page and restart actions against the resulting page number.
- The test shelves a finished book, reads the saved completed status and zero progress, then reopens the book at page one. Finally it confirms removal and checks both the Books list and the fixture file.

## Gotchas

- Confirm removal only in the disposable library during verification.
- The automated run shortcuts reaching the last page. The extra forward key and all dialog choices go through SDL input.
