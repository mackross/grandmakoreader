-- Writes the report behind Settings, Advanced, Report a problem: a mailto link whose message holds the
-- last crash and the latest warnings from KOReader's log. The home screen shows it as a QR code, so the
-- phone that reads it sends the email and the Kindle needs no Wi-Fi.
-- KOReader runs only the numbered files in this folder. Patches load this one with dofile.
local DataStorage = require("datastorage")
local Version = require("version")

local Report = {
    address = "andrew@mackross.net",
    -- A link this long makes a QR code whose squares stay large enough to read off the screen.
    -- KOReader's encoder never answers when given more than 2953 bytes.
    max_bytes = 1500,
}

local log_bytes = 100 * 1024 -- how much of the end of the log is read
local line_bytes = 120
local crash_lines = 10 -- the error, then the frames nearest to it

-- RFC 6068 lets few characters stand for themselves in a mailto link.
local function encode(text)
    return (text:gsub("[^%w%-%._~:,]", function(character)
        return string.format("%%%02X", character:byte())
    end))
end

local function link(lines)
    return "mailto:" .. Report.address .. "?subject=" .. encode("Kindle report")
        .. "&body=" .. encode(table.concat(lines, "\r\n"))
end

-- A log line as the report carries it. A character outside ASCII would cost the link up to twelve bytes.
local function tidy(line)
    return (line:gsub("^%s+", "  "):gsub("[^\32-\126]", "?"):sub(1, line_bytes))
end

-- The lines at the end of KOReader's log, or nil without one. On the Kindle the launcher sends
-- everything KOReader prints to crash.log.
local function logLines()
    local file = io.open(DataStorage:getDataDir() .. "/crash.log", "rb")
    if not file then return end
    file:seek("set", math.max(0, file:seek("end") - log_bytes))
    local lines = {}
    for line in file:read("*a"):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    file:close()
    return lines
end

-- Where the last uncaught error and its traceback start and end, and the time on the log line before it.
local function lastCrash(lines)
    local first, time, latest_time
    for index, line in ipairs(lines) do
        latest_time = line:match("^(%d%d/%d%d/%d%d%-%d%d:%d%d:%d%d) ") or latest_time
        if line:find("^%S*luajit: ") then first, time = index, latest_time end
    end
    if not first then return end
    local last = first
    while lines[last + 1] and (lines[last + 1] == "stack traceback:" or lines[last + 1]:find("^\t")) do
        last = last + 1
    end
    return first, math.min(last, first + crash_lines - 1), time
end

local function isNews(line)
    return line:find("^%S+ WARN ") or line:find("^%S+ ERROR ") or line:find("Auto-update:", 1, true)
end

-- The mailto link, at most Report.max_bytes long. The crash comes first because it matters most; the
-- latest warnings and update checks fill the room that is left.
function Report.url()
    local body = { "Kindle report, " .. os.date("%d %b %Y %H:%M"), "KOReader " .. Version:getCurrentRevision() }
    -- Puts a line at this place in the message, unless that makes the link too long.
    local function add(line, place)
        place = place or #body + 1
        table.insert(body, place, line)
        if #link(body) <= Report.max_bytes then return true end
        table.remove(body, place)
        return false
    end

    local read, lines = pcall(logLines)
    if not read or not lines then
        add("The log could not be read.")
        return link(body)
    end
    local first, last, time = lastCrash(lines)
    if first then
        add("Last crash" .. (time and ", after " .. time or "") .. ":")
        for index = first, last do
            if not add(tidy(lines[index])) then break end
        end
    else
        add("No crash in the log.")
    end

    -- From the newest back, each above the one before it, so they read in the order they happened.
    local heading = #body + 1
    if add("Latest warnings and update checks:") then
        for index = #lines, 1, -1 do
            if isNews(lines[index]) and not add(tidy(lines[index]), heading + 1) then break end
        end
        if not body[heading + 1] then table.remove(body, heading) end
    end
    return link(body)
end

return Report
