--[[
    hdr_badge.lua - Dynamic HDR/DV/SDR Format Badge Overlay for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)

    Displays a sleek, minimalist format badge in the top-right corner
    (e.g., "DV", "HDR10+", "HDR", "HLG", "SDR") matching player theme.
    Includes smart collision-avoidance with hard-space margins so it never overlaps with the mute icon.
--]]

local mp = require "mp"
local msg = require "mp.msg"
local options = require "mp.options"

local opts = {
    -- General
    enable = true,
    duration = 2.5,                 -- Seconds to display on file launch (0 = keep visible)
    badge_format = "compact",       -- "compact" ("DV", "HDR10+", "HDR", "HLG", "SDR") or "full" ("DOLBY VISION", "HDR10+", "HDR10", "HLG", "SDR")
    show_sdr = true,                -- Show badge for SDR content
    show_on_start = true,           -- Show badge for 2.5s when video starts playing
    show_on_unpause = false,        -- Show badge when unpausing
    show_on_seek = false,           -- Show badge after seeking

    -- Position
    position = "top_right",

    -- Typography & Styling (Theme-matched with pause_indicator_lite & ModernZ)
    font = "Segoe UI",              -- Font family
    font_size = 20,                 -- Clear, legible font size
    bold = true,                    -- Bold typography

    -- Colors & Opacity (Hex #RRGGBB, Opacity 0-100)
    text_color = "#FFFFFF",
    border_color = "#111111",
    border_width = 1.5,
    shadow_offset = 0,
    opacity = 80,                   -- Opacity percent matching user config
}

options.read_options(opts, "hdr_badge")

-- State tracking
local state = {
    overlay = mp.create_osd_overlay("ass-events"),
    timer = nil,
    visible = false,
    current_badge = nil,
    is_muted = false,
    file_badge_shown = false,
}

-- Convert #RRGGBB to ASS BGR format (&HBBGGRR&)
local function hex_to_bgr(hex)
    if not hex or hex:find("^#%x%x%x%x%x%x$") == nil then
        return "FFFFFF"
    end
    return hex:sub(6,7) .. hex:sub(4,5) .. hex:sub(2,3)
end

-- Convert opacity percentage (0-100) to ASS Alpha hex (&HAA&)
local function opacity_to_alpha(opacity)
    opacity = math.max(0, math.min(100, tonumber(opacity) or 100))
    local alpha = math.floor((100 - opacity) * 2.55 + 0.5)
    return string.format("%02X", alpha)
end

local text_bgr = hex_to_bgr(opts.text_color)
local border_bgr = hex_to_bgr(opts.border_color)
local alpha_hex = opacity_to_alpha(opts.opacity)

-- Detect active video dynamic range format
local function detect_format()
    local vid = mp.get_property("vid")
    if vid == "no" then
        return nil
    end

    local colormatrix = mp.get_property("video-params/colormatrix") or ""
    local gamma = mp.get_property("video-params/gamma") or ""
    local primaries = mp.get_property("video-params/primaries") or ""
    local sig_peak = mp.get_property_number("video-params/sig-peak", 0) or 0
    local max_cll = mp.get_property_number("video-params/max-cll", 0) or 0
    local hdr10plus = mp.get_property_native("video-params/hdr10plus")

    local filename = (mp.get_property("filename") or ""):lower()
    local media_title = (mp.get_property("media-title") or ""):lower()
    local title_str = filename .. " " .. media_title

    -- 1. Dolby Vision
    if colormatrix == "dolbyvision" or title_str:find("dolby.?vision") or title_str:find("dovi") then
        if opts.badge_format == "full" then
            return "DOLBY VISION"
        else
            return "DV"
        end
    end

    -- 2. HDR10+ (Dynamic metadata)
    if hdr10plus == true or title_str:find("hdr10%+") or title_str:find("hdr10plus") then
        return "HDR10+"
    end

    -- 3. Standard HDR10
    if gamma == "pq" or (primaries == "bt.2020" and (sig_peak > 1 or max_cll > 0)) or title_str:find("hdr10") then
        if opts.badge_format == "full" then
            return "HDR10"
        else
            return "HDR"
        end
    end

    -- 4. HLG (Hybrid Log-Gamma)
    if gamma == "hlg" or title_str:find("hlg") then
        return "HLG"
    end

    -- 5. Generic HDR
    if primaries == "bt.2020" or sig_peak > 1 or title_str:find("hdr") then
        return "HDR"
    end

    -- 6. Standard Dynamic Range (SDR)
    return "SDR"
end

-- Generate pure ASS string docked at top-right (\an9) with hard-space collision clearance
local function generate_ass(badge_text)
    -- Use ASS \h (hard spaces) to cleanly push badge to the left of the 60px mute icon
    local trailing = state.is_muted and "\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h" or "\\h\\h\\h"
    return string.format(
        "{\\rDefault\\an9\\alpha&H%s\\fn%s\\fs%d\\b%d\\bord%0.1f\\shad%0.1f\\1c&H%s&\\3c&H%s&}\\h%s%s",
        alpha_hex,
        opts.font,
        opts.font_size,
        opts.bold and 1 or 0,
        opts.border_width,
        opts.shadow_offset,
        text_bgr,
        border_bgr,
        badge_text,
        trailing
    )
end

-- Kill running timer safely
local function kill_timer()
    if state.timer then
        state.timer:kill()
        state.timer = nil
    end
end

-- Hide the overlay
local function hide_badge()
    kill_timer()
    state.overlay:remove()
    state.visible = false
end

-- Show the overlay
local function show_badge(temporary)
    if not opts.enable then return end

    local badge = detect_format()
    if not badge then
        hide_badge()
        return
    end

    if badge == "SDR" and not opts.show_sdr and temporary then
        hide_badge()
        return
    end

    state.current_badge = badge
    state.overlay:remove()
    state.overlay.data = generate_ass(badge)
    state.overlay:update()
    state.visible = true

    kill_timer()

    if temporary and opts.duration > 0 then
        state.timer = mp.add_timeout(opts.duration, function()
            hide_badge()
        end)
    end
end

-- Toggle badge visibility manually (pressing 'l')
local function toggle_badge()
    if state.visible then
        hide_badge()
    else
        show_badge(false) -- Stays visible until pressed again
    end
end

-- Trigger file badge on playback start
local function trigger_file_badge()
    if opts.show_on_start and not state.file_badge_shown then
        local badge = detect_format()
        if badge then
            state.file_badge_shown = true
            show_badge(true) -- 2.5s display when video frame starts playing
        end
    end
end

local function on_mute_change(_, muted)
    state.is_muted = muted or false
    if state.visible and state.current_badge then
        state.overlay.data = generate_ass(state.current_badge)
        state.overlay:update()
    end
end

local function on_file_loaded()
    state.file_badge_shown = false
end

local function on_playback_restart()
    trigger_file_badge()
end

local function on_video_params(_, params)
    if params and not state.file_badge_shown then
        trigger_file_badge()
    end
end

local function on_pause_change(_, paused)
    if not paused and opts.show_on_unpause then
        show_badge(true)
    end
end

local function on_seek()
    if opts.show_on_seek then
        show_badge(true)
    end
end

-- Key & Script Bindings
mp.add_key_binding("l", "toggle-hdr-badge", toggle_badge)
mp.add_key_binding(nil, "show-hdr-badge", function() show_badge(true) end)

-- Register mpv observers
mp.observe_property("mute", "bool", on_mute_change)
mp.observe_property("video-params", "native", on_video_params)
mp.observe_property("pause", "bool", on_pause_change)
mp.register_event("file-loaded", on_file_loaded)
mp.register_event("playback-restart", on_playback_restart)
mp.register_event("seek", on_seek)
