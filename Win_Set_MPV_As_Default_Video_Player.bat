<# :
@echo off
setlocal EnableDelayedExpansion
title Set MPV As Default Video Player - by Biraj2004
cd /d "%~dp0"

:: =======================================================================================================
:: Suite        : biraj-mpv-conf (Ultra-Optimized Modern MPV Configuration Suite)
:: Repository   : https://github.com/Biraj2004/biraj-mpv-conf
:: Developer    : Biraj Sarkar (@Biraj2004)
:: Description  : Configures MPV as the default media player for all supported video-only file formats.
::                - Automatically locates MPV (mpv.exe / mpvnet.exe) across PATH, Scoop, and standard paths.
::                - Supports specifying a custom MPV executable path as a command-line argument.
::                - Registers MPV application capabilities, App Paths, and shell verbs in Windows Registry.
::                - Configures file associations, ProgIDs, and OpenWithProgIDs for 81 video-only extensions.
::                - Safely excludes .ts to avoid conflicting with TypeScript source code files.
::                - Flushes Windows Explorer shell cache via SHChangeNotify to update file icons immediately.
::                - Provides a one-click shortcut to Windows Default Apps settings for verification.
::                - Re-running this script is SAFE: existing associations are verified and skipped idempotently.
:: =======================================================================================================

where powershell >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell was not found on this system. Cannot continue.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create([System.IO.File]::ReadAllText('%~f0')))" %*
set "PS_EXIT=!ERRORLEVEL!"

echo -------------------------------------------------------------------------------------------------------
echo =======================================================================================================
echo [FINISHED] Script execution finished. GitHub: https://github.com/Biraj2004
echo =======================================================================================================
echo.
pause
endlocal
exit /b !PS_EXIT!
#>

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Set MPV As Default Video Player - by Biraj2004'

$dividerHeavy = '=' * 103
$dividerLight = '-' * 103

Write-Host $dividerHeavy -ForegroundColor Cyan
Write-Host '                               SET MPV AS DEFAULT VIDEO PLAYER' -ForegroundColor Cyan
Write-Host '                       Suite        : biraj-mpv-conf' -ForegroundColor Gray
Write-Host '                       Developer    : Biraj Sarkar (@Biraj2004)' -ForegroundColor Gray
Write-Host '                       Repository   : https://github.com/Biraj2004/biraj-mpv-conf' -ForegroundColor Gray
Write-Host $dividerHeavy -ForegroundColor Cyan
Write-Host ''

# -----------------------------------------------------------------------------
# 1. Locate MPV Executable
# -----------------------------------------------------------------------------
$mpvPath = $null

if ($args -and $args.Count -gt 0 -and (Test-Path -LiteralPath $args[0])) {
    $mpvPath = (Resolve-Path -LiteralPath $args[0]).Path
}

if (-not $mpvPath) {
    $searchPaths = @(
        (Get-Command 'mpv.exe' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        (Get-Command 'mpvnet.exe' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        "$env:ProgramFiles\mpv\mpv.exe",
        "${env:ProgramFiles(x86)}\mpv\mpv.exe",
        "$env:ProgramFiles\mpv.net\mpvnet.exe",
        "${env:ProgramFiles(x86)}\mpv.net\mpvnet.exe",
        "$env:LOCALAPPDATA\Programs\mpv\mpv.exe",
        "$env:LOCALAPPDATA\mpv\mpv.exe",
        "$env:USERPROFILE\scoop\apps\mpv\current\mpv.exe",
        'C:\mpv\mpv.exe',
        'C:\ProgramData\chocolatey\bin\mpv.exe'
    )

    foreach ($candidate in $searchPaths) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            $mpvPath = (Resolve-Path -LiteralPath $candidate).Path
            break
        }
    }
}

if (-not $mpvPath) {
    Write-Host '[ERROR] MPV was NOT found on this system.' -ForegroundColor Red
    Write-Host ''
    Write-Host '        This script requires mpv.exe or mpvnet.exe to be installed.' -ForegroundColor Yellow
    Write-Host '        Recommended setup:' -ForegroundColor White
    Write-Host '          1. Download the latest mpv build from: https://github.com/zhongfly/mpv-winbuild/releases' -ForegroundColor White
    Write-Host '          2. Extract it to: C:\Program Files\mpv\ or C:\mpv\ (so mpv.exe exists)' -ForegroundColor White
    Write-Host '          3. Run this script again.' -ForegroundColor White
    Write-Host ''
    Write-Host '        Already have mpv somewhere else? Run this script from CMD as:' -ForegroundColor White
    Write-Host '          Win_Set_MPV_As_Default_Video_Player.bat "C:\your\path\to\mpv.exe"' -ForegroundColor Cyan
    Write-Host ''
    exit 1
}

# Find icon path if available
$iconPath = Join-Path (Split-Path -Parent $mpvPath) 'mpv-document.ico'
if (-not (Test-Path -LiteralPath $iconPath)) {
    $iconPath = Join-Path (Split-Path -Parent $mpvPath) 'mpv.ico'
}
if (-not (Test-Path -LiteralPath $iconPath)) {
    $iconPath = "$mpvPath,0"
} else {
    $iconPath = "$iconPath,0"
}

# -----------------------------------------------------------------------------
# 2. Comprehensive List of MPV-Supported Video-Only Formats (81 Extensions)
# -----------------------------------------------------------------------------
$videoFormats = @(
    # MPEG-4 & Web Video
    @{ Ext = '.mp4';   Name = 'MP4 Video File';                 Mime = 'video/mp4' },
    @{ Ext = '.m4v';   Name = 'M4V Video File';                 Mime = 'video/mp4' },
    @{ Ext = '.mp4v';  Name = 'MPEG-4 Video File';              Mime = 'video/mp4' },
    @{ Ext = '.mpeg4'; Name = 'MPEG-4 Video File';              Mime = 'video/mp4' },
    @{ Ext = '.mpg4';  Name = 'MPEG-4 Video File';              Mime = 'video/mp4' },
    @{ Ext = '.webm';  Name = 'WebM Video File';                Mime = 'video/webm' },

    # Matroska Video
    @{ Ext = '.mkv';   Name = 'Matroska Video File';            Mime = 'video/x-matroska' },
    @{ Ext = '.mk3d';  Name = 'Matroska 3D Video File';         Mime = 'video/x-matroska' },

    # Apple QuickTime
    @{ Ext = '.mov';   Name = 'QuickTime Movie';                Mime = 'video/quicktime' },
    @{ Ext = '.qt';    Name = 'QuickTime Video';                Mime = 'video/quicktime' },
    @{ Ext = '.hdmov'; Name = 'QuickTime HD Video';             Mime = 'video/quicktime' },

    # AVI & DivX / XviD Codecs
    @{ Ext = '.avi';   Name = 'Audio Video Interleave File';    Mime = 'video/avi' },
    @{ Ext = '.vfw';   Name = 'Video for Windows File';         Mime = 'video/avi' },
    @{ Ext = '.divx';  Name = 'DivX Video File';                Mime = 'video/divx' },
    @{ Ext = '.xvid';  Name = 'Xvid Video File';                Mime = 'video/xvid' },
    @{ Ext = '.3iv';   Name = '3ivx Video File';                Mime = 'video/3ivx' },

    # MPEG-1 / MPEG-2 Streams
    @{ Ext = '.mpeg';  Name = 'MPEG Video File';                Mime = 'video/mpeg' },
    @{ Ext = '.mpg';   Name = 'MPEG Video File';                Mime = 'video/mpeg' },
    @{ Ext = '.mpe';   Name = 'MPEG Video File';                Mime = 'video/mpeg' },
    @{ Ext = '.mpeg1'; Name = 'MPEG-1 Video File';              Mime = 'video/mpeg' },
    @{ Ext = '.mpeg2'; Name = 'MPEG-2 Video File';              Mime = 'video/mpeg' },
    @{ Ext = '.m1v';   Name = 'MPEG-1 Video File';              Mime = 'video/mpeg' },
    @{ Ext = '.m2v';   Name = 'MPEG-2 Video File';              Mime = 'video/mpeg' },
    @{ Ext = '.mp2v';  Name = 'MPEG-2 Video File';              Mime = 'video/mpeg' },
    @{ Ext = '.mpv';   Name = 'MPEG Video File';                Mime = 'video/mpeg' },
    @{ Ext = '.mpv2';  Name = 'MPEG-2 Video File';              Mime = 'video/mpeg' },

    # Transport Streams & High Definition
    @{ Ext = '.mts';   Name = 'AVCHD Video File';               Mime = 'video/vnd.dlna.mpeg-tts' },
    @{ Ext = '.m2ts';  Name = 'BDAV MPEG-2 Transport Stream';   Mime = 'video/vnd.dlna.mpeg-tts' },
    @{ Ext = '.m2t';   Name = 'MPEG-2 Transport Stream';        Mime = 'video/vnd.dlna.mpeg-tts' },
    @{ Ext = '.tts';   Name = 'MPEG-2 Transport Stream';        Mime = 'video/vnd.dlna.mpeg-tts' },
    @{ Ext = '.tsv';   Name = 'MPEG Transport Stream Video';    Mime = 'video/vnd.dlna.mpeg-tts' },
    @{ Ext = '.tsa';   Name = 'MPEG Transport Stream Video';    Mime = 'video/vnd.dlna.mpeg-tts' },
    @{ Ext = '.trp';   Name = 'HD Video Transport Stream';      Mime = 'video/vnd.dlna.mpeg-tts' },
    @{ Ext = '.mtv';   Name = 'MTV Video File';                 Mime = 'video/vnd.dlna.mpeg-tts' },

    # DVD & HD-DVD Media
    @{ Ext = '.vob';   Name = 'DVD Video Object File';          Mime = 'video/dvd' },
    @{ Ext = '.vro';   Name = 'DVD Video Recording File';       Mime = 'video/dvd' },
    @{ Ext = '.evo';   Name = 'Enhanced VOB File';              Mime = 'video/dvd' },
    @{ Ext = '.evob';  Name = 'Enhanced VOB File';              Mime = 'video/dvd' },

    # Camcorder & DV Formats
    @{ Ext = '.mod';   Name = 'JVC/Panasonic Camcorder Video';  Mime = 'video/mpeg' },
    @{ Ext = '.tod';   Name = 'JVC Camcorder Video';            Mime = 'video/mpeg' },
    @{ Ext = '.dv';    Name = 'Digital Video File';             Mime = 'video/x-dv' },
    @{ Ext = '.hdv';   Name = 'High Definition Video File';     Mime = 'video/x-dv' },

    # Flash Video
    @{ Ext = '.flv';   Name = 'Flash Video File';               Mime = 'video/x-flv' },
    @{ Ext = '.f4v';   Name = 'Flash MP4 Video File';           Mime = 'video/mp4' },

    # Ogg Video
    @{ Ext = '.ogv';   Name = 'Ogg Video File';                 Mime = 'video/ogg' },
    @{ Ext = '.ogm';   Name = 'Ogg Media File';                 Mime = 'video/ogg' },
    @{ Ext = '.ogx';   Name = 'Ogg Multiplexed File';           Mime = 'application/ogg' },

    # Windows Media Video
    @{ Ext = '.wmv';   Name = 'Windows Media Video';            Mime = 'video/x-ms-wmv' },
    @{ Ext = '.wm';    Name = 'Windows Media Video';            Mime = 'video/x-ms-wm' },
    @{ Ext = '.asf';   Name = 'Advanced Systems Format';        Mime = 'video/x-ms-asf' },
    @{ Ext = '.dvr-ms';Name = 'Microsoft Recorded TV Show';     Mime = 'video/x-ms-dvr-ms' },
    @{ Ext = '.dvr';   Name = 'Digital Video Recording';        Mime = 'video/x-ms-dvr' },
    @{ Ext = '.wtv';   Name = 'Windows Recorded TV Show';       Mime = 'video/x-ms-wtv' },

    # 3GPP Mobile Formats
    @{ Ext = '.3gp';   Name = '3GPP Multimedia File';           Mime = 'video/3gpp' },
    @{ Ext = '.3gpp';  Name = '3GPP Multimedia File';           Mime = 'video/3gpp' },
    @{ Ext = '.3g2';   Name = '3GPP2 Multimedia File';          Mime = 'video/3gpp2' },
    @{ Ext = '.3gp2';  Name = '3GPP2 Multimedia File';          Mime = 'video/3gpp2' },

    # RealMedia Formats
    @{ Ext = '.rm';    Name = 'RealMedia Video File';           Mime = 'application/vnd.rn-realmedia' },
    @{ Ext = '.rmvb';  Name = 'RealMedia Variable Bitrate';     Mime = 'application/vnd.rn-realmedia-vbr' },

    # Raw Video Streams
    @{ Ext = '.h264';  Name = 'Raw H.264 Video Stream';         Mime = 'video/h264' },
    @{ Ext = '.264';   Name = 'Raw H.264 Video Stream';         Mime = 'video/h264' },
    @{ Ext = '.x264';  Name = 'Raw H.264 Video Stream';         Mime = 'video/h264' },
    @{ Ext = '.avc';   Name = 'Raw AVC Video Stream';           Mime = 'video/avc' },
    @{ Ext = '.hevc';  Name = 'Raw HEVC Video Stream';          Mime = 'video/hevc' },
    @{ Ext = '.h265';  Name = 'Raw H.265 Video Stream';         Mime = 'video/hevc' },
    @{ Ext = '.265';   Name = 'Raw H.265 Video Stream';         Mime = 'video/hevc' },
    @{ Ext = '.x265';  Name = 'Raw H.265 Video Stream';         Mime = 'video/hevc' },
    @{ Ext = '.yuv';   Name = 'Raw YUV Video File';             Mime = 'video/x-raw-yuv' },
    @{ Ext = '.y4m';   Name = 'YUV4MPEG2 Video File';           Mime = 'video/x-raw-yuv' },

    # Broadcast & Professional
    @{ Ext = '.mxf';   Name = 'Material Exchange Format';       Mime = 'application/mxf' },
    @{ Ext = '.gxf';   Name = 'General Exchange Format';        Mime = 'application/gxf' },

    # Specialty, Game & Animation Video Formats
    @{ Ext = '.flic';  Name = 'FLIC Animation Video';           Mime = 'video/flc' },
    @{ Ext = '.fli';   Name = 'FLIC Animation Video';           Mime = 'video/flc' },
    @{ Ext = '.flc';   Name = 'FLIC Animation Video';           Mime = 'video/flc' },
    @{ Ext = '.nsv';   Name = 'Nullsoft Streaming Video';       Mime = 'video/x-nsv' },
    @{ Ext = '.nut';   Name = 'NUT Open Container Video';       Mime = 'video/nut' },
    @{ Ext = '.bik';   Name = 'Bink Video File';                Mime = 'video/vnd.radgametools.bink' },
    @{ Ext = '.bk2';   Name = 'Bink 2 Video File';              Mime = 'video/vnd.radgametools.bink' },
    @{ Ext = '.amv';   Name = 'Anime Music Video File';         Mime = 'video/amv' },
    @{ Ext = '.dav';   Name = 'DVR CCTV Video File';            Mime = 'video/dav' },
    @{ Ext = '.roq';   Name = 'Id Software RoQ Video';          Mime = 'video/roq' }
)

# -----------------------------------------------------------------------------
# 3. Present [INFO] and [WARNING] Blocks
# -----------------------------------------------------------------------------
Write-Host ('[INFO] Working Folder    : ' + (Get-Location).Path) -ForegroundColor White
Write-Host ('[INFO] MPV Executable    : ' + $mpvPath) -ForegroundColor White
Write-Host ('[INFO] Target Categories : Standard Web, Matroska, QuickTime, AVI, MPEG, TS, DVD, Camcorder, Flash, Ogg, WMV, 3GP, RM, Raw') -ForegroundColor White
Write-Host ('[INFO] Target Formats    : ' + $videoFormats.Count + ' Video-Only File Extensions') -ForegroundColor White
Write-Host  '[INFO] Scope             : Current User Shell Handlers, Capabilities & OpenWithProgIDs' -ForegroundColor White
Write-Host  '[INFO] Safety            : Non-destructive association; re-running is 100% idempotent' -ForegroundColor White
Write-Host ''

Write-Host $dividerHeavy -ForegroundColor Yellow
Write-Host (' WARNING: This will configure MPV as the default player for ' + $videoFormats.Count + ' video-only file formats.') -ForegroundColor Yellow
Write-Host $dividerHeavy -ForegroundColor Yellow
Write-Host ''

# -----------------------------------------------------------------------------
# 4. Y/N Safety Gate
# -----------------------------------------------------------------------------
$confirm = Read-Host 'Type Y and press Enter to proceed, or N to cancel'
if ($confirm -notmatch '^(?i:y|yes)$') {
    Write-Host ''
    Write-Host '[CANCELLED] Setup execution cancelled. No file associations were modified. Exiting safely.' -ForegroundColor Yellow
    Write-Host ''
    exit 0
}

Write-Host ''
Write-Host '[PROCESSING] Registering MPV application capabilities and shell verbs...' -ForegroundColor Cyan
Write-Host $dividerLight -ForegroundColor Gray

# -----------------------------------------------------------------------------
# 5. Core Registration Helpers
# -----------------------------------------------------------------------------
function Set-RegistryValueQuiet([string]$keyPath, [string]$valueName, [object]$valueData, [Microsoft.Win32.RegistryValueKind]$kind = [Microsoft.Win32.RegistryValueKind]::String) {
    if ($null -eq $valueData) {
        $valueData = ''
    }
    $normalizedKey = $keyPath -replace '^HKCU:\\?', 'HKEY_CURRENT_USER\' -replace '^HKLM:\\?', 'HKEY_LOCAL_MACHINE\'
    [Microsoft.Win32.Registry]::SetValue($normalizedKey, $valueName, $valueData, $kind)
}

try {
    # 5a. Register App Paths
    $appPathsKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\mpv.exe'
    Set-RegistryValueQuiet $appPathsKey '' $mpvPath
    Set-RegistryValueQuiet $appPathsKey 'UseUrl' 1 ([Microsoft.Win32.RegistryValueKind]::DWord)

    # 5b. Register Applications\mpv.exe
    $appKey = 'HKCU:\Software\Classes\Applications\mpv.exe'
    Set-RegistryValueQuiet $appKey 'FriendlyAppName' 'mpv'
    Set-RegistryValueQuiet "$appKey\shell" '' 'play'
    Set-RegistryValueQuiet "$appKey\shell\open" 'LegacyDisable' ''
    Set-RegistryValueQuiet "$appKey\shell\open\command" '' "`"$mpvPath`" `"%1`""
    Set-RegistryValueQuiet "$appKey\shell\play" '' '&Play with mpv'
    Set-RegistryValueQuiet "$appKey\shell\play\command" '' "`"$mpvPath`" `"%1`""
    Set-RegistryValueQuiet "$appKey\DefaultIcon" '' $iconPath

    # 5c. Register SystemFileAssociations for Video
    $sysAssocKey = 'HKCU:\Software\Classes\SystemFileAssociations\video\OpenWithList\mpv.exe'
    Set-RegistryValueQuiet $sysAssocKey '' ''

    # 5d. Register Capabilities & RegisteredApplications
    $capabilitiesKey = 'HKCU:\Software\Clients\Media\mpv\Capabilities'
    Set-RegistryValueQuiet $capabilitiesKey 'ApplicationName' 'mpv'
    Set-RegistryValueQuiet $capabilitiesKey 'ApplicationDescription' 'mpv media player'
    Set-RegistryValueQuiet 'HKCU:\Software\RegisteredApplications' 'mpv' 'Software\Clients\Media\mpv\Capabilities'

    Write-Host '[INFO]     MPV application capabilities and shell verbs registered successfully.' -ForegroundColor Green
} catch {
    Write-Host ('[ERROR]    Failed to register base MPV capabilities: ' + $_.Exception.Message) -ForegroundColor Red
}

Write-Host ''
Write-Host '[PROCESSING] Configuring video format associations...' -ForegroundColor Cyan
Write-Host $dividerLight -ForegroundColor Gray

# -----------------------------------------------------------------------------
# 6. Per-Extension Association Loop
# -----------------------------------------------------------------------------
$grandSet = 0
$grandSkipped = 0
$grandErrors = 0

foreach ($item in $videoFormats) {
    $ext = $item.Ext
    $friendlyName = $item.Name
    $mime = $item.Mime
    $progId = 'io.mpv' + $ext

    try {
        # Check idempotency: if HKCU ProgID exists and extension default is already set
        $extKey = "HKCU:\Software\Classes\$ext"
        $progIdKey = "HKCU:\Software\Classes\$progId"
        $currentDefault = (Get-ItemProperty -LiteralPath $extKey -ErrorAction SilentlyContinue).'(default)'
        $openWithAssigned = (Get-ItemProperty -LiteralPath "$extKey\OpenWithProgids" -ErrorAction SilentlyContinue).$progId

        if ($currentDefault -eq $progId -and $null -ne $openWithAssigned -and (Test-Path -LiteralPath $progIdKey)) {
            Write-Host ("[SKIP]     $ext`t(already set to $progId)") -ForegroundColor DarkGray
            $grandSkipped++
            continue
        }

        # Create/Update ProgID
        Set-RegistryValueQuiet $progIdKey '' $friendlyName
        Set-RegistryValueQuiet $progIdKey 'FriendlyTypeName' $friendlyName
        Set-RegistryValueQuiet $progIdKey 'EditFlags' 4259840 ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueQuiet "$progIdKey\DefaultIcon" '' $iconPath
        Set-RegistryValueQuiet "$progIdKey\shell" '' 'play'
        Set-RegistryValueQuiet "$progIdKey\shell\open\command" '' "`"$mpvPath`" -- `"%1`""
        Set-RegistryValueQuiet "$progIdKey\shell\play" '' '&Play with mpv'
        Set-RegistryValueQuiet "$progIdKey\shell\play\command" '' "`"$mpvPath`" -- `"%1`""

        # Configure Extension Key
        Set-RegistryValueQuiet $extKey '' $progId
        Set-RegistryValueQuiet $extKey 'PerceivedType' 'video'
        if ($mime) {
            Set-RegistryValueQuiet $extKey 'Content Type' $mime
        }
        Set-RegistryValueQuiet "$extKey\OpenWithProgids" $progId ''

        # Register in Applications\mpv.exe\SupportedTypes
        Set-RegistryValueQuiet 'HKCU:\Software\Classes\Applications\mpv.exe\SupportedTypes' $ext ''

        # Register in Capabilities\FileAssociations
        Set-RegistryValueQuiet 'HKCU:\Software\Clients\Media\mpv\Capabilities\FileAssociations' $ext $progId

        # Register in Explorer FileExts OpenWithProgids & OpenWithList
        $fileExtsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
        Set-RegistryValueQuiet "$fileExtsKey\OpenWithProgids" $progId ''
        Set-RegistryValueQuiet "$fileExtsKey\OpenWithList" 'a' 'mpv.exe'

        Write-Host ("[SET]      $ext`t-->  $progId ($friendlyName)") -ForegroundColor Green
        $grandSet++
    } catch {
        Write-Host ("[ERROR]    $ext`t-- " + $_.Exception.Message) -ForegroundColor Red
        $grandErrors++
    }
}

# -----------------------------------------------------------------------------
# 7. Notify Windows Shell of File Association Changes
# -----------------------------------------------------------------------------
try {
    $sig = @'
    [DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern void SHChangeNotify(uint wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
'@
    $win32 = Add-Type -MemberDefinition $sig -Name 'ShellNotification' -Namespace 'Win32' -PassThru
    # SHCNE_ASSOCCHANGED = 0x08000000, SHCNF_FLUSH = 0x1000
    $win32::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)
    Write-Host ''
    Write-Host '[INFO]     Windows Explorer shell cache flushed successfully (SHChangeNotify).' -ForegroundColor Green
} catch {
    # Non-fatal if shell notification cannot be invoked directly
}

# -----------------------------------------------------------------------------
# 8. Summary & Settings Helper
# -----------------------------------------------------------------------------
Write-Host ''
Write-Host $dividerLight -ForegroundColor Gray
Write-Host ("[SUMMARY] Total Formats : " + $videoFormats.Count) -ForegroundColor Green
Write-Host ("[SUMMARY] Configured    : " + $grandSet) -ForegroundColor Green
Write-Host ("[SUMMARY] Already OK    : " + $grandSkipped) -ForegroundColor Green
Write-Host ("[SUMMARY] Errors        : " + $grandErrors) -ForegroundColor $(if ($grandErrors -gt 0) { 'Yellow' } else { 'Green' })

if ($grandErrors -eq 0 -or $grandSet -gt 0) {
    Write-Host '[SUCCESS] MPV default video player associations configured successfully!' -ForegroundColor Green
} else {
    Write-Host '[ERROR]   Failed to configure some video format associations. See messages above.' -ForegroundColor Red
}

Write-Host $dividerHeavy -ForegroundColor Gray
Write-Host ''
Write-Host 'Tip: On Windows 10 & 11, you can finalize system defaults under Settings > Default apps.' -ForegroundColor Cyan
Write-Host '     Would you like to open the Windows Default Apps settings page now? (Y/N)' -ForegroundColor White
$openSettings = Read-Host 'Open Settings (Y/N)'
if ($openSettings -match '^(?i:y|yes)$') {
    try {
        Start-Process 'ms-settings:defaultapps'
    } catch {
        # Fallback to control panel
        Start-Process 'control.exe' -ArgumentList '/name Microsoft.DefaultPrograms' -ErrorAction SilentlyContinue
    }
}

exit $(if ($grandErrors -gt 0 -and $grandSet -eq 0) { 1 } else { 0 })
