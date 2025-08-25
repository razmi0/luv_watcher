# Watcher

A directory watcher that reload a given script on change, on start or on error.

## Usage

Here we watch directories ./ and ./src for change or error and reload main.lua using luajit runtime.

```lua
local watch = require("lib.watch")

---@type WatcherConfig
local config = {
    paths = { "./", "./src" },
    exec = "luajit main.lua",
}

watch.new(config)
    :on("start")
    :on("error")
    :on("change")
    :run()

```

The WatcherConfig type is :

```lua

---@class WatcherConfig
---@field paths string[]|nil A list of directories to monitor for events such as change. Default to working directory.
---@field exec string The command to execute when a change is detected <runtime> <executed_file>.
---@field recursive boolean|nil Whether to monitor subdirectories recursively.
---@field ignore string[]|nil A list of files that can be ignored.

```
