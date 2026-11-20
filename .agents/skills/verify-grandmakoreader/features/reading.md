# Page input and font preview

The reader gives the page to the book. Buttons and side swipes turn pages, and a tap anywhere brings up the reading menu. The font controls preview the current page.

## Sub-features

- `page-input` turns pages with the buttons and with left (forward) and right (back) swipes, and ignores up and down swipes.
- `tap-menu` opens the sidebar from a tap anywhere on the page.
- `large-print` opens a book without a saved size at font size 36 instead of KOReader’s 22.
- `font-preview` adjusts type on the current page while preserving the reading location.
- `menu-exit` saves font changes through **Done**, a tap on the preview page, or a page turn.
- `find-a-place` first offers **Find a page**, **Go to the beginning**, and **Cancel**, stacked in that order. Find a page explains the search, with **Start** and **Cancel**. Start opens halfway through the book and asks whether the place is before or after the page on screen. Each answer halves the pages left. Page buttons and side swipes turn pages under the question, a tap on the page leaves it up, and **Done** ends the search on the page shown.

## How to get to it (user POV)

- Tap a book title on Books. Press a page button to read.
- Tap the page, then tap **Change Text Size**. Use **Smaller** and **Bigger**.
- Tap the page, then tap **Find a place**, then **Find a page** and **Start**. Answer **Before** or **After** until the page shows, then tap **Done**.

## Driving it with SDL

Preconditions: the doctor passes and the seeded text book opens at the start.

- Run `tools/review-koreader "$evidence"`. The run swipes up and down from the centre and both edges, swipes left and right to turn a page each way, then taps the centre and two corners and checks the sidebar width. Compare `02-reading.png` and `03-reading-menu.png`.
- The run checks that the fresh fixture book opens at size 36.
- Compare `02-reading.png` and `04-font-preview.png` for the larger rendered text and bottom controls. The run checks the retained text location and reads the saved size after tapping **Done** and after tapping the preview page.
- The test sends Page Down from the font preview and Page Up from the sidebar. Each must dismiss the overlay and turn exactly one page.
- Near the end, the run opens a temporary 600-line book, Zebra Pages, for Find a place. It checks that Cancel on either box leaves the page alone and Go to the beginning opens page one, then the halfway start, page turns and a tap under the question, **Done**, the answers reaching the first, last, and two inner pages within the halving limit, and an answer across a rotation. Inspect `10-find-a-place-choice.png`, `10-find-a-page-help.png`, and `10-find-a-place.png`.

## Gotchas

- **Change Text Size** applies to reflowable books. This recipe uses HTML through KOReader's reflowable engine.
