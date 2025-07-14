local function createAppSpecificHotkey(
    appName,
    shouldDisableInApp,
    mods,
    key,
    pressFn,
    releaseFn,
    repeatFn
)
    local hotkey = nil

    local function enableHotkey()
        if hotkey then
            return
        end
        hotkey = hs.hotkey.bind(mods, key, pressFn, releaseFn, repeatFn)
    end

    local function disableHotkey()
        if hotkey then
            hotkey:delete()
            hotkey = nil
        end
    end

    local appWatcher = hs.application.watcher.new(function(name, eventType, appObject)
        if name == appName then
            if eventType == hs.application.watcher.activated then
                if shouldDisableInApp then
                    disableHotkey()
                else
                    enableHotkey()
                end
            elseif eventType == hs.application.watcher.deactivated then
                if shouldDisableInApp then
                    enableHotkey()
                else
                    disableHotkey()
                end
            end
        end
    end)
    appWatcher:start()

    -- Initialize based on current frontmost app
    if hs.application.frontmostApplication():name() == appName then
        if not shouldDisableInApp then
            enableHotkey()
        end
    else
        if shouldDisableInApp then
            enableHotkey()
        end
    end
end

-- Global app tracking
local previousApp = nil

-- Track application switches globally
local currentApp = nil
local globalAppWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
        -- Store the current app as previous before updating
        if currentApp and currentApp:name() ~= appName then
            previousApp = currentApp
        end
        currentApp = appObject
    end
end)

-- Start the watcher immediately
globalAppWatcher:start()

-- Initialize current app
currentApp = hs.application.frontmostApplication()

local function createAppToggle(appName)
    return function()
        local currentApp = hs.application.frontmostApplication()
        
        if currentApp:name() == appName then
            -- Switch back to previous app
            if previousApp and previousApp:isRunning() then
                previousApp:activate()
            end
        else
            -- Switch to target app
            local targetApp = hs.application.find(appName)
            if targetApp then
                targetApp:activate()
            else
                hs.application.launchOrFocus(appName)
            end
        end
    end
end

local M = {}

M.createAppSpecificHotkey = createAppSpecificHotkey
M.createAppToggle = createAppToggle

return M
