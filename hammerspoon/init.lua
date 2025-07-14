hs.hotkey.bind({ "cmd", "alt" }, "V", function()
    hs.eventtap.keyStrokes(hs.pasteboard.getContents())
end)

local common = require("common")

local hyper = { "cmd", "alt", "shift", "ctrl" }

local function deleteWord()
    hs.eventtap.keyStroke({ "alt" }, "delete")
end

common.createAppSpecificHotkey("Alacritty", true, { "ctrl" }, "w", deleteWord, nil, deleteWord)

hs.hotkey.bind({ "ctrl" }, "\\", common.createAppToggle("Alacritty"))

hs.hotkey.bind(hyper, "c", common.createAppToggle("Google Chrome"))
hs.hotkey.bind(hyper, "s", common.createAppToggle("Slack"))

hs.hotkey.bind(hyper, "d", function()
    hs.osascript.applescript([[
        tell application "Finder"
            activate
            make new Finder window
            set target of front window to (path to desktop)
        end tell
    ]])
end)

-- Monitor audio output device changes and notify only when switching to bluetooth headphones
local lastAudioDevice = nil
local audioNotificationTimer = nil
hs.audiodevice.watcher.setCallback(function()
    local currentDevice = hs.audiodevice.defaultOutputDevice()
    if currentDevice and currentDevice:name() ~= lastAudioDevice then
        lastAudioDevice = currentDevice:name()
        if audioNotificationTimer then
            audioNotificationTimer:stop()
        end
        audioNotificationTimer = hs.timer.doAfter(0.5, function()
            if lastAudioDevice == "WH-1000XM6" then
                hs.notify
                    .new({
                        title = "Audio Output Changed",
                        informativeText = "Switched to: " .. lastAudioDevice,
                    })
                    :send()
            end
        end)
    end
end)
hs.audiodevice.watcher.start()

local function resizeWindowTo1080p()
    local win = hs.window.focusedWindow()
    if win then
        local screen = win:screen()
        local screenFrame = screen:frame()

        local targetWidth = 1920
        local targetHeight = 1080

        -- Scale down if window doesn't fit, maintaining 16:9 aspect ratio
        if targetWidth > screenFrame.w or targetHeight > screenFrame.h then
            local scaleX = screenFrame.w / targetWidth
            local scaleY = screenFrame.h / targetHeight
            local scale = math.min(scaleX, scaleY)

            targetWidth = targetWidth * scale
            targetHeight = targetHeight * scale
        end

        -- Calculate center position
        local x = (screenFrame.w - targetWidth) / 2
        local y = (screenFrame.h - targetHeight) / 2

        -- Set frame with calculated position and size
        win:setFrame(hs.geometry.rect(x, y, targetWidth, targetHeight))
    end
end

-- Menu bar item
local menubar = hs.menubar.new()
menubar:setTitle("🤖")
menubar:setMenu({
    { title = "Resize Window to 1080p", fn = resizeWindowTo1080p },
    { title = "-" },
    { title = "Reload Config", fn = hs.reload },
})
