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
end

-- Initialize on mpv startup
init_cache_dirs()

