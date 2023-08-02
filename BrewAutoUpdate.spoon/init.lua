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

local log = hs.logger.new(obj.name, "info")
local brewNotificationImage
local brewUpdateTimer

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

--- BrewAutoUpdate.init()
--- Method
--- Initializes BrewAutoUpdate. Tries to detect the local brew installation and loads the brew notification image.
function obj:init()
    local output, status = hs.execute("which brew", true)
    if status then
        obj.brewBinary = string.gsub(output, "\n", "")
        log.i("Detected " .. obj.brewBinary)
    end
    brewNotificationImage = hs.image.imageFromPath(hs.spoons.resourcePath("images/homebrew.png"))
end

--- BrewAutoUpdate.start()
--- Method
--- Starts a timer that executes `brew update` every `BrewAutoUpdate.updateInterval`.
function obj:start()
    if not obj.brewBinary then
        log.e("Cannot find local brew installation")
        return
    end

    -- run the function 10 seconds after start and then every `BrewAutoUpdate.updateInterval`
    brewUpdateTimer = hs.timer.doAt(hs.timer.localTime() + 10, obj.updateInterval, function()
        runBrew("update")
        local outdated = runBrew("outdated -v")

        local _, lineCount = string.gsub(outdated, "\n", "\n")
        if lineCount > 0 then
            local function handler(notification)
                if notification:activationType() == hs.notify.activationTypes.actionButtonClicked then
                    hs.osascript.applescript('tell app "Terminal" to activate do script "brew upgrade"')
                end
            end
            local updateStr = lineCount == 1 and "update" or "updates"
            hs.notify.new(handler, {
                title = "Homebrew",
                subTitle = string.format("%d %s available", lineCount, updateStr),
                informativeText = outdated,
                contentImage = brewNotificationImage,
                alwaysPresent = false,
                autoWithdraw = false,
                withdrawAfter = 0,
                actionButtonTitle = "Upgrade",
                hasActionButton = true
            }):send()
        else
            log.i("Homebrew packages are up-to-date")
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
