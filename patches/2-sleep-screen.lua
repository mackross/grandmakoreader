-- The Kindle shows the Grandma's Magic Pirate Book cover while it sleeps.
-- KOReader draws its sleep screen only on Kindles without Special Offers, and always in portrait.
-- The picture is the only image in the sleep-screen folder next to this patch, so it is the one shown.
local sleep_dir = debug.getinfo(1, "S").source:match("^@(.*/)") .. "sleep-screen"
G_reader_settings:saveSetting("screensaver_type", "random_image")
G_reader_settings:saveSetting("screensaver_dir", sleep_dir)
