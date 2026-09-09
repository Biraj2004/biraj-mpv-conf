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

local function open()
    local stdout = invoke_dialog(
        [[
        Add-Type -AssemblyName PresentationFramework
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        $ofd.Multiselect = $true
        $ofd.Filter = "Media files|*.mkv;*.mp4;*.avi;*.mov;*.webm;*.wmv;*.gif;*.m4v;*.flv;*.mpg;*.mpeg;*.vob;*.ogv;*.3gp;*.ts;*.divx;*.mp3;*.flac;*.aac;*.ogg;*.wav;*.m4a;*.opus;*.wma;*.mka;*.m3u;*.m3u8|All files|*.*"

        if ($ofd.ShowDialog() -eq $true) {
            foreach ($file in $ofd.FileNames) {
                [Console]::WriteLine($file)
            }
        }
    ]],
        'set f to choose file with prompt "Select Media Files" with multiple selections allowed\nset o to ""\nrepeat with i in f\nset o to o & (POSIX path of i) & linefeed\nend repeat\nreturn o',
        { "zenity", "--file-selection", "--multiple", "--separator=\n", "--title=Select Media Files" },
        { "kdialog", "--getopenfilename", "--multiple", "--separate-output", "--title", "Select Media Files" }
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
    local stdout = invoke_dialog(
        [[
        Add-Type -AssemblyName PresentationFramework
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        $ofd.Multiselect = $false
        $ofd.Filter = "Subtitle files|*.srt;*.ass;*.ssa;*.sub;*.idx;*.sup;*.vtt|All files|*.*"

        if ($ofd.ShowDialog() -eq $true) {
            [Console]::WriteLine($ofd.FileName)
        }
    ]],
        'return POSIX path of (choose file with prompt "Select Subtitle File")',
        { "zenity", "--file-selection", "--title=Select Subtitle File" },
        { "kdialog", "--getopenfilename", "--title", "Select Subtitle File" }
    )

    if not stdout then return end

    local filename = stdout:match("[^\r\n]+")
    if filename and filename ~= "" then
        mp.commandv("sub-add", filename, "select")
    end
end

local function add_audio()
    local stdout = invoke_dialog(
        [[
        Add-Type -AssemblyName PresentationFramework
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        $ofd.Multiselect = $false
        $ofd.Filter = "Audio files|*.mp3;*.flac;*.aac;*.ogg;*.wav;*.m4a;*.opus;*.wma;*.mka;*.ac3|All files|*.*"

        if ($ofd.ShowDialog() -eq $true) {
            [Console]::WriteLine($ofd.FileName)
        }
    ]],
        'return POSIX path of (choose file with prompt "Select Audio File")',
        { "zenity", "--file-selection", "--title=Select Audio File" },
        { "kdialog", "--getopenfilename", "--title", "Select Audio File" }
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
