# Watcher

A directory watcher that executes a given script ( options.executed_file) on change, on start or on error.

## Usage

Watch directories ./ and ./src for change or error and reload main.lua using luajit runtima

```lua
local watch = require("lib.watch")
watch.new({ "./", "./src" }, { runtime = "luajit", executed_file = "main.lua" })
    :on("start", function() print("Starting..") end)
    :on("error", function(err, filename) print("[Error] : " .. filename .. err) end)
    :on("change")
    :run()

```
