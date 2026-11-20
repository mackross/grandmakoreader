-- Loaded only by the headless simulator review in a disposable profile.
local Device = require("device")
local DocSettings = require("docsettings")
local Event = require("ui/event")
local ReaderUI = require("apps/reader/readerui")
local SDL = require("ffi/SDL3")
local UIManager = require("ui/uimanager")
local ffi = require("ffi")
local lfs = require("libs/libkoreader-lfs")

ffi.cdef[[bool SDL_PushEvent(SDL_Event *event);]]

local Screen = Device.screen
local power = Device:getPowerDevice()
local battery = 75
Device.hasBattery = function() return true end
power.getCapacity = function() return battery end

local function resume(thread)
    local ok, message = coroutine.resume(thread)
    if not ok then error(debug.traceback(thread, message), 0) end
end

local function wait(seconds)
    local thread = coroutine.running()
    UIManager:scheduleIn(seconds, resume, thread)
    coroutine.yield()
end

local function waitForInput()
    -- Reflow briefly suspends hardware input. Wait for KOReader before queuing the next action.
    for _ = 1, 75 do
        if not Device.input._abs_ev_handler and not Device.input._key_ev_handler then return end
        wait(0.02)
    end
    error("KOReader did not resume input")
end

local function screenshot(name)
    UIManager:forceRePaint()
    local path = os.getenv("KO_REVIEW_SCREENSHOTS") .. "/" .. name .. ".png"
    local temporary = path .. ".tmp.png"
    os.remove(temporary)
    local result, message = Screen:shot(temporary)
    assert(result ~= false and (lfs.attributes(temporary, "size") or 0) > 24,
        message or "KOReader did not write " .. temporary)
    assert(os.rename(temporary, path))
end

local function touch(kind, x, y)
    local event = ffi.new("SDL_Event")
    event.type = SDL.SDL[kind]
    event.tfinger.touchID = 1
    event.tfinger.fingerID = 10
    event.tfinger.x = x / SDL.w
    event.tfinger.y = y / SDL.h
    assert(SDL.SDL.SDL_PushEvent(event), "SDL could not queue the touch")
end

local function tap(x, y)
    waitForInput()
    touch("SDL_EVENT_FINGER_DOWN", x, y)
    touch("SDL_EVENT_FINGER_UP", x, y)
    wait(0.27)
end

local function swipe(x, y, dx, dy)
    waitForInput()
    touch("SDL_EVENT_FINGER_DOWN", x, y)
    for step = 1, 5 do
        touch("SDL_EVENT_FINGER_MOTION", x + dx * step / 5, y + dy * step / 5)
    end
    touch("SDL_EVENT_FINGER_UP", x + dx, y + dy)
    wait(0.27)
end

local function turnPage(forward)
    waitForInput()
    -- SDL keycodes for Page Down and Page Up, mapped to the Kindle right-side turn events.
    local event = ffi.new("SDL_Event")
    event.type = SDL.SDL.SDL_EVENT_KEY_DOWN
    event.key.key = forward and 1073741902 or 1073741899
    assert(SDL.SDL.SDL_PushEvent(event), "SDL could not queue the page-turn key")
    event.type = SDL.SDL.SDL_EVENT_KEY_UP
    assert(SDL.SDL.SDL_PushEvent(event), "SDL could not queue the page-turn key release")
    wait(0.25)
end

local function tapBounds(bounds)
    tap(bounds.x + bounds.w / 2, bounds.y + bounds.h / 2)
end

local function top()
    return UIManager:getTopmostVisibleWidget()
end

local function check()
    local width, height = Screen:getWidth(), Screen:getHeight()
    local landscape = width > height
    local home = top()
    assert(home.name == "books_home" and #home.item_table == 2, "startup opens the fixed Books folder")
    screenshot("01-books")

    local added = os.getenv("XDG_DOCUMENTS_DIR") .. "/Recently added.txt"
    local file = assert(io.open(added, "w"))
    file:write("This is a temporary book used to test shelf refresh.")
    file:close()
    UIManager:broadcastEvent(Event:new("NotCharging"))
    wait(0.15)
    assert(top().name == "books_home" and #top().item_table == 3, "shelf refreshes after unplugging")
    assert(os.remove(added))
    UIManager:sendEvent(Event:new("SetRotationMode", 1))
    wait(0.25)
    assert(top().dimen.w == height and top().dimen.h == width, "the open shelf relayouts when rotated")
    UIManager:sendEvent(Event:new("SetRotationMode", 0))
    wait(0.25)
    assert(top().dimen.w == width and #top().item_table == 2, "the shelf returns to its original size")

    tapBounds(top().layout[1][1][1].dimen)
    wait(3.2) -- Allow the fresh-profile book cache notice to clear.
    local reader = assert(ReaderUI.instance, "a touch on the shelf opens the book")
    local book = reader.document.file
    local footer = reader.view.footer
    assert(reader:getCurrentPage() == 1 and footer:getHeight() == 0)
    screenshot("02-reading")
    print("PASS books: launch, refresh after unplugging, rotation, tap to open")

    tap(width - 10, height / 2)
    tap(width / 2, height - 10)
    swipe(width / 2, height / 2, -240, 0)
    assert(not reader.reading_controls and reader:getCurrentPage() == 1, "reading taps and centre swipes do nothing")
    for _, edge in ipairs{
        { 4, height / 2, 250, 0 },
        { width - 4, height / 2, -250, 0 },
        { width / 2, 4, 0, 250 },
        { width / 2, height - 4, 0, -250 },
    } do
        swipe(unpack(edge))
        local menu = assert(reader.reading_controls, "SDL touch swipe opens the menu from every edge")
        assert(menu.panel == "menu" and menu.bounds.x == 0 and menu.bounds.w == math.floor(width * 0.8))
        tap(width - 10, height / 2)
        assert(not reader.reading_controls)
    end
    print("PASS reading input: ordinary taps and centre swipes ignored, all four edges open the sidebar")

    local function menuAction(index)
        local bounds = assert(reader.reading_controls).bounds
        tap(bounds.x + bounds.w / 2, bounds.h * (index - 0.5) / 4)
    end
    local function barAction(index)
        local bounds = assert(reader.reading_controls).bounds
        tap(width * (index - 0.5) / 3, bounds.y + bounds.h / 2)
    end
    local function sidebar()
        swipe(4, height / 2, 250, 0)
        assert(reader.reading_controls and reader.reading_controls.panel == "menu")
    end

    sidebar()
    screenshot("03-reading-menu")
    UIManager:sendEvent(Event:new("SetRotationMode", 1))
    wait(0.25)
    assert(reader.reading_controls.bounds.w == math.floor(height * 0.8), "open menu follows rotation")
    UIManager:sendEvent(Event:new("SetRotationMode", 0))
    wait(1.1) -- Allow the orientation notice to fade.
    menuAction(1)
    assert(reader.reading_controls.panel == "font")
    local old_size = reader.document.configurable.font_size
    local original_location = reader.rolling:getBookLocation()
    barAction(2)
    local new_size = reader.document.configurable.font_size
    assert(new_size == old_size + 2 and reader.rolling:getBookLocation() == original_location,
        "font preview grows the text and preserves the reading location")
    screenshot("04-font-preview")
    barAction(3)
    assert(not reader.reading_controls and DocSettings:open(book):readSetting("copt_font_size") == new_size)

    sidebar()
    menuAction(1)
    local page = reader:getCurrentPage()
    turnPage(true)
    assert(not reader.reading_controls and reader:getCurrentPage() == page + 1,
        "a page-turn key dismisses the font overlay and advances once")
    sidebar()
    turnPage(false)
    assert(not reader.reading_controls and reader:getCurrentPage() == page,
        "a page-turn key dismisses the sidebar and goes back once")
    sidebar()
    menuAction(1)
    barAction(1)
    tap(width / 2, height / 2)
    assert(not reader.reading_controls, "tapping the preview page dismisses the font controls")
    assert(DocSettings:open(book):readSetting("copt_font_size") == old_size,
        "tapping the preview page saves the new font size")
    turnPage(true)
    print("PASS font: live preview preserves location, saved size, both page keys dismiss and turn once")

    local function finishLight()
        local bounds = assert(reader.reading_controls).bounds
        local level = power:frontlightIntensity()
        local refresh = Screen.refreshFullImp
        local bar_refreshed = false
        -- SDL shares a framebuffer refresh implementation across waveform modes.
        function Screen:refreshFullImp(x, y, w, h, ...)
            if x <= bounds.x and y <= bounds.y and x + w >= bounds.x + bounds.w
                    and y + h >= bounds.y + bounds.h then
                bar_refreshed = true
            end
            return refresh(self, x, y, w, h, ...)
        end
        barAction(3)
        Screen.refreshFullImp = refresh
        assert(not reader.reading_controls and power:isFrontlightOn() and power:frontlightIntensity() == level,
            "brightness Done dismisses the controls and keeps the selected light level")
        assert(bar_refreshed, "brightness Done refreshes the whole area previously covered by the controls")
    end

    sidebar()
    menuAction(2)
    assert(power:isFrontlightOn() and reader.reading_controls.panel == "light")
    screenshot("05-light-controls")
    local start_level = power:frontlightIntensity()
    barAction(2)
    assert(power:frontlightIntensity() == start_level + 1)
    finishLight()
    sidebar()
    menuAction(2)
    sidebar()
    menuAction(2)
    power:setIntensity(power.fl_max - 1)
    reader:showReadingControls("light")
    wait(0.1)
    barAction(2)
    assert(power:frontlightIntensity() == power.fl_max)
    barAction(2)
    assert(power:frontlightIntensity() == power.fl_max and reader.reading_controls.panel == "light",
        "the brighter control disappears without moving Done")
    power:setIntensity(power.fl_min + 2)
    reader:showReadingControls("light")
    wait(0.1)
    barAction(1)
    assert(power:frontlightIntensity() == power.fl_min + 1)
    barAction(1)
    assert(power:frontlightIntensity() == power.fl_min + 1 and reader.reading_controls.panel == "light")
    finishLight()
    sidebar()
    menuAction(2)
    assert(power:isFrontlightOff() and not reader.reading_controls)
    print("PASS frontlight: toggle, both limits, Done keeps the level and refreshes the entire bar")

    battery = 10
    footer:updateBatteryWarning()
    assert(footer:getHeight() == 0)
    battery = 9
    footer:updateBatteryWarning()
    wait(0.27)
    assert(footer.battery_percent == 9 and footer.battery_label[1].text:find("9%% battery remaining"))
    screenshot("06-low-battery")

    sidebar()
    menuAction(3)
    assert(Device.screen_saver_mode and not reader.reading_controls, "Stop for now activates the simulator screensaver")
    screenshot("07-stop-for-now")
    UIManager.event_handlers.Resume()
    wait(0.4)
    assert(not Device.screen_saver_mode)
    battery = 75
    footer:updateBatteryWarning()
    wait(0.27)
    assert(footer:getHeight() == 0)
    print("PASS power: 10% hidden, 9% visible, sleep and resume, warning cleared on recovery")

    local saved_location = reader.rolling:getBookLocation()
    sidebar()
    menuAction(4)
    assert(top().name == "books_home" and not ReaderUI.instance)
    tapBounds(top().layout[1][1][1].dimen)
    wait(0.4)
    reader = assert(ReaderUI.instance)
    assert(reader.rolling:getBookLocation() == saved_location, "reading shelf action preserves the place")
    print("PASS reading position: shelve mid-book and reopen at the same location")
    local function openEndMenu()
        reader.gotopage:onGoToEnd()
        wait(0.27)
        turnPage(true)
        local dialog = top()
        assert(dialog.name == "end_document" and not dialog.cropping_widget)
        return dialog
    end
    local function endChoice(portrait_row, landscape_row, landscape_column)
        local dialog = top()
        tapBounds((landscape and dialog.layout[landscape_row][landscape_column] or dialog.layout[portrait_row][1]).dimen)
    end
    local end_menu = openEndMenu()
    screenshot("08-end-of-book")
    local before = end_menu:getContentSize():copy()
    endChoice(2, 1, 2)
    local confirmation = top()
    assert(confirmation.title:match("^Are you sure%?") and not UIManager:isWidgetShown(end_menu))
    local after = confirmation:getContentSize()
    assert(after.w == before.w and after.h == before.h and after.x == before.x and after.y == before.y)
    screenshot("09-removal-confirmation")
    tapBounds(confirmation.layout[1][1].dimen)
    assert(top().title == end_menu.title and lfs.attributes(book, "mode") == "file", "Cancel safely redraws the end menu")
    local last_page = reader:getCurrentPage()
    endChoice(4, 2, 2)
    assert(top().name ~= "end_document" and reader:getCurrentPage() == last_page
        and reader.doc_settings:readSetting("summary").status ~= "complete", "going back leaves the last page open")
    end_menu = openEndMenu()
    turnPage(true)
    assert(top() == end_menu and reader:getCurrentPage() == last_page, "page forward leaves the end menu open")
    turnPage(false)
    assert(top().name ~= "end_document" and reader:getCurrentPage() == last_page, "page back closes the end menu on the last page")
    openEndMenu()
    endChoice(3, 2, 1)
    assert(top().name ~= "end_document" and reader:getCurrentPage() == 1, "Read again now opens page one")
    openEndMenu()
    endChoice(1, 1, 1)
    local finished = DocSettings:open(book)
    assert(top().name == "books_home" and not ReaderUI.instance and finished:readSetting("summary").status == "complete"
        and finished:readSetting("percent_finished") == 0, "the end-of-book shelf action marks read and resets progress")
    tapBounds(top().layout[1][1][1].dimen)
    wait(0.4)
    reader = assert(ReaderUI.instance)
    assert(reader:getCurrentPage() == 1, "a finished book reopens at the beginning")
    openEndMenu()
    endChoice(2, 1, 2)
    endChoice(2, 1, 2)
    assert(top().name == "books_home" and #top().item_table == 1 and not lfs.attributes(book),
        "confirmation removes the book and refreshes the shelf")
    print("PASS end of book: same-size replacement, cancel restores menu, last page, restart, shelve with zero progress, confirmed removal")

    print(string.format("Reader review passed at %d × %d", width, height))
    UIManager:quit(0)
end

UIManager:scheduleIn(0.25, resume, coroutine.create(check))
