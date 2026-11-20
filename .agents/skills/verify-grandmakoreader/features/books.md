# Books and reading position

The Books screen lists supported titles from one folder. Returning from the reading menu keeps the current reading position.

## Sub-features

- `shelf-launch` opens the fixed library at startup, even with an older startup preference.
- `shelf-refresh` updates the list after unplugging and fits the active orientation.
- `shelf-open` opens a tapped book.
- `shelf-return` preserves the reading position when you leave and reopen a book.

## How to get to it (user POV)

- Start KOReader. Tap **An Evening Walk**.
- Swipe inward from an edge while reading, choose **Open another book**, then reopen the same title.

## Driving it with SDL

Preconditions: the doctor check passes and the review can seed the two fixture books.

- Run `tools/review-koreader "$evidence"`. In each orientation, `01-books.png` should show the two titles and `02-reading.png` should show the opening of **An Evening Walk**.
- The run changes the disposable folder and sends the unplug event, then checks the shelf count. It also rotates the open shelf and checks its new dimensions.
- The run turns to a later page, taps **Open another book**, reopens the book from Books, and checks the saved reading position after reopening.

## Gotchas

- On Kindle, copy books to the top-level `books` folder. The simulator creates its own temporary library.
- The reading menu says **Open another book**, while the end-of-book dialog says **Put back on shelf**. The [end-of-book action](end-of-book.md) marks the book read instead of keeping the place.
