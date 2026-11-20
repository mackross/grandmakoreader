local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local DevCheck = WidgetContainer:extend{
    name = "devcheck",
}

function DevCheck:init()
    self.ui.menu:registerToMainMenu(self)
    if os.getenv("KO_DEV_SMOKE") then
        UIManager:nextTick(function()
            local items = {}
            self:addToMainMenu(items)
            items.plugin_check.callback()
        end)
    end
end

function DevCheck:addToMainMenu(items)
    items.plugin_check = {
        text = "Plugin check",
        sorting_hint = "tools",
        callback = function() self:showCheck() end,
    }
end

function DevCheck:showCheck()
    local screen = Device.screen
    local width, height, dpi = screen:getWidth(), screen:getHeight(), screen:getDPI()
    UIManager:show(InfoMessage:new{
        text = string.format("Plugin loaded and running.\n%d × %d at %d DPI", width, height, dpi),
    })

    local capture = os.getenv("KO_DEV_CAPTURE")
    if capture then
        -- Let KOReader paint the dialog before reading the framebuffer.
        UIManager:scheduleIn(0.2, function()
            local temporary = capture .. ".tmp.png"
            os.remove(temporary)
            local result, err = screen:shot(temporary)
            local ok = result ~= false and (lfs.attributes(temporary, "size") or 0) > 24
            if ok then ok, err = os.rename(temporary, capture) end
            if ok then
                logger.info("Plugin check screenshot:", capture)
            else
                logger.err("Plugin check screenshot failed:", err or temporary)
            end
            if os.getenv("KO_DEV_SMOKE") then
                local expected_width = tonumber(os.getenv("EMULATE_READER_W"))
                local expected_height = tonumber(os.getenv("EMULATE_READER_H"))
                if ok and width == expected_width and height == expected_height and dpi == 300 then
                    logger.info("Plugin check passed")
                    UIManager:quit(0)
                else
                    logger.err("Plugin check failed; framebuffer:", width, height, dpi)
                    UIManager:quit(1)
                end
            end
        end)
    end
end

return DevCheck
