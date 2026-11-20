# Decisions for Andrew to review

## Pin the Orb to a public KOReader release

Orbs use the released Linux KOReader `v2026.07.1` on x86-64 or ARM64. The existing Mac environment keeps `v2026.07.2-339-g21cc368`. This lets Amp prepare its snapshot before GitHub credentials are available. Both runtimes run the same Lua patches and verification flow. A future change that depends on a newer KOReader API needs to pass on both pins or move them forward together. Review the final runtime against the version you run on the Kindle. [Linux release](https://github.com/koreader/koreader/releases/tag/v2026.07.1)

## Base Orb verification on the real reader in headless SDL

The Orb runs KOReader with disposable copies of sample books and captures its framebuffer. The feature map checks persisted reading position, completion status, and removal alongside the screens. Touch and page inputs travel through SDL, while battery, frontlight, and sleep use the simulator. Physical buttons, light output, suspend, and e-ink rendering still need a pass on the Oasis.

## Make the GitHub repository public

Andrew chose `mackross/grandmakoreader` as the GitHub repository and first kept it private. He then made it public so the Kindle can fetch updates without a credential stored on it. Nothing secret belongs in the repository, including Wi‑Fi passwords and tokens. An Amp project clones it through Andrew’s GitHub connection. [Amp project setup](https://ampcode.com/docs/orbs/getting-started)

## Use icon-pack icons in the reading menu

The reading menu uses Material Symbols for Change Font and the light, Phosphor for Stop for now, and Tabler for Open another book. The SVGs and their licenses (Apache 2.0 and MIT) live in `patches/icons/`, and the patch loads them from the `icons` folder next to itself. Copy that folder along with the patches to `koreader/patches/` on the Kindle; a missing folder shows KOReader’s icon-not-found picture. Tabler’s and Phosphor’s icons used `currentColor`, which KOReader’s SVG renderer draws as gray, so the copies use plain black. [Material Symbols](https://github.com/google/material-design-icons) [Phosphor](https://github.com/phosphor-icons/core) [Tabler Icons](https://github.com/tabler/tabler-icons)

## Keep Wi‑Fi on only while something needs it

`patches/2-wifi.lua` owns the Wi‑Fi radio. The updater and the future book store register named needs with timeouts. Wi‑Fi turns off 10 seconds after the last need ends and when the Kindle sleeps. A need gives up after 60 seconds without a connection, counted separately for each need. Needs form a set rather than a stack, because downloads and timeouts end in any order. At startup, the module turns off Wi‑Fi left on by the Kindle. On a Kindle it connects through `wifid` with `restoreWifiAsync`, which joins saved networks without KOReader’s 20-second blocking scan and popups. So the reader’s home network must be saved, either through the stock Kindle UI or the planned setup screen. A failed connection shows nothing unless the book store asked for it. Turning Wi‑Fi off blocks everything, updates included, and lifts by itself after 24 hours, so a Kindle can never be cut off from fixes for longer than a day. The updater uses `Wifi:need` and switches the radio itself only when this module is missing.

## Update the Kindle from `main`

The Kindle mirrors `patches/` from `main` of the public repository, with no credential on the device. The whole folder ships, subfolders included, so a patch and its resources (such as `patches/icons/`) always arrive together; that makes `patches/` the one place for anything the Kindle needs. Andrew chose `main` over a separate `release` branch, so publishing is any push to `main` and there is no second step to forget. The cost is that `main` must always be fit for the Kindle: every thread's push ships within about an hour of the next wake, and unfinished work belongs on another branch. This needs no server, build step, or release artifact. The device compares GitHub's file hashes with its own and downloads only the files that changed. GitHub allows 60 anonymous requests an hour from one network; a check is one request and an update adds one per changed file. A read-only token in `auto-update.lua` is still supported, for a private repository or a shared network that runs out of anonymous requests. [Setup and behavior](README.md#update-the-kindle-over-wi-fi)

The updater applies a release by restarting KOReader. It restarts at once only when the shelf is the front screen and nothing else holds Wi-Fi, so it never restarts under the planned book store, settings, or setup screens or during a book download. Otherwise it waits for the next wake. It rolls back a release that fails to load or dies in its first minute. It only updates the Lua patches. KOReader itself, books, and settings stay as shipped.

The updater borrows the radio from `patches/2-wifi.lua` with the `auto-update` need and tells that module whether the internet answered, which feeds the planned settings line. It keeps its own radio switching only for when that module is missing or fails to load, so a fix can still arrive. Turning Wi-Fi off for a day stops updates for that day. Checks are skipped below 10% battery, the same threshold as the low-battery warning.

`tools/review-auto-update` covers download, staging, restart rules, rollback, reopening the book, and the Wi-Fi hand-off against a stand-in for GitHub. The real GitHub download over verified HTTPS was checked by hand in the simulator. Joining the saved network, the restart through Kindle's launcher script, and wake detection still need a check on the Oasis before it ships.

## Make the home screen a Book Shelf with a Book Shop and Settings beside it

Three places sit along the bottom: Book Shop, Book Shelf in the centre and raised over the bar, and Settings. Book Shop shows “Coming soon” until it has content. Settings holds Advanced; see below. The shop and shelf icons were drawn for this project and live with the others in `patches/icons/`.

## File the shelf in library order and name shelves by letter

Titles follow the ALA Filing Rules in `patches/library.lua`: a leading The, A, or An is ignored, words file one at a time, and numbers come before letters. The stock page controls are gone. The title names the open shelf, such as “Books B–L”, and an arrow on each side shows the neighbouring shelf’s letters. Shelves stop at both ends. The labels use only the first letter, so a letter that fills more than one shelf repeats; that case is being worked on separately.

## Find a book by letter, by Read lately, or by typing, with no sort switch

Find a book sits at the bottom right and appears only with more than one shelf. It costs two rows: 12 books a shelf in portrait and 7 in landscape. The shelf stays in title order; Read lately takes the place of a sort switch. One typed search matches titles and authors together. KOReader’s own file search was left out for its filename wording and extra controls, while its keyboard, input dialog, and reading history are reused.

## Read authors through KOReader’s cover browser plugin

`patches/authors.lua` borrows the cover browser’s background reader and database for each book’s author, so the plugin has to stay installed on the Kindle. A typed author matches a book once it has been read in the background. The speed of that on the Oasis is unmeasured.

## Put Exit to Kindle behind Settings, Advanced, and a confirmation

Andrew asked for Advanced (Exit to Kindle) in Settings. Settings shows one row, Advanced, and Advanced shows one row, Exit to Kindle. A tap on it asks “Leave the books and go to the Kindle’s own home screen?” with Cancel and Exit to Kindle. Leaving takes three deliberate taps in three places, so a stray tap or swipe while reading cannot strand the reader on the Kindle’s home screen, which she may not know how to leave. The word Advanced tells her the row is not for her, and Settings stays free for everyday choices later. A row straight in Settings would cost one fewer tap but sit beside those everyday choices. A password or long press was left out: the confirmation is enough for an accident, and nothing here needs to be kept from her. Advanced is a side room of Settings, like Find on the shelf: no place is filled in, and the Settings button goes back. Exit to Kindle ends KOReader with code 0, as KOReader’s own Exit does, and the Kindle’s launcher returns to its home screen. The simulator checks the quit; the return to the Kindle home screen and how to reopen KOReader from there need a check on the Oasis.
