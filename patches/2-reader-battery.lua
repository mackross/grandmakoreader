local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local ReaderDeviceStatus = require("apps/reader/modules/readerdevicestatus")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")

local Screen = Device.screen
local preview_battery = Device:isSDL() and tonumber(os.getenv("KO_DEV_BATTERY_PERCENT"))
local device_name = os.getenv("KO_DEV_DEVICE_NAME") or (Device:isKindle() and "Kindle" or "device")
local init = ReaderFooter.init
local onReaderReady = ReaderFooter.onReaderReady

local function lowBatteryPercent()
    local percent = preview_battery
    if not percent and Device:hasBattery() then
        percent = Device:getPowerDevice():getCapacity()
    end
    if percent and percent >= 0 and percent < 10 then
        return math.floor(percent)
    end
end

function ReaderFooter:init()
    init(self)
    self.reclaim_height = false
    self.settings.reclaim_height = false
    self.battery_percent = lowBatteryPercent()
    self.view.footer_visible = self.battery_percent ~= nil
end

function ReaderFooter:getHeight()
    return self.battery_percent and Screen:scaleBySize(96) or 0
end

-- Retain KOReader's reading position calculations without exposing its status display.
function ReaderFooter:setupTouchZones() end
function ReaderFooter:onUpdateFooter() end
function ReaderFooter:rescheduleFooterAutoRefreshIfNeeded() end
function ReaderDeviceStatus:startBatteryChecker() end

function ReaderFooter:paintTo(bb, x, y)
    local height = self:getHeight()
    if height == 0 then return end

    local width = Screen:getWidth()
    local percent = self.battery_percent
    if percent ~= self.battery_label_percent or width ~= self.battery_label_width then
        if self.battery_label then self.battery_label:free() end
        self.battery_label_width = width
        self.battery_label_percent = percent
        self.battery_label = CenterContainer:new{
            dimen = Geom:new{ w = width, h = height },
            TextBoxWidget:new{
                text = string.format("This %s needs to be charged. %d%% battery remaining.", device_name, percent),
                face = Font:getFace("smalltfont", 28),
                width = width - 2 * Size.padding.large,
                alignment = "center",
            },
        }
    end
    y = y + Screen:getHeight() - height
    bb:paintRect(x, y, width, height, Blitbuffer.COLOR_WHITE)
    bb:paintRect(x, y, width, Size.line.medium, Blitbuffer.COLOR_BLACK)
    self.battery_label:paintTo(bb, x, y)
end

function ReaderFooter:updateBatteryWarning()
    local percent = lowBatteryPercent()
    if percent == self.battery_percent then return end
    local was_visible = self.battery_percent ~= nil
    self.battery_percent = percent
    self.view.footer_visible = percent ~= nil
    if was_visible ~= self.view.footer_visible then
        if self.ui.rolling then
            self.ui:handleEvent(Event:new("SetPageBottomMargin", self.ui.document.configurable.b_page_margin))
        else
            self.ui:handleEvent(Event:new("SetDimensions", Screen:getSize()))
            self.ui:handleEvent(Event:new("InitScrollPageStates"))
        end
        self.ui:handleEvent(Event:new("BatteryBannerChanged"))
    end
    UIManager:setDirty(self.ui.dialog, "ui")
end

function ReaderFooter:pollBattery()
    self:updateBatteryWarning()
    UIManager:scheduleIn(60, self.pollBattery, self)
end

function ReaderFooter:onReaderReady()
    onReaderReady(self)
    UIManager:scheduleIn(60, self.pollBattery, self)
end

function ReaderFooter:onSuspend()
    UIManager:unschedule(self.pollBattery)
end

function ReaderFooter:onCloseDocument()
    self:onSuspend()
    if self.battery_label then self.battery_label:free() end
end

function ReaderFooter:onResume()
    self:onSuspend()
    self:pollBattery()
end

ReaderFooter.onCharging = ReaderFooter.updateBatteryWarning
ReaderFooter.onNotCharging = ReaderFooter.updateBatteryWarning
