--[[
    resume_indicator.lua - On-Screen Resume Notification for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)
    Developed by : Biraj Sarkar (@Biraj2004)
    
    Features:
    - Follows the exact native OSD styling of biraj-mpv-conf (Subtitles/Audio/Playlist format).
    - Displays: "Resuming: (14:22 / 24:00)" or "Resuming: (14:22)"
    - Automatically ignores fresh file starts (0:00 to 0:02).
    - Only triggers once on initial file load restoration; never triggers during manual seeks.
--]]

local mp = require 'mp'
local options = require 'mp.options'

local opts = {
    enable = true,
    duration = 2.5,          -- OSD display duration in seconds (matches osd-duration)
    min_resume_time = 3.0,   -- Minimum position in seconds to be considered a resume (ignores starts from beginning)
    show_duration = true,    -- Include total duration e.g. "Resuming: (14:22 / 24:00)"
}

options.read_options(opts, "resume_indicator")

local has_checked_resume = false

local function format_time(seconds)
    local s = math.floor(seconds)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, sec)
    else
        return string.format("%02d:%02d", m, sec)
    end
end

local function check_and_notify_resume()
    if not opts.enable or has_checked_resume then return end

    -- Check if active file has valid duration
    local duration = mp.get_property_number("duration", 0)
    if duration <= 0 then return end

    local time_pos = mp.get_property_number("time-pos", 0)
    if time_pos >= opts.min_resume_time then
        has_checked_resume = true
        local cur_str = format_time(time_pos)
        local msg_text
        if opts.show_duration and duration > 0 then
            local dur_str = format_time(duration)
            msg_text = string.format("Resuming: (%s / %s)", cur_str, dur_str)
        else
            msg_text = string.format("Resuming: (%s)", cur_str)
        end
        mp.osd_message(msg_text, opts.duration)
    else
        has_checked_resume = true
    end
end

-- Reset state when starting a new file
mp.register_event("start-file", function()
    has_checked_resume = false
end)

-- Detect playback start / position restoration from watch_later
mp.register_event("playback-restart", function()
    if not has_checked_resume then
        -- Small deferred check to ensure watch-later seek has completed
        mp.add_timeout(0.05, function()
            check_and_notify_resume()
        end)
    end
end)

mp.register_event("end-file", function()
    has_checked_resume = false
end)
