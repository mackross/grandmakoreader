-- KOReader still re-renders the book in the background after a font or margin change, without
-- showing its progress icons in the top-left corner.
local ReaderFlipping = require("apps/reader/modules/readerflipping")
function ReaderFlipping:getRollingRenderingStateIconWidget() end
