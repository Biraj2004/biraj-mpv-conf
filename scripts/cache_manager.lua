-- cache_manager.lua
-- Centralized Cache Architecture for mpv
-- Ensures the common parent cache directory and all segregated subfolders
-- (shaders, watch_later, thumbnails) are automatically created on startup if deleted or absent.

local utils = require "mp.utils"

local function init_cache_dirs()
    local cache_root = mp.command_native({"expand-path", "~~cache/"})
    if not cache_root or cache_root == "" then return end

    local is_windows = mp.get_property("platform") == "windows" or (package.config:sub(1,1) == "\\")
    local sep = is_windows and "\\" or "/"

    -- Ensure trailing separator
    if cache_root:sub(-1) ~= "/" and cache_root:sub(-1) ~= "\\" then
        cache_root = cache_root .. sep
    end

    local subdirs = {
        "shaders",
        "watch_later",
        "thumbnails",
        "icc",
        "demuxer"
    }

    for _, sub in ipairs(subdirs) do
        local full_path = cache_root .. sub
        local info = utils.file_info(full_path)
        if not (info and info.is_dir) then
            if is_windows then
                local win_path = full_path:gsub("/", "\\")
                utils.subprocess({
                    args = { "cmd.exe", "/c", "mkdir", win_path },
                    cancellable = false,
                })
            else
                utils.subprocess({
                    args = { "mkdir", "-p", full_path },
                    cancellable = false,
                })
            end
        end
    end

    -- Ensure configured screenshot directory exists
    local shot_dir = mp.get_property("screenshot-directory")
    if shot_dir and shot_dir ~= "" then
        local exp_shot_dir = mp.command_native({"expand-path", shot_dir})
        if exp_shot_dir and exp_shot_dir ~= "" then
            local shot_info = utils.file_info(exp_shot_dir)
            if not (shot_info and shot_info.is_dir) then
                if is_windows then
                    local win_path = exp_shot_dir:gsub("/", "\\")
                    utils.subprocess({
                        args = { "cmd.exe", "/c", "mkdir", win_path },
                        cancellable = false,
                    })
                else
                    utils.subprocess({
                        args = { "mkdir", "-p", exp_shot_dir },
                        cancellable = false,
                    })
                end
            end
        end
    end

    -- Automatically purge stale scratch files & legacy root files
    local now = os.time()

    -- 1. Clean orphaned thumbnail buffers older than 30 mins (from force-killed sessions)
    local thumb_dir = cache_root .. "thumbnails" .. sep
    local thumb_files = utils.readdir(thumb_dir, "files")
    if thumb_files then
        for _, fname in ipairs(thumb_files) do
            local fpath = thumb_dir .. fname
            local finfo = utils.file_info(fpath)
            if finfo and finfo.mtime and (now - finfo.mtime > 1800) then
                os.remove(fpath)
            end
        end
    end

    -- 2. Clean orphaned demuxer disk chunks older than 30 mins
    local demux_dir = cache_root .. "demuxer" .. sep
    local demux_files = utils.readdir(demux_dir, "files")
    if demux_files then
        for _, fname in ipairs(demux_files) do
            local fpath = demux_dir .. fname
            local finfo = utils.file_info(fpath)
            if finfo and finfo.mtime and (now - finfo.mtime > 1800) then
                os.remove(fpath)
            end
        end
    end

    -- 3. Clean legacy unsegregated shader files in cache root
    local root_files = utils.readdir(cache_root, "files")
    if root_files then
        for _, fname in ipairs(root_files) do
            if fname:match("^shader_") then
                os.remove(cache_root .. fname)
            end
        end
    end

    -- 4. Clean watch_later resume state files older than 90 days (7,776,000s)
    local wl_prop = mp.get_property("watch-later-directory")
    local wl_dir = (wl_prop and wl_prop ~= "") and mp.command_native({"expand-path", wl_prop}) or (cache_root .. "watch_later")
    if wl_dir:sub(-1) ~= "/" and wl_dir:sub(-1) ~= "\\" then
        wl_dir = wl_dir .. sep
    end
    local wl_files = utils.readdir(wl_dir, "files")
    if wl_files then
        local max_wl_age = 90 * 86400 -- 90 days
        for _, fname in ipairs(wl_files) do
            local fpath = wl_dir .. fname
            local finfo = utils.file_info(fpath)
            if finfo and finfo.mtime and (now - finfo.mtime > max_wl_age) then
                os.remove(fpath)
            end
        end
    end
end

-- Initialize non-blockingly after playback starts to eliminate cold-start launch contention
mp.add_timeout(4.0, init_cache_dirs)