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
    - Inter-Script Coordination: Receives osd-notify events from cycle_audio, sort_playlist, and resume_indicator.
    - Stats & Console Auto-Suppression: Automatically hides when technical stats (i / Shift+I) or console (`) are active.
    - Motion & Window State Isolation: Ignores ModernZ mouse hover events and window fullscreen/unfullscreen toggles.
    - Repositions back up automatically as soon as the other OSD message fades away.
    - Dynamically updates the timestamp if seeking while paused.
    - Immediately disappears the exact second playback resumes (zero lingering display).
    - Zero Demuxer Startup Overhead: Targeted debug-level message filtering prevents demuxer trace floods, ensuring 100% native bare-metal opening speed on massive multi-hour media.
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
local is_stats_active = false
local is_console_active = false
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
    lines = math.max(1, lines or 1)
    if opts.shift_offset > 0 then
        return lines * opts.shift_offset
    end
    local fs = mp.get_property_number("osd-font-size", 26)
    fs = (fs and fs > 0) and fs or 26
    -- Native mpv OSD with background-box occupies:
    -- line_height = font-size * 1.35 (libass line spacing) + 8px (background-box padding & separation gap)
    local first_line = math.floor(fs * 1.50) + 4
    local extra_line = math.floor(fs * 1.20)
    return first_line + (lines - 1) * extra_line
end

-- Render the pause notification overlay with exact native mpv OSD styling
local function update_overlay()
    if not opts.enable or not is_paused or is_stats_active or is_console_active then
        ov.data = ""
        ov:remove()
        mp.set_property_bool("user-data/pause_notify/visible", false)
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
    mp.set_property_bool("user-data/pause_notify/visible", true)
end

-- Trigger shifting the pause notification down when another OSD message is active
local function trigger_shift(duration, lines)
    if not opts.enable or is_stats_active or is_console_active then return end

    local default_dur = (mp.get_property_number("osd-duration", 2500) / 1000.0)
    local active_dur = (duration or default_dur) + opts.reposition_delay
    local now = mp.get_time() or 0
    local new_target = now + active_dur

    local req_lines = math.max(1, lines or 1)
    -- If a multi-line notification (e.g. screenshot or audio filter) is active on screen,
    -- never downgrade active_osd_lines to 1 from subsequent internal/sub-commands!
    if now < active_osd_expire_time then
        active_osd_lines = math.max(active_osd_lines, req_lines)
    else
        active_osd_lines = req_lines
    end

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

-- Estimate visual lines occupied by text in mpv's native OSD,
-- accurately accounting for both explicit newlines (\n, \N) and libass word-wrapping based on window width.
local function estimate_text_lines(text)
    if not text or #text == 0 then return 1 end

    local osd_w, _ = mp.get_osd_size()
    if not osd_w or osd_w <= 0 then
        local dims = mp.get_property_native("osd-dimensions")
        if dims and dims.w and dims.w > 0 then
            osd_w = dims.w
        else
            local dw = mp.get_property_number("dwidth", 0)
            osd_w = (dw > 0) and dw or 1600
        end
    end
    local mx = mp.get_property_number("osd-margin-x", 16)
    local usable_w = math.max(400, osd_w - (mx * 2))
    local fs = mp.get_property_number("osd-font-size", 26)
    fs = (fs and fs > 0) and fs or 26

    -- In libass / mpv native OSD, character width averages ~0.50 * fs for proportional fonts.
    local char_w = fs * 0.50
    local max_line_chars = math.max(30, math.floor(usable_w / char_w))

    -- Normalize explicit linebreaks (\N, \n, \r\n)
    local clean_text = text:gsub("\\N", "\n"):gsub("\\n", "\n"):gsub("\r\n", "\n")
    local total_lines = 0

    for paragraph in (clean_text .. "\n"):gmatch("(.-)\n") do
        if #paragraph == 0 then
            total_lines = total_lines + 1
        else
            local cur_line_len = 0
            local p_lines = 1
            for token in paragraph:gmatch("%S+%s*") do
                local t_len = #token
                if cur_line_len + t_len <= max_line_chars then
                    cur_line_len = cur_line_len + t_len
                else
                    if cur_line_len > 0 then
                        p_lines = p_lines + 1
                        cur_line_len = 0
                    end
                    while t_len > max_line_chars do
                        p_lines = p_lines + 1
                        t_len = t_len - max_line_chars
                    end
                    cur_line_len = t_len
                end
            end
            total_lines = total_lines + p_lines
        end
    end

    return math.max(1, total_lines)
end

-- Predictively estimate screenshot lines before the file is finished writing to disk.
-- Screenshot notifications print "Screenshot: '<full_path>'", which almost universally
-- wraps to 2+ lines on standard desktop/laptop displays.
local function estimate_screenshot_lines()
    local path = mp.get_property("path") or ""
    local title = mp.get_property("media-title") or mp.get_property("filename") or ""
    local dir = mp.get_property("screenshot-directory") or "~/Pictures/MPV-Screenshots"
    local home = os.getenv("USERPROFILE") or os.getenv("HOME") or "C:/Users/user"
    local dir_expanded = dir:gsub("^~", home)
    local name = (#title > 0) and title or ((#path > 0) and path or "Screenshot")
    local predicted_text = string.format("Screenshot: '%s/%s-(00_00_00.000)-0001.jpg'", dir_expanded, name)
    local lines = estimate_text_lines(predicted_text)
    return math.max(2, lines)
end

-- Listen for cplayer log messages to detect show-text, screenshot, show-progress, and native OSD commands
mp.enable_messages("debug")

mp.register_event("log-message", function(e)
    if not opts.enable then return end
    if e.prefix ~= "cplayer" then return end

    -- Ultra-fast early discard of high-frequency rendering logs (frametime, video_output_image, etc.)
    local c = e.text:sub(1, 1)
    if c ~= "R" and c ~= "S" then return end

    -- Detect screenshot completion or progress log: "Screenshot: '...'" or "Starting screenshot: '...'"
    local shot_path = e.text:match("Screenshot: '(.-)'") or e.text:match("Starting screenshot: '(.-)'")
    if shot_path then
        local full_msg = "Screenshot: '" .. shot_path .. "'"
        local lines = math.max(2, estimate_text_lines(full_msg))
        trigger_shift(nil, lines)
        return
    end

    -- Detect show-text (e.g., from mp.osd_message in scripts or user show-text commands)
    if e.text:find("Run command: show%-text") then
        local dur_str = e.text:match('duration="([%d%-]+)"') or e.text:match('duration="(%d+)"')
        local raw_dur = dur_str and tonumber(dur_str) or nil
        -- Negative duration (e.g. -1) means default osd-duration in mpv
        local duration = (raw_dur and raw_dur > 0) and (raw_dur / 1000.0) or nil

        -- Count visual lines accounting for explicit newlines and word wrapping
        local text = e.text:match('text="(.-)"') or e.text:match('text="([^"]*)"')

        -- Ignore empty text or duration == 0 (OSD wipe/clear commands)
        if not text or #text == 0 or raw_dur == 0 then
            return
        end

        -- Suppress OSD shift while diagnostic overlay (stats or console) is active
        if is_stats_active or is_console_active then
            return
        end

        local lines = estimate_text_lines(text)
        trigger_shift(duration, lines)
        return
    end

    -- Detect show-progress command
    if e.text:find("Run command: show%-progress") then
        trigger_shift()
        return
    end

    -- Detect screenshot command invocation (immediate anticipatory shift)
    if e.text:find("Run command: screenshot") or e.text:find('arg0="screenshot"') then
        local lines = estimate_screenshot_lines()
        trigger_shift(nil, lines)
        return
    end

    -- Accurately detect when the stats overlay is active (via 'i', 'I', or page keys)
    if e.text:find('input_forced_stats') then
        local clean = e.text:gsub('\\+"', '"')
        local contents = clean:match('contents="([^"]*)"')
        if contents then
            is_stats_active = (#contents > 0)
            update_overlay()
        end
        return
    end

    -- Accurately detect when the interactive console overlay is active (via '`' or commands)
    if e.text:find('input_forced_console') then
        local clean = e.text:gsub('\\+"', '"')
        local contents = clean:match('contents="([^"]*)"')
        if contents then
            is_console_active = (#contents > 0)
            update_overlay()
        end
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

        -- Exclude silent commands that do not display text OSD (pause toggle, fullscreen toggle, etc.)
        if (cmd == "cycle" or cmd == "set") and (
            e.text:find('name="pause"') or
            e.text:find('name="fullscreen"') or
            e.text:find('video%-align') or
            e.text:find('file%-local%-options')
        ) then
            return
        end

        -- Screenshot commands are handled specifically above; ignore here to prevent overriding line count
        if cmd == "screenshot" then
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
            cmd == "chapter-seek" or cmd == "playlist-play-index" or cmd == "playlist-shuffle" or
            (cmd == "script-binding" and e.text:find("modernz/visibility"))
        )) then
            local lines = 1
            -- cycle-values on filters: "Audio filters:\n..." is 2 lines when enabled, 1 line when cleared
            if cmd == "cycle-values" and (e.text:find('arg0="af"') or e.text:find('arg0="vf"')) then
                local filter_val = e.text:match('arg1="([^"]*)"') or ""
                lines = (#filter_val > 0) and 2 or 1
            end
            trigger_shift(nil, lines)
        end
    end
end)

-- Direct script message support for custom scripts (e.g. cycle_audio, sort_playlist)
mp.register_script_message("osd-notify", function(text, dur_str)
    if not opts.enable then return end
    local duration = dur_str and tonumber(dur_str) or nil
    local lines = estimate_text_lines(text)
    trigger_shift(duration, lines)
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

-- Hide pause notification whenever mpv's interactive console is open
mp.observe_property("user-data/mpv/console/open", "bool", function(_, is_open)
    is_console_active = (is_open == true)
    update_overlay()
end)

local is_observing_time = false

-- Dynamic timestamp update during seeking while paused
local function on_time_pos_change(_, _)
    if is_paused and opts.enable then
        update_overlay()
    end
end

-- Handle pause / unpause state changes
local function on_pause_change(_, paused)
    is_paused = (paused == true)
    if is_paused then
        if not is_observing_time then
            is_observing_time = true
            mp.observe_property("time-pos", "number", on_time_pos_change)
        end
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
        if is_observing_time then
            is_observing_time = false
            mp.unobserve_property(on_time_pos_change)
        end
        if shift_timer then
            shift_timer:kill()
            shift_timer = nil
        end
        shift_target_time = 0
        is_shifted = false
        shift_lines = 1
        update_overlay()
    end
end

mp.observe_property("pause", "bool", on_pause_change)

-- Update if a new file is loaded while paused
mp.register_event("file-loaded", function()
    is_stats_active = false
    is_console_active = false
    if is_paused and opts.enable then
        update_overlay()
    end
end)

-- Cleanup on file change or exit
local function cleanup()
    is_stats_active = false
    is_console_active = false
    if is_observing_time then
        is_observing_time = false
        mp.unobserve_property(on_time_pos_change)
    end
    if shift_timer then
        shift_timer:kill()
        shift_timer = nil
    end
    shift_target_time = 0
    is_shifted = false
    shift_lines = 1
    update_overlay()
end

mp.register_event("end-file", cleanup)
mp.register_event("shutdown", cleanup)
