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

local NetworkMgr = require("ui/network/manager")
local Wifi -- Loaded once every patch has run.

local function checkWifi()
    -- The simulator connects as soon as the radio is on. Shorten the timers to keep the run brief.
    Wifi.grace, Wifi.poll, Wifi.connect_timeout = 0.4, 0.1, 0.5
    local function on() return NetworkMgr:isWifiOn() end
    Wifi:update()
    wait(0.6)
    assert(not on(), "Wi-Fi left on before startup turns off when nothing needs it")

    local answers = {}
    Wifi:need("store", 5, function(connected) answers.store = connected end)
    wait(0.2)
    assert(on() and answers.store == true, "the first need connects and answers true")
    Wifi:need("update", 5, function(connected) answers.update = connected end)
    assert(answers.update == true, "a need registered while connected answers at once")
    assert(Wifi:isNeeded("update"), "isNeeded sees other needs")
    Wifi:release("store")
    assert(not Wifi:isNeeded("update"), "isNeeded ignores the named need")
    wait(0.6)
    assert(on(), "an earlier need released first leaves the later one connected")
    Wifi:release("update")
    wait(0.2)
    assert(on(), "Wi-Fi waits out the grace period after the last need")
    wait(0.4)
    assert(not on(), "Wi-Fi turns off after the grace period")

    Wifi:need("short", 0.5)
    wait(0.3)
    Wifi:need("short", 0.5)
    wait(0.7)
    assert(on(), "registering a need again extends it")
    wait(0.5)
    assert(not on(), "an unreleased need times out")

    local connected = NetworkMgr.isConnected
    NetworkMgr.isConnected = function() return false end
    Wifi:need("cancelled", 5, function(ok, reason) answers.cancelled = reason or ok end)
    Wifi:release("cancelled")
    assert(answers.cancelled == "ended", "releasing a need before the connection answers ended")
    Wifi:need("background", 5, function(ok, reason) answers.background = reason or ok end)
    wait(0.3)
    assert(answers.background == nil, "a need waits while connecting")
    Wifi:need("store-late", 5, function(ok, reason) answers.late = reason or ok end)
    wait(0.35)
    assert(answers.background == "unreachable" and answers.late == nil and Wifi.needs["store-late"],
        "an earlier attempt timing out leaves a later need its own full connect timeout")
    assert(Wifi:hasProblem(), "an unreachable connection is recorded for settings")
    wait(0.3)
    assert(answers.late == "unreachable" and not next(Wifi.needs), "the later need times out on its own")
    wait(0.5)
    NetworkMgr.isConnected = connected
    assert(not on(), "Wi-Fi turns off after the failed needs")
    Wifi:report(true)
    assert(not Wifi:hasProblem(), "a reached request clears the settings problem")

    Wifi:setOff(true)
    Wifi:need("blocked", 5, function(ok, reason) answers.blocked = reason or ok end)
    wait(0.2)
    assert(answers.blocked == "off" and not on(), "the off setting refuses every need")
    Wifi:setOff(false)
    Wifi.off_seconds = 0.3
    Wifi:setOff(true)
    wait(0.4)
    Wifi:need("after-off", 5, function(ok) answers.after_off = ok end)
    wait(0.2)
    assert(answers.after_off == true, "Wi-Fi off expires by itself")
    Wifi:release("after-off")
    print("PASS wifi: startup takeover, overlapping needs, grace, extension, timeout, per-need connect timeout, problem report, off setting and its expiry")
end

local function check()
    local width, height = Screen:getWidth(), Screen:getHeight()
    local landscape = width > height
    Wifi = require("grandma/wifi")
    local home = top()
    assert(home.name == "books_home" and #home.item_table == 2, "startup opens the fixed Books folder")
    screenshot("01-books")
    if not landscape then checkWifi() end

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

    local function button(text, widget)
        widget = widget or top()
        if widget.text == text and widget.label_widget then return widget end
        for _, child in ipairs(widget) do
            local found = type(child) == "table" and button(text, child)
            if found then return found end
        end
    end
    local function place(index)
        tap(width * (index - 0.5) / 3, height - 40)
        return top()
    end
    assert(place(1).place == "shop" and top().title == "Book Shop", "the left button opens the Book Shop")
    screenshot("01-book-shop")
    assert(place(3).place == "settings" and top().title == "Settings", "the right button opens Settings")
    screenshot("01-settings")
    local function row(text)
        local first = top().layout[1][1]
        assert(#top().item_table == 1 and first.text == text, "the screen offers only " .. text)
        return first[1]
    end
    local function advanced()
        tapBounds(row("Advanced").dimen)
        assert(top().place == "settings" and top().view.kind == "advanced" and top().title == "Advanced",
            "Advanced opens from Settings")
    end
    local function askToExit()
        tapBounds(row("Exit to Kindle").dimen)
        assert(button("Cancel") and button("Exit to Kindle"), "Exit to Kindle asks before leaving")
    end
    advanced()
    screenshot("01-advanced")
    askToExit()
    screenshot("01-exit-to-kindle")
    tapBounds(button("Cancel").dimen)
    assert(top().title == "Advanced" and not button("Cancel"), "Cancel stays in Advanced")
    assert(place(3).place == "settings" and not top().view, "the Settings button returns from Advanced")
    UIManager:broadcastEvent(Event:new("NotCharging"))
    wait(0.15)
    assert(top().place == "settings", "a refresh stays on the open place")
    assert(place(2).place == "shelf" and #top().item_table == 2, "the centre button returns to the shelf")

    -- Fourteen more titles make more than one shelf. Library order ignores a leading "The", "A", or "An".
    local library_order = {
        "Bleak House", "Cranford", "Dracula", "Emma", "An Evening Walk", "Frankenstein", "The Go-Between",
        "Great Expectations", "Ivanhoe", "Jane Eyre", "Kidnapped", "Mansfield Park", "Martin Chuzzlewit",
        "Oasis Sample", "Persuasion", "A Tale of Two Cities",
    }
    -- Two of them are FictionBook files, which name their author inside the file.
    local written_by = { ["Jane Eyre"] = { "Charlotte", "Brontë" }, ["Persuasion"] = { "Jane", "Austen" } }
    local extras, authored = {}, {}
    for _, title in ipairs(library_order) do
        if not lfs.attributes(os.getenv("XDG_DOCUMENTS_DIR") .. "/" .. title .. ".html") then
            local author = written_by[title]
            extras[#extras + 1] = os.getenv("XDG_DOCUMENTS_DIR") .. "/" .. title .. (author and ".fb2" or ".txt")
            file = assert(io.open(extras[#extras], "w"))
            if author then
                authored[#authored + 1] = extras[#extras]
                file:write(string.format('<?xml version="1.0" encoding="UTF-8"?>\n'
                    .. '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0"><description><title-info>'
                    .. '<author><first-name>%s</first-name><last-name>%s</last-name></author>'
                    .. '<book-title>%s</book-title><lang>en</lang></title-info></description>'
                    .. '<body><section><p>This is a temporary book used to test the shelves.</p></section></body>'
                    .. '</FictionBook>\n', author[1], author[2], title))
            else
                file:write("This is a temporary book used to test the shelves.")
            end
            file:close()
        end
    end
    assert(#extras == 14)
    UIManager:broadcastEvent(Event:new("NotCharging"))
    wait(0.15)
    local shelved = {}
    for index, item in ipairs(top().item_table) do shelved[index] = item.text end
    assert(table.concat(shelved, "|") == table.concat(library_order, "|"), "the books stand in library order")
    -- A shelf holds twelve books in portrait and seven in landscape, so G or M runs onto a second shelf.
    -- An end of a shelf's letters takes as many letters as it needs to differ from its neighbour.
    local shelf_size = #top().page_items[1]
    local shelf_letters = ({ [12] = { "B–Man", "Mar–T" }, [7] = { "B–Go", "Gr–O", "P–T" } })[shelf_size]
    assert(shelf_letters, "a shelf holds twelve books in portrait or seven in landscape")
    local last = top().page_num
    assert(last == #shelf_letters, "sixteen books fill the expected number of shelves")
    local function shelf(page, message)
        local previous, next_shelf
        for _, arrow in ipairs(top().shelf_arrows) do
            if arrow.points_left then previous = arrow.text else next_shelf = arrow.text end
        end
        assert(not top().view and top().page == page and top().page_num == last and button("Find a book")
            and top().title_bar.title_widget.text == "Books " .. shelf_letters[page]
            and previous == shelf_letters[page - 1] and next_shelf == shelf_letters[page + 1], message)
    end
    shelf(1, "the first shelf is titled by its letters and points right to the second")
    screenshot("01-first-shelf")
    turnPage(false)
    shelf(1, "the page-back key stops at the first shelf")
    local right_arrow
    for page = 2, last do
        right_arrow = top().next_shelf.dimen:copy()
        tapBounds(right_arrow)
        shelf(page, "the right arrow opens the next shelf, which points back to the one before")
    end
    screenshot("01-last-shelf")
    tapBounds(right_arrow)
    shelf(last, "the place where the right arrow was does nothing on the last shelf")
    turnPage(true)
    shelf(last, "the page-forward key stops at the last shelf")
    swipe(width / 2, height / 2, -240, 0)
    shelf(last, "a swipe stops at the last shelf")
    tapBounds(top().previous_shelf.dimen)
    shelf(last - 1, "the left arrow goes back a shelf")
    turnPage(true)
    shelf(last, "the page-forward key turns to the next shelf")
    swipe(width / 2, height / 2, 240, 0)
    shelf(last - 1, "a swipe turns back a shelf")
    print("PASS shelves: library order, lettered arrows that tell shelves of one letter apart, both ends stop")

    local function title() return top().title_bar.title_widget.text end
    local function find()
        tapBounds(button("Find a book").dimen)
        assert(top().view and top().view.kind == "find" and title() == "Find a book", "Find a book opens the Find screen")
    end
    find()
    screenshot("01-find")
    assert(not button("A").enabled and not button("N").enabled and button("T").enabled and not button("0–9"),
        "a letter is offered only where a title is filed, ignoring a leading article")
    tapBounds(button("A").dimen)
    assert(top().view and top().view.kind == "find", "a letter without books does nothing")
    tapBounds(button("T").dimen)
    shelf(last, "T opens the shelf that holds A Tale of Two Cities")
    screenshot("01-letter-shelf")
    find()
    tapBounds(button("E").dimen)
    shelf(1, "E opens the shelf that holds Emma")
    find()
    local continued = shelf_size == 12 and "M" or "G"
    tapBounds(button(continued).dimen)
    shelf(1, continued .. " opens its first shelf, whose right arrow shows the letter going on")
    assert(top().next_shelf.text:sub(1, 1) == continued, "the right arrow starts with the same letter")

    find()
    tapBounds(button("Read lately").dimen)
    assert(top().view.kind == "recent" and title() == "Read lately" and #top().item_table == 1
        and top().item_table[1].text == "No books read yet", "Read lately says so before any book is read")
    -- Reading history is a fixture here: three books last open today, yesterday, and twenty days ago.
    local ReadHistory = require("readhistory")
    local read = { { "Bleak House", 1, "Yesterday" }, { "Emma", 20, "2 weeks ago" }, { "Kidnapped", 0, "Today" } }
    for _, book in ipairs(read) do
        book.path = os.getenv("XDG_DOCUMENTS_DIR") .. "/" .. book[1] .. ".txt"
        assert(ReadHistory:addItem(book.path, os.time() - book[2] * 86400, true))
    end
    tapBounds(button("Find a book").dimen)
    tapBounds(button("Read lately").dimen)
    local lately = {}
    for index, item in ipairs(top().item_table) do lately[index] = item.text .. " " .. item.mandatory end
    assert(table.concat(lately, "|") == "Kidnapped Today|Bleak House Yesterday|Emma 2 weeks ago",
        "Read lately lists the books in reading history, newest first")
    screenshot("01-read-lately")
    for _, book in ipairs(read) do ReadHistory:removeItemByPath(book.path) end

    local function typeName(text)
        tapBounds(button("Find a book").dimen)
        local screen = top()
        tapBounds(button("Type a name").dimen)
        local dialog = assert(screen.name_dialog, "Type a name opens KOReader's text box")
        assert(not button("T", screen) and not button("Read lately", screen) and screen.view.kind == "find",
            "the letters and buttons are put away while a name is typed")
        -- The text is set directly. The keyboard itself is KOReader's.
        dialog:setInputText(text)
        wait(0.2)
        return dialog.button_table:getButtonById("find").dimen, dialog, screen
    end
    local find_button, name_dialog, find_screen = typeName("EVENING w")
    screenshot("01-type-a-name")
    tapBounds(name_dialog.button_table:getButtonById("close").dimen)
    assert(top() == find_screen and not find_screen.name_dialog and button("T") and button("Type a name"),
        "Cancel puts the text box away and brings the letters back")
    tapBounds(button("Type a name").dimen)
    find_screen.name_dialog:setInputText("EVENING w")
    wait(0.2)
    tapBounds(find_button)
    assert(top().view.kind == "search" and title() == "Books with “EVENING w”" and #top().item_table == 1
        and top().item_table[1].text == "An Evening Walk", "typed words find the book whatever their capitals")
    screenshot("01-typed-name")
    tapBounds(typeName("zebra"))
    assert(#top().item_table == 1 and top().item_table[1].text == "No book or author has “zebra” in its name"
        and not top().item_table[1].callback, "a name no book or author has says so")

    -- The home screen has KOReader read each book's details in the background. Wait for the two authors.
    local details = assert(package.loaded.bookinfomanager, "the home screen loads KOReader's book details")
    for _ = 1, 40 do
        local read_all = true
        for _, path in ipairs(authored) do
            read_all = read_all and details:getDocProps(path) ~= nil
        end
        if read_all then break end
        wait(0.25)
    end
    local function named(text)
        tapBounds(typeName(text))
        local rows = {}
        for index, item in ipairs(top().item_table) do
            rows[index] = item.text .. " by " .. tostring(item.mandatory)
        end
        return table.concat(rows, "|")
    end
    assert(named("austen") == "Persuasion by Jane Austen", "an author's name finds their book")
    assert(named("bronte") == "Jane Eyre by Charlotte Brontë", "an author is found without the accent")
    assert(named("jane") == "Jane Eyre by Charlotte Brontë|Persuasion by Jane Austen",
        "typed words match titles and authors together, in library order")
    screenshot("01-typed-author")
    assert(place(2).place == "shelf", "Book Shelf leaves Find")
    shelf(1, "Book Shelf returns from Find to the first shelf")
    print("PASS find: letters, Read lately, typed name or author, return to the shelf")

    for _, extra in ipairs(extras) do assert(os.remove(extra)) end
    UIManager:broadcastEvent(Event:new("NotCharging"))
    wait(0.15)
    assert(#top().item_table == 2 and top().page_num == 1 and not top().shelf_arrows
        and top().title_bar.title_widget.text == "Books", "one shelf of two fixture books has a plain title and no arrows")

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
    assert(old_size == 36, "a new book opens in large print")
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

    local slept_answer
    Wifi:need("sleep", 60, function(ok, reason) slept_answer = reason or ok end)
    sidebar()
    menuAction(3)
    assert(Device.screen_saver_mode and not reader.reading_controls, "Stop for now activates the simulator screensaver")
    assert((slept_answer == true or slept_answer == "asleep") and not next(Wifi.needs) and not NetworkMgr:isWifiOn(),
        "sleep ends every Wi-Fi need and turns the radio off")
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

    -- The run ends the way the reader leaves for the Kindle: Exit to Kindle, then its confirmation.
    place(3)
    advanced()
    askToExit()
    print(string.format("Reader review passed at %d × %d", width, height))
    tapBounds(button("Exit to Kindle").dimen)
    error("Exit to Kindle left KOReader running")
end

UIManager:scheduleIn(0.25, resume, coroutine.create(check))
