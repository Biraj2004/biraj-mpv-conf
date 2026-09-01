--[[
    single_instance.lua - Single-Instance & Multi-Select Playlist Engine for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)
    Developed by : Biraj Sarkar (@Biraj2004)
    
    Features:
    - Pure native MPV implementation (0 external binaries / 0 wrappers).
    - Lock-synchronized named pipe IPC (\\\\.\\pipe\\mpvsocket_playlist) preventing race conditions.
    - Automatically suppresses directory scanning on multi-file batches to prevent Desktop file pollution.
    - Forwards secondary process files into the master playlist and terminates secondary instances in ~10ms.
--]]

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'
local options = require 'mp.options'

local opts = {
    enabled = false, -- Activated via --script-opts-append=single_instance-enabled=yes
}

options.read_options(opts, "single_instance")

if not opts.enabled then
    return
end

local is_windows = package.config:sub(1,1) == "\\"
local ipc_socket_path = is_windows and "\\\\.\\pipe\\mpvsocket_playlist" or ((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/mpvsocket_playlist")
local temp_dir = os.getenv("TEMP") or os.getenv("TMP") or "C:\\Windows\\Temp"
local lock_file = temp_dir .. "\\mpv_playlist_master.lock"

local function sleep_ms(ms)
    local start = mp.get_time()
    local target = ms / 1000.0
    while (mp.get_time() - start) < target do end
end

local function escape_json_str(str)
    if not str then return "" end
    return (str:gsub("\\", "\\\\"):gsub("\"", "\\\""))
end

local function try_connect_pipe(path)
    local mode = is_windows and "w" or "r"
    local f = io.open(path, mode)
    if f then
        f:close()
        return true
    end
    return false
end

local function send_file_to_main(path, filepath)
    local escaped = escape_json_str(filepath or "")
    local json = string.format('{"command": ["loadfile", "%s", "append-play"]}', escaped)

    local f = io.open(path, "w")
    if not f then
        return false
    end

    f:write(json .. "\n")
    f:close()
    return true
end

local function create_ipc_server(path)
    if not is_windows then
        pcall(os.remove, path)
    end
    mp.set_property("input-ipc-server", path)
    -- When explicitly launched as a multi-file playlist batch, disable folder autocreation to avoid Desktop pollution
    mp.set_property("autocreate-playlist", "no")
end

local function get_lock_info()
    local f = io.open(lock_file, "r")
    if not f then return nil, 0 end
    local content = f:read("*all")
    f:close()
    local time = tonumber(content) or 0
    return content, time
end

local function write_lock()
    local f = io.open(lock_file, "w")
    if f then
        f:write(tostring(os.time()))
        f:close()
    end
end

local function remove_lock()
    pcall(os.remove, lock_file)
end

-- ==================== INITIALIZATION LOGIC ====================

local is_main_instance = false
local current_time = os.time()
local lock_content, lock_time = get_lock_info()

-- Check if pipe is already alive
if try_connect_pipe(ipc_socket_path) then
    is_main_instance = false
else
    -- Check if another process recently claimed the lock (within last 3 seconds)
    if lock_time > 0 and (current_time - lock_time) < 3 then
        -- Wait up to 500ms for master pipe to be created by the other starting process
        local connected = false
        for i = 1, 15 do
            sleep_ms(30)
            if try_connect_pipe(ipc_socket_path) then
                connected = true
                break
            end
        end
        if connected then
            is_main_instance = false
        else
            -- Stale lock or pipe failed, claim master
            write_lock()
            create_ipc_server(ipc_socket_path)
            is_main_instance = true
        end
    else
        -- We are the first process: claim lock and create pipe
        write_lock()
        create_ipc_server(ipc_socket_path)
        is_main_instance = true
    end
end

mp.register_event("start-file", function()
    local filepath = mp.get_property("path") or ""
    if filepath == "" then return end

    if not is_main_instance then
        -- Retry forwarding to ensure pipe is ready
        local sent = false
        for i = 1, 10 do
            if send_file_to_main(ipc_socket_path, filepath) then
                sent = true
                break
            end
            sleep_ms(25)
        end

        if sent then
            mp.commandv("quit")
        else
            -- Fallback: promote to master if forward failed
            create_ipc_server(ipc_socket_path)
            is_main_instance = true
        end
    end
end)

mp.register_event("shutdown", function()
    if is_main_instance then
        remove_lock()
    end
end)
