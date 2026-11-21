local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local DataStorage = require("datastorage")
local Device = require("device")
local DocumentRegistry = require("document/documentregistry")
local FileManager = require("apps/filemanager/filemanager")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local LineWidget = require("ui/widget/linewidget")
local Menu = require("ui/widget/menu")
local OverlapGroup = require("ui/widget/overlapgroup")
local QuickStart = require("ui/quickstart")
local ReadHistory = require("readhistory")
local ReaderUI = require("apps/reader/readerui")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")

-- The helpers and icons this patch loads ship in the folder it runs from.
local patch_dir = debug.getinfo(1, "S").source:match("^@(.*/)")
local Details = dofile(patch_dir .. "details.lua")
local Library = dofile(patch_dir .. "library.lua")
local books_dir = Device:isKindle() and Device.home_dir .. "/books"
    or os.getenv("XDG_DOCUMENTS_DIR") or Device.home_dir .. "/books"
local Screen = Device.screen
local icons_dir = patch_dir .. "icons/"

-- The shop's Find a new book opens the Z-library plugin. The patch replaces FileManager:showFiles,
-- so no FileManager exists to load the plugin's widget into; load it here instead, the way
-- KOReader would, and keep the one instance for later taps. In the simulator the plugin is
-- vendored under plugins/; on the Kindle it sits in the koreader folder.
local zlibrary_instance
local function openZlibrary()
    -- Z-library wants the radio; the need expires if the search outlives its welcome.
    local ok, Wifi = pcall(require, "grandma/wifi")
    if ok and Wifi then Wifi:need("zlibrary", 600) end
    if not zlibrary_instance then
        local dir
        for _, candidate in ipairs{
            patch_dir .. "../plugins/zlibrary.koplugin/",
            (lfs.currentdir() or "") .. "/plugins/zlibrary.koplugin/",
            "/mnt/us/koreader/plugins/zlibrary.koplugin/",
        } do
            if lfs.attributes(candidate .. "_meta.lua", "mode") == "file" then
                dir = candidate
                break
            end
        end
        if not dir then
            logger.err("Find a new book: no zlibrary.koplugin folder found")
            return
        end
        package.path = dir .. "?.lua;" .. package.path
        zlibrary_instance = dofile(dir .. "main.lua"):new{}
    end
    zlibrary_instance:onZlibrarySearch()
end
local places = {
    { id = "shop", title = "Book Shop", text = "Book Shop", file = icons_dir .. "shop.svg" },
    { id = "shelf", title = "Books", text = "Book Shelf", file = icons_dir .. "bookshelf.svg", prominent = true },
    { id = "settings", title = "Settings", text = "Settings", icon = "appbar.settings" },
}
local home
local showHome

local PlaceButton = InputContainer:extend{}

function PlaceButton:init()
    local place = self.place
    local icon_size = Screen:scaleBySize(place.prominent and 46 or 34)
    local margin = Screen:scaleBySize(6)
    local border = place.prominent and Size.border.thick or 0
    self.hit_area = self.dimen:copy()
    self.ges_events.Activate = { GestureRange:new{ ges = "tap", range = self.hit_area } }
    self[1] = CenterContainer:new{
        dimen = self.dimen:copy(),
        FrameContainer:new{
            background = self.current and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
            bordersize = border,
            radius = Screen:scaleBySize(10),
            padding = 0,
            CenterContainer:new{
                dimen = Geom:new{
                    w = self.dimen.w - 2 * (margin + border),
                    h = self.dimen.h - 2 * (margin + border),
                },
                VerticalGroup:new{
                    align = "center",
                    IconWidget:new{ icon = place.icon, file = place.file, width = icon_size, height = icon_size, invert = self.current },
                    VerticalSpan:new{ width = Screen:scaleBySize(2) },
                    TextWidget:new{
                        text = place.text,
                        face = Font:getFace(place.prominent and "smalltfont" or "cfont", place.prominent and 32 or 28),
                        fgcolor = self.current and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
                    },
                },
            },
        },
    }
end

function PlaceButton:paintTo(bb, x, y)
    self.hit_area.x, self.hit_area.y = x, y
    self[1]:paintTo(bb, x, y)
end

function PlaceButton:onActivate()
    if not self.current then
        showHome(self.place.id)
    end
    return true
end

local function buildPlaceBar(current, width)
    local height = Screen:scaleBySize(100)
    local rise = Screen:scaleBySize(24)
    local line = Size.line.thick
    local side_width = math.floor(width * 0.3)
    -- The prominent place stands taller than its neighbours and breaks through the line above them.
    local buttons = HorizontalGroup:new{ align = "bottom" }
    for _, place in ipairs(places) do
        local button = PlaceButton:new{
            place = place,
            current = place.id == current,
            dimen = Geom:new{
                w = place.prominent and width - 2 * side_width or side_width,
                h = place.prominent and height + line + rise or height,
            },
        }
        buttons[#buttons + 1] = place.prominent and button or VerticalGroup:new{
            LineWidget:new{ dimen = Geom:new{ w = side_width, h = line } },
            button,
        }
    end
    return FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        buttons,
    }
end

-- A shelf button shaped like an arrow: pointed on the side it leads to, rounded on the other.
local ShelfArrow = InputContainer:extend{}

function ShelfArrow:init()
    local height = Screen:scaleBySize(52)
    local padding = Screen:scaleBySize(14)
    self.label = TextWidget:new{ text = self.text, face = Font:getFace("cfont", 36) }
    self.point = math.floor(height / 2)
    self.dimen = Geom:new{ w = self.point + self.label:getSize().w + 2 * padding, h = height }
    self.hit_area = self.dimen:copy()
    self.ges_events.Activate = { GestureRange:new{ ges = "tap", range = self.hit_area } }
end

function ShelfArrow:paintTo(bb, x, y)
    local width, height, point = self.dimen.w, self.dimen.h, self.point
    local line, radius = Size.border.thick, Screen:scaleBySize(10)
    local reach = Screen:scaleBySize(8)
    self.dimen.x, self.dimen.y = x, y
    self.hit_area.x, self.hit_area.y = x - reach, y - reach
    self.hit_area.w, self.hit_area.h = width + 2 * reach, height + 2 * reach

    -- Outline the rounded body, then open the side that becomes the point.
    local body_x = self.points_left and x + point or x
    local open_x = self.points_left and body_x or x + width - point - radius - line
    bb:paintBorder(body_x, y, width - point, height, line, Blitbuffer.COLOR_BLACK, radius)
    bb:paintRect(open_x, y, radius + line, height, Blitbuffer.COLOR_WHITE)
    bb:paintRect(open_x, y, radius + line, line, Blitbuffer.COLOR_BLACK)
    bb:paintRect(open_x, y + height - line, radius + line, line, Blitbuffer.COLOR_BLACK)
    -- Two slanted strokes run from the body's corners to the point, a row at a time.
    local middle = (height - 1) / 2
    local stroke = math.ceil(line * math.sqrt(point * point + middle * middle) / middle)
    for row = 0, height - 1 do
        local slant = math.floor(point * math.abs(row - middle) / middle + 0.5)
        bb:paintRect(self.points_left and x + slant or x + width - slant - stroke, y + row, stroke, 1,
            Blitbuffer.COLOR_BLACK)
    end

    -- The label sits a little towards the point, where the arrow has room.
    local label = self.label:getSize()
    local nudge = math.floor(point / 4) * (self.points_left and -1 or 1)
    self.label:paintTo(bb, body_x + math.floor((width - point - label.w) / 2) + nudge,
        y + math.floor((height - label.h) / 2))
end

function ShelfArrow:onActivate()
    self.callback()
    return true
end

function ShelfArrow:free()
    self.label:free()
end

local button_margin = Screen:scaleBySize(8)
-- The button across the bottom of the shelf is set as large as the titles above it.
local lookup_font_size = 40

-- An outlined button with a word or a letter on it. Without a callback it is greyed out.
local function wordButton(button)
    local border = Size.border.thick
    button.enabled = button.callback ~= nil
    button.height = button.height and button.height - 2 * (border + button_margin)
    button.padding_v = button.height and 0 or button.padding_v or Screen:scaleBySize(4)
    button.padding_h = Screen:scaleBySize(18)
    button.text_font_size = button.text_font_size or 36
    button.text_font_bold = false
    button.bordersize = border
    button.radius = Screen:scaleBySize(10)
    button.margin = button_margin
    button = Button:new(button)
    if not button.callback then
        button.frame.color = Blitbuffer.COLOR_GRAY
    end
    return button
end

local Home = Menu:extend{
    name = "books_home",
    covers_fullscreen = true,
    is_borderless = true,
    is_popout = false,
    items_per_page = 8,
    items_font_size = 40,
    items_max_lines = 2,
    is_enable_shortcut = false,
}

function Home:init()
    -- Find and the lists it leads to are side rooms of the shelf, so no place is marked as open there.
    local bar = buildPlaceBar(not self.view and self.place, Screen:getWidth())
    self.height = Screen:getHeight() - bar:getSize().h
    -- Menu sizes the strip below the list from its page label, so make that label as tall as Find.
    self.page_info_text = wordButton{ show_parent = self, text = "", text_font_size = lookup_font_size, padding_v = 0 }
    Menu.init(self)
    -- Menu opens at the bold book's shelf. Open at the first, or at the shelf that holds the book a
    -- letter or a return leads to.
    local focus = self.item_table.focus
    local page = focus and self:getPageNumber(focus) or 1
    if self.page ~= page then
        self.page = page
        self:updateItems(1, true)
    end
    -- The list stays above the bar. The screen as a whole belongs to Home.
    self.dimen.h = Screen:getHeight()
    self[1] = VerticalGroup:new{ align = "left", self[1], bar }
end

function Home:onShowingReader()
    UIManager:close(self)
end

function Home:onCloseWidget()
    if self.name_dialog then
        UIManager:close(self.name_dialog)
    end
    home = nil
    Menu.onCloseWidget(self)
end

function Home:refresh()
    UIManager:nextTick(function()
        if home ~= self then return end
        local page = self.page_items[self.page]
        local first_item = page and self.item_table[page[1]]
        showHome(self.place, first_item and first_item.path, self.view)
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

-- The shelf arrows live in the title bar, so the list runs down to the bar unless Find needs the
-- strip below it. Menu reserves that strip only while it has a return arrow.
function Home:_recalculateDimen(no_recalculate_dimen)
    if no_recalculate_dimen then return end
    local return_arrow = self.page_return_arrow
    self.page_return_arrow = nil
    Menu._recalculateDimen(self)
    self.page_return_arrow = return_arrow

    -- Find appears once the books need more than one shelf, and stays beside the lists it leads to.
    local view = self.view
    self.has_find = self.place == "shelf" and (view and view.kind ~= "find" or not view and self.page_num > 1)
    if self.has_find then
        Menu._recalculateDimen(self)
    end
end

-- A shelf's letters, such as "A–L". Like an encyclopedia's spines, an end takes as many letters as
-- it needs to differ from the neighbouring shelf, as in "S–Sec" beside "Sen–T", up to self.label_letters.
function Home:shelfLetters(page)
    -- Read lately runs from the newest book back, so its arrows say which way they go in time.
    if self.view and self.view.kind == "recent" then
        return page < self.page and "Newer" or "Older"
    end
    local function title(page_index, last)
        local shelf = self.page_items[page_index]
        return self.item_table[shelf[last and #shelf or 1]].text
    end
    local first_title, last_title = title(page), title(page, true)
    local first, last = Library.prefix(first_title, 1), Library.prefix(last_title, 1)
    if page > 1 then
        first = select(2, Library.beginnings(title(page - 1, true), first_title, self.label_letters))
    end
    if page < self.page_num then
        last = Library.beginnings(last_title, title(page + 1), self.label_letters)
    end
    -- An end never stops short of the other, as in "Sen–Sil" rather than "Sen–S".
    if #last < #first and first:sub(1, #last) == last then
        last = Library.prefix(last_title, #util.splitToChars(first))
    end
    return first == last and first or first .. "–" .. last
end

-- The title of a shelf with neighbours. Portrait has no room for the word beside the arrows, so the
-- letters stand alone there, as in "K–P" against "Books K–P" in landscape.
function Home:shelfTitle(page)
    local letters = self:shelfLetters(page)
    return Screen:getWidth() < Screen:getHeight() and letters or self.title .. " " .. letters
end

-- Whether every shelf's title fits between the arrows to its neighbours.
function Home:shelfLabelsFit()
    local bar = self.title_bar
    for page = 1, self.page_num do
        local title = TextWidget:new{
            text = self.view and self.title or self:shelfTitle(page),
            face = bar.title_face,
        }
        local room = (bar.width - title:getSize().w) / 2 - Size.padding.fullscreen - Screen:scaleBySize(8)
        title:free()
        for _, neighbour in ipairs{ page - 1, page + 1 } do
            if neighbour >= 1 and neighbour <= self.page_num then
                local arrow = ShelfArrow:new{ text = self:shelfLetters(neighbour) }
                local width = arrow:getSize().w
                arrow:free()
                if width > room then return false end
            end
        end
    end
    return true
end

function Home:updatePageInfo(...)
    Menu.updatePageInfo(self, ...)
    local page_controls = self.page_info
    for index = #page_controls, 1, -1 do
        page_controls[index] = nil
    end
    page_controls:resetLayout()
    local inset = Size.padding.fullscreen - button_margin
    if self.place == "shop" then
        -- The shop has no rows of its own yet. In the place where the shelf looks books up, it
        -- offers a new one through Z-library.
        self.new_book_button = self.new_book_button or wordButton{
            show_parent = self,
            text = "Find a new book",
            text_font_size = lookup_font_size,
            padding_v = 0,
            width = self.inner_dimen.w - 2 * inset,
            callback = openZlibrary,
        }
        page_controls[1] = HorizontalSpan:new{ width = inset }
        page_controls[2] = self.new_book_button
        page_controls[3] = HorizontalSpan:new{ width = inset }
    elseif self.has_find then
        -- The button spans the bottom of the list, with its outline as wide as the rules under the titles.
        self.find_button = self.find_button or wordButton{
            show_parent = self,
            text = "Look up a book",
            text_font_size = lookup_font_size,
            padding_v = 0,
            width = self.inner_dimen.w - 2 * inset,
            callback = function() showHome("shelf", nil, { kind = "find" }) end,
        }
        page_controls[1] = HorizontalSpan:new{ width = inset }
        page_controls[2] = self.find_button
        page_controls[3] = HorizontalSpan:new{ width = inset }
    end
    if self.page_num <= 1 then return end

    -- Up to three letters at each end, or fewer when that is what fits, the same on every shelf.
    if not self.label_letters then
        self.label_letters = 3
        while self.label_letters > 1 and not self:shelfLabelsFit() do
            self.label_letters = self.label_letters - 1
        end
    end
    -- With more than one shelf, an arrow on each side names its neighbour. On the full shelf the
    -- title names the open one.
    local bar = self.title_bar
    if not self.view then
        bar:setTitle(self:shelfTitle(self.page), true)
    end
    if not self.shelf_arrows then
        self.shelf_arrows = OverlapGroup:new{ dimen = Geom:new{ w = bar.width, h = bar:getHeight() } }
        table.insert(bar, self.shelf_arrows)
    end
    self.shelf_arrows:clear()
    local rule_y = bar:getHeight() - Size.padding.default - Size.line.thick
    local function addArrow(page, points_left, callback)
        if page < 1 or page > self.page_num then return end
        local arrow = ShelfArrow:new{ text = self:shelfLetters(page), points_left = points_left, callback = callback }
        local size = arrow:getSize()
        arrow.overlap_offset = {
            points_left and Size.padding.fullscreen or bar.width - Size.padding.fullscreen - size.w,
            math.floor((rule_y - size.h) / 2),
        }
        table.insert(self.shelf_arrows, arrow)
        return arrow
    end
    self.previous_shelf = addArrow(self.page - 1, true, function() self:onPrevPage() end)
    self.next_shelf = addArrow(self.page + 1, false, function() self:onNextPage() end)
end

-- The Find screen: a key for each letter, then the two other ways to find a book.
function Home:buildFind()
    local first_filed = {}
    for _, book in ipairs(self.books) do
        local initial = Library.initial(book.text)
        if initial:match("^%d$") then initial = "0–9" end
        first_filed[initial] = first_filed[initial] or book.path
    end
    local keys = {}
    if first_filed["0–9"] then keys[1] = "0–9" end
    for letter in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do
        keys[#keys + 1] = letter
    end

    local columns = Screen:getWidth() > Screen:getHeight() and 9 or 6
    local rows = math.ceil(#keys / columns) + 1
    local gap = Screen:scaleBySize(10)
    local inset = Size.padding.fullscreen - button_margin
    local width = self.inner_dimen.w - 2 * inset
    local prompt = TextWidget:new{ text = "Which letter does it start with?", face = Font:getFace("cfont", 36) }
    local key_height = math.min(Screen:scaleBySize(84),
        math.floor((self.available_height - prompt:getSize().h - 3 * gap) / rows))

    local screen = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = gap },
        HorizontalGroup:new{ HorizontalSpan:new{ width = Size.padding.fullscreen }, prompt },
        VerticalSpan:new{ width = gap },
    }
    local row
    for index, key in ipairs(keys) do
        if index % columns == 1 then
            row = HorizontalGroup:new{ HorizontalSpan:new{ width = inset } }
            screen[#screen + 1] = row
        end
        local file = first_filed[key]
        row[#row + 1] = wordButton{
            show_parent = self,
            text = key,
            text_font_size = 36,
            width = math.floor(width / columns),
            height = key_height,
            -- A letter opens the shelf that holds the first book filed under it.
            callback = file and function() showHome("shelf", file) end,
        }
    end
    local function wideButton(text, callback)
        return wordButton{
            show_parent = self, text = text, width = math.floor(width / 2), height = key_height, callback = callback,
        }
    end
    screen[#screen + 1] = HorizontalGroup:new{
        HorizontalSpan:new{ width = inset },
        wideButton("Read lately", function() showHome("shelf", nil, { kind = "recent" }) end),
        wideButton("Type a name", function() self:typeName() end),
    }
    return screen
end

-- A book's author goes on a line of its own under the title, in smaller type.
-- In Read lately the line ends with when the book was last open, which stays whole while a long
-- author's name is shortened.
local function authorLine(author, width, when)
    local function words(text, max_width)
        return TextWidget:new{
            text = text,
            face = Font:getFace("smallinfofont", 32),
            max_width = max_width,
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
        }
    end
    if not (author and when) then return words(author or when, width) end
    local date = words(" · " .. when)
    return HorizontalGroup:new{ words(author, width and width - date:getSize().w), date }
end

-- Menu fills each page by the lines of the titles alone. Fill them again, giving each author a line.
function Home:setupItemHeights()
    Menu.setupItemHeights(self)
    local author_height = authorLine("A"):getSize().h
    local page, height = {}, 0
    self.page_items = {}
    for index, item in ipairs(self.item_table) do
        if item.author or item.when then item.height = item.height + author_height end
        height = height + item.height
        if height > self.available_height and #page > 0 then
            table.insert(self.page_items, page)
            page, height = {}, item.height
        end
        table.insert(page, index)
    end
    table.insert(self.page_items, page)
end

function Home:updateItems(...)
    Menu.updateItems(self, ...)
    -- Menu sets a row's text alone in its place, so set the title over the author there instead.
    for _, row in ipairs(self.item_group) do
        local entry = row.entry
        local line = entry and (entry.author or entry.when) and row._underline_container[1][1][2][1]
        local title = line and line[2]
        -- Only a title Menu wraps over lines has room set aside for it. Leave any other as it is.
        if title and title.width then
            local author_line = authorLine(entry.author, title.width, entry.when)
            line[2] = VerticalGroup:new{
                align = "left",
                TextBoxWidget:new{
                    text = title.text,
                    face = title.face,
                    width = title.width,
                    height = row.dimen.h - 2 * Size.span.vertical_default - row.linesize - author_line:getSize().h,
                    height_adjust = true,
                    height_overflow_show_ellipsis = true,
                    alignment = "left",
                    bold = title.bold,
                },
                author_line,
            }
            title:free()
        end
    end
    -- While a name is being typed the letters are put away, so only the text box asks for anything.
    if self.view and self.view.kind == "find" and not self.name_dialog then
        self.item_group[1] = self:buildFind()
        self.item_group:resetLayout()
    end
end

-- KOReader's own text box and keyboard, asking for part of a book's name or its author's.
function Home:typeName()
    local dialog
    local function close()
        UIManager:close(dialog)
        self.name_dialog = nil
    end
    dialog = InputDialog:new{
        title = "Type a book’s name or its author",
        buttons = { {
            {
                text = "Cancel",
                id = "close",
                callback = function()
                    close()
                    -- Bring the letters back.
                    self:updateItems()
                end,
            },
            {
                text = "Find",
                id = "find",
                is_enter_default = true,
                callback = function()
                    local text = dialog:getInputText():match("^%s*(.-)%s*$")
                    if text == "" then return end
                    close()
                    showHome("shelf", nil, { kind = "search", text = text })
                end,
            },
        } },
    }
    self.name_dialog = dialog
    self:updateItems()
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

-- Menu wraps from the last page to the first. The shelves stop at both ends, like the buttons.
function Home:onNextPage()
    return self.page >= self.page_num or self:onGotoPage(self.page + 1)
end

function Home:onPrevPage()
    return self.page <= 1 or self:onGotoPage(self.page - 1)
end

-- Every book in the folder, in library order, named by its own title, or by its file name until
-- that has been read.
local function allBooks()
    local books = {}
    util.makePath(books_dir)
    if lfs.attributes(books_dir, "mode") == "directory" then
        for filename in lfs.dir(books_dir) do
            local path = books_dir .. "/" .. filename
            if filename:sub(1, 1) ~= "." and lfs.attributes(path, "mode") == "file"
                    and DocumentRegistry:hasProvider(path) then
                books[#books + 1] = {
                    text = Details.title(path) or filename:match("^(.+)%.%w+$") or filename,
                    author = Details.authors(path),
                    path = path,
                    callback = function()
                        ReaderUI:showReader(path)
                    end,
                }
            end
        end
    end
    return Library.sort(books, function(book) return book.text end)
end

-- How long ago a book was open, in whole days.
local function readWhen(time)
    local function noon(moment)
        local date = os.date("*t", moment)
        return os.time{ year = date.year, month = date.month, day = date.day, hour = 12 }
    end
    local days = math.floor((noon(os.time()) - noon(time)) / 86400 + 0.5)
    if days <= 0 then return "Today" end
    if days == 1 then return "Yesterday" end
    if days < 14 then return days .. " days ago" end
    if days < 60 then return math.floor(days / 7) .. " weeks ago" end
    if days < 365 then return math.floor(days / 30) .. " months ago" end
    return "Over a year ago"
end

-- The books KOReader's reading history remembers, most recently open first.
local function recentBooks(books)
    local by_path = {}
    for _, book in ipairs(books) do
        by_path[ffiUtil.realpath(book.path) or book.path] = book
    end
    local recent = {}
    for _, read in ipairs(ReadHistory.hist) do
        local book = by_path[read.file]
        if book then
            -- The date goes on the author's line, so the title has the full width.
            book.when = readWhen(read.time)
            recent[#recent + 1] = book
        end
    end
    return recent
end

-- The books with the given words in their name or their author's.
local function namedBooks(books, text)
    local named = {}
    for _, book in ipairs(books) do
        if Library.contains(book.text, text) or book.author and Library.contains(book.author, text) then
            named[#named + 1] = book
        end
    end
    return named
end

-- The rows of the full shelf, or of one of the lists Find leads to.
local function shelfItems(books, view, focused_file)
    local items, nothing = books, "No books yet"
    if view and view.kind == "recent" then
        items, nothing = recentBooks(books), "No books read yet"
    elseif view then
        items, nothing = namedBooks(books, view.text), "No book or author has “" .. view.text .. "” in its name"
    end
    -- The book being read, the last one opened, stays in bold wherever it shows, however the
    -- list was reached. The book a letter or a return leads to only picks the shelf.
    local last_file = G_reader_settings:readSetting("lastfile")
    last_file = last_file and (ffiUtil.realpath(last_file) or last_file)
    for index, item in ipairs(items) do
        if item.path == focused_file then items.focus = index end
        if last_file and (ffiUtil.realpath(item.path) or item.path) == last_file then items.current = index end
    end
    if #items == 0 then
        items[1] = { text = nothing, select_enabled = false }
    end
    return items
end

-- Leaving KOReader hands the Kindle back to its own home screen, so a tap on the row only asks first.
local function confirmExit()
    local dialog
    local function choice(text, callback)
        return { text = text, font_size = 36, callback = callback }
    end
    dialog = ButtonDialog:new{
        modal = true,
        title = "Leave the books and go to the Kindle’s own home screen?",
        title_align = "center",
        title_face = Font:getFace("infofont", 32),
        buttons = { {
            choice("Cancel", function() UIManager:close(dialog) end),
            choice("Exit to Kindle", function()
                UIManager:close(dialog)
                -- Like KOReader's own Exit: reader.lua saves settings, and the Kindle's launcher takes over.
                UIManager:quit(0)
            end),
        } },
    }
    UIManager:show(dialog)
end

-- What Settings says under Check for updates, by how 1-auto-update.lua reports the check. A check cut
-- short by sleep ("asleep" or "ended") says nothing.
local update_messages = {
    connecting = "Looking for the Wi‑Fi… this might take a minute.",
    checking = "Checking for an update…",
    ["up to date"] = "This Kindle is up to date.",
    downloaded = "Found an update. The Kindle will restart in a moment.",
    ["rolled back"] = "The newest update didn’t work on this Kindle, so it is keeping the one it has.",
    unreachable = "The Kindle couldn’t find the Wi‑Fi. Check the internet is on at home, then try again.",
    off = "Updates need Wi‑Fi, but Wi‑Fi is turned off on this Kindle.",
    ["no internet"] = "The Kindle is on the Wi‑Fi but can’t reach the internet. Please try again later.",
    failed = "Updates aren’t working right now. Please try again later.",
    ["low battery"] = "The battery is too low to update. Charge the Kindle, then try again.",
}
local update_state -- how the check asked for from Settings is going, or how it ended
local settingsItems

local function updateReported(state, reason)
    update_state = state == "no wifi" and reason or state
    if home and home.place == "settings" and not home.view then
        home:switchItemTable(nil, settingsItems())
    end
end

-- The rows of Settings, or of Advanced within it.
function settingsItems(view)
    if view then
        return { { text = "Exit to Kindle", callback = confirmExit } }
    end
    -- The updater provides this once every patch has loaded, and only when updates are switched on.
    local Update = package.loaded["grandma/update"]
    local ready = Update ~= nil and update_state ~= "connecting" and update_state ~= "checking"
    local message = Update and update_messages[update_state]
    if not Update then message = "Updates are switched off on this Kindle." end
    -- The row is greyed out while a check runs. Under it, a row that is not a button says how the check went.
    local items = { {
        text = "Check for updates",
        dim = not ready,
        select_enabled = ready,
        callback = function()
            if not pcall(Update.check, Update, updateReported) then
                logger.warn("Settings: the update check could not start")
                updateReported("failed")
            end
        end,
    } }
    if message then
        items[2] = { text = message, select_enabled = false }
    end
    items[#items + 1] = { text = "Advanced", callback = function() showHome("settings", nil, { kind = "advanced" }) end }
    return items
end

-- Shows a place. On the shelf, view is nil for every book, or { kind = "find" } for the Find screen,
-- { kind = "recent" } for Read lately, or { kind = "search", text = ... } for books with that name
-- or author. In Settings, { kind = "advanced" } is the Advanced screen.
function showHome(place_id, focused_file, view)
    -- How the last check ended is news only until Settings is left.
    local stays_in_settings = home and home.place == "settings" and place_id == "settings"
    if not stays_in_settings and update_state ~= "connecting" and update_state ~= "checking" then
        update_state = nil
    end
    if home then
        UIManager:close(home)
    end

    local title
    for _, place in ipairs(places) do
        if place.id == place_id then title = place.title end
    end
    local finding = view and view.kind == "find"
    if view then
        title = finding and "Look up a book" or view.kind == "recent" and "Read lately"
            or view.kind == "advanced" and "Advanced" or "Books with “" .. view.text .. "”"
    end
    local books = place_id == "shelf" and allBooks() or nil
    if books then
        -- Books added since the last visit have their titles and authors read while the shelf is on
        -- show. The open shelf then takes up their titles, unless a name is being typed, and stays
        -- where it was rather than following a book that moved.
        local paths = {}
        for index, book in ipairs(books) do paths[index] = book.path end
        Details.read(paths, function()
            if not home or home.place ~= "shelf" or home.name_dialog then return end
            local page = home.page
            showHome("shelf", nil, home.view)
            home:onGotoPage(math.max(1, math.min(page, home.page_num)))
        end)
    end
    Device.screen:setWindowTitle("Books")
    home = Home:new{
        place = place_id,
        view = view,
        title = title,
        custom_title_bar = TitleBar:new{
            width = Device.screen:getWidth(),
            title = title,
            title_face = Font:getFace("smalltfont", 40),
            title_top_padding = Screen:scaleBySize(8),
            with_bottom_line = true,
        },
        books = books,
        -- What Settings says about a check may take more lines than a title on the shelf is given.
        items_max_lines = place_id == "settings" and 4 or nil,
        -- The shop holds no rows of its own yet; its Find a new book button opens Z-library.
        item_table = place_id == "settings" and settingsItems(view)
            or not books and {}
            or finding and {} or shelfItems(books, view, focused_file),
    }
    UIManager:show(home, "full")
end

function FileManager:showFiles(_, focused_file)
    showHome("shelf", focused_file)
end

G_reader_settings:saveSetting("start_with", "filemanager")
if not QuickStart:isShown() then
    G_reader_settings:saveSetting("quickstart_shown_version", QuickStart.quickstart_force_show_version)
end
