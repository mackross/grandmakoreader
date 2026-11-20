# End of book

Turning forward from the last page offers four choices. Portrait stacks the choices and landscape uses a 2×2 grid.

## Sub-features

- `finish-shelve` marks the book read, saves exactly zero progress, and returns to Books.
- `finish-restart` immediately opens the first page.
- `finish-stay` dismisses the choices and leaves the last page open.
- `finish-remove` replaces the choices with a same-size confirmation. Cancel restores the choices. **Yes, it's rubbish** removes the fixture from the library.

## How to get to it (user POV)

- Continue to the last page and press the forward page button again.
- Choose **Put back on shelf**, **Read it again now**, **Go back to last page**, or **Throw it away**.

## Driving it with SDL

Preconditions: the doctor passes and the review uses its own fixture copies. The test places the reader on the last page, then uses the forward key to enter the dialog.

- Run `tools/review-koreader "$evidence"`. Compare `08-end-of-book.png` and `09-removal-confirmation.png` in each orientation. The confirmation must replace the first dialog at equal bounds and ask **Are you sure?**.
- The test taps **Cancel**, verifies the book still exists, and checks that the original choices return. It checks the last-page and restart actions against the resulting page number.
- The test shelves a finished book, reads the saved completed status and zero progress, then reopens the book at page one. Finally it confirms removal and checks both the Books list and the fixture file.

## Gotchas

- Confirm removal only in the disposable library during verification.
- The automated run shortcuts reaching the last page. The extra forward key and all dialog choices go through SDL input.
