--[[
    sort_playlist.lua - Natural Ascending Playlist Sorter for mpv
    
    When multiple files are dropped or loaded into mpv, sorts the playlist
    in natural alphanumeric ascending order (e.g. Episode 1, Episode 2, ... Episode 10).
    Preserves the currently playing file without restarting playback.
--]]

local utils = require 'mp.utils'

local function padnum(n, d)
    return #d > 0 and ("%03d%s%.12f"):format(#n, n, tonumber(d) / (10 ^ #d))
        or ("%03d%s"):format(#n, n)
end

local function alphanum_key(filename)
    if not filename or filename == "" then return "" end
    local _, fn = utils.split_path(filename)
    local target = (fn and fn ~= "") and fn or filename
    return target:lower():gsub("0*(%d+)%.?(%d*)", padnum)
end

local is_sorting = false

local function sort_playlist(silent)
    if is_sorting then return end
    
    local pl = mp.get_property_native("playlist", {})
    if not pl or #pl <= 1 then
        if not silent then
            mp.osd_message("Playlist: Only 1 item (no sorting needed)", 2)
        end
        return
    end

    -- Check if already sorted
    local already_sorted = true
    local last_key = ""
    for i, entry in ipairs(pl) do
        local key = alphanum_key(entry.filename)
        if i > 1 and key < last_key then
            already_sorted = false
            break
        end
        last_key = key
    end

    if already_sorted then
        if not silent then
            mp.osd_message("Playlist already sorted (ascending)", 2)
        end
        return
    end

    is_sorting = true

    -- Create indexed list of sorted target items
    local sorted_items = {}
    local current_list = {}
    for i, entry in ipairs(pl) do
        table.insert(current_list, entry.filename)
        table.insert(sorted_items, {
            filename = entry.filename,
            key = alphanum_key(entry.filename)
        })
    end

    table.sort(sorted_items, function(a, b)
        if a.key == b.key then
            return (a.filename or "") < (b.filename or "")
        end
        return a.key < b.key
    end)

    -- Accurately simulate moves so asynchronous mpv indices are 100% synchronized
    for target_pos = 1, #sorted_items do
        local target_fn = sorted_items[target_pos].filename
        local current_idx = nil
        for idx, fn in ipairs(current_list) do
            if fn == target_fn then
                current_idx = idx
                break
            end
        end
        if current_idx and current_idx ~= target_pos then
            -- mpv uses 0-based indexing for playlist-move
            mp.commandv("playlist-move", current_idx - 1, target_pos - 1)
            local item = table.remove(current_list, current_idx)
            table.insert(current_list, target_pos, item)
        end
    end

    is_sorting = false

    if not silent then
        mp.osd_message("Playlist sorted in ascending order", 2)
    end
end

-- Debounce timer to allow all dropped files to finish queuing before sorting
local sort_timer = nil
local function request_sort(silent)
    if sort_timer then
        sort_timer:kill()
        sort_timer = nil
    end
    sort_timer = mp.add_timeout(0.12, function()
        sort_timer = nil
        sort_playlist(silent)
    end)
end

-- Automatically sort when multiple files are dropped or loaded
local last_count = 0
mp.observe_property("playlist-count", "number", function(_, count)
    if not count then return end
    if count > 1 and count ~= last_count then
        request_sort(true)
    end
    last_count = count
end)

mp.register_event("start-file", function()
    local count = mp.get_property_number("playlist-count", 0)
    if count > 1 then
        request_sort(true)
    end
end)

local function manual_trigger()
    if sort_timer then
        sort_timer:kill()
        sort_timer = nil
    end
    sort_playlist(false)
end

mp.add_key_binding(nil, "sort-playlist", manual_trigger)
mp.add_key_binding(nil, "sort_playlist", manual_trigger)
