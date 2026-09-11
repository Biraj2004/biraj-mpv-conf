--[[
    resume_indicator.lua - On-Screen Resume Notification for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)
    Developed by : Biraj Sarkar (@Biraj2004)
    
    Features:
    - Follows the exact native OSD styling of biraj-mpv-conf (Subtitles/Audio/Playlist format).
    - Displays: "Resuming: (14:22 / 24:00)" or "Resuming: (14:22)"
    - Automatically ignores fresh file starts (first 2% / min 3s) and near-completion (last 5% / 95% mark).
    - Only triggers once on initial file load restoration; never triggers during manual seeks.
--]]

local mp = require 'mp'
local options = require 'mp.options'

local opts = {
    enable = true,
    duration = 2.5,                -- OSD display duration in seconds (matches osd-duration)
    min_resume_percent = 2.0,      -- Minimum playback percentage to trigger resume (ignores fresh starts < 2%)
    max_resume_percent = 95.0,     -- Maximum playback percentage to trigger resume (ignores near-completion >= 95%)
    min_duration = 100.0,          -- Minimum media duration in seconds to trigger resume notification (default: 100s)
    show_duration = true,          -- Include total duration e.g. "Resuming: (14:22 / 24:00)"
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

-- Helper to display OSD and notify pause_notify for dynamic collision avoidance
local function show_osd(text, duration)
    local dur = duration or opts.duration
    mp.osd_message(text, dur)
    mp.commandv("script-message-to", "pause_notify", "osd-notify", text, tostring(dur))
end

-- Calculate start and end percentage threshold boundaries
local function get_threshold_bounds(duration)
    if not duration or duration <= 0 then return nil, nil end
    local start_p = math.max(0.0, opts.min_resume_percent or 0.0)
    local max_p = math.min(100.0, opts.max_resume_percent or 100.0)

    local start_sec = 0
    if start_p > 0 then
        start_sec = math.max(3.0, duration * (start_p / 100.0))
    end

    local end_sec = duration
    if max_p < 100.0 then
        end_sec = math.min(duration - 5.0, duration * (max_p / 100.0))
    end

    if start_sec >= end_sec then return nil, nil end
    return start_sec, end_sec
end

local function check_and_notify_resume()
    if not opts.enable or has_checked_resume then return end

    -- Check if active file has valid duration and is greater than min_duration (default: 100s)
    local duration = mp.get_property_number("duration", 0)
    if duration <= 0 or (opts.min_duration and duration <= opts.min_duration) then return end

    local time_pos = mp.get_property_number("time-pos", 0)
    local start_sec, end_sec = get_threshold_bounds(duration)
    local is_valid_resume = false

    if start_sec and end_sec then
        is_valid_resume = (time_pos >= start_sec and time_pos < end_sec)
    else
        is_valid_resume = (time_pos >= 3.0 and time_pos < (duration - 5.0))
    end

    -- Ignore fresh starts and ignore files restoring near the very end
    if is_valid_resume then
        has_checked_resume = true
        local cur_str = format_time(time_pos)
        local msg_text
        if opts.show_duration and duration > 0 then
            local dur_str = format_time(duration)
            msg_text = string.format("Resuming: (%s / %s)", cur_str, dur_str)
        else
            msg_text = string.format("Resuming: (%s)", cur_str)
        end
        show_osd(msg_text, opts.duration)
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
