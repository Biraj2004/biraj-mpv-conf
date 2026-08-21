-- cycle_audio.lua
-- High-performance VLC-style & MPV track cycler with instant OSD and anti-spam debouncing.
-- Protects video/audio playback from micro-stutters even during rapid key spamming.

local mp = require 'mp'

local DEBOUNCE_DELAY = 0.08 -- 80ms debounce window (perceptual instant threshold)
local OSD_DURATION = 2.0     -- 2.0 seconds display time (VLC standard 2000ms)

-- Audio State
local pending_aid = nil
local audio_timer = nil
local last_audio_idx = nil

-- Subtitle State
local pending_sid = nil
local sub_timer = nil
local last_sub_idx = nil

local function format_audio_osd(track, index, count)
    if not track then return "Audio: none" end
    local parts = {}
    if track.lang and track.lang ~= "" then
        table.insert(parts, "[" .. track.lang .. "]")
    end
    if track.title and track.title ~= "" then
        table.insert(parts, "'" .. track.title .. "'")
    end
    if track.external then
        table.insert(parts, "[ext]")
    end
    if track.codec and track.codec ~= "" then
        local details = track.codec
        if track["audio-channels"] then
            details = details .. " " .. track["audio-channels"] .. "ch"
        end
        if track["demux-samplerate"] then
            details = details .. " " .. track["demux-samplerate"] .. "Hz"
        end
        table.insert(parts, "(" .. details .. ")")
    end
    local desc = table.concat(parts, " ")
    if desc ~= "" then
        return string.format("Audio: (%d/%d) %s", index, count, desc)
    else
        return string.format("Audio: (%d/%d)", index, count)
    end
end

local function format_sub_osd(track, index, count)
    if not track or track.id == "no" then
        return "Subtitles: none"
    end
    local parts = {}
    if track.lang and track.lang ~= "" then
        table.insert(parts, "[" .. track.lang .. "]")
    end
    if track.title and track.title ~= "" then
        table.insert(parts, "'" .. track.title .. "'")
    end
    if track.forced then
        table.insert(parts, "[forced]")
    end
    if track.external then
        table.insert(parts, "[ext]")
    end
    if track.codec and track.codec ~= "" then
        table.insert(parts, "(" .. track.codec .. ")")
    end
    local desc = table.concat(parts, " ")
    if desc ~= "" then
        return string.format("Subtitles: (%d/%d) %s", index, count, desc)
    else
        return string.format("Subtitles: (%d/%d)", index, count)
    end
end

-- ==================== AUDIO CYCLING ====================

local function get_audio_tracks()
    local track_list = mp.get_property_native("track-list") or {}
    local tracks = {}
    for _, track in ipairs(track_list) do
        if track.type == "audio" then
            table.insert(tracks, track)
        end
    end
    return tracks
end

local function apply_audio_switch()
    if pending_aid ~= nil then
        mp.set_property("aid", tostring(pending_aid))
        pending_aid = nil
    end
    audio_timer = nil
    last_audio_idx = nil
end

local function cycle_audio(direction)
    local tracks = get_audio_tracks()
    local count = #tracks

    if count == 0 then
        mp.osd_message("No audio tracks", OSD_DURATION)
        return
    end

    local current_aid = pending_aid or mp.get_property_native("aid")
    local current_index = nil

    if pending_aid ~= nil then
        current_index = last_audio_idx
    end

    if not current_index then
        if current_aid == false or current_aid == "no" or not current_aid then
            current_index = 1
        else
            for i, track in ipairs(tracks) do
                if tostring(track.id) == tostring(current_aid) or track.selected then
                    current_index = i
                    break
                end
            end
        end
    end

    if count == 1 then
        last_audio_idx = 1
        pending_aid = tracks[1].id
        mp.osd_message(format_audio_osd(tracks[1], 1, 1), OSD_DURATION)
        if audio_timer then audio_timer:kill() end
        audio_timer = mp.add_timeout(DEBOUNCE_DELAY, apply_audio_switch)
        return
    end

    local step = (direction == "down" or direction == "prev") and -1 or 1
    local next_index
    if not current_index then
        next_index = (step == 1) and 1 or count
    else
        next_index = ((current_index - 1 + step) % count) + 1
    end

    last_audio_idx = next_index
    local next_track = tracks[next_index]
    pending_aid = next_track.id

    -- Instant visual OSD feedback with 0ms delay
    mp.osd_message(format_audio_osd(next_track, next_index, count), OSD_DURATION)

    -- Debounce heavy decoder initialization
    if audio_timer then audio_timer:kill() end
    audio_timer = mp.add_timeout(DEBOUNCE_DELAY, apply_audio_switch)
end

-- ==================== SUBTITLE CYCLING ====================

local function get_sub_tracks()
    local track_list = mp.get_property_native("track-list") or {}
    local tracks = {}
    for _, track in ipairs(track_list) do
        if track.type == "sub" then
            table.insert(tracks, track)
        end
    end
    return tracks
end

local function apply_sub_switch()
    if pending_sid ~= nil then
        mp.set_property("sid", tostring(pending_sid))
        pending_sid = nil
    end
    sub_timer = nil
    last_sub_idx = nil
end

local function cycle_sub(direction)
    local tracks = get_sub_tracks()
    local count = #tracks

    if count == 0 then
        mp.osd_message("No subtitles", OSD_DURATION)
        return
    end

    local current_sid = pending_sid
    local current_index = nil

    if pending_sid ~= nil then
        current_index = last_sub_idx
    else
        current_sid = mp.get_property_native("sid")
    end

    if not current_index then
        if current_sid == false or current_sid == "no" or not current_sid then
            current_index = 0 -- "none" state
        else
            for i, track in ipairs(tracks) do
                if tostring(track.id) == tostring(current_sid) or track.selected then
                    current_index = i
                    break
                end
            end
            if not current_index then
                current_index = 0
            end
        end
    end

    -- Subtitles cycle through 1..N and 0 (none/off)
    -- Total cycle states = count + 1
    local total_states = count + 1
    local step = (direction == "down" or direction == "prev") and -1 or 1
    local next_state = (current_index + step) % total_states

    last_sub_idx = next_state

    if next_state == 0 then
        pending_sid = "no"
        mp.osd_message("Subtitles: none", OSD_DURATION)
    else
        local next_track = tracks[next_state]
        pending_sid = next_track.id
        mp.osd_message(format_sub_osd(next_track, next_state, count), OSD_DURATION)
    end

    -- Debounce libass font-loading and demuxer switches
    if sub_timer then sub_timer:kill() end
    sub_timer = mp.add_timeout(DEBOUNCE_DELAY, apply_sub_switch)
end

-- Reset state on new file or playback stop
local function reset_state()
    if audio_timer then audio_timer:kill(); audio_timer = nil end
    if sub_timer then sub_timer:kill(); sub_timer = nil end
    pending_aid = nil
    pending_sid = nil
    last_audio_idx = nil
    last_sub_idx = nil
end

mp.register_event("end-file", reset_state)
mp.register_event("file-loaded", reset_state)

-- Keybindings
mp.add_key_binding(nil, "cycle-audio", function() cycle_audio("up") end)
mp.add_key_binding(nil, "cycle-audio-back", function() cycle_audio("down") end)
mp.add_key_binding(nil, "cycle-sub", function() cycle_sub("up") end)
mp.add_key_binding(nil, "cycle-sub-back", function() cycle_sub("down") end)
