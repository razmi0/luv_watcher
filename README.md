# Watcher

A directory watcher that executes a given script on change.

## Usage

```bash
luajit watch.lua <runtime> <watch_directory> <executed_file>
```

## Arguments

Parameter | Description
-- | --
runtime |The executable to run the file (e.g., luajit).
watch_directory | The directory to monitor for changes.
executed_file | The file to execute on change.

## Example  

Watch the src directory and execute main.lua with luajit on any change.  

```sh  
luajit watch.lua luajit ./src main.lua  
```  

Copy this :

```lua
local watcher, directory = require("watch"), "./src"
watcher.new(directory)
    :on("start")
    :on("error", function(err, filename) print("[Error] : " .. filename .. err) end)
    :on("change")
    :run()
```
