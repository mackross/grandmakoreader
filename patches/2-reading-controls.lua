local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local ReaderUI = require("apps/reader/readerui")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")

local Screen = Device.screen
local power = Device:getPowerDevice()
local page_keys = { LPgFwd = true, LPgBack = true, RPgFwd = true, RPgBack = true }
-- Books open in large print until a size is chosen with Change Text Size.
if G_reader_settings:hasNot("copt_font_size") then
    G_reader_settings:saveSetting("copt_font_size", 36)
end
-- Menu icons ship in the icons folder next to this patch.
local icons_dir = debug.getinfo(1, "S").source:match("^@(.*/)") .. "icons/"

if Device:isSDL() and os.getenv("KO_DEV_DEVICE_NAME") == "Kindle" then
    -- Exercise the same frontlight actions with SDL's in-memory hardware.
    Device.hasFrontlight = function() return true end
    power.fl_max = 24
    power.fl_intensity = 8
    power.hw_intensity = 0
    power.is_fl_on = false

    if not Device:canSuspend() then
        local Screensaver = require("ui/screensaver")
        Device.supportsScreensaver = function() return true end
        UIManager.event_handlers.Suspend = function()
            Screensaver:setup()
            Screensaver:show()
            power:beforeSuspend()
        end
        UIManager.event_handlers.PowerRelease = function()
            if Device.screen_saver_mode then
                Screensaver:close()
                power:afterResume()
            else
                UIManager:suspend()
            end
        end
    end
end

local ActionRow = InputContainer:extend{}

function ActionRow:init()
    local inset = Screen:scaleBySize(26)
    local icon_size = math.min(Screen:scaleBySize(52), math.floor(self.dimen.h * 0.48))
    self.hit_area = self.dimen:copy()
    self.ges_events.Activate = { GestureRange:new{ ges = "tap", range = self.hit_area } }
    self[1] = LeftContainer:new{
        dimen = self.dimen:copy(),
        HorizontalGroup:new{
            align = "center",
            HorizontalSpan:new{ width = inset },
            IconWidget:new{ file = icons_dir .. self.icon .. ".svg", width = icon_size, height = icon_size, alpha = true },
            HorizontalSpan:new{ width = inset },
            TextBoxWidget:new{
                text = self.text,
                width = self.dimen.w - icon_size - 3 * inset,
                face = Font:getFace("smalltfont", 40),
            },
        },
    }
end

function ActionRow:paintTo(bb, x, y)
    self.hit_area.x, self.hit_area.y = x, y
    self[1]:paintTo(bb, x, y)
end

function ActionRow:onActivate()
    self.callback()
    return true
end

local Controls = InputContainer:extend{ modal = true }

function Controls:onClose()
    local reader = self.reader
    -- The button's feedback only refreshes its own rectangle.
    UIManager:close(self, "ui", self.bounds)
    reader.reading_controls = nil
    if self.panel == "font" then
        reader:saveSettings()
    elseif self.panel == "find" then
        reader.find_place = nil
    end
    return true
end

function Controls:handleEvent(event)
    if event.handler == "onSetRotationMode" then
        self.reader:handleEvent(event)
        return true
    elseif event.handler == "onKeyPress" then
        local key = event.args[1].key
        if page_keys[key] then
            -- Finding a place keeps its question up while the pages turn.
            if self.panel ~= "find" then self:onClose() end
            return self.reader:handleEvent(event)
        elseif key == "Back" then
            return self:onClose()
        end
    elseif event.handler == "onGesture" then
        if self.panel == "find" and event.args[1].ges == "swipe" then
            return self.reader:handleEvent(event)
        end
        if not InputContainer.handleEvent(self, event) then
            local gesture = event.args[1]
            if gesture.ges == "tap" and self.panel ~= "find" and not self.bounds:contains(gesture.pos) then
                self:onClose()
            end
        end
        return true
    end
    return InputContainer.handleEvent(self, event)
end

function Controls:changeFontSize(step)
    local reader = self.reader
    local configurable = reader.document.configurable
    local size = math.max(12, math.min(255, configurable.font_size + step))
    if size ~= configurable.font_size then
        configurable.font_size = size
        reader.document:setFontSize(Screen:scaleBySize(size))
        reader:handleEvent(Event:new("UpdatePos"))
    end
end

function Controls:adjustLight()
    if power:isFrontlightOff() and not power:turnOnFrontlight() then
        power:setIntensity(power.fl_min + 1)
    end
    self.reader:showReadingControls("light")
end

-- Find a place halves the pages it could be on with each answer, starting halfway through the book.
function Controls:goToBeginning()
    self:onClose()
    self.reader:handleEvent(Event:new("GotoPage", 1))
end

function Controls:startFindPlace()
    local reader = self.reader
    local count = reader.document:getPageCount()
    reader.find_place = { low = 1, high = count, count = count }
    reader:handleEvent(Event:new("GotoPage", math.floor((1 + count) / 2)))
    reader:showReadingControls("find")
end

function Controls:answerFindPlace(after)
    local reader = self.reader
    local find = reader.find_place
    local count = reader.document:getPageCount()
    if count ~= find.count then
        -- Turning the Kindle renumbers the pages, so keep the same share of the book.
        find.low = math.max(1, math.floor((find.low - 1) * count / find.count) + 1)
        find.high = math.min(count, math.ceil(find.high * count / find.count))
        find.count = count
    end
    -- The page on screen may be one turned to with the page buttons. An answer that agrees with the
    -- earlier ones keeps their narrower range; one that contradicts them wins and reopens that side.
    local page = reader:getCurrentPage()
    if after then
        find.low = math.max(find.low, math.min(page + 1, count))
        if find.high < find.low then find.high = count end
    else
        find.high = math.min(find.high, math.max(page - 1, 1))
        if find.low > find.high then find.low = 1 end
    end
    if find.low == find.high then
        self:onClose()
        reader:handleEvent(Event:new("GotoPage", find.low))
    else
        reader:handleEvent(Event:new("GotoPage", math.floor((find.low + find.high) / 2)))
    end
end

function Controls:putBookDown()
    self:onClose()
    self.reader:saveSettings()
    UIManager:suspend()
end

function Controls:putBackOnShelf()
    local reader = self.reader
    local file = reader.document.file
    self:onClose()
    UIManager:nextTick(function()
        reader:onClose()
        reader:showFileManager(file)
    end)
end

function Controls:buildSidebar(width, height)
    local actions = {}
    if self.reader.rolling then
        actions[#actions + 1] = {
            text = "Change Text Size",
            icon = "change-font",
            callback = function() self.reader:showReadingControls("font") end,
        }
    end
    if Device:hasFrontlight() then
        actions[#actions + 1] = {
            text = power:isFrontlightOn() and "Adjust light" or "Turn on light",
            icon = "light",
            callback = function() self:adjustLight() end,
        }
    end
    actions[#actions + 1] = {
        text = "Find a place",
        icon = "find-a-place",
        callback = function() self.reader:showReadingControls("find-choice") end,
    }
    actions[#actions + 1] = {
        text = "Stop for now",
        icon = "stop-for-now",
        callback = function() self:putBookDown() end,
    }
    actions[#actions + 1] = {
        text = "Open another book",
        icon = "open-another-book",
        callback = function() self:putBackOnShelf() end,
    }

    local group = VerticalGroup:new{}
    local panel_width = math.floor(width * 0.8)
    local inner_width = panel_width - 2 * Size.border.window
    local row_space = height - 2 * Size.border.window - (#actions - 1) * Size.line.medium
    for index, action in ipairs(actions) do
        action.dimen = Geom:new{
            w = inner_width,
            h = math.floor(row_space * index / #actions) - math.floor(row_space * (index - 1) / #actions),
        }
        if index > 1 then
            group[#group + 1] = LineWidget:new{
                background = Blitbuffer.COLOR_GRAY,
                dimen = Geom:new{ w = inner_width, h = Size.line.medium },
            }
        end
        group[#group + 1] = ActionRow:new(action)
    end
    self.bounds = Geom:new{ x = 0, y = 0, w = panel_width, h = height }
    return LeftContainer:new{
        dimen = Geom:new{ w = width, h = height },
        allow_mirroring = false,
        FrameContainer:new{
            background = Blitbuffer.COLOR_WHITE,
            bordersize = Size.border.window,
            padding = 0,
            group,
        },
    }
end

function Controls:buildBar(width, height)
    -- A grid of two columns leaves room for large words on each button.
    local rows = { {} }
    local button_height = Screen:scaleBySize(90)
    local function addButton(text, callback)
        local row = rows[#rows]
        row[#row + 1] = {
            text = text,
            callback = callback,
            font_size = 40,
            height = button_height,
            enabled = callback ~= nil,
            focusable = callback ~= nil,
        }
    end
    if self.panel == "font" then
        addButton("Smaller", function() self:changeFontSize(-2) end)
        addButton("Bigger", function() self:changeFontSize(2) end)
        rows[2] = {}
    elseif self.panel == "find" then
        -- One row of buttons leaves more of the page to recognise, which matters in landscape.
        addButton("Before", function() self:answerFindPlace(false) end)
        addButton("Done", function() self:onClose() end)
        addButton("After", function() self:answerFindPlace(true) end)
    else
        local level = power:frontlightIntensity()
        local function addBrightnessButton(text, target)
            if target < power.fl_min + 1 or target > power.fl_max then
                addButton("")
            else
                addButton(text, function()
                    power:setIntensity(target)
                    self.reader:showReadingControls("light")
                end)
            end
        end
        addBrightnessButton("Darker", level - 1)
        addBrightnessButton("Brighter", level + 1)
        rows[2] = {}
        addButton("Turn off", function()
            power:turnOffFrontlight()
            self:onClose()
        end)
    end
    if self.panel ~= "find" then
        addButton("Done", function() self:onClose() end)
    end

    local inner_width = width - 2 * Size.border.window
    local content = ButtonTable:new{
        buttons = rows,
        width = inner_width,
        show_parent = self,
    }
    if self.panel == "find" then
        local padding = Size.padding.large
        content = VerticalGroup:new{
            FrameContainer:new{
                bordersize = 0,
                padding = padding,
                TextBoxWidget:new{
                    text = "Find a place: is it before or after this page?",
                    width = inner_width - 2 * padding,
                    alignment = "center",
                    face = Font:getFace("smalltfont", 40),
                },
            },
            content,
        }
    end
    local frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        padding = 0,
        content,
    }
    local bar_height = frame:getSize().h
    self.bounds = Geom:new{ x = 0, y = height - bar_height, w = width, h = bar_height }
    return BottomContainer:new{ dimen = Geom:new{ w = width, h = height }, frame }
end

-- Find a place first offers the beginning of the book or a search. Find a page then explains the search.
function Controls:buildFindChoice(width, height)
    local box_width = math.floor(width * 0.9)
    local inner_width = box_width - 2 * Size.border.window
    local padding = Size.padding.large
    local function text(words, face)
        return FrameContainer:new{
            bordersize = 0,
            padding = padding,
            padding_bottom = 0,
            TextBoxWidget:new{ text = words, width = inner_width - 2 * padding, face = face },
        }
    end
    local function button(words, callback)
        return { text = words, callback = callback, font_size = 40, height = Screen:scaleBySize(90) }
    end
    local cancel = button("Cancel", function() self:onClose() end)
    local title, rows, explanation
    if self.panel == "find-help" then
        title = "Find a page"
        explanation = text("The book opens in the middle. Tap Before or After, and each time it gets closer. "
            .. "The page buttons turn pages as normal. Tap Done when you see your page.",
            Font:getFace("cfont", 34))
        rows = { { button("Start", function() self:startFindPlace() end), cancel } }
    else
        local find = button("Find a page", function() self.reader:showReadingControls("find-help") end)
        local beginning = button("Go to the beginning", function() self:goToBeginning() end)
        rows = { { find }, { beginning }, { cancel } }
    end
    local frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        radius = Size.radius.window,
        padding = 0,
        VerticalGroup:new{
            title and text(title, Font:getFace("smalltfont", 40)) or VerticalGroup:new{},
            explanation or VerticalGroup:new{},
            FrameContainer:new{ bordersize = 0, padding = 0, padding_top = padding,
                ButtonTable:new{
                    buttons = rows,
                    width = inner_width,
                    show_parent = self,
                },
            },
        },
    }
    local size = frame:getSize()
    self.bounds = Geom:new{ x = math.floor((width - size.w) / 2), y = math.floor((height - size.h) / 2), w = size.w, h = size.h }
    return CenterContainer:new{ dimen = Geom:new{ w = width, h = height }, frame }
end

function Controls:init()
    local width = Screen:getWidth()
    local height = Screen:getHeight() - self.reader.view.footer:getHeight()
    if self.panel == "menu" then
        self[1] = self:buildSidebar(width, height)
    elseif self.panel == "find-choice" or self.panel == "find-help" then
        self[1] = self:buildFindChoice(width, height)
    else
        self[1] = self:buildBar(width, height)
    end
end

function ReaderUI:showReadingControls(panel)
    if self.reading_controls then
        UIManager:close(self.reading_controls)
    end
    self.reading_controls = Controls:new{
        name = "reading_" .. panel,
        reader = self,
        panel = panel,
    }
    UIManager:show(self.reading_controls, "ui")
end

function ReaderUI:onBatteryBannerChanged()
    if self.reading_controls then
        self:showReadingControls(self.reading_controls.panel)
    end
end

-- A finger moved left goes forward a page, as on a printed book.
local swipe_pages = { west = 1, east = -1 }

local handleEvent = ReaderUI.handleEvent
function ReaderUI:handleEvent(event)
    if event.handler == "onGesture" then
        -- Up and down swipes, holds, and other gestures leave the page alone.
        local gesture = event.args[1]
        if gesture.ges == "tap" and not self.reading_controls then
            self:showReadingControls("menu")
        elseif gesture.ges == "swipe" and swipe_pages[gesture.direction] then
            handleEvent(self, Event:new("GotoViewRel", swipe_pages[gesture.direction]))
        end
        return true
    end
    if (event.handler == "onKeyPress" or event.handler == "onKeyRepeat")
            and not page_keys[event.args[1].key] then
        return true
    end
    return handleEvent(self, event)
end

local onScreenResize = ReaderUI.onScreenResize
function ReaderUI:onScreenResize(dimen)
    onScreenResize(self, dimen)
    self:onBatteryBannerChanged()
end

local onClose = ReaderUI.onClose
function ReaderUI:onClose(...)
    if self.reading_controls then
        UIManager:close(self.reading_controls)
        self.reading_controls = nil
    end
    return onClose(self, ...)
end
