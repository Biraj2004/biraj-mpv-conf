-- cycle_audio.lua
-- High-performance VLC-style & MPV track cycler with instant OSD and anti-spam debouncing.
-- Protects video/audio playback from micro-stutters even during rapid key spamming.

local mp = require 'mp'

local DEBOUNCE_DELAY = 0.03 -- 30ms debounce window (ultra-fast near-instant response while preventing decoder thrashing)
local OSD_DURATION = 2.5     -- 2.5 seconds display time (universal OSD duration)

-- Helper to display OSD and notify pause_notify for dynamic collision avoidance
local function show_osd(text, duration)
    local dur = duration or OSD_DURATION
    mp.osd_message(text, dur)
    mp.commandv("script-message-to", "pause_notify", "osd-notify", text, tostring(dur))
end

-- Audio State
local pending_aid = nil
local audio_timer = nil
local last_audio_idx = nil

-- Subtitle State
local pending_sid = nil
local sub_timer = nil
local last_sub_idx = nil
local last_selected_sid = nil

-- Track active subtitle selection across external changes (OSC, menu, watch-later)
mp.observe_property("sid", "native", function(_, sid)
    if sid and sid ~= "no" and sid ~= false then
        last_selected_sid = sid
    end
end)

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
        show_osd("No audio tracks", OSD_DURATION)
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
                if tostring(track.id) == tostring(current_aid) then
                    current_index = i
                    break
                end
            end
            if not current_index then
                for i, track in ipairs(tracks) do
                    if track.selected then
                        current_index = i
                        break
                    end
                end
            end
        end
    end

    if count == 1 then
        last_audio_idx = 1
        pending_aid = tracks[1].id
        show_osd(format_audio_osd(tracks[1], 1, 1), OSD_DURATION)
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
    show_osd(format_audio_osd(next_track, next_index, count), OSD_DURATION)

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
        show_osd("No subtitles", OSD_DURATION)
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
                if tostring(track.id) == tostring(current_sid) then
                    current_index = i
                    break
                end
            end
            if not current_index then
                for i, track in ipairs(tracks) do
                    if track.selected then
                        current_index = i
                        break
                    end
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
        show_osd("Subtitles: none", OSD_DURATION)
    else
        local next_track = tracks[next_state]
        pending_sid = next_track.id
        last_selected_sid = next_track.id
        show_osd(format_sub_osd(next_track, next_state, count), OSD_DURATION)
    end

    -- Debounce libass font-loading and demuxer switches
    if sub_timer then sub_timer:kill() end
    sub_timer = mp.add_timeout(DEBOUNCE_DELAY, apply_sub_switch)
end

-- ==================== SUBTITLE TOGGLE (ON / OFF) ====================

-- Calculates a deterministic quality/priority score for an English subtitle track.
-- Higher score = better candidate for automatic activation.
local function score_english_track(track)
    if not track then return -1000 end
    local lang = (track.lang or ""):lower()
    local title = (track.title or ""):lower()
    local codec = (track.codec or ""):lower()

    -- Check if this is an English track
    local is_eng = false
    if lang == "en" or lang == "eng" or lang == "enm"
       or lang:find("^en%-") or lang:find("^eng%-")
       or lang:find("^en_") or lang:find("^eng_") then
        is_eng = true
    elseif title:find("english") or title:find("%f[%a]eng%f[%A]") then
        is_eng = true
    end

    if not is_eng then
        return -1000
    end

    local score = 100

    -- 1. Heavily penalize commentary tracks
    if title:find("commentary") then
        score = score - 150
    end

    -- 2. Penalize forced / signs tracks (when turning ON subtitles, user wants full dialogue)
    if track.forced or title:find("forced") or title:find("signs") then
        score = score - 60
    end

    -- 3. Prefer regular dialogue over SDH / hearing-impaired
    local is_sdh = track["hearing-impaired"] or title:find("sdh")
                   or title:find("%f[%a]cc%f[%A]") or title:find("hearing")
    if not is_sdh then
        score = score + 25 -- Clean dialogue bonus
    end

    -- 4. Prefer vector/text subtitles (ASS, SubRip, WebVTT) over heavy bitmap formats (PGS, VobSub)
    -- Text subtitles render with zero lag, scale cleanly, and obey mpv.conf font styles
    if codec == "subrip" or codec == "ass" or codec == "ssa" or codec == "webvtt" or codec == "mov_text" then
        score = score + 20
    end

    -- 5. Prefer container default flag if marked by the media author
    if track["default"] then
        score = score + 15
    end

    -- 6. Prefer external subtitles placed alongside video
    if track.external then
        score = score + 10
    end

    return score
end

local function toggle_sub()
    local tracks = get_sub_tracks()
    local count = #tracks

    if count == 0 then
        show_osd("No subtitles", OSD_DURATION)
        return
    end

    local current_sid = pending_sid
    if current_sid == nil then
        current_sid = mp.get_property_native("sid")
    end

    local is_active = (current_sid ~= false and current_sid ~= "no" and current_sid ~= nil)

    if is_active then
        -- TOGGLE OFF: Remember active track and turn off
        if current_sid ~= "no" and current_sid ~= false then
            last_selected_sid = current_sid
        end
        pending_sid = "no"
        last_sub_idx = 0
        show_osd("Subtitles: off", OSD_DURATION)
    else
        -- TOGGLE ON: Restore last selected track or search for English track
        local target_track = nil
        local target_idx = nil

        -- Step 1: Check if last_selected_sid is valid in current tracks
        if last_selected_sid then
            for i, track in ipairs(tracks) do
                if tostring(track.id) == tostring(last_selected_sid) then
                    target_track = track
                    target_idx = i
                    break
                end
            end
        end

        -- Step 2: If not selected before or previous track no longer exists:
        -- Evaluate all tracks using priority scoring to pick the best English version
        -- (prioritizes clean dialogue > SDH > forced, text SRT/ASS > bitmap PGS)
        if not target_track then
            local best_score = -50
            for i, track in ipairs(tracks) do
                local s = score_english_track(track)
                if s > best_score and s > 0 then
                    best_score = s
                    target_track = track
                    target_idx = i
                end
            end
        end

        -- Step 3: If no English track found, show OSD notice and do not turn on
        if not target_track then
            show_osd("Subtitles: no English track found", OSD_DURATION)
            return
        end

        pending_sid = target_track.id
        last_selected_sid = target_track.id
        last_sub_idx = target_idx
        show_osd(format_sub_osd(target_track, target_idx, count), OSD_DURATION)
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
    last_selected_sid = nil
end

mp.register_event("end-file", reset_state)
mp.register_event("file-loaded", reset_state)

-- Keybindings & Script Messages
mp.add_key_binding(nil, "cycle-audio", function() cycle_audio("up") end)
mp.add_key_binding(nil, "cycle-audio-back", function() cycle_audio("down") end)
mp.add_key_binding(nil, "cycle-sub", function() cycle_sub("up") end)
mp.add_key_binding(nil, "cycle-sub-back", function() cycle_sub("down") end)
mp.add_key_binding(nil, "toggle-sub", toggle_sub)
mp.register_script_message("toggle-sub", toggle_sub)
