#!/usr/bin/env luajit
--

local uv, inspect = require("luv"), require("inspect")

---@class WatcherConfig
---@field paths string[]|nil A list of directories to monitor for events such as change. Default to working directory.
---@field exec string The command to execute when a change is detected <runtime> <executed_file>.
---@field recursive boolean|nil Whether to monitor subdirectories recursively.
---@field ignore string[]|nil A list of files that can be ignored.

local function log_error(field)
    error(field .. " not provided. Provide " .. field .. " = '<runtime> <executed_file>'")
end

local Watch = {}
Watch.__index = Watch

---@param config WatcherConfig
function Watch.new(config)
    if not config.exec then log_error("config.exec") end
    local runtime, executed_file = config.exec:match("([^%s]+)%s+([^%s]+)")
    if not runtime or not executed_file then log_error("config.exec") end
    return setmetatable({
        events = {},
        paths = config.paths or { "./" },
        handle = nil,
        counter = 0,
        recursive = config and config.recursive or false,
        runtime = runtime,
        executed_file = executed_file,
        ignore_file_list = config and config.ignore or {}
    }, Watch)
end

---@param event "change"|"error"|"start"
---@param cb function|nil
---@return self
function Watch:on(event, cb)
    if not event then return self end
    self.events[event] = function(err, filename)
        if cb then cb() end
        self:_spawn(err, filename)
    end
    return self
end

local function log(str) print("\x1b[90m" .. str .. "\x1b[0m") end
local function clear() log '\x1b[2J\x1b[H' end
function Watch:_spawn(err, filename)
    assert(not err, "\x1b[31mUnexpected Error\x1b[0m \n" .. inspect(self))

    local function kill()
        if self.handle then
            uv.process_kill(self.handle, "sigterm")
            uv.close(self.handle)
            self.handle = nil
        end
    end

    kill()
    clear()

    self.counter = self.counter + 1
    log(
        "(x" .. self.counter .. ") " ..
        os.date("%d/%m %H:%M")
    )

    self.handle = uv.spawn(self.runtime,
        {
            args = { self.executed_file },
            stdio = { 0, 1, 2 }, -- directly pipe child stds so no wrappers possible

        },
        function(code, signal) -- on exit
            if code == 0 then
                log("Process exited code " .. code)
            end
            kill()
        end
    )
end

function Watch:run()
    local timer_debouncer, timer_start = nil, uv.new_timer()
    local on_err = self.events["error"]
    local on_change = self.events["change"]
    local on_start = self.events["start"]

    local function debouncer(cb, delay)
        if timer_debouncer then uv.timer_stop(timer_debouncer) end
        timer_debouncer = uv.new_timer()
        uv.timer_start(timer_debouncer, delay, 0, function()
            uv.timer_stop(timer_debouncer)
            uv.close(timer_debouncer)
            timer_debouncer = nil
            cb()
        end)
    end

    -- stopping gracefully
    local signal = uv.new_signal()
    uv.signal_start(signal, "sigint", function(signame)
        clear()
        os.exit(1)
    end)



    -- watcher
    for i = 1, #self.paths, 1 do
        local ev = uv.new_fs_event()

        -- at start
        uv.timer_start(timer_start, 0, 0, function()
            uv.timer_stop(timer_start)
            uv.close(timer_start)
            on_start(nil, self.paths[i])
        end)

        ev:start(self.paths[i], { recursive = self.recursive },
            function(err, filename, events)
                for _, ignore_file in ipairs(self.ignore_file_list) do
                    if filename == ignore_file then
                        return
                    end
                end
                if err and on_err then
                    on_err(err, filename)
                    return
                end

                if events.change and on_change then
                    debouncer(function()
                        on_change(err, filename)
                    end, 50)
                end
            end
        )
    end

    uv.run()
end

return Watch
