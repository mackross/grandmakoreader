-- Keeps Wi-Fi on only while something needs it. Other code can require it once patches have loaded.
--
--   local Wifi = require("grandma/wifi")
--   Wifi:need("book-store", 120, function(connected) ... end)
--   Wifi:release("book-store")
--
-- A need lasts until it is released or its time runs out. Register it again under the same
-- name to extend it, or under a new name to overlap it. The callback runs once, possibly inside
-- need, with true when the Kindle is connected, or with false and a reason:
--   "off"         Wi-Fi was turned off for a day with setOff
--   "unreachable" no connection within connect_timeout of this need; the need ends
--   "asleep"      the Kindle went to sleep
--   "ended"       the need ended before the connection
-- Wi-Fi turns off a grace period after the last need.
--
-- Settings' Airplane mode is setOff, for off_seconds (a day); offUntil says when it lifts.
--
-- Wifi:report(reached) records whether a request reached the internet, for the settings line;
-- an unreachable connection records false. Wifi:hasProblem() reads it back.
local Device = require("device")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local time = require("ui/time")

local Wifi = {
    connect_timeout = 60,
    off_seconds = 24 * 60 * 60,
    grace = 10,
    poll = 1,
    needs = {},
    waiting = {},
}
package.loaded["grandma/wifi"] = Wifi

-- KOReader's own automatic switching would fight the needs.
G_reader_settings:makeFalse("auto_restore_wifi")
G_reader_settings:makeFalse("auto_disable_wifi")

local function now()
    return time.to_number(time.now())
end

-- Wall-clock time, so the off period survives restarts and sleep.
local function clock()
    return time.to_number(time.realtime())
end

function Wifi:isOff()
    return (G_reader_settings:readSetting("grandma_wifi_off_until") or 0) > clock()
end

-- When Wi-Fi turned off with setOff comes back on, as seconds since the epoch, or nil when it is not off.
function Wifi:offUntil()
    return self:isOff() and G_reader_settings:readSetting("grandma_wifi_off_until") or nil
end

-- Blocks every need, including updates, for off_seconds; false ends it early.
function Wifi:setOff(off)
    G_reader_settings:saveSetting("grandma_wifi_off_until", off and clock() + self.off_seconds or nil)
    self:update()
end

function Wifi:isConnected()
    return NetworkMgr:isWifiOn() and NetworkMgr:isConnected() and true or false
end

function Wifi:need(name, seconds, callback)
    if self:isOff() then
        if callback then UIManager:nextTick(callback, false, "off") end
        return
    end
    self.needs[name] = now() + seconds
    if callback then
        table.insert(self.waiting, { name = name, since = now(), callback = callback })
    end
    self:update()
end

function Wifi:release(name)
    self.needs[name] = nil
    self:update()
end

-- Whether a need other than except is registered.
function Wifi:isNeeded(except)
    local current = now()
    for name, deadline in pairs(self.needs) do
        if name ~= except and deadline > current then return true end
    end
    return false
end

function Wifi:report(reached)
    G_reader_settings:saveSetting("grandma_internet_reached", reached and true or false)
end

function Wifi:hasProblem()
    return G_reader_settings:isFalse("grandma_internet_reached")
end

-- Sleep ends every need and turns the radio off now; KOReader turns it off too.
function Wifi:stop(reason)
    self.needs = {}
    self.turning_on = nil
    self.settling_until = nil
    self.idle_since = nil
    local waiting = self.waiting
    self.waiting = {}
    UIManager:unschedule(self.update)
    if NetworkMgr:isWifiOn() then
        NetworkMgr:disableWifi()
    end
    for _, entry in ipairs(waiting) do
        entry.callback(false, reason)
    end
end

function Wifi:update()
    UIManager:unschedule(self.update)
    local current = now()
    local next_check
    local function checkAt(at)
        next_check = math.min(next_check or at, at)
    end

    local off = self:isOff()
    for name, deadline in pairs(self.needs) do
        if off or deadline <= current then
            self.needs[name] = nil
        else
            checkAt(deadline)
        end
    end

    -- Each waiting need has its own connect timeout, so a long background attempt
    -- does not shorten one that started later.
    local connected = next(self.needs) and self:isConnected()
    local waiting, answers = {}, {}
    for _, entry in ipairs(self.waiting) do
        if not self.needs[entry.name] then
            table.insert(answers, { entry.callback, false, off and "off" or "ended" })
        elseif connected then
            table.insert(answers, { entry.callback, true })
        elseif current - entry.since >= self.connect_timeout then
            self.needs[entry.name] = nil
            self:report(false)
            table.insert(answers, { entry.callback, false, "unreachable" })
        else
            table.insert(waiting, entry)
            checkAt(current + self.poll)
        end
    end
    self.waiting = waiting

    if next(self.needs) then
        self.idle_since = nil
        if connected then
            self.turning_on = nil
        elseif not self.turning_on and not NetworkMgr:isWifiOn() then
            self.turning_on = true
            -- On a Kindle this switches the radio on and lets wifid join a saved network,
            -- without KOReader's blocking scan and network list.
            if Device:hasWifiRestore() then
                NetworkMgr:restoreWifiAsync()
            else
                NetworkMgr:turnOnWifi()
            end
        end
    else
        -- On a Kindle the radio comes up a while after it is asked to, so a radio asked for by needs
        -- that have since ended is watched for, and turned off when it arrives.
        if self.turning_on then
            self.settling_until = current + self.connect_timeout
            self.turning_on = nil
        end
        if NetworkMgr:isWifiOn() then
            self.settling_until = nil
            self.idle_since = self.idle_since or current
            if off or current - self.idle_since >= self.grace then
                self.idle_since = nil
                NetworkMgr:disableWifi()
            else
                checkAt(self.idle_since + self.grace)
            end
        else
            self.idle_since = nil
            if self.settling_until and self.settling_until > current then
                checkAt(current + self.poll)
            else
                self.settling_until = nil
            end
        end
    end

    if next_check then
        UIManager:scheduleIn(math.max(next_check - current, 0), self.update, self)
    end
    for _, call in ipairs(answers) do
        call[1](call[2], call[3])
    end
end

-- Sleep ends every need; KOReader also turns the radio off.
local beforeSuspend = Device._beforeSuspend
function Device:_beforeSuspend(...)
    Wifi:stop("asleep")
    return beforeSuspend(self, ...)
end

-- Take control of Wi-Fi left on by the Kindle before KOReader started.
UIManager:nextTick(Wifi.update, Wifi)
