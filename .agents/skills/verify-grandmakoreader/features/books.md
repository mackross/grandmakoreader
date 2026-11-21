# Books and reading position

The Books screen lists supported titles from one folder. Returning from the reading menu keeps the current reading position.

## Sub-features

- `shelf-launch` opens the fixed library at startup, even with an older startup preference.
- `shelf-refresh` updates the list after unplugging and fits the active orientation.
- `places` shows Book Shop, Book Shelf, and Settings along the bottom, with the open one filled in. Settings lists Instructions, [Check for updates](auto-update.md), and Advanced.
- `instructions` opens the instructions book that ships in `patches/instructions/`, from a copy in KOReader's data folder. Its last page asks nothing; **Open another book** returns to the shelf.
- `exit-to-kindle` leaves KOReader from Settings, Advanced, Exit to Kindle, after a confirmation.
- `report-a-problem` shows a QR code from Settings, Advanced, Report a problem. A phone's camera reads it as an email to Andrew whose message [`patches/report.lua`](../../../../patches/report.lua) has written: the time, the KOReader version, the last uncaught error in `crash.log` with the top of its traceback, and the newest warnings and `Auto-update:` lines that fit. The link stays within 1,500 bytes so the squares stay large. The phone sends the email, so the Kindle needs no Wi‑Fi.
- `shelf-order` names each book by the title inside it, with its author on a smaller line below, and files titles the way a library does, ignoring a leading The, A, or An.
- `shelf-arrows` names the open shelf in the title and each neighbour on an arrow, and stops at both ends. Each end takes as many letters as tell it from the neighbouring shelf, such as **B–Gr** beside **Gu–O** in portrait. Portrait titles a shelf by its letters alone; landscape says **Books** first, as in **Books F–G**.
- `find` reaches a book by its first letter, by Read lately, or by typing part of its title or author.
- `shelf-open` opens a tapped book.
- `throw-away` asks, when a book is held for four seconds, whether to throw it away. **Yes, it's rubbish** removes it and keeps its shelf open; **Cancel** keeps it.
- `shelf-return` preserves the reading position when you leave and reopen a book.

## How to get to it (user POV)

- Start KOReader. Tap **An Evening Walk**.
- With more than one shelf of books, tap the arrow beside the title to change shelf. Tap **Look up a book**, then a letter, **Read lately**, or **Type a name**.
- Hold a title for four seconds until the question appears, then choose **Cancel** or **Yes, it's rubbish**.
- Tap **Settings**, **Advanced**, then **Exit to Kindle**. Choose **Cancel** to stay, or **Exit to Kindle** to leave KOReader.
- Tap the page while reading, choose **Open another book**, then reopen the same title.

## Driving it with SDL

Preconditions: the doctor check passes and the review can seed the two fixture books.

- Run `tools/review-koreader "$evidence"`. In each orientation, `01-books.png` should show the two titles and `02-reading.png` should show the opening of **An Evening Walk**.
- Before the two-book checks, the run fills the folder with 16 titles and checks their library order, the letters on the title and arrows, and that the first and last shelves stop. Two of them are FictionBook files whose file names are not their titles: the run checks that a file name stands in at first and that the shelf takes up the titles inside them by itself. A shelf holds eight one-line books in portrait and five in landscape, and fewer when authors take a second line, so G runs onto a second shelf in portrait, and Find checks that the right arrow of its first shelf starts with G. See `01-first-shelf.png` and `01-last-shelf.png`, and `01-book-shop.png` and `01-settings.png` for the other two places.
- The run opens **Look up a book** and checks a letter (`01-find.png`, `01-letter-shelf.png`), **Read lately** with seeded history, its dates on the author line and, in landscape, its Older and Newer arrows (`01-read-lately.png`, `01-read-lately-older.png`), and a typed title and author (`01-type-a-name.png`, `01-typed-name.png`, `01-typed-author.png`). It sets the typed text directly instead of pressing each key.
- In Settings the run taps **Instructions** (`01-instructions.png`), checks the book opens from the copy, turns past its end without a question, and leaves with **Open another book**.
- In Settings the run taps **Advanced** (`01-advanced.png`). It writes a fixture `crash.log`, taps **Report a problem** (`01-report-a-problem.png`), and checks the link the code holds: the address, the crash, the newest warnings, and its length. Then it taps **Exit to Kindle** (`01-exit-to-kindle.png`), cancels, and returns with the Settings button. It ends by confirming **Exit to Kindle**, so the review exits 0 only when that button quits KOReader.
- On the second shelf the run holds the first title for 3.5 seconds and checks nothing happens, then for four seconds (`01-throw-away.png`), cancels, then holds it again and confirms. It checks the file is gone and the same shelf is open, starting with the next title (`01-thrown-away.png`).
- The run changes the disposable folder and sends the unplug event, then checks the shelf count. It also rotates the open shelf and checks its new dimensions.
- The run turns to a later page, taps **Open another book**, reopens the book from Books, and checks the saved reading position after reopening.

## Gotchas

- The review checks the text handed to the QR widget, not that a camera reads the picture. Whether a phone reads it off the e-ink screen is a device check.
- Only an uncaught Lua error leaves a crash in the log. A freeze or a crash below Lua shows as “No crash in the log.” with whatever warnings came before it.
- **Look up a book** and the arrows appear only when the books fill more than one shelf. Two books show neither.
- Titles and authors come from KOReader’s cover browser plugin, which reads each book in a background process. Until then the shelf shows the file name and no author; the shelf rebuilds once a batch has read something, and the run waits for it.
- The simulator cannot show the Kindle's own home screen. Exit to Kindle only ends KOReader there.
- On Kindle, copy books to the top-level `books` folder. The simulator creates its own temporary library.
- The reading menu says **Open another book**, while the end-of-book dialog says **Put back on shelf**. The [end-of-book action](end-of-book.md) marks the book read instead of keeping the place.
