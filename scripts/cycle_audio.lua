-- cycle_audio.lua
-- Cycles strictly between available audio tracks without selecting "no" (audio disabled), matching VLC behavior.

local mp = require 'mp'

local function get_audio_tracks()
    local track_list = mp.get_property_native("track-list") or {}
    local audio_tracks = {}
    for _, track in ipairs(track_list) do
        if track.type == "audio" then
            table.insert(audio_tracks, track)
        end
    end
    return audio_tracks
end

local function cycle_audio(direction)
    local audio_tracks = get_audio_tracks()
    local count = #audio_tracks

    if count == 0 then
        mp.osd_message("No audio tracks", 2)
        return
    end

    local current_aid = mp.get_property_native("aid")
    local current_index = nil

    for i, track in ipairs(audio_tracks) do
        if track.id == current_aid or track.selected then
            current_index = i
            break
        end
    end

    if count == 1 then
        -- Only 1 track: show OSD without disabling audio
        mp.commandv("osd-msg", "set", "aid", tostring(audio_tracks[1].id))
        return
    end

    local step = (direction == "down" or direction == "prev") and -1 or 1
    local next_index
    if not current_index then
        next_index = 1
    else
        next_index = ((current_index - 1 + step) % count) + 1
    end

    local next_track = audio_tracks[next_index]
    mp.commandv("osd-msg", "set", "aid", tostring(next_track.id))
end

mp.add_key_binding(nil, "cycle-audio", function() cycle_audio("up") end)
mp.add_key_binding(nil, "cycle-audio-back", function() cycle_audio("down") end)
