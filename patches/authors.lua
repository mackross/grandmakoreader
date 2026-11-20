-- Who wrote each book, as the book file itself says.
-- KOReader runs only the numbered files in this folder. Patches load this one with dofile.
--
-- KOReader's cover browser plugin reads a book's details in a background process and keeps them in
-- its own database. This borrows that, so each book is read once and the screen never waits for it.
local ffiUtil = require("ffi/util")
local logger = require("logger")

local Authors = {}

-- The cover browser's module lives on the plugin's own path. Once loaded, the plugin shares it.
local manager
do
    local path = package.path
    package.path = "plugins/coverbrowser.koplugin/?.lua;" .. path
    local ok, result = pcall(require, "bookinfomanager")
    package.path = path
    if ok then
        manager = result
    else
        logger.warn("Authors are unavailable without the cover browser plugin:", result)
    end
end

-- The cover browser announces a newly created database with a notice. Create it without one.
if manager and not manager.db_created then
    local UIManager = require("ui/uimanager")
    local show = UIManager.show
    UIManager.show = function() end
    local ok, message = pcall(manager.createDB, manager)
    UIManager.show = show
    if not ok then
        logger.warn("Authors are unavailable without the book details database:", message)
        manager = nil
    end
end

--- The authors of a book, such as "Jane Austen", or nil while the book is unread or names none.
function Authors.of(path)
    local details = manager and manager:getDocProps(path)
    local authors = details and details.authors
    if authors and authors ~= "" then
        -- KOReader keeps several authors on separate lines, and a name without a middle name
        -- can come with a doubled space.
        return (authors:gsub("\n", ", "):gsub("%s+", " "))
    end
end

-- Whether an earlier batch is still being read. The cover browser only notices a finished batch
-- every ten seconds, so ask about each of its processes directly.
local function reading()
    for _, pid in ipairs(manager.subprocesses_pids) do
        if not ffiUtil.isSubProcessDone(pid) then return true end
    end
    return false
end

--- Starts reading, in the background, those of the given books that have not been read yet.
-- While an earlier batch is still being read this does nothing, so call it again later for the rest.
-- Starting a new batch would stop the earlier one, and a book stopped three times is given up on.
function Authors.read(paths)
    if not manager or reading() then return end
    local unread = {}
    for _, path in ipairs(paths) do
        if not manager:getDocProps(path) then
            unread[#unread + 1] = { filepath = path }
        end
    end
    if manager:extractInBackground(unread) then
        -- Have the temporary cache removed once the batch ends.
        manager:cleanUp()
    end
end

return Authors
