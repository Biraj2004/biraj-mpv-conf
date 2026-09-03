--[[
    auto_exit_eof.lua - Graceful Auto-Exit at End of Media for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)
    Developed by : Biraj Sarkar (@Biraj2004)

    Features:
    - Waits for a configurable grace period (default: 5.0s) after a video/playlist finishes.
    - Gives user time to seek backwards (e.g., Left Arrow) or unpause to keep mpv open.
    - Displays a native top-left OSD warning ("Exiting...") during the final moments (default: last 2.0s).
    - Intelligently handles edge cases:
        * Multi-file playlists (only exits on the final file).
        * Looping modes (loop-file / loop-playlist are respected).
        * Idle mode / empty player states (never exits unexpectedly).
        * Live streams or files with invalid duration.
        * Immediate cancel on seek backwards, unpause, new file load, or playlist append.
--]]

local mp = require 'mp'
local options = require 'mp.options'

local opts = {
    enable = true,                  -- Enable or disable auto-exit at EOF
    delay = 6.0,                    -- Total grace period in seconds before exiting
    warning_time = 2.5,             -- Time in seconds before exit to show the OSD warning
    warning_text = "Exiting...",     -- Text to display on OSD
    show_warning = true,            -- Show the OSD warning message
    only_fullscreen = false,        -- Only auto-exit if mpv is in fullscreen mode
}

options.read_options(opts, "auto_exit_eof")

local warning_timer = nil
local exit_timer = nil
local is_showing_warning = false

-- Check if active item is the last file in the playlist
local function is_last_file()
    local pos = mp.get_property_number("playlist-pos", -1)
    local count = mp.get_property_number("playlist-count", 0)
    if pos == -1 or count <= 0 then
        return false
    end
    return (pos + 1) >= count
end

-- Check if any loop mode is currently enabled
local function is_looping()
    local loop_file = mp.get_property("loop-file", "no")
    if loop_file ~= "no" and loop_file ~= "0" and loop_file ~= nil then
        return true
    end

    local loop_playlist = mp.get_property("loop-playlist", "no")
    if loop_playlist ~= "no" and loop_playlist ~= "0" and loop_playlist ~= nil then
        return true
    end

    return false
end

-- Check if current media is valid for auto-exit
local function is_valid_media()
    local idle = mp.get_property_bool("idle-active", false)
    if idle then
        return false
    end

    local path = mp.get_property("path")
    if not path or path == "" then
        return false
    end

    local duration = mp.get_property_number("duration", 0)
    if duration <= 0 then
        return false
    end

    return true
end

-- Cancel any active countdown and clear warning
local function cancel_exit()
    if warning_timer then
        warning_timer:kill()
        warning_timer = nil
    end

    if exit_timer then
        exit_timer:kill()
        exit_timer = nil
    end

    if is_showing_warning then
        is_showing_warning = false
        mp.osd_message("", 0)
    end
end

-- Start the graceful exit countdown
local function start_exit_countdown()
    if not opts.enable then return end
    if exit_timer then return end -- Already counting down
    if not is_valid_media() then return end
    if not is_last_file() then return end
    if is_looping() then return end

    if opts.only_fullscreen and not mp.get_property_bool("fullscreen", false) then
        return
    end

    local total_delay = math.max(opts.delay, 0.5)
    local warn_time = math.min(opts.warning_time, total_delay)
    local silent_delay = total_delay - warn_time

    if silent_delay > 0 then
        warning_timer = mp.add_timeout(silent_delay, function()
            if opts.show_warning then
                is_showing_warning = true
                -- Show for slightly longer than warn_time to ensure it stays until exit
                mp.osd_message(opts.warning_text, warn_time + 0.5)
            end
        end)
    else
        if opts.show_warning then
            is_showing_warning = true
            mp.osd_message(opts.warning_text, warn_time + 0.5)
        end
    end

    exit_timer = mp.add_timeout(total_delay, function()
        mp.command("quit")
    end)
end

-- Observe EOF state
mp.observe_property("eof-reached", "bool", function(_, eof)
    if eof then
        start_exit_countdown()
    else
        cancel_exit()
    end
end)

-- Observe pause property: if user unpauses, cancel countdown
mp.observe_property("pause", "bool", function(_, paused)
    if not paused and exit_timer then
        cancel_exit()
    end
end)

-- Observe playback position: if user seeks back from EOF, cancel immediately
mp.observe_property("time-pos", "number", function(_, time_pos)
    if exit_timer and time_pos then
        local duration = mp.get_property_number("duration", 0)
        if duration > 0 and (duration - time_pos) > 1.0 then
            cancel_exit()
        end
    end
end)

-- Observe playlist count: if items are added while at EOF, cancel exit
mp.observe_property("playlist-count", "number", function(_, count)
    if exit_timer and not is_last_file() then
        cancel_exit()
    end
end)

-- Observe fullscreen change if only_fullscreen is active
mp.observe_property("fullscreen", "bool", function(_, fs)
    if opts.only_fullscreen and not fs and exit_timer then
        cancel_exit()
    end
end)

-- Clear timers on file transitions
mp.register_event("start-file", function()
    cancel_exit()
end)

mp.register_event("end-file", function(event)
    -- If file ended for reasons other than natural eof (e.g. user stopped, error), cancel
    if event.reason ~= "eof" then
        cancel_exit()
    end
end)

-- Register script-binding for manual cancellation if desired
mp.add_key_binding(nil, "cancel-exit", cancel_exit)
