local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local DataStorage = require("datastorage")
local Device = require("device")
local FileManager = require("apps/filemanager/filemanager")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local InputContainer = require("ui/widget/container/inputcontainer")
local QuickStart = require("ui/quickstart")
local ReaderStatus = require("apps/reader/modules/readerstatus")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")

local onEndOfBook = ReaderStatus.onEndOfBook

local function confirmThrowAway(reader, dialog, return_to_menu)
    local file = reader.document.file
    local device_name = os.getenv("KO_DEV_DEVICE_NAME") or (Device:isKindle() and "Kindle" or "device")
    local button_height = dialog.buttons[1][1].height
    local landscape = #dialog.buttons[1] == 2
    local confirmation
    local cancel = {
        text = "Cancel",
        font_size = 30,
        height = button_height,
        -- Match the first grid cell and let the other absorb any rounding remainder.
        width = landscape and dialog.layout[1][1].width or nil,
        callback = function()
            confirmation:onClose()
        end,
    }
    local discard = {
        text = "Yes, it's rubbish",
        font_size = 30,
        height = button_height,
        callback = function()
            UIManager:close(confirmation)
            UIManager:nextTick(function()
                reader:onClose()
                FileManager:deleteFile(file, true)
                reader:showFileManager(file)
            end)
        end,
    }
    confirmation = ButtonDialog:new{
        name = "end_document",
        modal = true,
        title = "Are you sure?\n\nThis removes the book from this " .. device_name .. ".",
        title_align = dialog.title_align,
        title_face = dialog.title_face,
        title_padding = dialog.title_padding,
        use_info_style = dialog.use_info_style,
        width = dialog.width,
        buttons = landscape and { { cancel, discard } } or { { cancel }, { discard } },
        onClose = function(self)
            local offset = self.movable:getMovedOffset()
            UIManager:close(self)
            return_to_menu(offset)
            return true
        end,
    }

    -- Keep the original frame height by centering the message in the space above the buttons.
    local spare_height = dialog.movable:getSize().h - confirmation.movable:getSize().h
    if spare_height > 0 then
        local header = confirmation.title_group
        header.padding_top = header.padding + math.floor(spare_height / 2)
        header.padding_bottom = header.padding + math.ceil(spare_height / 2)
        confirmation.movable[1][1]:resetLayout()
    end
    confirmation.movable:setMovedOffset(dialog.movable:getMovedOffset())
    UIManager:close(dialog)
    UIManager:show(confirmation)
end

local function showEndOfBookDialog(self, offset, after_tap)
    local screen = Device.screen
    local screen_width, screen_height = screen:getWidth(), screen:getHeight()
    local landscape = screen_width > screen_height
    local button_height = math.floor(math.min(screen:scaleBySize(86), screen_height * 0.15))
    local dialog
    local choices = {
        {
            text = "Put back on shelf",
            font_size = 30,
            height = button_height,
            callback = function()
                UIManager:close(dialog)
                UIManager:nextTick(function()
                    self:markBook(true)
                    self.ui.gotopage:onGoToBeginning()
                    -- KOReader normally counts page one as nonzero progress on save.
                    self.ui.view.footer.percent_finished = 0
                    self:openFileBrowser()
                end)
            end,
        },
        {
            text = "Throw away",
            font_size = 30,
            height = button_height,
            callback = function()
                confirmThrowAway(self.ui, dialog, function(confirmation_offset)
                    showEndOfBookDialog(self, confirmation_offset)
                end)
            end,
        },
        {
            text = "Read again now",
            font_size = 30,
            height = button_height,
            callback = function()
                UIManager:close(dialog)
                self.ui.gotopage:onGoToBeginning()
            end,
        },
        {
            text = "Go back to last page",
            font_size = 30,
            font_bold = false,
            height = button_height,
            callback = function()
                UIManager:close(dialog)
            end,
        },
    }
    local buttons
    if landscape then
        buttons = {
            { choices[1], choices[2] },
            { choices[3], choices[4] },
        }
    else
        buttons = {
            { choices[1] },
            { choices[2] },
            { choices[3] },
            { choices[4] },
        }
    end
    dialog = ButtonDialog:new{
        name = "end_document",
        title = "It seems you've reached the end. What do you want to do with this book?",
        title_align = "center",
        title_face = Font:getFace("smalltfont", 34),
        title_padding = screen:scaleBySize(landscape and 16 or 40),
        use_info_style = false,
        width = landscape and math.floor(screen_width * 0.9) or nil,
        width_factor = 0.94,
        buttons = buttons,
    }
    -- A tap that turned Andrew's page often comes with a second, impatient one; let it fall on nothing.
    local settling = after_tap
    if settling then
        UIManager:scheduleIn(0.5, function() settling = false end)
    end
    -- Page back dismisses the choices like "Go back to last page"; page forward does nothing.
    function dialog:handleEvent(event)
        if settling and event.handler == "onGesture" then
            return true
        elseif event.handler == "onKeyPress" then
            local key = event.args[1].key
            if key == "LPgBack" or key == "RPgBack" then
                UIManager:close(self)
                return true
            elseif key == "LPgFwd" or key == "RPgFwd" then
                return true
            end
        end
        return ButtonDialog.handleEvent(self, event)
    end
    dialog.movable:setMovedOffset(offset)
    UIManager:show(dialog)
end

-- Every book ends with a page from Andrew. Turning forward from it, by button, swipe, or tap,
-- offers the end-of-book choices; turning back returns to the book's own last page.
local function showLoveNote(self)
    local size = Device.screen:getSize()
    local note = InputContainer:new{
        name = "love_note",
        covers_fullscreen = true,
        dimen = size,
        FrameContainer:new{
            width = size.w,
            height = size.h,
            padding = 0,
            bordersize = 0,
            background = Blitbuffer.COLOR_WHITE,
            CenterContainer:new{
                dimen = size,
                TextBoxWidget:new{
                    text = "Dear Grandma,\n\nI hope you enjoyed\nthis book.\n\nWith love,\nAndrew ♥",
                    face = Font:getFace("NotoSerif-Italic.ttf", 40),
                    width = math.floor(size.w * 0.8),
                    alignment = "center",
                },
            },
        },
    }
    local function turn(forward, by_tap)
        UIManager:close(note, "full")
        if forward then
            showEndOfBookDialog(self, nil, by_tap)
        end
        return true
    end
    function note:handleEvent(event)
        if event.handler == "onKeyPress" then
            local key = event.args[1].key
            if key == "LPgFwd" or key == "RPgFwd" then
                return turn(true)
            elseif key == "LPgBack" or key == "RPgBack" then
                return turn(false)
            end
            return true
        elseif event.handler == "onGesture" then
            local gesture = event.args[1]
            if gesture.ges == "tap" then
                return turn(true, true)
            elseif gesture.ges == "swipe" and gesture.direction == "west" then
                return turn(true)
            elseif gesture.ges == "swipe" and gesture.direction == "east" then
                return turn(false)
            end
            return true
        end
        return InputContainer.handleEvent(self, event)
    end
    UIManager:show(note, "full")
end

function ReaderStatus:onEndOfBook()
    if self.document.file == QuickStart.quickstart_filename then
        return onEndOfBook(self)
    end
    -- The instructions are not one of her books, so their end offers no shelf and no throwing away.
    -- The reading menu's Open another book leads back to the shelf.
    if self.document.file == DataStorage:getDataDir() .. "/instructions/Instructions.epub" then
        return true
    end
    -- Find a place stays open while pages turn; put it away so the note is not drawn under it.
    if self.ui.reading_controls then
        self.ui.reading_controls:onClose()
    end

    local top_widget = UIManager:getTopmostVisibleWidget()
    if top_widget and (top_widget.name == "end_document" or top_widget.name == "love_note") then
        return true
    end

    Device:performHapticFeedback("CONTEXT_CLICK")
    showLoveNote(self)
    return true
end
