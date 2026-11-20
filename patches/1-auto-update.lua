-- Keeps this device's patches folder, with its subfolders, identical to the patches folder of a GitHub branch.
-- Inert unless auto-update.lua exists in KOReader's data directory and returns a table; `return {}` turns it on.
-- A public repository needs no token. Add token = "..." for a private one.
local DataStorage = require("datastorage")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local sha2 = require("ffi/sha2")
local userpatch = require("userpatch")

local configured, config = pcall(loadfile(DataStorage:getDataDir() .. "/auto-update.lua"))
if not configured or type(config) ~= "table" then return end

local repo_url = (config.api or "https://api.github.com") .. "/repos/" .. (config.repo or "mackross/grandmakoreader")
local ref = config.ref or "main"
local check_interval = config.interval or 3600
local fetch_seconds = 180 -- to connect and download
local tick_seconds = 5
local trial_seconds = 60

local live = DataStorage:getPatchesDir()
local incoming = live .. ".new" -- a complete, checked release waiting for the next launch
local previous = live .. ".old" -- what ran before the last release
local scratch = live .. ".download"
local trial_marker = live .. ".trial" -- present until a new release has survived trial_seconds
local rejected_marker = live .. ".rejected" -- identity of the release that was rolled back
local reopen_marker = live .. ".reopen" -- the restart interrupted a book

local function read(path)
    local file = io.open(path, "rb")
    if not file then return end
    local content = file:read("*a")
    file:close()
    return content
end

local function write(path, content)
    local file = assert(io.open(path, "wb"))
    assert(file:write(content))
    assert(file:close())
end

-- Dot files stay out of the comparison and the download, so Finder's leftovers do not count as a change.
local function isShipped(path)
    return not ("/" .. path):find("/.", 1, true) and not path:find("\\", 1, true)
end

-- Git's blob hash, so installed files compare directly with GitHub's listing.
local function blobHash(content)
    return sha2.sha1("blob " .. #content .. "\0" .. content)
end

-- Identifies a release from { [path below the patches folder] = blob hash }.
local function identity(hashes)
    local lines = {}
    for name, hash in pairs(hashes) do
        lines[#lines + 1] = name .. " " .. hash
    end
    table.sort(lines)
    return sha2.sha1(table.concat(lines, "\n"))
end

local function installedHashes(directory, prefix, hashes)
    for name in lfs.dir(directory) do
        local path = directory .. "/" .. name
        local mode = lfs.attributes(path, "mode")
        if not isShipped(name) then
            -- This also skips "." and "..".
        elseif mode == "directory" then
            installedHashes(path, prefix .. name .. "/", hashes)
        elseif mode == "file" then
            hashes[prefix .. name] = blobHash(read(path) or "")
        end
    end
    return hashes
end

local function installedIdentity()
    return identity(installedHashes(live, "", {}))
end

-- Makes `replacement` the live patches and leaves the old ones in `aside`.
local function install(replacement, aside)
    ffiutil.purgeDir(aside)
    if not os.rename(live, aside) then return false end
    if os.rename(replacement, live) then return true end
    os.rename(aside, live)
    return false
end

local function rollBack()
    if lfs.attributes(previous, "mode") == "directory" then
        write(rejected_marker, installedIdentity())
        install(previous, scratch)
    end
    os.remove(trial_marker)
end

-- KOReader lists the late patches after this file returns, so a swap here takes effect on this launch.
-- This file is already running by then, so after a swap it runs the release's own copy in its place,
-- with "installed" to say the swap is done. Every later version must keep answering to that word.
-- A release whose updater is missing or fails there goes back, like one whose patch fails to load.
local on_trial = ... == "installed"
if on_trial then
    -- The updater of the previous release made the swap and started the trial.
elseif lfs.attributes(incoming, "mode") == "directory" then
    if install(incoming, previous) then
        write(trial_marker, "")
        logger.info("Auto-update: installed a new release")
        local updater, err = loadfile(live .. "/1-auto-update.lua")
        local took_over = updater ~= nil
        if updater then took_over, err = pcall(updater, "installed") end
        if took_over then return end
        logger.warn("Auto-update: rolling back, the release's updater failed:", err)
        rollBack()
    end
elseif lfs.attributes(trial_marker, "mode") then
    logger.warn("Auto-update: the last release did not survive its first launch, rolling back")
    rollBack()
end

-- KOReader's HTTPS accepts any certificate. Updates are code, so require a trusted one issued for the host.
local function verifiedConnection()
    local create = require("ssl.https").tcp{ verify = "peer", cafile = "data/ca-bundle.crt" }
    return function()
        local connection = create()
        local connect = connection.connect
        function connection:connect(host, port)
            connect(self, host, port)
            local alternative_names = self:getpeercertificate():extensions()["2.5.29.17"] or {}
            for _, name in ipairs(alternative_names.dNSName or {}) do
                if name == host or name == "*" .. host:match("%..*$") then return 1 end
            end
            error("certificate is not for " .. host)
        end
        return connection
    end
end

local reached_internet = false -- any HTTP answer counts, whatever its status

local function get(path, accept)
    local http = require("socket.http")
    local socketutil = require("socketutil")
    local chunks = {}
    socketutil:set_timeout(15, 60)
    local received, code = http.request{
        url = repo_url .. path,
        headers = { Authorization = config.token and "Bearer " .. config.token, Accept = accept },
        sink = socketutil.table_sink(chunks),
        create = repo_url:find("^https:") and verifiedConnection() or nil,
    }
    reached_internet = reached_internet or type(code) == "number"
    assert(received and code == 200, "GET " .. path .. ": " .. tostring(code))
    return table.concat(chunks)
end

-- Runs in a subprocess. Leaves `incoming` behind only when a whole release arrived intact and parses.
-- Returns how the check ended, and a longer description for the log when the two differ.
local function download()
    local hashes = {}
    local listing = get("/git/trees/" .. ref .. ":patches?recursive=1", "application/vnd.github+json")
    listing = require("json").decode(listing)
    assert(not listing.truncated, "the release has too many files to list")
    for _, entry in ipairs(listing.tree) do
        -- Mode 100644 or 100755 is a regular file; folders and links are not downloaded.
        if entry.type == "blob" and entry.mode:find("^100") and isShipped(entry.path) then
            hashes[entry.path] = entry.sha
        end
    end
    local release = identity(hashes)
    local installed = installedHashes(live, "", {})
    if not next(hashes) or release == identity(installed) then return "up to date" end
    if release == read(rejected_marker) then
        return "rolled back", "release was rolled back before, waiting for a new one"
    end

    ffiutil.purgeDir(scratch)
    assert(lfs.mkdir(scratch))
    for path, hash in pairs(hashes) do
        -- Only files that changed are downloaded; the rest are copied from the installed release.
        local content = installed[path] == hash and read(live .. "/" .. path)
            or get("/git/blobs/" .. hash, "application/vnd.github.raw")
        assert(blobHash(content) == hash, path .. " did not arrive intact")
        if path:find("%.lua$") then assert(loadstring(content, path)) end
        local folder = path:match("^(.*)/")
        if folder then require("util").makePath(scratch .. "/" .. folder) end
        write(scratch .. "/" .. path, content)
    end
    assert(os.rename(scratch, incoming))
    return "downloaded", "downloaded a new release"
end

local function start()
    local Device = require("device")
    local UIManager = require("ui/uimanager")

    if on_trial then
        for name, applied in pairs(userpatch.execution_status or {}) do
            if not applied then
                logger.warn("Auto-update: rolling back,", name, "failed to load")
                rollBack()
                return UIManager:nextTick(UIManager.restartKOReader, UIManager)
            end
        end
        UIManager:scheduleIn(trial_seconds, os.remove, trial_marker)
    end
    if os.remove(reopen_marker) then
        -- 2-books-home.lua points this back at the shelf on every launch.
        G_reader_settings:saveSetting("start_with", "last")
    end

    local fetch
    local slept = false
    local last_tick = os.time()
    local next_check = last_tick + math.min(trial_seconds + 30, check_interval)

    -- Tells the Settings screen how the check it asked for is going. Its mistakes must not stop the updater.
    local function tell(check, ...)
        if not check.report then return end
        local told, err = pcall(check.report, ...)
        if not told then logger.warn("Auto-update:", err) end
    end

    -- `ending` is how the check ended when the download did not get to say so itself.
    local function finishFetch(ending, reason)
        local finished = fetch
        fetch = nil
        local answer = finished.result and ffiutil.readAllFromFD(finished.result) or ""
        local reached = answer:find("^reached ") ~= nil
        if finished.wifi then
            finished.wifi:release("auto-update")
            -- The settings screen reads this. Sleep cuts requests short, which says nothing about the internet.
            if finished.result and not finished.interrupted then
                finished.wifi:report(reached)
            end
        elseif finished.turned_wifi_on then
            require("ui/network/manager"):turnOffWifi()
        end
        if not ending then
            ending = answer:match(" (.+)$") or "failed"
            if ending == "failed" and not reached then ending = "no internet" end
        end
        tell(finished, ending, reason)
    end

    -- 2-wifi.lua owns the radio. If it is missing or failed to load, switch Wi-Fi here so a fix can still arrive.
    local function startFetch(now, report)
        local started = { deadline = now + fetch_seconds, wifi = package.loaded["grandma/wifi"], report = report }
        fetch = started
        tell(started, "connecting")
        if started.wifi then
            started.wifi:need("auto-update", fetch_seconds, function(connected, reason)
                if fetch ~= started then return end
                started.connected = connected
                if not connected then
                    logger.info("Auto-update: no Wi-Fi,", reason)
                    finishFetch("no wifi", reason)
                end
            end)
        else
            local NetworkMgr = require("ui/network/manager")
            started.turned_wifi_on = not NetworkMgr:isWifiOn()
            if started.turned_wifi_on then NetworkMgr:restoreWifiAsync() end
        end
    end

    local function connected()
        if fetch.wifi then return fetch.connected end
        local NetworkMgr = require("ui/network/manager")
        return NetworkMgr:isWifiOn() and NetworkMgr:isConnected()
    end

    local function batteryIsLow()
        local percent = Device:hasBattery() and Device:getPowerDevice():getCapacity()
        return percent and percent >= 0 and percent < 10
    end

    local function step(now)
        local asleep = Device.screen_saver_mode
        if asleep or now - last_tick > 6 * tick_seconds then
            slept = true
            if fetch then fetch.interrupted = true end
        end

        if fetch then
            if fetch.pid then
                if ffiutil.isSubProcessDone(fetch.pid) then
                    finishFetch()
                elseif now > fetch.deadline then
                    ffiutil.terminateSubProcess(fetch.pid)
                end
            elseif now > fetch.deadline then
                finishFetch("no wifi", "unreachable")
            elseif connected() then
                local pid, result = ffiutil.runInSubProcess(function(_, write_end)
                    local ok, ending, description = pcall(download)
                    logger.info("Auto-update:", description or ending)
                    local answer = (reached_internet and "reached " or "none ") .. (ok and ending or "failed")
                    ffiutil.writeToFD(write_end, answer, true)
                end, true)
                if pid then
                    fetch.pid, fetch.result = pid, result
                    tell(fetch, "checking")
                end
            end
        elseif asleep then
            return -- nothing starts while the screensaver is up
        elseif lfs.attributes(incoming, "mode") then
            -- Restart at once only from an idle shelf. A book or any other screen waits for the
            -- device to wake, and nothing restarts while something else holds Wi-Fi, such as a download.
            local Wifi = package.loaded["grandma/wifi"]
            local top = UIManager:getTopmostVisibleWidget()
            local on_shelf = top and top.name == "books_home"
            if (slept or on_shelf) and not (Wifi and Wifi:isNeeded("auto-update")) then
                local reader = require("apps/reader/readerui").instance
                if reader then
                    write(reopen_marker, "")
                    reader:onClose()
                end
                UIManager:restartKOReader()
            end
        elseif now >= next_check then
            next_check = now + check_interval
            if batteryIsLow() then
                logger.info("Auto-update: battery below 10%, skipping this check")
            else
                startFetch(now)
            end
        end
        if not asleep then slept = false end
    end

    local function tick()
        local now = os.time()
        local ok, err = pcall(step, now)
        -- Someone is watching a check asked for from Settings, so it moves along every second.
        local delay = fetch and fetch.report and 1 or tick_seconds
        if not ok then
            logger.warn("Auto-update:", err)
            if fetch then
                if fetch.pid then ffiutil.terminateSubProcess(fetch.pid) end
                pcall(finishFetch, "failed")
            end
            delay = check_interval
        end
        last_tick = now + delay - tick_seconds
        UIManager:scheduleIn(delay, tick)
    end
    UIManager:scheduleIn(tick_seconds, tick)

    -- For the Settings screen's button: checks now instead of at the next hour. `report` hears "connecting",
    -- then "checking" once Wi-Fi is up, then how the check ended: "up to date", "downloaded" (the restart
    -- follows by itself), "rolled back", "no internet", "failed", "low battery", or "no wifi" with the
    -- Wi-Fi module's reason.
    package.loaded["grandma/update"] = {
        check = function(_, report)
            local now = os.time()
            if fetch then
                fetch.report = report
                tell(fetch, fetch.pid and "checking" or "connecting")
            elseif lfs.attributes(incoming, "mode") then
                report("downloaded")
            elseif batteryIsLow() then
                report("low battery")
            else
                next_check = now + check_interval
                startFetch(now, report)
            end
            UIManager:unschedule(tick)
            tick()
        end,
    }
end

local applyPatches = userpatch.applyPatches
function userpatch.applyPatches(priority)
    applyPatches(priority)
    if priority == userpatch.late then
        local started, err = pcall(start)
        if not started then
            logger.warn("Auto-update:", err)
            if on_trial then
                -- Without its updater a release could never be replaced, so it does not stay.
                local UIManager = require("ui/uimanager")
                rollBack()
                UIManager:nextTick(UIManager.restartKOReader, UIManager)
            end
        end
    elseif priority == userpatch.before_exit then
        os.remove(trial_marker) -- an orderly exit is not a crash
    end
end
