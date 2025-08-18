--
local inspect = require("inspect")
local uv = require("luv")
print(inspect(uv))
--
local handle, counter, debounce, runtime, directory_target, executed_file = nil, 0, nil, arg[1], arg[2], arg[3]
--
if not directory_target or not executed_file then
    error("\n\x1b[31mUsage : luajit w.lua <runtime> <watch_directory> <executed_file>\x1b[0m")
    return
end

---@param path string
---@param cbs table<"on_change"|"on_error"|"on_start",fun(err? : string , filename : string)>
local function watch(path, cbs)
    local ev = uv.new_fs_event()

    ev:start(path, { watch_entry = false },
        function(err, filename, events)
            if err then
                cbs.on_error(err, filename)
            else
                if events.change then
                    if debounce then uv.timer_stop(debounce) end
                    debounce = uv.new_timer()
                    uv.timer_start(debounce, 50, 0, function()
                        uv.timer_stop(debounce)
                        uv.close(debounce)
                        debounce = nil
                        cbs.on_change(err, filename)
                    end)
                end
            end
        end
    )

    local t = uv.new_timer()
    uv.timer_start(t, 0, 0, function()
        uv.timer_stop(t)
        uv.close(t)
        cbs.on_start(nil, path)
    end)
end
--
local function on_change(err, filename)
    assert(not err, "\x1b[31m[Error] : Unexpected Error\x1b[0m")

    local function kill()
        if handle then
            uv.process_kill(handle, "sigterm")
            uv.close(handle)
            handle = nil
        end
    end

    kill()

    print '\x1b[2J\x1b[H'
    counter = counter + 1
    print("\x1b[90m(x" .. counter .. ")\x1b[0m ")

    handle = uv.spawn(runtime,
        {
            args = { executed_file },
            stdio = { 0, 1, 2 }, -- directly pipe child stds so no wrappers possible

        },
        function(code, signal) -- on exit
            if code == 0 then
                print("Process exited with code 0" .. ", signal", signal)
            end
            kill()
        end
    )
end
--

watch(directory_target, {
    on_start = on_change,
    on_change = on_change,
    on_error = function(err, filename)
        print("[Error] : " .. filename .. err)
    end,
})

uv.run()

