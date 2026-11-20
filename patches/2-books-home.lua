local Device = require("device")
local DocumentRegistry = require("document/documentregistry")
local FileManager = require("apps/filemanager/filemanager")
local Font = require("ui/font")
local Menu = require("ui/widget/menu")
local QuickStart = require("ui/quickstart")
local ReaderUI = require("apps/reader/readerui")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local books_dir = Device:isKindle() and Device.home_dir .. "/books"
    or os.getenv("XDG_DOCUMENTS_DIR") or Device.home_dir .. "/books"
local home
local Home = Menu:extend{
    name = "books_home",
    covers_fullscreen = true,
    is_borderless = true,
    is_popout = false,
    items_per_page = 8,
    items_font_size = 26,
    items_max_lines = 2,
    is_enable_shortcut = false,
}

function Home:onShowingReader()
    UIManager:close(self)
end

function Home:onCloseWidget()
    home = nil
    Menu.onCloseWidget(self)
end

function Home:refresh()
    UIManager:nextTick(function()
        if home ~= self then return end
        local page = self.page_items[self.page]
        local first_item = page and self.item_table[page[1]]
        FileManager:showFiles(nil, first_item and first_item.path)
    end)
end

function Home:onScreenResize()
    self:refresh()
    return true
end

function Home:onSetRotationMode(mode)
    local screen = Device.screen
    if mode and mode ~= screen:getRotationMode() then
        screen:setRotationMode(mode)
        self:refresh()
        return true
    end
end

Home.onNotCharging = Home.refresh
Home.onResume = Home.refresh

function Home:updatePageInfo(...)
    Menu.updatePageInfo(self, ...)
    if self.page_num <= 1 then
        self.page_info_text:setText("")
        self.page_info_left_chev:hide()
        self.page_info_right_chev:hide()
        self.page_info_first_chev:hide()
        self.page_info_last_chev:hide()
    end
end

function FileManager:showFiles(_, focused_file)
    if home then
        UIManager:close(home)
    end

    local items = {}
    util.makePath(books_dir)
    if lfs.attributes(books_dir, "mode") == "directory" then
        for filename in lfs.dir(books_dir) do
            local path = books_dir .. "/" .. filename
            if filename:sub(1, 1) ~= "." and lfs.attributes(path, "mode") == "file"
                    and DocumentRegistry:hasProvider(path) then
                items[#items + 1] = {
                    text = filename:match("^(.+)%.%w+$") or filename,
                    path = path,
                    callback = function()
                        ReaderUI:showReader(path)
                    end,
                }
            end
        end
    end
    table.sort(items, function(first, second)
        return first.text:lower() < second.text:lower()
    end)
    for index, item in ipairs(items) do
        if item.path == focused_file then
            items.current = index
            break
        end
    end
    if #items == 0 then
        items[1] = { text = "No books yet", select_enabled = false }
    end

    Device.screen:setWindowTitle("Books")
    home = Home:new{
        title = "Books",
        custom_title_bar = TitleBar:new{
            width = Device.screen:getWidth(),
            title = "Books",
            title_face = Font:getFace("smalltfont", 32),
            with_bottom_line = true,
        },
        item_table = items,
    }
    UIManager:show(home, "full")
end

G_reader_settings:saveSetting("start_with", "filemanager")
if not QuickStart:isShown() then
    G_reader_settings:saveSetting("quickstart_shown_version", QuickStart.quickstart_force_show_version)
end
