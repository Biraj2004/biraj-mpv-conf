--[[
    pause_notify.lua - On-Screen Pause Notification with Dynamic Collision Avoidance for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)
    Developed by : Biraj Sarkar (@Biraj2004)
    
    Features:
    - Follows the exact native OSD styling of biraj-mpv-conf (Subtitles/Audio/Playlist/Resume format).
    - Displays: "Paused at hr:min:sec / total time" (or "Paused at min:sec / total time" for files under 1 hour).
    - Uses a dedicated ASS OSD overlay to keep mpv's native OSD channel completely free.
    - Non-Overlapping Collision Avoidance: Only this pause notification shifts down when another OSD message
      (volume, mute, tracks, etc.) appears, leaving the top native position for the other message.
    - Repositions back up automatically as soon as the other OSD message fades away.
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
    shift_offset = 0,           -- Distance in px to shift down (0 = auto-calculate based on font size)
    reposition_delay = 0.10,    -- Extra buffer in seconds before shifting back up after OSD expires
}

options.read_options(opts, "pause_notify")

local is_paused = false
local is_shifted = false
local shift_lines = 1
local shift_timer = nil
local shift_target_time = 0
local active_osd_expire_time = 0
local active_osd_lines = 1

-- Dedicated ASS OSD Overlay
local ov = mp.create_osd_overlay("ass-events")

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

-- Compose formatted pause text matching mpv styling
local function get_pause_message()
    local pos = mp.get_property_number("time-pos", 0)
    local duration = mp.get_property_number("duration", 0)

    local has_hours = false
    if opts.hour_format == "always" then
        has_hours = true
    elseif opts.hour_format == "auto" then
        has_hours = (duration >= 3600 or pos >= 3600)
    end

    local cur_str = format_time(pos, has_hours)

    if opts.show_duration and duration > 0 then
        local dur_str = format_time(duration, has_hours)
        return string.format("%s%s / %s", opts.prefix, cur_str, dur_str)
    else
        return string.format("%s%s", opts.prefix, cur_str)
    end
end

-- Calculate shift distance in pixels based on font size or custom config
local function get_shift_amount(lines)
    lines = lines or 1
    if opts.shift_offset > 0 then
        return opts.shift_offset + (lines - 1) * math.floor(opts.shift_offset * 0.75)
    end
    local fs = mp.get_property_number("osd-font-size", 26)
    -- In mpv native OSD with background-box, first line height is fs + 14px padding.
    -- Each additional line in multi-line text adds font-size + 4px interline spacing.
    local first_line = fs + 14
    local extra_line = fs + 4
    return first_line + (lines - 1) * extra_line
end

-- Render the pause notification overlay with exact native mpv OSD styling
local function update_overlay()
    if not opts.enable or not is_paused then
        ov.data = ""
        ov:remove()
        return
    end

    local mx = mp.get_property_number("osd-margin-x", 16)
    local my = mp.get_property_number("osd-margin-y", 16)

    local y = my
    if is_shifted then
        y = my + get_shift_amount(shift_lines)
    end

    local msg_text = get_pause_message()
    -- \an7 pins to top-left. Inherits exact native OSD font, size, background box, and colors from mpv.
    ov.data = string.format("{\\an7\\pos(%d,%d)}%s", mx, y, msg_text)
    ov:update()
end

-- Trigger shifting the pause notification down when another OSD message is active
local function trigger_shift(duration, lines)
    if not opts.enable then return end

    local default_dur = (mp.get_property_number("osd-duration", 2500) / 1000.0)
    local active_dur = (duration or default_dur) + opts.reposition_delay
    local now = mp.get_time() or 0
    local new_target = now + active_dur

    active_osd_lines = lines or 1
    if new_target >= active_osd_expire_time then
        active_osd_expire_time = new_target
    end

    -- If currently paused, immediately update the overlay position and manage reposition timer
    if is_paused then
        shift_lines = active_osd_lines
        is_shifted = true
        update_overlay()

        if new_target >= shift_target_time then
            shift_target_time = new_target
            if shift_timer then
                shift_timer:kill()
                shift_timer = nil
            end
            shift_timer = mp.add_timeout(active_dur, function()
                shift_timer = nil
                shift_target_time = 0
                is_shifted = false
                shift_lines = 1
                active_osd_expire_time = 0
                active_osd_lines = 1
                if is_paused then
                    update_overlay()
                end
            end)
        end
    end
end

-- Listen for cplayer log messages to detect show-text, screenshot, show-progress, and native OSD commands
mp.enable_messages("trace")

mp.register_event("log-message", function(e)
    if not opts.enable then return end
    if e.prefix ~= "cplayer" then return end

    -- Detect show-text (e.g., from mp.osd_message in scripts or user show-text commands)
    if e.text:find("Run command: show%-text") then
        local dur_str = e.text:match('duration="(%d+)"')
        local duration = dur_str and (tonumber(dur_str) / 1000.0) or nil

        -- Count multi-line text to shift accurately without excessive gap
        local text = e.text:match('text="(.-)"') or e.text:match('text="([^"]*)"')
        local lines = 1
        if text then
            for _ in text:gmatch("\\n") do lines = lines + 1 end
            for _ in text:gmatch("\n") do lines = lines + 1 end
            for _ in text:gmatch("\\N") do lines = lines + 1 end
        end
        trigger_shift(duration, lines)
        return
    end

    -- Detect show-progress command
    if e.text:find("Run command: show%-progress") then
        trigger_shift()
        return
    end

    -- Detect screenshot command
    if e.text:find("Run command: screenshot") then
        trigger_shift()
        return
    end

    -- Detect commands carrying OSD flags
    local cmd, flags = e.text:match('Run command: ([%w%-_]+), flags=(%d+)')
    if cmd and flags then
        -- Exclude non-OSD or internal commands
        if cmd == "frame-step" or cmd == "frame-back-step" or cmd == "quit" or cmd == "ignore"
            or cmd == "osd-overlay" or cmd == "del" or cmd == "define-section"
            or cmd == "enable-section" or cmd == "disable-section" or cmd == "apply-profile" then
            return
        end

        -- Exclude pause toggle commands (pausing/unpausing doesn't display text OSD)
        if (cmd == "cycle" or cmd == "set") and e.text:find('name="pause"') then
            return
        end

        local f = tonumber(flags) or 0
        local osd_type = f % 8
        -- osd_type >= 4: osd-msg (flags=76) or osd-msg-bar (flags=78)
        -- osd_type == 1: osd-auto (flags=73) for input keybindings (volume, mute, speed, seek, cycle-values, etc.)
        if osd_type >= 4 or (osd_type == 1 and (
            cmd == "add" or cmd == "cycle" or cmd == "cycle-values" or cmd == "multiply" or
            cmd == "seek" or cmd == "sub-seek" or cmd == "sub-step" or cmd == "revert-seek" or
            cmd == "set" or cmd == "ab-loop" or cmd == "playlist-next" or cmd == "playlist-prev" or
            cmd == "chapter-seek" or cmd == "playlist-play-index" or cmd == "playlist-shuffle"
        )) then
            local lines = 1
            -- cycle-values on filters (af, vf) formats as 2 lines in mpv native OSD: "Audio filters:\n..."
            if cmd == "cycle-values" and (e.text:find('arg0="af"') or e.text:find('arg0="vf"')) then
                lines = 2
            end
            trigger_shift(nil, lines)
        end
    end
end)

-- Adapt immediately if mpv or scripts change layout/margins/font-size
local layout_props = {"osd-margin-x", "osd-margin-y", "osd-font-size", "osd-dimensions"}
for _, prop in ipairs(layout_props) do
    mp.observe_property(prop, "native", function(_, _)
        if is_paused and opts.enable then
            update_overlay()
        end
    end)
end

-- Handle pause / unpause state changes
local function on_pause_change(_, paused)
    is_paused = (paused == true)
    if is_paused then
        local now = mp.get_time() or 0
        -- If an OSD message (e.g. from seek or volume right before pausing) is still active on screen:
        if now < active_osd_expire_time then
            is_shifted = true
            shift_lines = active_osd_lines
            shift_target_time = active_osd_expire_time
            local remaining = active_osd_expire_time - now
            if shift_timer then shift_timer:kill() end
            shift_timer = mp.add_timeout(remaining, function()
                shift_timer = nil
                shift_target_time = 0
                is_shifted = false
                shift_lines = 1
                active_osd_expire_time = 0
                active_osd_lines = 1
                if is_paused then
                    update_overlay()
                end
            end)
        else
            is_shifted = false
            shift_lines = 1
            shift_target_time = 0
            if shift_timer then
                shift_timer:kill()
                shift_timer = nil
            end
        end
        update_overlay()
    else
        if shift_timer then
            shift_timer:kill()
            shift_timer = nil
        end
        shift_target_time = 0
        is_shifted = false
        shift_lines = 1
        ov.data = ""
        ov:remove()
    end
end

-- Dynamic timestamp update during seeking while paused
local function on_time_pos_change(_, _)
    if is_paused and opts.enable then
        update_overlay()
    end
end

mp.observe_property("pause", "bool", on_pause_change)
mp.observe_property("time-pos", "number", on_time_pos_change)

-- Update if a new file is loaded while paused
mp.register_event("file-loaded", function()
    if is_paused and opts.enable then
        update_overlay()
    end
end)

-- Cleanup on file change or exit
local function cleanup()
    if shift_timer then
        shift_timer:kill()
        shift_timer = nil
    end
    shift_target_time = 0
    is_shifted = false
    shift_lines = 1
    ov.data = ""
    ov:remove()
end

mp.register_event("end-file", cleanup)
mp.register_event("shutdown", cleanup)
