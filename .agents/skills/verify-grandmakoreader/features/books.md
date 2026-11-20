# Books and reading position

The Books screen lists supported titles from one folder. Returning from the reading menu keeps the current reading position.

## Sub-features

- `shelf-launch` opens the fixed library at startup, even with an older startup preference.
- `shelf-refresh` updates the list after unplugging and fits the active orientation.
- `places` shows Book Shop, Book Shelf, and Settings along the bottom, with the open one filled in.
- `exit-to-kindle` leaves KOReader from Settings, Advanced, Exit to Kindle, after a confirmation.
- `shelf-order` files titles the way a library does, ignoring a leading The, A, or An.
- `shelf-arrows` names the open shelf in the title and each neighbour on an arrow, and stops at both ends. Each end takes as many letters as tell it from the neighbouring shelf, such as **Books B–Man** beside **Mar–T** in portrait.
- `find` reaches a book by its first letter, by Read lately, or by typing part of its title or author.
- `shelf-open` opens a tapped book.
- `shelf-return` preserves the reading position when you leave and reopen a book.

## How to get to it (user POV)

- Start KOReader. Tap **An Evening Walk**.
- With more than one shelf of books, tap the arrow beside the title to change shelf. Tap **Find a book**, then a letter, **Read lately**, or **Type a name**.
- Tap **Settings**, **Advanced**, then **Exit to Kindle**. Choose **Cancel** to stay, or **Exit to Kindle** to leave KOReader.
- Tap the page while reading, choose **Open another book**, then reopen the same title.

## Driving it with SDL

Preconditions: the doctor check passes and the review can seed the two fixture books.

- Run `tools/review-koreader "$evidence"`. In each orientation, `01-books.png` should show the two titles and `02-reading.png` should show the opening of **An Evening Walk**.
- Before the two-book checks, the run fills the folder with 16 titles and checks their library order, the letters on the title and arrows, and that the first and last shelves stop. G runs onto a second shelf in landscape and M in portrait, and Find checks that the right arrow of that letter’s first shelf starts with it. See `01-first-shelf.png` and `01-last-shelf.png`, and `01-book-shop.png` and `01-settings.png` for the other two places.
- The run opens **Find a book** and checks a letter (`01-find.png`, `01-letter-shelf.png`), **Read lately** with seeded history (`01-read-lately.png`), and a typed title and author (`01-type-a-name.png`, `01-typed-name.png`, `01-typed-author.png`). It sets the typed text directly instead of pressing each key.
- In Settings the run taps **Advanced** (`01-advanced.png`) and **Exit to Kindle** (`01-exit-to-kindle.png`), cancels, and returns with the Settings button. It ends by confirming **Exit to Kindle**, so the review exits 0 only when that button quits KOReader.
- The run changes the disposable folder and sends the unplug event, then checks the shelf count. It also rotates the open shelf and checks its new dimensions.
- The run turns to a later page, taps **Open another book**, reopens the book from Books, and checks the saved reading position after reopening.

## Gotchas

- **Find a book** and the arrows appear only when the books fill more than one shelf. Two books show neither.
- Authors come from KOReader’s cover browser plugin, which reads each book in a background process. A typed author matches once that has finished; the run waits for it.
- The simulator cannot show the Kindle's own home screen. Exit to Kindle only ends KOReader there.
- On Kindle, copy books to the top-level `books` folder. The simulator creates its own temporary library.
- The reading menu says **Open another book**, while the end-of-book dialog says **Put back on shelf**. The [end-of-book action](end-of-book.md) marks the book read instead of keeping the place.
