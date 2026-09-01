--[[
    sort_playlist.lua - Natural Ascending Video Playlist Sorter & Filter for mpv
    
    1. Video-Only Filtering: When multiple files or directories are dropped/loaded into mpv,
       automatically filters out non-video files (e.g. .txt, .nfo, .srt, .mp3, .jpg, .png)
       so the playlist list contains only playable videos. Subtitles (.srt, .ass, etc.)
       are auto-loaded directly to the matching video's subtitle tracks via MPV fuzzy matching
       without cluttering the playlist list.
    2. Natural Sorting: Sorts the playlist in natural alphanumeric ascending order
       (e.g. Episode 1, Episode 2, ... Episode 10, Episode 21).
    3. Seamless: Preserves the currently playing file without restarting playback.
--]]

local utils = require 'mp.utils'

local allowed_exts = nil

local function build_allowed_extensions()
    local allowed = {}
    
    -- Load user-configured or mpv default video extensions
    local val = mp.get_property("video-exts") or ""
    for ext in val:gmatch("[^,]+") do
        ext = ext:match("^%s*(.-)%s*$"):lower()
        if ext ~= "" then
            allowed[ext] = true
        end
    end

    -- Comprehensive video, playlist, and container fallback formats
    local default_video = {
        "3g2", "3gp", "asf", "avi", "f4v", "flv", "gif", "h264", "h265", "hevc",
        "ivf", "m2ts", "m4v", "mj2", "mkv", "mov", "mp4", "mp4v", "mpeg", "mpg",
        "mxf", "ogv", "rmvb", "ts", "webm", "wmv", "y4m", "dav", "vob", "divx",
        "m3u", "m3u8", "pls", "cue", "vdr", "iso", "bdmv"
    }
    for _, ext in ipairs(default_video) do
        allowed[ext] = true
    end

    -- Explicitly reject non-video files (audios, images, subtitles, documents, metadata)
    local non_video = {
        -- Subtitles & Metadata
        "srt", "ass", "ssa", "sub", "idx", "sup", "vtt", "smi", "rt",
        "txt", "nfo", "url", "exe", "bat", "cmd", "json", "xml", "ini",
        "torrent", "part", "aria2", "tmp", "log", "md", "pdf", "zip", "rar", "7z",
        -- Audio formats (handled by dedicated music players)
        "aac", "ac3", "aiff", "ape", "au", "dsf", "dts", "flac", "m4a", "mid",
        "midi", "mka", "mp1", "mp2", "mp3", "mpc", "oga", "ogg", "ogm", "opus",
        "tak", "thd", "tta", "wav", "wma", "wv", "alac",
        -- Image formats (handled by photo viewers)
        "apng", "avif", "bmp", "heic", "heif", "j2k", "jp2", "jpeg", "jpg",
        "jxl", "png", "qoi", "svg", "tga", "tif", "tiff", "webp", "ico"
    }
    for _, ext in ipairs(non_video) do
        allowed[ext] = nil
    end

    return allowed
end

local function is_valid_video(path)
    if not path or path == "" then return false end

    -- Check for URLs, protocols, pipes, stdin, special mpv video targets
    if path:find("^%a[%w+.-]*://") or path:find("^edl://") or path:find("^fd://") or path:find("^memory://") or path == "-" then
        return true
    end

    if not allowed_exts then
        allowed_exts = build_allowed_extensions()
    end

    -- Extract file extension (case-insensitive)
    local ext = path:match("%.([^./\\]+)$")
    if not ext then
        return false
    end

    return allowed_exts[ext:lower()] == true
end

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

local function clean_and_sort_playlist(silent)
    if is_sorting then return end

    local pl = mp.get_property_native("playlist", {})
    if not pl or #pl <= 1 then
        if not silent and pl and #pl == 1 then
            mp.osd_message("Playlist: 1 item", 2)
        end
        return
    end

    is_sorting = true

    -- Step 1: Filter out non-video files (.txt, .nfo, .srt, .mp3, .jpg, etc.) backwards to maintain index stability
    local removed_any = false
    for i = #pl, 1, -1 do
        local entry = pl[i]
        if not is_valid_video(entry.filename) then
            -- Remove from mpv's active playlist (0-based index)
            mp.commandv("playlist-remove", i - 1)
            table.remove(pl, i)
            removed_any = true
        end
    end

    -- If 0 or 1 items remain after filtering, no further sorting is needed
    if #pl <= 1 then
        is_sorting = false
        if removed_any and not silent then
            mp.osd_message("Playlist: Filtered non-video files", 2)
        end
        return
    end

    -- Step 2: Check if already sorted
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
        is_sorting = false
        if not silent then
            if removed_any then
                mp.osd_message("Playlist: Filtered non-video files (sorted)", 2)
            else
                mp.osd_message("Playlist already sorted (ascending)", 2)
            end
        end
        return
    end

    -- Step 3: Create indexed list of sorted target items
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

    -- Step 4: Accurately simulate moves so asynchronous mpv indices are 100% synchronized
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
        if removed_any then
            mp.osd_message("Playlist: Filtered non-video files & sorted", 2)
        else
            mp.osd_message("Playlist sorted in ascending order", 2)
        end
    end
end

-- Debounce timer to allow all dropped files to finish queuing before sorting
local sort_timer = nil
local function request_sort(silent)
    if sort_timer then
        sort_timer:kill()
        sort_timer = nil
    end
    sort_timer = mp.add_timeout(0.08, function()
        sort_timer = nil
        clean_and_sort_playlist(silent)
    end)
end

-- Automatically filter and sort when multiple files are dropped or loaded
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
    clean_and_sort_playlist(false)
end

mp.add_key_binding(nil, "sort-playlist", manual_trigger)
mp.add_key_binding(nil, "sort_playlist", manual_trigger)
