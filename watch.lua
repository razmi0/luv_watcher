#!/usr/bin/env luajit
--
local uv, inspect = require("luv"), require("inspect")
local runtime, directory, executed_file = arg[1], arg[2], arg[3]
if not directory or not executed_file then
    error("\n\x1b[31mUsage : luajit w.lua <runtime> <watch_directory> <executed_file>\x1b[0m")
    return
end

local Watch = {}
Watch.__index = Watch
function Watch.new(path)
    return setmetatable({
        events = {},
        path = path or "./",
        handle = nil,
        counter = 0
    }, Watch)
end

function Watch:on(event, cb)
    if not event then return end
    self.events[event] = function(err, filename)
        if cb then cb() end
        self:_spawn(err, filename)
    end
    return self
end

function Watch:_spawn(err, filename)
    assert(not err, "\x1b[31mUnexpected Error\x1b[0m \n" .. inspect(self))

    local function kill()
        if self.handle then
            uv.process_kill(self.handle, "sigterm")
            uv.close(self.handle)
            self.handle = nil
        end
    end
    local function log(str) print("\x1b[90m" .. str .. "\x1b[0m") end
    local function clear() log '\x1b[2J\x1b[H' end

    kill()
    clear()

    self.counter = self.counter + 1
    log(
        "(x" .. self.counter .. ") " ..
        os.date("%d/%m %H:%M")
    )

    self.handle = uv.spawn(runtime,
        {
            args = { executed_file },
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
    local ev = uv.new_fs_event()
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

    uv.timer_start(timer_start, 0, 0, function()
        uv.timer_stop(timer_start)
        uv.close(timer_start)
        on_start(nil, self.path)
    end)

    ev:start(self.path, { watch_entry = false },
        function(err, filename, events)
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

    uv.run()
end

--
Watch.new(directory)
    :on("start", function() print("Starting..") end)
    :on("error", function(err, filename) print("[Error] : " .. filename .. err) end)
    :on("change")
    :run()
