--[[
    pause_notify.lua - On-Screen Pause Notification for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)
    Developed by : Biraj Sarkar (@Biraj2004)
    
    Features:
    - Follows the exact native OSD styling of biraj-mpv-conf (Subtitles/Audio/Playlist/Resume format).
    - Displays: "Paused at hr:min:sec / total time" (or "Paused at min:sec / total time" for files under 1 hour).
    - Dynamically chooses between HH:MM:SS and MM:SS based on total media duration.
    - Persists continuously for the entire duration the media remains paused.
    - Dynamically updates the timestamp if seeking while paused.
    - Immediately disappears the exact second playback resumes (zero lingering display).
--]]

local mp = require 'mp'
local options = require 'mp.options'

local opts = {
    enable = true,
    prefix = "Paused at ",
    hour_format = "auto",       -- "auto" (shows hours if file duration >= 1h), "always", or "never"
    show_duration = true,       -- Include total duration: "Paused at 08:27 / 43:40"
    refresh_interval = 1.0,     -- Periodic refresh interval in seconds to keep OSD active
}

options.read_options(opts, "pause_notify")

local is_paused = false
local refresh_timer = nil

-- Format seconds into MM:SS or HH:MM:SS
local function format_time(seconds, show_hours)
    local s = math.max(0, math.floor(seconds or 0))
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if show_hours then
        return string.format("%02d:%02d:%02d", h, m, sec)
    else
        return string.format("%02d:%02d", m, sec)
    end
end

-- Determine if hours should be displayed based on file duration and current position
local function should_show_hours(pos, duration)
    if opts.hour_format == "always" then
        return true
    elseif opts.hour_format == "never" then
        return false
    end
    -- "auto": show hours if file duration >= 1 hour or current position >= 1 hour
    return (duration and duration >= 3600) or (pos and pos >= 3600)
end

-- Construct the pause message string
local function get_pause_message()
    local duration = mp.get_property_number("duration", 0)
    local time_pos = mp.get_property_number("time-pos", 0)
    local has_hours = should_show_hours(time_pos, duration)

    local cur_str = format_time(time_pos, has_hours)
    if opts.show_duration and duration > 0 then
        local dur_str = format_time(duration, has_hours)
        return string.format("%s%s / %s", opts.prefix, cur_str, dur_str)
    else
        return string.format("%s%s", opts.prefix, cur_str)
    end
end

-- Display pause OSD message with maximum duration to persist while paused
local function show_pause_osd()
    if not opts.enable or not is_paused then return end
    local msg_text = get_pause_message()
    -- 86400 seconds (24 hours) ensures the message persists continuously during pause
    mp.osd_message(msg_text, 86400)
end

-- Instantly clear the OSD message when resuming playback
local function clear_pause_osd()
    mp.osd_message("", 0)
end

-- Manage periodic refresh while paused (keeps OSD alive if overwritten by seeks)
local function start_refresh_timer()
    if refresh_timer then
        refresh_timer:kill()
        refresh_timer = nil
    end
    refresh_timer = mp.add_periodic_timer(opts.refresh_interval, function()
        if is_paused then
            show_pause_osd()
        end
    end)
end

local function stop_refresh_timer()
    if refresh_timer then
        refresh_timer:kill()
        refresh_timer = nil
    end
end

-- Handle pause state changes
local function on_pause_change(_, paused)
    is_paused = (paused == true)
    if is_paused then
        show_pause_osd()
        start_refresh_timer()
    else
        stop_refresh_timer()
        clear_pause_osd()
        -- Micro-deferred safety clear to guarantee zero lingering frames
        mp.add_timeout(0.05, clear_pause_osd)
    end
end

-- Update OSD dynamically on seeking while paused
local function on_time_pos_change(_, _)
    if is_paused then
        show_pause_osd()
    end
end

-- Register property observers
mp.observe_property("pause", "bool", on_pause_change)
mp.observe_property("time-pos", "number", on_time_pos_change)

-- Clean up on file change or exit
mp.register_event("end-file", function()
    stop_refresh_timer()
    clear_pause_osd()
end)

mp.register_event("shutdown", function()
    stop_refresh_timer()
    clear_pause_osd()
end)
