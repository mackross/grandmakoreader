-- The Kindle shows the Grandma's Magic Pirate Book cover while it sleeps, always in portrait.
-- The picture is the only image in the sleep-screen folder next to this patch, so it is the one shown.
local Device = require("device")
local FileManager = require("apps/filemanager/filemanager")
local ReaderUI = require("apps/reader/readerui")
local Screensaver = require("ui/screensaver")
local ffiUtil = require("ffi/util")

-- The sleep screen attaches to the reader or KOReader's file manager, and skips drawing without one.
-- The home screen replaces the file manager, so stand one in while the sleep screen is set up there.
-- An image sleep screen without a book needs nothing from it.
local setup = Screensaver.setup
function Screensaver:setup(...)
    if ReaderUI.instance or FileManager.instance then return setup(self, ...) end
    FileManager.instance = {}
    local ok, err = pcall(setup, self, ...)
    FileManager.instance = nil
    if not ok then error(err, 0) end
end

local patch_dir = debug.getinfo(1, "S").source:match("^@(.*/)")
G_reader_settings:saveSetting("screensaver_type", "random_image")
G_reader_settings:makeFalse("screensaver_show_message")
G_reader_settings:saveSetting("screensaver_dir", ffiUtil.realpath(patch_dir .. "sleep-screen") or patch_dir .. "sleep-screen")

-- KOReader keeps the Kindle framework running, so the Kindle's own sleep screen, with or without
-- Special Offers, draws over KOReader's. KOReader also leaves sleep to the Kindle when the ad
-- screensaver is loaded. Unload both and draw the picture; load them again on exit for the Kindle's reader.
local lipc = Device:isKindle() and Device:getPowerDevice().lipc_handle
if lipc then
    local loaded = " " .. (lipc:get_string_property("com.lab126.blanket", "load") or "") .. " "
    local unloaded = {}
    for _, module in ipairs({ "ad_screensaver", "screensaver" }) do
        if loaded:find(" " .. module .. " ", 1, true) then
            lipc:set_string_property("com.lab126.blanket", "unload", module)
            table.insert(unloaded, module)
        end
    end
    local special_offers = Device.isSpecialOffers
    Device.isSpecialOffers = false
    local exit = Device.exit
    function Device:exit(...)
        for _, module in ipairs(unloaded) do
            lipc:set_string_property("com.lab126.blanket", "load", module)
        end
        self.isSpecialOffers = special_offers
        return exit(self, ...)
    end
end
