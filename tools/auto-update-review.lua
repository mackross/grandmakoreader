-- Loaded only by tools/review-auto-update. It travels inside each fixture release, so it survives the swap.
local Device = require("device")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")

local action, argument = os.getenv("KO_UPDATE_REVIEW"):match("^([^:]+):?(.*)$")
local incoming = os.getenv("KO_HOME") .. "/patches.new"
local trial_marker = os.getenv("KO_HOME") .. "/patches.trial"

-- Headless SDL has no battery and reports 0%.
local battery = 75
Device.hasBattery = function() return true end
Device:getPowerDevice().getCapacity = function() return battery end

local function resume(thread)
    local ok, message = coroutine.resume(thread)
    if not ok then error(debug.traceback(thread, message), 0) end
end

local function wait(seconds)
    UIManager:scheduleIn(seconds, resume, coroutine.running())
    coroutine.yield()
end

local function say(...)
    print(table.concat({ "REVIEW", ... }, " "))
end

local function report()
    local ReaderUI = require("apps/reader/readerui")
    local top = UIManager:getTopmostVisibleWidget()
    say("TOP", tostring(top and top.name))
    say("PAGE", tostring(ReaderUI.instance and ReaderUI.instance:getCurrentPage()))
    say("TRIAL", tostring(lfs.attributes(trial_marker, "mode") ~= nil))
end

-- Prints the simulated radio, the Wi-Fi module's needs, and its internet record whenever they change.
local last_wifi
local function watchWifi()
    local NetworkMgr = require("ui/network/manager")
    local Wifi = package.loaded["grandma/wifi"]
    local names = {}
    for name in pairs(Wifi and Wifi.needs or {}) do names[#names + 1] = name end
    table.sort(names)
    local state = string.format("%s needs=%s internet=%s", NetworkMgr:isWifiOn() and "on" or "off",
        Wifi and table.concat(names, ",") or "no-module",
        tostring(G_reader_settings:readSetting("grandma_internet_reached")))
    if state ~= last_wifi then
        last_wifi = state
        say("WIFI", state)
    end
    UIManager:scheduleIn(1, watchWifi)
end

local function waitForRelease()
    while not lfs.attributes(incoming, "mode") do wait(1) end
    say("RELEASE WAITING")
    wait(14) -- Nearly three updater ticks.
end

local actions = {}

function actions.idle() end

function actions.quit(seconds)
    wait(tonumber(seconds))
    say("QUIT")
    UIManager:quit(0)
end

function actions.crash(seconds)
    wait(tonumber(seconds))
    say("CRASH")
    os.exit(3, true)
end

function actions.read()
    local ReaderUI = require("apps/reader/readerui")
    ReaderUI:showReader(os.getenv("XDG_DOCUMENTS_DIR") .. "/Oasis Sample.html")
    wait(3)
    ReaderUI.instance:handleEvent(Event:new("GotoPage", 2))
    wait(1)
    report()
    waitForRelease()
    say("STILL READING", tostring(ReaderUI.instance:getCurrentPage()))
    UIManager.event_handlers.Suspend()
    wait(12)
    say("STILL ASLEEP", tostring(Device.screen_saver_mode))
    UIManager.event_handlers.Resume()
    say("AWAKE")
end

-- Another full-screen feature, such as the book store, in front of the shelf.
function actions.cover()
    local screen = require("ui/widget/container/widgetcontainer"):new{
        name = "review_cover",
        covers_fullscreen = true,
        dimen = Device.screen:getSize(),
    }
    UIManager:show(screen)
    waitForRelease()
    say("STILL COVERED")
    UIManager:close(screen)
end

-- Another feature holding Wi-Fi on the shelf, such as a book download.
function actions.hold()
    local Wifi = require("grandma/wifi")
    Wifi:need("review", 300)
    waitForRelease()
    say("STILL HELD")
    Wifi:release("review")
end

function actions.lowbattery(seconds)
    battery = 9
    actions.quit(seconds)
end

function actions.nowifi(seconds)
    require("ui/network/manager").isConnected = function() return false end
    require("grandma/wifi").connect_timeout = 3
    actions.quit(seconds)
end

UIManager:scheduleIn(0.5, resume, coroutine.create(function()
    watchWifi()
    wait(3)
    report()
    actions[action](argument)
end))
