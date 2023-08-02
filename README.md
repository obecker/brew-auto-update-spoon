# BrewAutoUpdate.spoon
[Hammerspoon](https://www.hammerspoon.org) plugin (a.k.a. [Spoon](https://www.hammerspoon.org/go/#spoonsintro)) 
for running `brew update` automatically.

The plugin executes `brew update` at startup and then repeatedly every day (or some other defined interval).
If there are outdated packages (determined by executing `brew outdated`) it will display a notification with a button
to run `brew upgrade` in a Terminal.

![Example notification](images/notification.png)

## Installation

_Prerequisite_: you have [Hammerspoon](https://www.hammerspoon.org) installed.

Download [BrewAutoUpdate.spoon.zip](https://github.com/obecker/brew-auto-update-spoon/releases/download/v1.0.0/BrewAutoUpdate.spoon.zip) and double-click the extracted `BrewAutoUpdate.spoon` folder. 
Hammerspoon should automatically move it into your `$HOME/.hammerspoon/Spoons/` folder.

Add these lines to your `$HOME/.hammerspoon/init.lua` file:
```lua
hs.loadSpoon("BrewAutoUpdate"):start()
```

The plugin will auto-detect your `brew` binary and uses by default an update interval of 24 hours.
You may overwrite these settings with
```lua
hs.loadSpoon("BrewAutoUpdate")
spoon.BrewAutoUpdate.brewBinary = "/path/to/your/brew"
spoon.BrewAutoUpdate.updateInterval = "6h" -- run every 6 hours
spoon.BrewAutoUpdate:start()
```
