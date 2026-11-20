# Page input and font preview

The reader gives the page to the book. Buttons turn pages and inward edge swipes bring up the reading menu. The font controls preview the current page.

## Sub-features

- `page-input` handles page turns and ignores ordinary taps and centre swipes.
- `edge-menu` opens the same sidebar from left, right, top, and bottom.
- `font-preview` adjusts type on the current page while preserving the reading location.
- `menu-exit` saves font changes through **Done**, a tap on the preview page, or a page turn.

## How to get to it (user POV)

- Tap a book title on Books. Press a page button to read.
- Swipe inward from any edge, then tap **Change Font**. Use **−** and **+**.

## Driving it with SDL

Preconditions: the doctor passes and the seeded text book opens at the start.

- Run `tools/review-koreader "$evidence"`. The run taps in ordinary reading, swipes from the centre, then checks all four edges and the sidebar width. Compare `02-reading.png` and `03-reading-menu.png`.
- Compare `02-reading.png` and `04-font-preview.png` for the larger rendered text and bottom controls. The run checks the retained text location and reads the saved size after tapping **Done** and after tapping the preview page.
- The test sends Page Down from the font preview and Page Up from the sidebar. Each must dismiss the overlay and turn exactly one page.

## Gotchas

- Begin an edge swipe near the physical edge of the reader surface. The four edges use the same panel.
- **Change Font** applies to reflowable books. This recipe uses HTML through KOReader's reflowable engine.
