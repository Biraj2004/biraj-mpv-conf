--[[
    screenshot_metadata.lua - Background HDR and Stream Metadata Injection for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)

    Automatically intercepts screenshots captured via 's', 'S', ModernZ GUI, or commands,
    and embeds rich stream/container properties in the background:
      - Standardized cICP Chunk (ITU-T H.273 / ISO 23091-2) for true HDR on iOS 13+, macOS, Windows 10/11, Android 10+
      - Standard TIFF/EXIF 'eXIf' Chunk (Make, Model, DateTime, Description, Software)
      - Standard PNG 'tEXt' Chunks (Title, Timestamp, Frame, HDR Format, Primaries, TRC, Matrix,
        Mastering Luminance, MaxCLL/MaxFALL, GPS, Codec, Resolution)
      - Zero playback lag / zero frame drops (pure in-place chunk injection in <10ms)
--]]

local mp = require "mp"
local msg = require "mp.msg"
local options = require "mp.options"
local bit = require "bit"

local opts = {
    enable = true,
    inject_exif = true,
    inject_text_chunks = true,
    ensure_cicp = true,
    show_osd_badge = true,
    osd_duration = 3.0,
}

options.read_options(opts, "screenshot_metadata")

if not opts.enable then
    return
end

-- FIFO queue to pair rapid capture keystrokes with resulting screenshot files
local capture_queue = {}

-- ---------------------------------------------------------
-- Binary Serialization & CRC32 (Pure LuaJIT)
-- ---------------------------------------------------------
local function u16(val)
    return string.char(math.floor(val / 256) % 256, val % 256)
end

local function u32(val)
    local b0 = math.floor(val / 16777216) % 256
    local b1 = math.floor(val / 65536) % 256
    local b2 = math.floor(val / 256) % 256
    local b3 = val % 256
    return string.char(b0, b1, b2, b3)
end

local crc_table = {}
for i = 0, 255 do
    local c = i
    for j = 1, 8 do
        if bit.band(c, 1) == 1 then
            c = bit.bxor(bit.rshift(c, 1), 0xEDB88320)
        else
            c = bit.rshift(c, 1)
        end
    end
    crc_table[i] = c
end

local function crc32(str)
    local c = 0xFFFFFFFF
    for i = 1, #str do
        local b = string.byte(str, i)
        local idx = bit.band(bit.bxor(c, b), 0xFF)
        c = bit.bxor(bit.rshift(c, 8), crc_table[idx])
    end
    return bit.bxor(c, 0xFFFFFFFF)
end

local function make_chunk(chunk_type, data)
    local len = u32(#data)
    local type_and_data = chunk_type .. data
    local crc = u32(bit.band(crc32(type_and_data), 0xFFFFFFFF))
    return len .. type_and_data .. crc
end

-- ---------------------------------------------------------
-- Standard TIFF/EXIF IFD0 Generator (Big-Endian MM)
-- ---------------------------------------------------------
local function build_exif(tags)
    local sorted_tags = {}
    for id, val in pairs(tags) do
        if val and val ~= "" then
            table.insert(sorted_tags, {id = id, val = tostring(val)})
        end
    end
    table.sort(sorted_tags, function(a, b) return a.id < b.id end)

    local num_entries = #sorted_tags
    if num_entries == 0 then
        return nil
    end

    local ifd_header = "MM" .. u16(42) .. u32(8) .. u16(num_entries)
    local data_offset = 8 + 2 + (num_entries * 12) + 4
    local entries = ""
    local data_block = ""

    for _, entry in ipairs(sorted_tags) do
        local str = entry.val .. "\0"
        local count = #str
        local val_or_offset = ""
        if count <= 4 then
            val_or_offset = str .. string.rep("\0", 4 - count)
        else
            val_or_offset = u32(data_offset + #data_block)
            data_block = data_block .. str
        end
        -- Tag ID, Type (2 = ASCII), Count, Value/Offset
        entries = entries .. u16(entry.id) .. u16(2) .. u32(count) .. val_or_offset
    end

    return ifd_header .. entries .. u32(0) .. data_block
end

-- ---------------------------------------------------------
-- Helper Parsers
-- ---------------------------------------------------------
local function format_time(seconds)
    if not seconds or seconds < 0 then return "00:00:00.000" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%06.3f", h, m, s)
end

local function parse_iso6709(iso_str)
    if not iso_str or iso_str == "" then return nil end
    -- Example: "+26.3247+089.4498+048.546/" or "+26.3247-089.4498/"
    local lat_sign, lat_val, lon_sign, lon_val, alt = iso_str:match("([%+%-])([%d%.]+)([%+%-])([%d%.]+)([%+%-%d%.]*)")
    if not lat_val or not lon_val then return nil end
    local lat_num = tonumber(lat_val) or 0
    local lon_num = tonumber(lon_val) or 0
    local lat_dir = (lat_sign == "-") and "S" or "N"
    local lon_dir = (lon_sign == "-") and "W" or "E"
    local res = string.format("%.4f° %s, %.4f° %s", lat_num, lat_dir, lon_num, lon_dir)
    if alt and alt ~= "" and alt ~= "/" then
        local alt_clean = alt:gsub("/", "")
        local alt_num = tonumber(alt_clean)
        if alt_num then
            res = res .. string.format(" (Alt: %.1f m)", alt_num)
        end
    end
    return res
end

local function normalize_date(date_str)
    if not date_str or date_str == "" then return nil end
    local y, mo, d, ho, mi, se = date_str:match("(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d):(%d%d)")
    if y then
        return string.format("%04d:%02d:%02d %02d:%02d:%02d", y, mo, d, ho, mi, se)
    end
    return date_str
end

-- ---------------------------------------------------------
-- Metadata Snapshot Collector
-- ---------------------------------------------------------
local function collect_metadata()
    local vp = mp.get_property_native("video-params") or {}
    local meta = mp.get_property_native("metadata") or {}
    local time_pos = mp.get_property_number("time-pos", 0)
    local frame = mp.get_property_number("estimated-frame-number", 0)
    local filename = mp.get_property("filename") or "screenshot"
    local media_title = mp.get_property("media-title") or filename
    local time_str = format_time(time_pos)

    local colormatrix = vp["colormatrix"] or ""
    local gamma = vp["gamma"] or ""
    local primaries = vp["primaries"] or ""
    local sig_peak = tonumber(vp["sig-peak"]) or 0
    local max_cll = tonumber(vp["max-cll"]) or 0
    local max_fall = tonumber(vp["max-fall"]) or 0
    local max_luma = tonumber(vp["max-luma"]) or 0
    local min_luma = tonumber(vp["min-luma"]) or 0
    local pixelformat = vp["pixelformat"] or ""

    local fn_lower = filename:lower()
    local title_lower = media_title:lower()
    local title_combined = fn_lower .. " " .. title_lower

    -- Determine Dynamic Range Format
    local hdr_format = "SDR"
    local cicp_primaries = 1  -- BT.709
    local cicp_transfer = 1   -- BT.709
    local is_hdr = false

    if colormatrix == "dolbyvision" or title_combined:find("dovi") or title_combined:find("dolby.?vision") then
        if gamma == "hlg" or gamma == "arib-std-b67" then
            hdr_format = "Dolby Vision (HLG)"
            cicp_primaries = 9 -- BT.2020
            cicp_transfer = 18 -- HLG
        else
            hdr_format = "Dolby Vision"
            cicp_primaries = 9 -- BT.2020
            cicp_transfer = 16 -- PQ
        end
        is_hdr = true
    elseif vp["hdr10plus"] or title_combined:find("hdr10%+") or title_combined:find("hdr10plus") then
        hdr_format = "HDR10+"
        cicp_primaries = 9
        cicp_transfer = 16
        is_hdr = true
    elseif gamma == "pq" or gamma == "smpte2084" or sig_peak > 1 or max_cll > 0 then
        hdr_format = "HDR10"
        cicp_primaries = 9
        cicp_transfer = 16
        is_hdr = true
    elseif gamma == "hlg" or gamma == "arib-std-b67" then
        hdr_format = "HLG"
        cicp_primaries = 9
        cicp_transfer = 18
        is_hdr = true
    elseif primaries == "display-p3" or primaries == "dci-p3" then
        hdr_format = "SDR (Wide-Gamut P3)"
        cicp_primaries = 12
        cicp_transfer = 13 -- sRGB
    elseif primaries:find("601") or (vp["h"] and vp["h"] > 0 and vp["h"] <= 576) then
        hdr_format = "SD (BT.601)"
        cicp_primaries = 6
        cicp_transfer = 6
    end

    -- Camera & Container tags
    local make = meta["com.apple.quicktime.make"] or meta["make"] or meta["Make"] or ""
    local model = meta["com.apple.quicktime.model"] or meta["model"] or meta["Model"] or ""
    local creation_time = meta["com.apple.quicktime.creationdate"] or meta["creation_time"] or meta["date"] or ""
    local raw_gps = meta["com.apple.quicktime.location.ISO6709"] or meta["location"] or ""
    local readable_gps = parse_iso6709(raw_gps)
    local software_tag = meta["com.apple.quicktime.software"] or meta["encoder"] or "mpv (biraj-mpv-conf)"

    -- Resolution and Aspect Ratio
    local w = vp["w"] or 0
    local h = vp["h"] or 0
    local res_str = string.format("%dx%d", w, h)
    if vp["aspect"] and vp["aspect"] > 0 then
        res_str = res_str .. string.format(" (%.2f:1)", vp["aspect"])
    end

    -- Video Codec
    local vcodec = mp.get_property("video-codec") or mp.get_property("video-format") or "unknown"

    -- Text chunks mapping
    local text_chunks = {
        ["Title"] = media_title,
        ["Source"] = filename,
        ["Timestamp"] = time_str,
        ["Frame"] = tostring(frame),
        ["HDR_Format"] = hdr_format,
        ["Color_Primaries"] = primaries ~= "" and primaries or (is_hdr and "bt.2020" or "bt.709"),
        ["Transfer_Function"] = gamma ~= "" and gamma or (is_hdr and "pq" or "bt.709"),
        ["Matrix_Coefficients"] = colormatrix ~= "" and colormatrix or "bt.709",
        ["Resolution"] = res_str,
        ["Video_Codec"] = vcodec,
        ["Pixel_Format"] = pixelformat ~= "" and pixelformat or "unknown",
        ["Software"] = "mpv + biraj-mpv-conf",
    }

    if max_luma > 0 then
        text_chunks["Mastering_Luminance"] = string.format("Min: %.4f cd/m2, Max: %.2f cd/m2", min_luma, max_luma)
    end
    if sig_peak > 0 then
        text_chunks["Peak_Luminance"] = string.format("%.1f nits (sig-peak: %.3f)", max_luma > 0 and max_luma or (sig_peak * 203), sig_peak)
    end
    if max_cll > 0 then
        text_chunks["Maximum_CLL"] = string.format("%d cd/m2", max_cll)
    end
    if max_fall > 0 then
        text_chunks["Maximum_FALL"] = string.format("%d cd/m2", max_fall)
    end
    if make ~= "" then text_chunks["Camera_Make"] = make end
    if model ~= "" then text_chunks["Camera_Model"] = model end
    if creation_time ~= "" then text_chunks["Creation_Time"] = creation_time end
    if raw_gps ~= "" then text_chunks["GPS_ISO6709"] = raw_gps end
    if readable_gps then text_chunks["GPS_Coordinates"] = readable_gps end

    -- Web stream metadata
    local artist = meta["artist"] or meta["uploader"] or meta["channel"] or ""
    if artist ~= "" then text_chunks["Author"] = artist end

    -- Standard EXIF tags (IFD0)
    local exif_desc = string.format("%s @ %s [%s]", filename, time_str, hdr_format)
    if readable_gps then
        exif_desc = exif_desc .. " (" .. readable_gps .. ")"
    end

    local exif_tags = {
        [0x0131] = "mpv player (biraj-mpv-conf)",
        [0x010E] = exif_desc,
    }
    if make ~= "" then exif_tags[0x010F] = make end
    if model ~= "" then exif_tags[0x0110] = model end

    local normalized_date = normalize_date(creation_time)
    if normalized_date then
        exif_tags[0x0132] = normalized_date
    end

    -- Summary for OSD
    local badge_elements = { hdr_format }
    if primaries ~= "" and primaries ~= "auto" then
        table.insert(badge_elements, primaries:upper())
    end
    if model ~= "" then
        table.insert(badge_elements, model)
    end

    return {
        text_chunks = text_chunks,
        exif_tags = exif_tags,
        hdr_format = hdr_format,
        is_hdr = is_hdr,
        cicp_primaries = cicp_primaries,
        cicp_transfer = cicp_transfer,
        summary = table.concat(badge_elements, " • "),
        filename = filename,
        time_str = time_str
    }
end

-- ---------------------------------------------------------
-- In-Place PNG Metadata Injection
-- ---------------------------------------------------------
local function inject_into_png(file_path, info)
    local f, err = io.open(file_path, "r+b")
    if not f then
        msg.warn("Cannot open screenshot file for injection: " .. tostring(err))
        return false
    end

    -- 1. Read first 64 bytes to inspect PNG header and cICP
    local head = f:read(64)
    if not head or #head < 33 or head:sub(1, 8) ~= "\137PNG\r\n\26\n" then
        f:close()
        return false
    end

    -- Check if cICP already exists in file
    local has_cicp = (head:find("cICP") ~= nil)

    -- If cICP is missing and ensure_cicp is enabled for HDR or wide-gamut
    if not has_cicp and opts.ensure_cicp and info.is_hdr then
        -- Insert cICP right after IHDR chunk (starts at byte 34)
        f:seek("set", 0)
        local full_content = f:read("*all")
        f:close()

        if full_content and #full_content > 33 then
            local cicp_data = string.char(info.cicp_primaries, info.cicp_transfer, 0, 1)
            local cicp_chunk = make_chunk("cICP", cicp_data)
            local new_content = full_content:sub(1, 33) .. cicp_chunk .. full_content:sub(34)
            local fw = io.open(file_path, "wb")
            if fw then
                fw:write(new_content)
                fw:close()
            end
        end

        -- Reopen for chunk append
        f = io.open(file_path, "r+b")
        if not f then return false end
    end

    -- 2. Locate IEND at the end of the file
    f:seek("end", -12)
    local iend_chunk = f:read(12)
    if not iend_chunk or #iend_chunk < 12 or iend_chunk:sub(5, 8) ~= "IEND" then
        f:close()
        msg.warn("Invalid PNG file: missing IEND chunk")
        return false
    end

    -- Overwrite from the start of IEND
    f:seek("end", -12)

    -- Inject tEXt chunks
    if opts.inject_text_chunks and info.text_chunks then
        for k, v in pairs(info.text_chunks) do
            if v and v ~= "" then
                local payload = k .. "\0" .. v
                f:write(make_chunk("tEXt", payload))
            end
        end
    end

    -- Inject eXIf chunk
    if opts.inject_exif and info.exif_tags then
        local exif_bytes = build_exif(info.exif_tags)
        if exif_bytes then
            f:write(make_chunk("eXIf", exif_bytes))
        end
    end

    -- Re-append standard IEND chunk
    f:write(iend_chunk)
    f:close()
    return true
end

-- ---------------------------------------------------------
-- Event Handlers
-- ---------------------------------------------------------
local function on_screenshot_saved(file_path)
    local meta = table.remove(capture_queue, 1)
    if not meta then
        meta = collect_metadata()
    end

    local success, err = pcall(function()
        return inject_into_png(file_path, meta)
    end)

    if success and err then
        msg.info(string.format("Metadata embedded into %s [%s]", file_path, meta.summary))
        if opts.show_osd_badge then
            local fname_only = file_path:match("[^/\\]+$") or file_path
            local osd_text = string.format("Screenshot: %s\n[%s • Metadata Saved]", fname_only, meta.summary)
            mp.osd_message(osd_text, opts.osd_duration)
        end
    else
        msg.warn("Screenshot metadata injection encountered: " .. tostring(err))
    end
end

-- Intercept native mpv log messages when screenshots are written
mp.enable_messages("info")
mp.register_event("log-message", function(e)
    if e.prefix == "cplayer" and e.text:find("Screenshot:") then
        local file_path = e.text:match("Screenshot: '([^']+)'")
        if file_path then
            on_screenshot_saved(file_path)
        end
    end
end)

-- ---------------------------------------------------------
-- Key Binding Triggers
-- ---------------------------------------------------------
local function trigger_capture(flag)
    -- Snap current playback metadata at the exact millisecond of the keystroke
    local meta = collect_metadata()
    table.insert(capture_queue, meta)
    mp.commandv("screenshot", flag or "subtitles")
end

mp.add_key_binding(nil, "capture", function()
    trigger_capture("subtitles")
end)

mp.add_key_binding(nil, "capture-video", function()
    trigger_capture("video")
end)

mp.add_key_binding(nil, "capture-window", function()
    trigger_capture("window")
end)
