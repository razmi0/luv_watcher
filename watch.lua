--
local uv, inspect = require("luv"), require("inspect")

local Watch = {}
Watch.__index = Watch
function Watch.new(paths, options)
    return setmetatable({
        events = {},
        paths = paths or { "./" },
        handle = nil,
        counter = 0,
        recursive = options and options.recursive or false,
        runtime = options and options.runtime or "luajit",
        executed_file = options and options.executed_file or "main.lua"
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

--

return Watch
