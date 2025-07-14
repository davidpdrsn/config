hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

hs.hotkey.bind({ "cmd", "alt" }, "V", function()
    hs.eventtap.keyStrokes(hs.pasteboard.getContents())
end)

local function deleteWord()
    hs.eventtap.keyStroke({ "alt" }, "delete")
end

local ctrlWHotkey = nil

local function enableCtrlW()
    if ctrlWHotkey then
        return
    end
    ctrlWHotkey = hs.hotkey.bind({ "ctrl" }, "w", deleteWord, nil, deleteWord)
end

local function disableCtrlW()
    if ctrlWHotkey then
        ctrlWHotkey:delete()
        ctrlWHotkey = nil
    end
end

local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if appName == "Alacritty" then
        if eventType == hs.application.watcher.activated then
            disableCtrlW()
        elseif eventType == hs.application.watcher.deactivated then
            enableCtrlW()
        end
    end
end)
appWatcher:start()
