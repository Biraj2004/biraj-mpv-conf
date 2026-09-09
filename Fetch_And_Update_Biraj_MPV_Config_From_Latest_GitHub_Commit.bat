@echo off
setlocal EnableDelayedExpansion
title Fetch and Update biraj-mpv-conf from Latest GitHub Commit - by Biraj2004
cd /d "%~dp0"

:: =======================================================================================================
:: Suite        : biraj-mpv-conf (Ultra-Optimized Modern MPV Configuration Suite)
:: Developer    : Biraj Sarkar (@Biraj2004)
:: Repository   : https://github.com/Biraj2004/biraj-mpv-conf
:: Live Docs    : https://biraj2004.github.io/biraj-mpv-conf/
:: Tested Build : mpv v0.41.0+ (zhongfly mpv-winbuild x86_64-v3 with gpu-next & libplacebo)
:: License      : Apache-2.0
:: =======================================================================================================

cls
echo =======================================================================================================
echo               FETCH ^& UPDATE BIRAJ-MPV-CONF FROM LATEST GITHUB COMMIT
echo                             Developed by : Biraj Sarkar (@Biraj2004)
echo                   Repository: https://github.com/Biraj2004/biraj-mpv-conf
echo                   Documentation: https://biraj2004.github.io/biraj-mpv-conf/
echo =======================================================================================================
echo  GOAL: Automatically sync the latest GitHub commit configuration files, scripts,
echo        fonts, and options into your active %%APPDATA%%\mpv directory.
echo.
echo  Reference Engine : mpv v0.41.0+ [zhongfly winbuild x86_64-v3 with gpu-next ^& libplacebo]
echo  Target Directory : %%APPDATA%%\mpv
echo.
echo -------------------------------------------------------------------------------------------------------
echo [SAFETY GATE]
echo -------------------------------------------------------------------------------------------------------
echo  This script will inspect the latest commit on GitHub (branch: main), create an automated
echo  safety backup of your existing configuration, and synchronize all updated files into %%APPDATA%%\mpv.
echo.
choice /c YN /n /m "Proceed with syncing latest GitHub commit into %APPDATA%\mpv? [Y/N]: "
if errorlevel 2 goto :CANCEL_START
goto :START_PROCESS

:CANCEL_START
echo.
echo [CANCELLED] Operation aborted by user. No files were checked or modified.
echo.
pause
exit /b 0

:START_PROCESS
echo.

:: -------------------------------------------------------------------------------------------------------
:: Step 1: Detect MPV Player Installation & Verify Recommended Build
:: -------------------------------------------------------------------------------------------------------
echo [STEP 1/4] Detecting local mpv installation and validating build...

set "MPV_EXE="
if exist "C:\Program Files\mpv\mpv.exe" set "MPV_EXE=C:\Program Files\mpv\mpv.exe"
if not defined MPV_EXE if exist "C:\Program Files\mpv\mpv.com" set "MPV_EXE=C:\Program Files\mpv\mpv.com"
if not defined MPV_EXE if exist "C:\mpv\mpv.exe" set "MPV_EXE=C:\mpv\mpv.exe"
if not defined MPV_EXE if exist "%LOCALAPPDATA%\Programs\mpv\mpv.exe" set "MPV_EXE=%LOCALAPPDATA%\Programs\mpv\mpv.exe"
if not defined MPV_EXE if exist "%USERPROFILE%\scoop\apps\mpv\current\mpv.exe" set "MPV_EXE=%USERPROFILE%\scoop\apps\mpv\current\mpv.exe"

if not defined MPV_EXE (
    for /f "delims=" %%I in ('where mpv.exe 2^>nul') do (
        set "MPV_EXE=%%I"
    )
)

if defined MPV_EXE goto :MPV_FOUND

:: MPV NOT FOUND ADVISORY
echo.
echo -------------------------------------------------------------------------------------------------------
echo [ADVISORY] mpv.exe was NOT detected at standard installation locations.
echo -------------------------------------------------------------------------------------------------------
echo  To experience biraj-mpv-conf with maximum fidelity and gpu-next libplacebo tone-mapping:
echo.
echo  1. WHAT BUILD TO USE:
echo     - Recommended: zhongfly mpv-winbuild [64-bit v3 or git master builds]
echo       Download URL: https://github.com/zhongfly/mpv-winbuild/releases
echo       [Alternative: shinchiro builds at https://sourceforge.net/projects/mpv-player-windows/files/]
echo.
echo  2. WHAT WAS USED TO BUILD ^& TEST THIS CONFIG:
echo     - Built and validated on: mpv v0.41.0-1042-g7e4cb538a [64-bit Windows build]
echo       Engine: gpu-next renderer + libplacebo v7+ + Vulkan/D3D11 + FFmpeg 7.x + yt-dlp
echo.
echo  3. RECOMMENDED INSTALLATION DIRECTORY:
echo     - Extract the downloaded mpv-x86_64-v3-*.7z archive.
echo     - Rename the extracted folder to "mpv" and place it directly in:
echo       C:\Program Files\mpv\
echo       [Ensuring C:\Program Files\mpv\mpv.exe is your main player executable]
echo     - Right-click "mpv-register.bat" inside that folder -^> Click "Run as administrator"
echo.
echo  4. FULL ONLINE DOCUMENTATION:
echo     - Setup Guide : https://biraj2004.github.io/biraj-mpv-conf/#installation
echo     - GitHub Repo : https://github.com/Biraj2004/biraj-mpv-conf
echo -------------------------------------------------------------------------------------------------------
echo  Note: You can still deploy the configuration files into %%APPDATA%%\mpv now so that
echo        the moment you install mpv, your player is instantly pre-configured.
echo.
choice /c YN /n /m "Do you wish to continue deploying the configuration suite now? [Y/N]: "
if errorlevel 2 goto :DEFER_SETUP
goto :MPV_CHECK_DONE

:DEFER_SETUP
echo.
echo [INFO] Setup deferred. Install mpv to C:\Program Files\mpv\ and run this script anytime.
echo.
pause
exit /b 0

:MPV_FOUND
echo   [FOUND] Player Executable : !MPV_EXE!
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { $ver = (& '!MPV_EXE!' --version | Select-Object -First 1); Write-Host ('  [BUILD] Active Version   : ' + $ver) -ForegroundColor Green } catch {}"
echo   [INFO]  Recommended Build : zhongfly mpv-winbuild [mpv v0.39+ / v0.41+ with gpu-next]
echo   [INFO]  Build Reference   : This suite was designed and tested on mpv v0.41.0-1042-g7e4cb538a

:MPV_CHECK_DONE
set "TARGET_DIR=%APPDATA%\mpv"
if defined MPV_EXE (
    for %%P in ("!MPV_EXE!") do set "MPV_PARENT=%%~dpP"
    if exist "!MPV_PARENT!portable_config\" (
        set "TARGET_DIR=!MPV_PARENT!portable_config"
        echo   [MODE]  Portable detected : !TARGET_DIR!
    )
)
echo   [TARGET] Configuration Dir : !TARGET_DIR!
echo.

:: -------------------------------------------------------------------------------------------------------
:: Step 2: Query Latest Commit Details from GitHub API
:: -------------------------------------------------------------------------------------------------------
echo [STEP 2/4] Checking latest commit metadata from GitHub repository...

del /f /q "%TEMP%\biraj_commit_meta.txt" 2>nul

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
    "try {" ^
    "    $c = Invoke-RestMethod -Uri 'https://api.github.com/repos/Biraj2004/biraj-mpv-conf/commits/main' -Headers @{'User-Agent'='biraj-mpv-updater'};" ^
    "    $d = ([DateTime]$c.commit.author.date).ToString('yyyy-MM-dd HH:mm:ss');" ^
    "    $m = ($c.commit.message -split [char]10)[0].Trim();" ^
    "    $lines = @($c.sha, $c.sha.Substring(0,7), $d, $c.commit.author.name, $m);" ^
    "    [System.IO.File]::WriteAllLines([System.IO.Path]::Combine($env:TEMP, 'biraj_commit_meta.txt'), $lines, [System.Text.Encoding]::UTF8);" ^
    "} catch {" ^
    "    Write-Host 'API_ERROR';" ^
    "}"

if exist "%TEMP%\biraj_commit_meta.txt" goto :COMMIT_META_OK

:: API QUERY FAILED (Fallback to direct main branch archive sync)
echo.
echo   [NOTICE] GitHub API query unavailable (rate-limited or offline).
echo            Proceeding with direct synchronization from main branch archive...
echo.
set "REMOTE_SHORT_SHA=latest"
set "REMOTE_FULL_SHA=latest-main-branch"
set "REMOTE_DATE=%DATE% %TIME%"
set "REMOTE_AUTHOR=Biraj Sarkar"
set "REMOTE_MSG=Direct synchronization from GitHub main branch"
goto :PARSE_META_OK

:COMMIT_META_OK
set "LINE_NUM=0"
for /f "usebackq delims=" %%L in ("%TEMP%\biraj_commit_meta.txt") do (
    set /a LINE_NUM+=1
    if !LINE_NUM!==1 set "REMOTE_FULL_SHA=%%L"
    if !LINE_NUM!==2 set "REMOTE_SHORT_SHA=%%L"
    if !LINE_NUM!==3 set "REMOTE_DATE=%%L"
    if !LINE_NUM!==4 set "REMOTE_AUTHOR=%%L"
    if !LINE_NUM!==5 set "REMOTE_MSG=%%L"
)
del /f /q "%TEMP%\biraj_commit_meta.txt" 2>nul

if defined REMOTE_SHORT_SHA goto :PARSE_META_OK

echo   [ERROR] Could not parse commit information from GitHub response.
echo   Guidance: Please re-run the script or download the ZIP manually from:
echo   https://github.com/Biraj2004/biraj-mpv-conf/archive/refs/heads/main.zip
echo.
pause
exit /b 1

:PARSE_META_OK
echo.
echo =======================================================================================================
echo                               LATEST GITHUB REPOSITORY STATUS
echo =======================================================================================================
echo  Repository      : Biraj2004/biraj-mpv-conf [branch: main]
echo  Latest Commit   : !REMOTE_SHORT_SHA! [!REMOTE_FULL_SHA!]
echo  Commit Date     : !REMOTE_DATE! [UTC]
echo  Author          : !REMOTE_AUTHOR!
echo  Commit Message  : !REMOTE_MSG!
echo =======================================================================================================
echo.

:: -------------------------------------------------------------------------------------------------------
:: Step 3: Check Local Synchronization State & Compare Commits
:: -------------------------------------------------------------------------------------------------------
echo [STEP 3/4] Comparing local %%APPDATA%%\mpv with latest GitHub commit...

set "VERSION_FILE=%APPDATA%\mpv\biraj-mpv-version.txt"
set "LOCAL_SHORT_SHA="
set "LOCAL_INSTALLED_AT="

if exist "!VERSION_FILE!" (
    for /f "tokens=1,* delims=:" %%X in ('findstr /b /c:"Commit-Short" "!VERSION_FILE!" 2^>nul') do (
        for /f "tokens=* delims= " %%Z in ("%%Y") do set "LOCAL_SHORT_SHA=%%Z"
    )
    for /f "tokens=1,* delims=:" %%X in ('findstr /b /c:"Installed-At" "!VERSION_FILE!" 2^>nul') do (
        for /f "tokens=* delims= " %%Z in ("%%Y") do set "LOCAL_INSTALLED_AT=%%Z"
    )
)

if not defined LOCAL_SHORT_SHA (
    echo   [STATUS] Fresh deployment detected.
    echo            Targeting latest GitHub commit: !REMOTE_SHORT_SHA! [!REMOTE_DATE! UTC]
    echo.
    goto :EXECUTE_UPDATE_START
)

if not "!LOCAL_SHORT_SHA!"=="!REMOTE_SHORT_SHA!" (
    echo   [STATUS] NEW COMMIT DETECTED!
    echo            Currently Installed : !LOCAL_SHORT_SHA!
    echo            Latest on GitHub    : !REMOTE_SHORT_SHA! [!REMOTE_DATE! UTC]
    echo            Commit Message      : !REMOTE_MSG!
    echo.
    echo   [ACTION] Synchronizing updated configuration files into %%APPDATA%%\mpv...
    echo.
    goto :EXECUTE_UPDATE_START
)

:: UP TO DATE STATUS
echo   [STATUS] Your installed configuration is ALREADY UP TO DATE with latest commit [!REMOTE_SHORT_SHA!].
if defined LOCAL_INSTALLED_AT echo            Last synced on: !LOCAL_INSTALLED_AT!
echo.
choice /c YN /n /m "Would you like to force re-download and re-sync anyway? [Y/N]: "
if errorlevel 2 goto :NO_CHANGES_EXIT

echo.
echo   [ACTION] Force re-sync requested. Re-applying latest release to %%APPDATA%%\mpv...
goto :EXECUTE_UPDATE_START

:NO_CHANGES_EXIT
echo.
echo [INFO] No changes made. Your %%APPDATA%%\mpv configuration is already at the latest release.
echo        To explore features and shortcuts, visit: https://biraj2004.github.io/biraj-mpv-conf/
echo.
pause
exit /b 0

:: -------------------------------------------------------------------------------------------------------
:: Step 4: Backup Existing Configuration, Download ZIP, Extract, and Deploy
:: -------------------------------------------------------------------------------------------------------
:EXECUTE_UPDATE_START
echo.
echo =======================================================================================================
echo                 [STEP 4/4] EXECUTING SAFETY BACKUP ^& SYNCHRONIZATION
echo =======================================================================================================
echo.

:: Edge Case: Check if MPV is actively running and locked
tasklist /fi "imagename eq mpv.exe" 2>nul | findstr /i "mpv.exe" >nul
if not errorlevel 1 (
    echo [NOTICE] An active mpv player process is currently running.
    echo          Closing mpv is recommended to prevent file lock conflicts during overwrite.
    choice /c YN /n /m "Close running mpv instances now? [Y/N]: "
    if not errorlevel 2 (
        taskkill /im mpv.exe /t /f >nul 2>&1
        timeout /t 1 >nul 2>&1
        echo   [CLOSED] Active mpv instances closed.
        echo.
    )
)

set "ZIP_URL=https://github.com/Biraj2004/biraj-mpv-conf/archive/refs/heads/main.zip"
set "TEMP_ZIP=%TEMP%\biraj-mpv-conf-latest-%RANDOM%.zip"
set "EXTRACT_DIR=%TEMP%\biraj-mpv-conf-extract-%RANDOM%"

echo [1/4] Creating safety backup of current configuration...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$source = [System.Environment]::ExpandEnvironmentVariables('%%APPDATA%%\mpv');" ^
    "if (Test-Path $source) {" ^
    "    $backupDir = Join-Path $source 'backups';" ^
    "    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null };" ^
    "    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss';" ^
    "    $zipPath = Join-Path $backupDir ('biraj-mpv-conf-backup-' + $timestamp + '.zip');" ^
    "    $tempBkp = Join-Path $env:TEMP ('mpv-bkp-' + $timestamp);" ^
    "    New-Item -ItemType Directory -Path $tempBkp -Force | Out-Null;" ^
    "    Get-ChildItem -Path $source -Exclude 'cache','backups','*.zip' | Copy-Item -Destination $tempBkp -Recurse -Force;" ^
    "    Compress-Archive -Path (Join-Path $tempBkp '*') -DestinationPath $zipPath -Force;" ^
    "    Remove-Item -Path $tempBkp -Recurse -Force;" ^
    "    Write-Host ('  [BACKUP CREATED] ' + $zipPath) -ForegroundColor Green;" ^
    "    $old = Get-ChildItem -Path $backupDir -Filter 'biraj-mpv-conf-backup-*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 5;" ^
    "    if ($old) { $old | Remove-Item -Force };" ^
    "}"

echo.
echo [2/4] Downloading latest configuration ZIP from GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
    "$url = '%ZIP_URL%';" ^
    "$out = '%TEMP_ZIP%';" ^
    "$sw = [Diagnostics.Stopwatch]::StartNew();" ^
    "try {" ^
    "    $wc = New-Object System.Net.WebClient;" ^
    "    $wc.Headers.Add('User-Agent', 'biraj-mpv-updater');" ^
    "    $wc.DownloadFile($url, $out);" ^
    "    $sw.Stop();" ^
    "    $bytes = (Get-Item $out).Length;" ^
    "    Write-Host ('  [DOWNLOADED] ' + [Math]::Round($bytes / 1MB, 2) + ' MB in ' + [Math]::Round($sw.ElapsedMilliseconds / 1000.0, 1) + 's') -ForegroundColor Green;" ^
    "} catch {" ^
    "    Write-Error $_.Exception.Message;" ^
    "}"

:: Edge Case: Verify file exists and is not a corrupted 0-byte or partial download (> 1MB)
if exist "!TEMP_ZIP!" (
    for %%F in ("!TEMP_ZIP!") do (
        if %%~zF GTR 1048576 goto :DOWNLOAD_OK
    )
)

echo.
echo -------------------------------------------------------------------------------------------------------
echo [ERROR] Failed to download valid ZIP archive from GitHub (file missing or incomplete).
echo -------------------------------------------------------------------------------------------------------
echo Guidance:
echo   - Check your internet connection or download the ZIP manually:
echo     https://github.com/Biraj2004/biraj-mpv-conf/archive/refs/heads/main.zip
echo   - Extract and copy the folders into %%APPDATA%%\mpv.
echo   - See manual instructions: https://biraj2004.github.io/biraj-mpv-conf/#installation
echo -------------------------------------------------------------------------------------------------------
echo.
if exist "!TEMP_ZIP!" del /f /q "!TEMP_ZIP!" 2>nul
pause
exit /b 1

:DOWNLOAD_OK
echo.
echo [3/4] Extracting configuration archive...
if exist "!EXTRACT_DIR!" rmdir /s /q "!EXTRACT_DIR!" 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try {" ^
    "    Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%EXTRACT_DIR%' -Force;" ^
    "} catch {" ^
    "    Write-Error $_.Exception.Message;" ^
    "}"

set "ROOT_EXTRACT="
for /d %%D in ("!EXTRACT_DIR!\biraj-mpv-conf*") do (
    set "ROOT_EXTRACT=%%D"
)

if defined ROOT_EXTRACT goto :EXTRACT_OK

echo.
echo [ERROR] Failed to locate extracted repository files in: !EXTRACT_DIR!
echo Guidance: Please ensure your system has enough free disk space in %%TEMP%% and re-run.
echo.
if exist "!TEMP_ZIP!" del /f /q "!TEMP_ZIP!" 2>nul
if exist "!EXTRACT_DIR!" rmdir /s /q "!EXTRACT_DIR!" 2>nul
pause
exit /b 1

:EXTRACT_OK
echo.
echo [4/4] Deploying configuration suite into %APPDATA%\mpv...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$src = '!ROOT_EXTRACT!';" ^
    "$dst = [System.Environment]::ExpandEnvironmentVariables('%%APPDATA%%\mpv');" ^
    "if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null };" ^
    "$cfgFiles = @('mpv.conf', 'input.conf', 'menu.conf', 'yt-dlp.conf', 'biraj-mpv-guide.pdf', 'biraj-mpv-key-binding.pdf');" ^
    "foreach ($f in $cfgFiles) {" ^
    "    $sp = Join-Path $src $f;" ^
    "    if (Test-Path $sp) { Copy-Item -Path $sp -Destination (Join-Path $dst $f) -Force; Write-Host ('  Updated: ' + $f) };" ^
    "};" ^
    "$cfgDirs = @('fonts', 'script-opts', 'scripts', 'Stremio-Play-in-MPV', 'Windows-Context-Menu');" ^
    "foreach ($d in $cfgDirs) {" ^
    "    $sd = Join-Path $src $d;" ^
    "    if (Test-Path $sd) {" ^
    "        $dd = Join-Path $dst $d;" ^
    "        if (-not (Test-Path $dd)) { New-Item -ItemType Directory -Path $dd -Force | Out-Null };" ^
    "        Copy-Item -Path (Join-Path $sd '*') -Destination $dd -Recurse -Force;" ^
    "        Write-Host ('  Synced Directory: ' + $d + '/') -ForegroundColor Cyan;" ^
    "    };" ^
    "};"

:: Write new version stamp file
(
    echo Repository   : https://github.com/Biraj2004/biraj-mpv-conf
    echo Branch       : main
    echo Commit-Full  : !REMOTE_FULL_SHA!
    echo Commit-Short : !REMOTE_SHORT_SHA!
    echo Commit-Date  : !REMOTE_DATE!
    echo Commit-Author: !REMOTE_AUTHOR!
    echo Commit-Msg   : !REMOTE_MSG!
    echo Installed-At : %DATE% %TIME%
) > "!VERSION_FILE!"

:: Clean up temporary download artifacts
if exist "!TEMP_ZIP!" del /f /q "!TEMP_ZIP!" 2>nul
if exist "!EXTRACT_DIR!" rmdir /s /q "!EXTRACT_DIR!" 2>nul

echo.
echo =======================================================================================================
echo                                   SYNC COMPLETED SUCCESSFULLY!
echo =======================================================================================================
echo  [SUCCESS] %%APPDATA%%\mpv is now synchronized with latest commit: !REMOTE_SHORT_SHA!
echo  [DATE]    !REMOTE_DATE! UTC
echo  [MESSAGE] !REMOTE_MSG!
echo.
echo RECOMMENDED NEXT STEPS:
echo  1. INSTALL MODERNZ ICONS FONT:
echo     - If icons appear as boxes/squares, open:
echo       %APPDATA%\mpv\fonts\modernz-icons.ttf
echo     - Right-click -^> Click "Install" (or "Install for all users").
echo.
echo  2. EXPLORER RIGHT-CLICK CONTEXT MENU [Optional]:
echo     - To add "Play with MPV" for videos and folders in Windows Explorer:
echo       Open %APPDATA%\mpv\Windows-Context-Menu\ and run "Setup_Play_with_MPV_Context_Menu.bat".
echo.
echo  3. STREMIO "PLAY IN MPV" INTEGRATION [Optional]:
echo     - To stream torrents/HTTP links directly into MPV with tone-mapping:
echo       Follow instructions in %APPDATA%\mpv\Stremio-Play-in-MPV\README.md.
echo.
echo  4. CHEAT-SHEET ^& DOCUMENTATION:
echo     - User Guide PDF        : %APPDATA%\mpv\biraj-mpv-guide.pdf
echo     - Keybinding Cheat-Sheet : %APPDATA%\mpv\biraj-mpv-key-binding.pdf
echo     - Online Website         : https://biraj2004.github.io/biraj-mpv-conf/
echo =======================================================================================================
echo.

if defined MPV_EXE (
    echo [INFO] Verifying MPV binary launch...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "try { & '!MPV_EXE!' --version | Select-Object -First 2 } catch { Write-Host 'Ready.' }"
    echo.
)

pause
exit /b 0
