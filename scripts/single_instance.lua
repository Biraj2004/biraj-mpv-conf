--[[
    single_instance.lua - Conditional Single Instance & Multi-Select Playlist Forwarder for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)
    
    Behavior Logic:
    1. Standard "Open" / Double-Click: Runs in normal independent multi-window mode.
    2. "Play with MPV as a Playlist": Passes `--script-opts-append=single_instance-enabled=yes`.
       - First file becomes Master Instance with IPC named pipe (\\\\.\\pipe\\mpvsocket_playlist).
       - Subsequent multi-selected files forward their path to the master window via `loadfile append-play`
         and exit immediately.
       - Master window collects all files into a single unified ascending playlist via `sort_playlist.lua`.
--]]

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'
local options = require 'mp.options'

local opts = {
    enabled = false, -- Default false: only activated when explicitly requested via --script-opts-append=single_instance-enabled=yes
}

options.read_options(opts, "single_instance")

-- If not launched as "Play with MPV as a Playlist", allow normal separate window playback
if not opts.enabled then
    return
end

local is_windows = package.config:sub(1,1) == "\\"
local ipc_socket_path = is_windows and "\\\\.\\pipe\\mpvsocket_playlist" or ((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/mpvsocket_playlist")

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
        msg.error("Could not connect to playlist pipe: " .. path)
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
end

local is_main_instance = false
if try_connect_pipe(ipc_socket_path) then
    is_main_instance = false
else
    create_ipc_server(ipc_socket_path)
    is_main_instance = true
end

mp.register_event("start-file", function()
    local filepath = mp.get_property("path") or ""
    if filepath == "" then return end

    if not is_main_instance then
        -- Forward file to the master playlist window and terminate duplicate process immediately
        if send_file_to_main(ipc_socket_path, filepath) then
            mp.commandv("quit")
        else
            -- If pipe communication failed, promote to main instance
            create_ipc_server(ipc_socket_path)
            is_main_instance = true
        end
    end
end)
