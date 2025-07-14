hs.hotkey.bind({ "cmd", "ctrl" }, "r", function()
    hs.notify.new({ title = "Hammerspoon", informativeText = "Config loaded" }):send()
    hs.reload()
end)

hs.hotkey.bind({ "cmd", "alt" }, "V", function()
    hs.eventtap.keyStrokes(hs.pasteboard.getContents())
end)

local common = require("common")

local function deleteWord()
    hs.eventtap.keyStroke({ "alt" }, "delete")
end

common.createAppSpecificHotkey("Alacritty", true, { "ctrl" }, "w", deleteWord, nil, deleteWord)

hs.hotkey.bind({ "ctrl" }, "\\", common.createAppToggle("Alacritty"))
