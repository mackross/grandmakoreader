local ReaderFooter = require("apps/reader/modules/readerfooter")
local footer = G_reader_settings:readSetting("footer", ReaderFooter.default_settings)
footer.disable_progress_bar = true
