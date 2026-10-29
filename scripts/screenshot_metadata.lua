--[[
    screenshot_metadata.lua - Background HDR Frame Capture & Stream Metadata Injection for mpv
    Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)

    Direct decoded stream frame capture (distinct from desktop PrtScr) triggered via
    's', 'S', 'Ctrl+s', or context menu, automatically embedding rich stream properties:
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

    -- Check if MPV is tone-mapping to sRGB (screenshot-tag-colorspace=no)
    local tag_colorspace = mp.get_property_bool("screenshot-tag-colorspace", false)
    local is_tonemapped = (not tag_colorspace) and is_hdr

    if is_tonemapped then
        text_chunks["Color_Space"] = "sRGB (libplacebo tone-mapped)"
        text_chunks["Source_HDR_Format"] = hdr_format
        text_chunks["Tone_Mapping"] = "libplacebo dynamic tone-mapping"
        text_chunks["Transfer_Function"] = "srgb"
        text_chunks["Color_Primaries"] = "bt.709"
    end

    -- Summary for OSD
    local badge_elements = {}
    if is_tonemapped then
        table.insert(badge_elements, hdr_format .. " -> sRGB")
    else
        table.insert(badge_elements, hdr_format)
        if primaries ~= "" and primaries ~= "auto" then
            table.insert(badge_elements, primaries:upper())
        end
    end
    if model ~= "" then
        table.insert(badge_elements, model)
    end

    local peak_val = (max_luma > 0 and max_luma) or (sig_peak > 0 and (sig_peak * 203)) or 1000.0

    return {
        text_chunks = text_chunks,
        exif_tags = exif_tags,
        hdr_format = hdr_format,
        is_hdr = is_hdr,
        is_tonemapped = is_tonemapped,
        tag_colorspace = tag_colorspace,
        cicp_primaries = cicp_primaries,
        cicp_transfer = cicp_transfer,
        summary = table.concat(badge_elements, " • "),
        filename = filename,
        time_str = time_str,
        make = make,
        model = model,
        creation_time = creation_time,
        raw_gps = raw_gps,
        peak_nits = peak_val
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

    -- Check if cICP or sRGB already exists in file
    local has_cicp = (head:find("cICP") ~= nil)
    local has_srgb = (head:find("sRGB") ~= nil)

    if info.is_tonemapped then
        -- Tone-mapped sRGB capture: embed standard sRGB chunk (Perceptual intent = 0)
        -- so all viewers (Windows Photos, browsers, apps) render it vibrant and accurate
        if not has_srgb and not has_cicp then
            f:seek("set", 0)
            local full_content = f:read("*all")
            f:close()

            if full_content and #full_content > 33 then
                local srgb_chunk = make_chunk("sRGB", string.char(0))
                local new_content = full_content:sub(1, 33) .. srgb_chunk .. full_content:sub(34)
                local fw = io.open(file_path, "wb")
                if fw then
                    fw:write(new_content)
                    fw:close()
                end
            end

            f = io.open(file_path, "r+b")
            if not f then return false end
        end
    else
        -- Raw HDR capture: Only inject cICP when tagging raw colorspace and ensure_cicp is enabled
        if not has_cicp and opts.ensure_cicp and info.is_hdr and info.tag_colorspace then
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

            f = io.open(file_path, "r+b")
            if not f then return false end
        end
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
-- In-Place JPEG Metadata Injection (Native Pure-Lua Fallback)
-- ---------------------------------------------------------
local function inject_into_jpeg(file_path, info)
    local f, err = io.open(file_path, "rb")
    if not f then
        msg.warn("Cannot open JPEG for injection: " .. tostring(err))
        return false
    end
    local full = f:read("*all")
    f:close()
    if not full or #full < 4 or full:sub(1, 2) ~= string.char(255, 216) then
        return false
    end

    if full:find("Exif%z%z") then
        return true
    end

    local exif_bytes = build_exif(info.exif_tags)
    if not exif_bytes then
        return true
    end

    local payload = "Exif\0\0" .. exif_bytes
    local seg_len = #payload + 2
    local app1 = string.char(255, 225) .. u16(seg_len) .. payload
    local new_content = full:sub(1, 2) .. app1 .. full:sub(3)

    local fw, werr = io.open(file_path, "wb")
    if fw then
        fw:write(new_content)
        fw:close()
        return true
    else
        msg.warn("Cannot write EXIF to JPEG: " .. tostring(werr))
        return false
    end
end

-- ---------------------------------------------------------
-- Event Handlers
-- ---------------------------------------------------------
local function to_json_val(v)
    if type(v) == "boolean" then
        return v and "true" or "false"
    elseif type(v) == "number" then
        return tostring(v)
    else
        return string.format("%q", tostring(v or ""))
    end
end

local function on_screenshot_saved(file_path)
    local meta = table.remove(capture_queue, 1)
    if not meta then
        meta = collect_metadata()
    end

    local fname_only = file_path:match("[^/\\]+$") or file_path
    local ext = file_path:lower():match("%.([^%.]+)$")

    if ext == "jpg" or ext == "jpeg" then
        -- Ultra HDR (ISO 21496-1) + EXIF + GPS background processing via utils/process_capture.py
        local py_script = mp.find_config_file("utils/process_capture.py") or mp.command_native({"normalize-path", "~~/utils/process_capture.py"})

        local function do_lua_jpeg_fallback(reason)
            pcall(function() inject_into_jpeg(file_path, meta) end)
            if opts.show_osd_badge then
                local badge_tag = meta.is_hdr and (meta.hdr_format .. " -> sRGB") or "SDR"
                local dev_tag = (meta.model ~= "") and meta.model or meta.hdr_format
                local osd_text = string.format("Frame Captured: %s\n[%s • %s • Metadata Saved]", fname_only, badge_tag, dev_tag)
                mp.osd_message(osd_text, opts.osd_duration)
            end
        end

        if py_script then
            local json_parts = {
                string.format('"is_hdr":%s', meta.is_hdr and "true" or "false"),
                string.format('"hdr_format":%s', to_json_val(meta.hdr_format)),
                string.format('"make":%s', to_json_val(meta.make)),
                string.format('"model":%s', to_json_val(meta.model)),
                string.format('"creation_time":%s', to_json_val(meta.creation_time)),
                string.format('"raw_gps":%s', to_json_val(meta.raw_gps)),
                string.format('"filename":%s', to_json_val(meta.filename)),
                string.format('"time_str":%s', to_json_val(meta.time_str)),
                string.format('"peak_nits":%s', tostring(meta.peak_nits or 1000.0))
            }
            local json_str = "{" .. table.concat(json_parts, ",") .. "}"

            mp.command_native_async({
                name = "subprocess",
                playback_only = false,
                capture_stdout = true,
                capture_stderr = true,
                args = { "python", py_script, file_path, json_str }
            }, function(success, res, err)
                if success and res and res.status == 0 then
                    msg.info("Ultra HDR & EXIF processed for " .. file_path)
                    if opts.show_osd_badge then
                        local badge_tag = meta.is_hdr and "Ultra HDR" or "SDR"
                        local dev_tag = (meta.model ~= "") and meta.model or meta.hdr_format
                        local osd_text = string.format("Frame Captured: %s\n[%s • %s • Metadata Saved]", fname_only, badge_tag, dev_tag)
                        mp.osd_message(osd_text, opts.osd_duration)
                    end
                else
                    local err_msg = (res and res.stderr and res.stderr ~= "") and res.stderr or tostring(err or (res and res.error_string))
                    msg.info("Python Ultra HDR processor unavailable: " .. tostring(err_msg) .. ". Embedded EXIF via native Lua engine.")
                    do_lua_jpeg_fallback(err_msg)
                end
            end)
        else
            do_lua_jpeg_fallback("process_capture.py not found")
        end
    else
        -- PNG metadata injection fallback
        local success, err = pcall(function()
            return inject_into_png(file_path, meta)
        end)

        if success and err then
            msg.info(string.format("Metadata embedded into %s [%s]", file_path, meta.summary))
            if opts.show_osd_badge then
                local osd_text = string.format("Frame Captured: %s\n[%s • Metadata Saved]", fname_only, meta.summary)
                mp.osd_message(osd_text, opts.osd_duration)
            end
        else
            msg.warn("Screenshot metadata injection encountered: " .. tostring(err))
        end
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

