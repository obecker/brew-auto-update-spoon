--- == BrewAutoUpdate ==
---
--- Runs automatically and periodically `brew update` in the background.
--- If any outdated packages are detected, a notification is displayed with a button to run `brew upgrade` in a Terminal.
---
--- Basic usage:
--- ```
--- hs.loadSpoon("BrewAutoUpdate"):start()
--- ```
--- With full configuration:
--- ```
--- hs.loadSpoon("BrewAutoUpdate")
--- spoon.BrewAutoUpdate.brewBinary = "/path/to/your/brew"
--- spoon.BrewAutoUpdate.updateInterval = "1d"
--- spoon.BrewAutoUpdate.alertSeconds = 5
--- spoon.BrewAutoUpdate:start()
--- ```

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "BrewAutoUpdate"
obj.version = "1.0.0"
obj.author = "Oliver Becker <ob@obqo.de>"
obj.homepage = "https://github.com/obecker/brew-auto-update-spoon"
obj.license = "Apache License 2.0"

--- BrewAutoUpdate.brewBinary
--- Variable
--- The full path to the brew binary. Will be auto-detected in `BrewAutoUpdate.init()`.
obj.brewBinary = nil

--- BrewAutoUpdate.updateInterval
--- Variable
--- Interval for running `brew update`. Default is one day. See `repeatInterval` of [hs.timer.doAt](https://www.hammerspoon.org/docs/hs.timer.html#doAt) for allowed values.
obj.updateInterval = "1d"

--- BrewAutoUpdate.alertSeconds
--- Variable
--- Number of seconds the info alert is visible before it closes automatically. Default is 5.
--- The info alert display will be toggled by clicking the contents of the upgrade notification (helpful if there
--- are too many outdated packages, so the notification text gets too long and cannot be displayed completely)
obj.alertSeconds = 5

--- Private variables
local log = hs.logger.new(obj.name, "info")
local brewNotificationImage
local brewUpdateTimer
local notificationFunctionTag = obj.name .. ".notification"
local infoAlertId
local infoAlertCloseTimer
local initialized = false

--- Executes a brew command and returns the output of the command
local function runBrew(cmd)
    local brewCmd = string.format("%s %s", obj.brewBinary, cmd)
    log.d("Run " .. brewCmd)
    local output, status, type, rc = hs.execute(brewCmd)
    log.d("Output " .. output)
    log.d("Status " .. tostring(status))
    log.d("Type " .. tostring(type))
    log.d("rc " .. tostring(rc))
    if not status then
        log.e(string.format("Error when running '%s': %s", brewCmd, output))
        return ""
    end
    return output or ""
end

local function trim(s)
    return s:match "^%s*(.-)%s*$"
end

--- BrewAutoUpdate.init()
--- Method
--- Initializes BrewAutoUpdate. Tries to detect the local brew installation and loads the brew notification image.
function obj:init()
    if initialized then
        return
    end

    local output, status = hs.execute("which brew", true)
    if status then
        obj.brewBinary = trim(output)
        log.i("Detected " .. obj.brewBinary)
    end
    brewNotificationImage = hs.image.imageFromPath(hs.spoons.resourcePath("images/homebrew.png"))
    initialized = true
end

--- BrewAutoUpdate.start()
--- Method
--- Starts a timer that executes `brew update` every `BrewAutoUpdate.updateInterval`.
function obj:start()
    if not obj.brewBinary then
        log.e("Cannot find local brew installation")
        return
    end

    -- handler function that gets called when the notification is clicked
    hs.notify.register(notificationFunctionTag, function(notification)
        if notification:activationType() == hs.notify.activationTypes.contentsClicked then
            if (infoAlertCloseTimer) then
                infoAlertCloseTimer:fire()
            else
                infoAlertId = hs.alert.show(notification:informativeText(), "infinity") -- closed by the timer below
                infoAlertCloseTimer = hs.timer.doAfter(obj.alertSeconds, function()
                    hs.alert.closeSpecific(infoAlertId)
                    infoAlertId = nil
                    infoAlertCloseTimer = nil
                end)
            end
        elseif notification:activationType() == hs.notify.activationTypes.actionButtonClicked then
            if (infoAlertCloseTimer) then
                infoAlertCloseTimer:fire()
            end
            hs.osascript.applescript('tell app "Terminal" to activate do script "brew upgrade"')
        end
    end)

    -- run the function 10 seconds after start and then every `BrewAutoUpdate.updateInterval`
    brewUpdateTimer = hs.timer.doAt(hs.timer.localTime() + 10, obj.updateInterval, function()
        -- check if there is already a notification displayed
        local activeNotification = hs.fnutils.find(hs.notify.deliveredNotifications(), function(n)
            return n:getFunctionTag() == notificationFunctionTag
        end)

        runBrew("update")
        local outdated = runBrew("outdated -v")

        local _, lineCount = outdated:gsub("\n", "\n")
        if lineCount > 0 then
            local updateStr = lineCount == 1 and "update" or "updates"

            -- notification.informativeText will be trimmed anyway, make it explicit so that we can compare the texts
            local trimmedOutdated = trim(outdated)

            if (activeNotification) then
                if (activeNotification:informativeText() == trimmedOutdated) then
                    -- an active notification with the same text is still present -> do nothing
                    log.d("Notification is still present")
                    return
                else
                    -- notification (with a different text) is present -> withdraw and show new
                    activeNotification:withdraw()
                end
            end

            hs.notify.new(notificationFunctionTag, {
                title = "Homebrew",
                subTitle = string.format("%d %s available", lineCount, updateStr),
                informativeText = trimmedOutdated,
                contentImage = brewNotificationImage,
                alwaysPresent = false,
                autoWithdraw = false,
                withdrawAfter = 0,
                actionButtonTitle = "Upgrade",
                hasActionButton = true
            }):send()
        else -- lineCount == 0
            log.i("Homebrew packages are up-to-date")
            if (activeNotification) then
                activeNotification:withdraw()
            end
        end
    end)

    log.d("Started")
end

--- BrewAutoUpdate.stop()
--- Method
--- Stops the timer that was started in `BrewAutoUpdate.start()`.
function obj:stop()
    if brewUpdateTimer then
        brewUpdateTimer:stop()
    end
    brewUpdateTimer = nil
end

return obj
