--[[

    Open files, add subtitles, or add audio tracks directly from mpv 
    via the Windows file dialog

    More info: https://github.com/Samillion/ModernZ/tree/main/extras/open-file

    A fork of https://github.com/rossy/mpv-open-file-dialog

--]]

local utils = require "mp.utils"

local is_windows = package.config:sub(1,1) == "\\"

local function invoke_dialog(ps_command, mac_script, zenity_args, kdialog_args)
    local was_ontop = mp.get_property_native("ontop")
    if was_ontop then mp.set_property_native("ontop", false) end

    local res = nil

    if is_windows then
        -- Primary / Default: Native Windows PowerShell WPF Dialog
        local full_cmd = "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; " .. ps_command
        res = utils.subprocess({
            args = { "powershell", "-NoProfile", "-STA", "-Command", full_cmd },
            cancellable = false,
            capture_stdout = true,
            capture_stderr = true,
        })
    else
        -- Fallback for macOS: Native Cocoa dialog via built-in AppleScript
        local platform = mp.get_property("platform")
        if platform == "darwin" or (not platform and utils.file_info("/System/Library/CoreServices")) then
            if mac_script then
                res = utils.subprocess({
                    args = { "osascript", "-e", mac_script },
                    cancellable = false,
                    capture_stdout = true,
                    capture_stderr = true,
                })
            end
        else
            -- Fallback for Linux: Zenity (GTK) with KDialog (KDE) secondary fallback
            if zenity_args then
                res = utils.subprocess({
                    args = zenity_args,
                    cancellable = false,
                    capture_stdout = true,
                    capture_stderr = true,
                })
            end
            if (not res or res.status ~= 0 or not res.stdout or res.stdout == "") and kdialog_args then
                res = utils.subprocess({
                    args = kdialog_args,
                    cancellable = false,
                    capture_stdout = true,
                    capture_stderr = true,
                })
            end
        end
    end

    if was_ontop then mp.set_property_native("ontop", true) end

    if res and res.status == 0 and res.stdout and res.stdout ~= "" then
        return res.stdout
    end
end

local function get_active_directory()
    local path = mp.get_property("path")
    if not path or path == "" then return nil end

    -- Skip URLs, network streams, or special protocols
    if path:find("^%a+://") or path:find("^edl://") or path:find("^bd://") or path:find("^dvd://") then
        return nil
    end

    local dir, _ = utils.split_path(path)
    if not dir or dir == "" or dir == "." or dir == "./" or dir == ".\\" then
        local work_dir = mp.get_property("working-directory")
        if work_dir and work_dir ~= "" then
            dir = work_dir
        else
            return nil
        end
    elseif not (dir:find("^%a:[/\\]") or dir:find("^[/\\][/\\]") or dir:find("^/")) then
        local work_dir = mp.get_property("working-directory")
        if work_dir and work_dir ~= "" then
            dir = utils.join_path(work_dir, dir)
        end
    end

    local info = utils.file_info(dir)
    if info and info.is_dir then
        return dir
    end
    return nil
end

local function build_ps_init(dir)
    if not dir then return "" end
    local ps_dir = dir:gsub("/", "\\"):gsub("'", "''")
    return string.format("$ofd.InitialDirectory = '%s'\n        ", ps_dir)
end

local function build_mac_loc(dir)
    if not dir then return "" end
    local mac_dir = dir:gsub('"', '\\"')
    return string.format(' default location POSIX file "%s"', mac_dir)
end

local function build_zenity_args(base_args, dir)
    local args = {}
    for _, a in ipairs(base_args) do table.insert(args, a) end
    if dir then
        local z_dir = dir:gsub("\\", "/")
        if z_dir:sub(-1) ~= "/" then z_dir = z_dir .. "/" end
        table.insert(args, "--filename=" .. z_dir)
    end
    return args
end

local function build_kdialog_args(base_args, dir)
    local args = {}
    for _, a in ipairs(base_args) do table.insert(args, a) end
    if dir then
        table.insert(args, dir)
    end
    return args
end

local function open()
    local dir = get_active_directory()
    local ps_init = build_ps_init(dir)
    local mac_loc = build_mac_loc(dir)

    local stdout = invoke_dialog(
        [[
        Add-Type -AssemblyName PresentationFramework
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        ]] .. ps_init .. [[$ofd.Multiselect = $true
        $ofd.Filter = "Media files|*.mkv;*.mp4;*.avi;*.mov;*.webm;*.wmv;*.gif;*.m4v;*.flv;*.mpg;*.mpeg;*.vob;*.ogv;*.3gp;*.ts;*.divx;*.mp3;*.flac;*.aac;*.ogg;*.wav;*.m4a;*.opus;*.wma;*.mka;*.m3u;*.m3u8|All files|*.*"

        if ($ofd.ShowDialog() -eq $true) {
            foreach ($file in $ofd.FileNames) {
                [Console]::WriteLine($file)
            }
        }
    ]],
        'set f to choose file with prompt "Select Media Files"' .. mac_loc .. ' with multiple selections allowed\nset o to ""\nrepeat with i in f\nset o to o & (POSIX path of i) & linefeed\nend repeat\nreturn o',
        build_zenity_args({ "zenity", "--file-selection", "--multiple", "--separator=\n", "--title=Select Media Files" }, dir),
        build_kdialog_args({ "kdialog", "--getopenfilename", "--multiple", "--separate-output", "--title", "Select Media Files" }, dir)
    )

    if not stdout then return end

    local first = true
    for filename in string.gmatch(stdout, "[^\r\n]+") do
        if filename and filename ~= "" then
            mp.commandv("loadfile", filename, first and "replace" or "append")
            first = false
        end
    end
end

local function add_subtitle()
    local dir = get_active_directory()
    local ps_init = build_ps_init(dir)
    local mac_loc = build_mac_loc(dir)

    local stdout = invoke_dialog(
        [[
        Add-Type -AssemblyName PresentationFramework
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        ]] .. ps_init .. [[$ofd.Multiselect = $false
        $ofd.Filter = "Subtitle files|*.srt;*.ass;*.ssa;*.sub;*.idx;*.sup;*.vtt|All files|*.*"

        if ($ofd.ShowDialog() -eq $true) {
            [Console]::WriteLine($ofd.FileName)
        }
    ]],
        'return POSIX path of (choose file with prompt "Select Subtitle File"' .. mac_loc .. ')',
        build_zenity_args({ "zenity", "--file-selection", "--title=Select Subtitle File" }, dir),
        build_kdialog_args({ "kdialog", "--getopenfilename", "--title", "Select Subtitle File" }, dir)
    )

    if not stdout then return end

    local filename = stdout:match("[^\r\n]+")
    if filename and filename ~= "" then
        mp.commandv("sub-add", filename, "select")
    end
end

local function add_audio()
    local dir = get_active_directory()
    local ps_init = build_ps_init(dir)
    local mac_loc = build_mac_loc(dir)

    local stdout = invoke_dialog(
        [[
        Add-Type -AssemblyName PresentationFramework
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        ]] .. ps_init .. [[$ofd.Multiselect = $false
        $ofd.Filter = "Audio files|*.mp3;*.flac;*.aac;*.ogg;*.wav;*.m4a;*.opus;*.wma;*.mka;*.ac3|All files|*.*"

        if ($ofd.ShowDialog() -eq $true) {
            [Console]::WriteLine($ofd.FileName)
        }
    ]],
        'return POSIX path of (choose file with prompt "Select Audio File"' .. mac_loc .. ')',
        build_zenity_args({ "zenity", "--file-selection", "--title=Select Audio File" }, dir),
        build_kdialog_args({ "kdialog", "--getopenfilename", "--title", "Select Audio File" }, dir)
    )

    if not stdout then return end

    local filename = stdout:match("[^\r\n]+")
    if filename and filename ~= "" then
        mp.commandv("audio-add", filename, "select")
    end
end

mp.add_key_binding(nil, "open", open)
mp.add_key_binding(nil, "add_subtitle", add_subtitle)
mp.add_key_binding(nil, "add_audio", add_audio)
