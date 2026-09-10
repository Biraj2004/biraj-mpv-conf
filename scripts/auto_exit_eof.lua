--[[
    auto_exit_eof.lua - Graceful Auto-Exit at End of Media for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)
    Developed by : Biraj Sarkar (@Biraj2004)

    Features:
    - Waits for a configurable grace period (default: 4.0s) after a video/playlist finishes.
    - Gives user time to seek backwards (e.g., Left Arrow) or unpause to keep mpv open.
    - Displays a native top-left OSD warning ("Exiting...") during the final moments (default: last 2.0s).
    - Automatically clears watch-later resume state when reaching the end (final 5% / 95% completion mark) or beginning (< 2%) so re-opening starts fresh from 0:00.
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
    delay = 4.0,                    -- Total grace period in seconds before exiting
    warning_time = 2.0,             -- Time in seconds before exit to show the OSD warning
    warning_text = "Exiting...",     -- Text to display on OSD
    show_warning = true,            -- Show the OSD warning message
    only_fullscreen = false,        -- Only auto-exit if mpv is in fullscreen mode
    reset_watch_later = true,       -- Reset watch-later position when reaching the end of media
    start_threshold_percent = 2.0,  -- Percentage from beginning to ignore watch-later (default: 2.0%)
    eof_threshold_percent = 5.0,    -- Percentage from end of media to treat video as completed (default: 5.0% / 95% completion mark)
    min_duration = 100.0,           -- Minimum video duration in seconds to enable watch-later saving (default: 100.0s)
}

options.read_options(opts, "auto_exit_eof")

local warning_timer = nil
local exit_timer = nil
local is_showing_warning = false
local initial_save_pos = true
local is_eof_cleaned = false
local has_checked_startup = false

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

-- Calculate start and EOF threshold boundaries based on duration percentages
local function get_threshold_bounds(duration)
    if not duration or duration <= 0 then return nil, nil end
    if opts.min_duration and duration <= opts.min_duration then return nil, nil end
    local start_p = math.max(0.0, opts.start_threshold_percent or 0.0)
    local eof_p = math.max(0.0, opts.eof_threshold_percent or 0.0)

    local start_sec = 0
    if start_p > 0 then
        start_sec = math.max(3.0, duration * (start_p / 100.0))
    end

    local end_sec = duration
    if eof_p > 0 then
        end_sec = math.min(duration - 5.0, duration * (1.0 - (eof_p / 100.0)))
    end

    if start_sec >= end_sec then return nil, nil end
    return start_sec, end_sec
end

-- Clean watch-later config and prevent saving position at EOF
local function clean_watch_later()
    if not opts.reset_watch_later then return end
    if not is_eof_cleaned then
        is_eof_cleaned = true
        mp.commandv("delete-watch-later-config")
        mp.set_property_bool("save-position-on-quit", false)
    end
end

-- Restore save-position-on-quit when seeking backwards away from EOF
local function restore_save_pos()
    if is_eof_cleaned then
        is_eof_cleaned = false
        mp.set_property_bool("save-position-on-quit", initial_save_pos)
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
        clean_watch_later()
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

-- Observe playback position: handle completion threshold, start threshold, and exit cancellation
mp.observe_property("time-pos", "number", function(_, time_pos)
    if not time_pos or not has_checked_startup then return end
    local duration = mp.get_property_number("duration", 0)

    -- Immediately suppress watch-later for short videos <= min_duration (default: 100.0s)
    if opts.reset_watch_later and opts.min_duration and duration > 0 and duration <= opts.min_duration then
        clean_watch_later()
        if exit_timer and (duration - time_pos) > 1.0 then
            cancel_exit()
        end
        return
    end

    -- Reset watch-later when within initial start threshold (default: 2.0%) or final completion threshold (default: 5.0% / 95% completion mark)
    local start_sec, end_sec = get_threshold_bounds(duration)
    if start_sec and end_sec then
        if time_pos < start_sec or time_pos >= end_sec then
            clean_watch_later()
        else
            restore_save_pos()
        end
    end

    if exit_timer and duration > 0 and (duration - time_pos) > 1.0 then
        cancel_exit()
    end
end)

-- Observe duration: suppress watch-later immediately when a short video (<= min_duration) is detected
mp.observe_property("duration", "number", function(_, duration)
    if not duration or not opts.reset_watch_later then return end
    if opts.min_duration and duration > 0 and duration <= opts.min_duration then
        clean_watch_later()
    end
end)

-- If a previously completed file is loaded at near-EOF or below start threshold, start over fresh from 0:00
mp.register_event("playback-restart", function()
    if not opts.reset_watch_later or has_checked_startup then return end
    has_checked_startup = true

    local duration = mp.get_property_number("duration", 0)
    if opts.min_duration and duration > 0 and duration <= opts.min_duration then
        clean_watch_later()
        return
    end

    local time_pos = mp.get_property_number("time-pos", 0)
    local start_sec, end_sec = get_threshold_bounds(duration)

    if start_sec and end_sec then
        if time_pos >= end_sec then
            mp.commandv("seek", 0, "absolute", "exact")
            clean_watch_later()
            if mp.get_property_bool("pause", false) then
                mp.set_property_bool("pause", false)
            end
        elseif time_pos < start_sec then
            clean_watch_later()
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

-- Clear timers on file transitions and track initial save-position-on-quit
mp.register_event("start-file", function()
    cancel_exit()
    has_checked_startup = false
    is_eof_cleaned = false
    initial_save_pos = mp.get_property_bool("save-position-on-quit", true)
end)

mp.register_event("end-file", function(event)
    -- If file ended for reasons other than natural eof (e.g. user stopped, error), cancel
    if event.reason ~= "eof" then
        cancel_exit()
    end
end)

-- Register script-binding for manual cancellation if desired
mp.add_key_binding(nil, "cancel-exit", cancel_exit)
