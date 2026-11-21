# Decisions for Andrew to review

## Pin the Orb to a public KOReader release

Orbs use the released Linux KOReader `v2026.07.1` on x86-64 or ARM64. The existing Mac environment keeps `v2026.07.2-339-g21cc368`. This lets Amp prepare its snapshot before GitHub credentials are available. Both runtimes run the same Lua patches and verification flow. A future change that depends on a newer KOReader API needs to pass on both pins or move them forward together. Review the final runtime against the version you run on the Kindle. [Linux release](https://github.com/koreader/koreader/releases/tag/v2026.07.1)

## Base Orb verification on the real reader in headless SDL

The Orb runs KOReader with disposable copies of sample books and captures its framebuffer. The feature map checks persisted reading position, completion status, and removal alongside the screens. Touch and page inputs travel through SDL, while battery, frontlight, and sleep use the simulator. Physical buttons, light output, suspend, and e-ink rendering still need a pass on the Oasis.

## Make the GitHub repository public

Andrew chose `mackross/grandmakoreader` as the GitHub repository and first kept it private. He then made it public so the Kindle can fetch updates without a credential stored on it. Nothing secret belongs in the repository, including Wi‑Fi passwords and tokens. An Amp project clones it through Andrew’s GitHub connection. [Amp project setup](https://ampcode.com/docs/orbs/getting-started)

## Use icon-pack icons in the reading menu

The reading menu uses Material Symbols for Change Text Size and the light, Phosphor for Stop for now, and Tabler for Open another book. The SVGs and their licenses (Apache 2.0 and MIT) live in `patches/icons/`, and the patch loads them from the `icons` folder next to itself. Copy that folder along with the patches to `koreader/patches/` on the Kindle; a missing folder shows KOReader’s icon-not-found picture. Tabler’s and Phosphor’s icons used `currentColor`, which KOReader’s SVG renderer draws as gray, so the copies use plain black. [Material Symbols](https://github.com/google/material-design-icons) [Phosphor](https://github.com/phosphor-icons/core) [Tabler Icons](https://github.com/tabler/tabler-icons)

## Keep Wi‑Fi on only while something needs it

`patches/2-wifi.lua` owns the Wi‑Fi radio. The updater and the future book store register named needs with timeouts. Wi‑Fi turns off 10 seconds after the last need ends and when the Kindle sleeps. A need gives up after 60 seconds without a connection, counted separately for each need. Needs form a set rather than a stack, because downloads and timeouts end in any order. At startup, the module turns off Wi‑Fi left on by the Kindle. On a Kindle it connects through `wifid` with `restoreWifiAsync`, which joins saved networks without KOReader’s 20-second blocking scan and popups. So the reader’s home network must be saved, either through the stock Kindle UI or the planned setup screen. A failed connection shows nothing unless the book store asked for it. Turning Wi‑Fi off blocks everything, updates included, and lifts by itself after 24 hours, so a Kindle can never be cut off from fixes for longer than a day. The updater uses `Wifi:need` and switches the radio itself only when this module is missing.

## Update the Kindle from `main`

The Kindle mirrors `patches/` from `main` of the public repository, with no credential on the device. The whole folder ships, subfolders included, so a patch and its resources (such as `patches/icons/`) always arrive together; that makes `patches/` the one place for anything the Kindle needs. Andrew chose `main` over a separate `release` branch, so publishing is any push to `main` and there is no second step to forget. The cost is that `main` must always be fit for the Kindle: every thread's push ships within about an hour of the next wake, and unfinished work belongs on another branch. This needs no server, build step, or release artifact. The device compares GitHub's file hashes with its own and downloads only the files that changed. GitHub allows 60 anonymous requests an hour from one network; a check is one request and an update adds one per changed file. A read-only token in `auto-update.lua` is still supported, for a private repository or a shared network that runs out of anonymous requests. [Setup and behavior](README.md#update-the-kindle-over-wi-fi)

The updater applies a release by restarting KOReader. It restarts at once only when the shelf is the front screen and nothing else holds Wi-Fi, so it never restarts under the planned book store, settings, or setup screens or during a book download. Otherwise it waits for the next wake. It rolls back a release that fails to load or dies in its first minute. It only updates the Lua patches. KOReader itself, books, and settings stay as shipped.

The updater borrows the radio from `patches/2-wifi.lua` with the `auto-update` need and tells that module whether the internet answered, which feeds the planned settings line. It keeps its own radio switching only for when that module is missing or fails to load, so a fix can still arrive. Turning Wi-Fi off for a day stops updates for that day. Checks are skipped below 10% battery, the same threshold as the low-battery warning.

`tools/review-auto-update` covers download, staging, restart rules, rollback, reopening the book, and the Wi-Fi hand-off against a stand-in for GitHub. The real GitHub download over verified HTTPS was checked by hand in the simulator. Joining the saved network, the restart through Kindle's launcher script, and wake detection still need a check on the Oasis before it ships.

## Check for updates from Settings

Andrew asked for a button under Settings that pulls the latest update. It is the first row in Settings, above Advanced: **Check for updates**, with a row under it that says how the check is going and how it ended. It is a row like Advanced rather than an outlined button, so Settings stays one list. It runs the same check as the hourly one, through the same download, staging, and rollback, so it adds no second way to install. It is greyed out while a check runs, and when the updater is switched off it stays greyed out and says so.

The wording is drafted, not yet approved. The Wi‑Fi failures reuse the book store lines Andrew approved, and the full list is in the [feature map](.agents/skills/verify-grandmakoreader/features/auto-update.md).

After a download the screen says an update was found and KOReader restarts within five seconds. Settings is part of the home screen, so an hourly check that finds a release also restarts from Settings, as it does from the shelf. The alternative, waiting for the next wake while Settings is open, would leave a release waiting for no gain while Settings holds only rows to tap; revisit it when Settings gains a screen where a restart would lose typing.

The row doubles as the diagnosis on the device. KOReader on a Kindle hides its storage from USB while it runs, so reading `crash.log` takes Exit to Kindle and a cable.

## Let a release’s own updater take over as it is installed

Andrew saw Settings say “Updates are switched off on this Kindle.” on a Kindle that was updating. The updater that installs a release is the previous release’s, already running when it swaps the folder, so the new Settings row found no check to call until the next restart. The updater now runs the release’s own copy in its place straight after the swap. A patch can therefore rely on the updater it ships with.

This also puts the updater inside the trial. A release whose updater is missing, fails as it loads, or fails as it starts now goes back to the previous release and is not downloaded again; before, such a release passed its trial on the old updater and then left the Kindle unable to update. The cost is a rule: the file must stay named `1-auto-update.lua`, and every later version must accept the word the previous one hands it.

## Make the home screen a Book Shelf with a Book Shop and Settings beside it

Three places sit along the bottom: Book Shop, Book Shelf in the centre and raised over the bar, and Settings. Book Shop shows “Coming soon” until it has content. Settings holds Advanced; see below. The shop and shelf icons were drawn for this project and live with the others in `patches/icons/`.

## File the shelf in library order and name shelves by letter

Titles follow the ALA Filing Rules in `patches/library.lua`: a leading The, A, or An is ignored, words file one at a time, and numbers come before letters. The stock page controls are gone. The title names the open shelf, such as “Books B–L”, and an arrow on each side shows the neighbouring shelf’s letters. Shelves stop at both ends.

## Label shelves like encyclopedia spines when a letter fills more than one

Each end of a shelf’s letters takes as many letters as it needs to differ from the neighbouring shelf, as on encyclopedia volumes such as “S–Sn” and “So–Sz”. A library with many S titles reads “C–Sea”, “Sec–St”, and “Sw–W” in portrait, so the title and both arrows stay distinct, and a letter that goes on past the shelf Find opens shows on that shelf’s right arrow. An end stops at three letters, or at fewer on every shelf when the widest labels would not fit beside the title. Two titles that agree in their first three letters on either side of a shelf break, such as The Secret Adversary and The Secret Agent, give both shelves the same end, such as “Ro–Sec” beside “Sec–So”. Shelves break by how many rows fit rather than at letters, so none is left part-empty; a book with its author on a second line takes more room than one without.

## Look up a book by letter, by Read lately, or by typing, with no sort switch

The button reads “Look up a book”, Andrew’s wording, spelled as two words. He found “Find a book” confusing, because it could mean finding one in the Book Shop; looking a book up is what she would do in a library’s catalogue. “Find a shelf” was tried and dropped, because Read lately and a typed name lead to books. It spans the bottom of the list in the titles’ type size, as Andrew asked, and appears only with more than one shelf. Its strip takes room from the list. The shelf stays in title order; Read lately takes the place of a sort switch. One typed search matches titles and authors together. KOReader’s own file search was left out for its filename wording and extra controls, while its keyboard, input dialog, and reading history are reused.

## Read titles and authors through KOReader’s cover browser plugin

`patches/details.lua` borrows the cover browser’s background reader and database for each book’s title and author, so the plugin has to stay installed on the Kindle. A typed author matches a book once it has been read in the background. The speed of that on the Oasis is unmeasured.

## Name books by the title inside them, with the author on a line below

Andrew found the shelf showing file names. Each book now shows the title its file gives, and its file name only until the book has been read in the background or when the file names no title. When a reading finishes, the open shelf takes up the new titles by itself and stays on the same shelf number, even if a renamed book moves to another shelf. Andrew asked for the author on a second line under the title, in smaller grey type (size 32 under the titles’ 40), knowing it means fewer books a shelf: a shelf of books that all name their authors holds about 5 in portrait and 3 in landscape. The same two lines show in a typed search, where the author used to sit at the right. In Read lately, when the book was last open goes on the author’s line, as in “Agatha Christie · Yesterday”, or alone there for a book without an author, so long titles have the full width; a long author’s name is shortened before the date is. Andrew chose this after seeing realistic long titles, where the date column squeezed the titles and only three books fitted. Read lately therefore runs past one screen, with arrows labelled Newer and Older in place of letters. A file whose own title is poor, such as some PDFs’, shows that title; there is no way to rename a book on the Kindle.

## Put Exit to Kindle behind Settings, Advanced, and a confirmation

Andrew asked for Advanced (Exit to Kindle) in Settings. Settings shows one row, Advanced, and Advanced shows one row, Exit to Kindle. A tap on it asks “Leave the books and go to the Kindle’s own home screen?” with Cancel and Exit to Kindle. Leaving takes three deliberate taps in three places, so a stray tap or swipe while reading cannot strand the reader on the Kindle’s home screen, which she may not know how to leave. The word Advanced tells her the row is not for her, and Settings stays free for everyday choices later. A row straight in Settings would cost one fewer tap but sit beside those everyday choices. A password or long press was left out: the confirmation is enough for an accident, and nothing here needs to be kept from her. Advanced is a side room of Settings, like Find on the shelf: no place is filled in, and the Settings button goes back. Exit to Kindle ends KOReader with code 0, as KOReader’s own Exit does, and the Kindle’s launcher returns to its home screen. The simulator checks the quit; the return to the Kindle home screen and how to reopen KOReader from there need a check on the Oasis.

## Report a problem as a QR code that writes an email

Andrew asked for crash reporting without a hosted service, and chose a QR code under Advanced holding a `mailto:` link to him. Advanced now lists Report a problem above Exit to Kindle. The screen shows one sentence and the code. Whoever is with the Kindle points a phone at it and presses Send, so the Kindle needs no Wi‑Fi, token, or service, and nothing leaves it unless a person sends it.

The email holds the time, the KOReader version, the last uncaught error in `crash.log` with the top of its traceback, and the newest warnings and update checks that fit. The link is held to 1,500 bytes, about half of what a QR code can carry, so each square is at least six pixels on the Oasis. The address, `andrew@mackross.net`, and the sentence on the screen are drafts for Andrew to confirm. The log can name book files, which is acceptable in an email to Andrew and was a reason not to post reports anywhere public.

It reports only what KOReader logged: a freeze, or a crash that leaves no Lua error, shows as no crash. It also needs someone with a phone beside the Kindle. A Google Form inbox with a daily heartbeat was the unattended alternative and can still be added by update, because it needs no secret.

## Use larger type on the home screen, with fewer books on a shelf

Andrew found the home screen crowded and its type too small, and pointed to the reading menu’s type as the size to aim for. Titles went from size 26 to 40, the reading menu’s size, which leaves 8 books a shelf in portrait and 5 in landscape where there were 12 and 7. The arrows, the title, Look up a book, the Find screen’s question and buttons, the Exit to Kindle question, and the labels on the bottom bar grew with them. A library therefore runs to more shelves. Titles stay in regular weight, because bold marks the book being read: the last one opened, wherever it shows. Andrew asked for that after a shelf rebuilt with new titles lost the bold; a letter or a return now only picks the shelf.

## Leave Books out of the shelf title in portrait

Andrew asked for this to make room for the larger arrows. In portrait a shelf with neighbours is titled by its letters alone, such as “J–O”. Landscape keeps “Books J–O”, and a single shelf is still titled “Books” in both.

## Vendor the Z-library plugin for testing

The Kindle already runs [zlibrary.koplugin](https://github.com/ZlibraryKO/zlibrary.koplugin) v1.0.59, so the simulator needs it too to design the book shop around it. The plugin is vendored at `plugins/zlibrary.koplugin/` with its `.git` removed, which the launcher symlinks into each profile like `devcheck.koplugin`. To take a newer upstream release, clone it fresh and copy it over, keeping the credentials file commented out. A new UI for the plugin can be tested by editing the vendored Lua, but the Kindle only receives `patches/`, so whatever is settled has to ship as a patch that overrides the plugin's files, and `plugins/zlibrary.koplugin/` stays development-only.

## The Book Shop opens Z-library through Find a new book

The Kindle already runs zlibrary.koplugin, so the simulator needed it too: the plugin is vendored at `plugins/zlibrary.koplugin/` (development-only, never shipped, refreshed by cloning a newer release over it, credentials file git-ignored). The Book Shop place shows no rows; where the shelf puts Look up a book it puts Find a new book, which loads the plugin class straight from its folder (the patch replaces `FileManager:showFiles`, so no FileManager exists to load plugins the usual way) and opens its search. The plugin is looked up first in the repo's `plugins/`, then next to the running KOReader, so the same button works on the Kindle. A UI redesign for the plugin can be prototyped in the vendored Lua, but the Kindle only receives `patches/`, so whatever is settled has to ship as a patch that overrides the plugin's files. [zlibrary.koplugin](https://github.com/ZlibraryKO/zlibrary.koplugin)

## Find a place by halving the book with Before and After

Andrew asked for Find a place in the reading menu, working the way he finds a page in a paper book. It opens the book halfway and asks “Find a place: is it before or after this page?”, with Before, Done, and After in one row so most of the page stays visible in landscape. Each answer jumps to the middle of the pages left, so a 300-page book needs about 8 answers, and the search lands on the page itself once one page is left. The page buttons and side swipes turn pages under the question, and the next answer counts from the page on screen. An answer that agrees with the earlier ones keeps their narrower range, and one that contradicts them wins and reopens that side of the book, so a mistaken answer can be corrected by paging and answering again. A tap on the page leaves the question up, and Done ends the search on the page shown. Andrew chose the wording Find a place over “Find your place” and “I’ve read this”. Starting from the furthest page read, Undo, and a “Not sure” answer were discussed and left out for now. Rotating mid-search keeps the same share of the book. The feature is one commit, so it can be reverted alone. The icon is Tabler’s file-search, in plain black like the other Tabler icon.

## Ask before Find a place starts, and offer Go to the beginning

Find a place first shows a box of three large buttons and no title: Find a page, Go to the beginning, and Cancel, stacked in that order in both orientations. Cancel leaves the page as it was. Andrew chose this order over Go to the beginning at the bottom. Andrew asked for the explanation to come after Find a page, so that box stays short: Find a page opens a second box, “The book opens in the middle. Tap Before or After, and each time it gets closer. The page buttons turn pages as normal. Tap Done when you see your page.”, with Start and Cancel. It describes what she sees and does rather than the halving, and shows every time, since she may not remember it from one week to the next. This is its own commit, separate from Find a place.

## Show the pirate book cover when the Kindle sleeps

`patches/2-sleep-screen.lua` sets KOReader’s sleep screen to the only picture in `patches/sleep-screen/`, Grandma’s Magic Pirate Book. KOReader draws image sleep screens in portrait, turning a sideways Kindle upright first. KOReader runs with the Kindle framework still up, so the Kindle’s own sleep screen drew over the picture on the device. Its ad sleep screen also makes KOReader hand sleep to the Kindle entirely, and the Kindle still holds an ad from before it was deregistered. So at startup the patch unloads whichever of the Kindle’s `ad_screensaver` and `screensaver` blanket modules are loaded, tells KOReader the Kindle has no Special Offers, and loads the same modules again on exit, so Exit to Kindle gets the stock sleep screen back. A crash that skips the exit leaves the Kindle’s sleep screen off until it restarts, which only means sleep keeps the last screen. KOReader skips its sleep screen when neither a book nor its file manager is open, and the home screen replaces the file manager, so on the home screen the patch stands in an empty file manager while the sleep screen is set up. The patch also turns off KOReader’s “Sleeping” message, so the picture shows alone.

## End every book with a note from Andrew

Andrew wanted a “with love” surprise that Grandma would find on her own, so every book now ends with a page from him. Turning forward past the last page shows a white page that reads “Dear Grandma, I hope you enjoyed this book. With love, Andrew ♥”, in large serif italic, before the end-of-book choices. It works like a page: the forward button, a left swipe, or a tap turns to the choices, and the back button or a right swipe returns to the last page. A line inside the end-of-book dialog was tried first; a page of its own reads more like a dedication at the back of a book. Andrew first wrote “I hope you are enjoying this magic book” and changed it to “I hope you enjoyed this book”, because it shows after every book, not only the pirate one. Because a tap now opens the choices, they ignore taps for half a second after it, so an impatient second tap cannot put the book away. Find a place closes when the book ends, so the note is never drawn under its bar.

## Fit the page above the Find a place bar

The Find a place bar covered the bottom of the page, so the page shown could not be read in full. Andrew kept the bar and its question and asked for the page to make room instead. While the search is up, the page's bottom margin grows by the bar's height, as it does for the battery warning, so the text ends above the bar. Done, Back, and the last answer put the margin back. Changing the margin reflows the book when the search starts and ends, and pages are numbered with the margin while searching. The time that reflow takes on the Oasis in a long book is unmeasured. PDFs keep their pages and are still partly covered.
