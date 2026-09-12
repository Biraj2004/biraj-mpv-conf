@echo off
setlocal EnableDelayedExpansion
title Setup "Play in MPV" Browser Extension - by Biraj2004
cd /d "%~dp0"

:: =======================================================================================================
:: GitHub      : https://github.com/Biraj2004/biraj-mpv-conf
:: Developer   : Biraj Sarkar (@Biraj2004)
:: License     : Apache-2.0
:: Description : Registers the Native Messaging host for the "Play in MPV" browser extension.
::
::               What this does:
::                 - Finds Python on your system (required to run mpv_launcher.py).
::                 - Finds mpv.exe on your system.
::                 - Creates launch_host.bat (a tiny wrapper Chrome uses to call Python).
::                 - Writes mpv_launcher_host.json with all absolute paths baked in.
::                 - Registers the host in the Windows registry for BOTH Chrome and Brave.
::                 - No admin rights required (writes to HKCU only).
::
::               After running this script:
::                 - Right-click any link in Chrome/Brave → "Open Link in MPV"
::                 - A "Play in MPV" button appears in the YouTube player controls
::
::               Re-run this script if:
::                 - You reload the extension (the Extension ID changes in Developer Mode)
::                 - You move this folder to a new location
::                 - You want to switch to a different Python or MPV installation
:: =======================================================================================================

echo =======================================================================================================
echo                         SETUP "PLAY IN MPV" BROWSER EXTENSION
echo                       Developed by : Biraj Sarkar
echo                       GitHub       : https://github.com/Biraj2004/biraj-mpv-conf
echo =======================================================================================================
echo.
echo  [1] Install   - Register native messaging host for Chrome and Brave
echo  [2] Uninstall - Remove native messaging host registration
echo  [3] Exit
echo.
echo =======================================================================================================
set "CHOICE="
set /p CHOICE=Choose an option [1, 2, or 3] and press Enter: 

if "%CHOICE%"=="1" goto :INSTALL
if "%CHOICE%"=="2" goto :UNINSTALL
if "%CHOICE%"=="3" goto :EXIT
goto :EXIT


:: ═══════════════════════════════════════════════════════════════════════════════
::  INSTALL
:: ═══════════════════════════════════════════════════════════════════════════════
:INSTALL
echo.
echo =======================================================================================================
echo  [STEP 1/4] Locating Python...
echo =======================================================================================================

set "PYTHON_EXE="

:: Check system PATH first (skip WindowsApps 0-byte execution alias)
for /f "delims=" %%P in ('where python.exe 2^>nul') do (
    if not defined PYTHON_EXE (
        echo "%%P" | findstr /i "WindowsApps" >nul
        if errorlevel 1 set "PYTHON_EXE=%%P"
    )
)

:: Common install locations if not in PATH
if not defined PYTHON_EXE (
    for %%D in (
        "%LOCALAPPDATA%\Python\bin\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python39\python.exe"
        "%APPDATA%\Python\Python314\Scripts\python.exe"
        "%APPDATA%\Python\Python313\Scripts\python.exe"
        "C:\Python314\python.exe"
        "C:\Python313\python.exe"
        "C:\Python312\python.exe"
        "C:\Python311\python.exe"
        "%USERPROFILE%\scoop\shims\python.exe"
    ) do (
        if not defined PYTHON_EXE if exist %%D set "PYTHON_EXE=%%~D"
    )
)

if not defined PYTHON_EXE (
    echo.
    echo [ERROR] Python was not found on this system.
    echo         Python is required to run the native messaging host.
    echo.
    echo         Install Python via winget:
    echo           winget install --id Python.Python.3
    echo.
    echo         Or download from: https://www.python.org/downloads/
    echo         Make sure to check "Add Python to PATH" during installation.
    echo.
    pause
    goto :EOF
)

echo [SUCCESS] Found Python at: "!PYTHON_EXE!"


echo.
echo =======================================================================================================
echo  [STEP 2/4] Locating mpv.exe...
echo =======================================================================================================

set "MPV_EXE="

:: Check PATH
for /f "delims=" %%P in ('where mpv.exe 2^>nul') do (
    if not defined MPV_EXE set "MPV_EXE=%%P"
)

:: Known install locations
if not defined MPV_EXE if exist "C:\Program Files\mpv\mpv.exe"                         set "MPV_EXE=C:\Program Files\mpv\mpv.exe"
if not defined MPV_EXE if exist "C:\mpv\mpv.exe"                                        set "MPV_EXE=C:\mpv\mpv.exe"
if not defined MPV_EXE if exist "%LOCALAPPDATA%\Programs\mpv\mpv.exe"                   set "MPV_EXE=%LOCALAPPDATA%\Programs\mpv\mpv.exe"
if not defined MPV_EXE if exist "%USERPROFILE%\scoop\apps\mpv\current\mpv.exe"          set "MPV_EXE=%USERPROFILE%\scoop\apps\mpv\current\mpv.exe"
if not defined MPV_EXE if exist "%USERPROFILE%\scoop\shims\mpv.exe"                     set "MPV_EXE=%USERPROFILE%\scoop\shims\mpv.exe"

if not defined MPV_EXE (
    echo [WARNING] mpv.exe was not found automatically.
    echo           Defaulting to: C:\Program Files\mpv\mpv.exe
    echo.
    echo           Install MPV via winget:
    echo             winget install --id shinchiro.mpv
    echo.
    echo           Or download from: https://github.com/zhongfly/mpv-winbuild/releases
    echo           Extract and rename the folder to "mpv", place in C:\Program Files\
    set "MPV_EXE=C:\Program Files\mpv\mpv.exe"
) else (
    echo [SUCCESS] Found MPV at: "!MPV_EXE!"
)


echo.
echo =======================================================================================================
echo  [STEP 3/4] Extension ID
echo =======================================================================================================
echo.
echo  To find your Extension ID:
echo    1. Open Chrome or Brave
echo    2. Navigate to:  chrome://extensions
echo    3. Enable "Developer mode" (top-right toggle)
echo    4. Find "Play in MPV" in the list
echo    5. Copy the ID shown below the extension name
echo       (it looks like: abcdefghijklmnopqrstuvwxyzabcdef)
echo.
echo =======================================================================================================
set "EXT_ID="
set /p EXT_ID=Paste your Extension ID and press Enter: 

if "%EXT_ID%"=="" (
    echo.
    echo [ERROR] No Extension ID entered. Please load the extension first.
    echo         See README.md for step-by-step instructions.
    echo.
    pause
    goto :EOF
)

:: Basic sanity check: Chrome extension IDs are 32 lowercase letters
set "EXT_ID_CLEAN=!EXT_ID: =!"
echo [INFO] Using Extension ID: !EXT_ID_CLEAN!


echo.
echo =======================================================================================================
echo  [STEP 4/4] Writing files and registering...
echo =======================================================================================================

:: Absolute path to THIS folder (mpv_native_host/)
set "HOST_DIR=%~dp0"
:: Remove trailing backslash
if "!HOST_DIR:~-1!"=="\" set "HOST_DIR=!HOST_DIR:~0,-1!"

set "LAUNCHER_PY=!HOST_DIR!\mpv_launcher.py"
set "WRAPPER_BAT=!HOST_DIR!\launch_host.bat"
set "MANIFEST_JSON=!HOST_DIR!\mpv_launcher_host.json"

:: ── 1. Create launch_host.bat (the actual executable Chrome calls) ──────────
:: Chrome requires the path in the manifest to be a real executable.
:: On Windows, a .bat file works perfectly — stdin/stdout are piped through correctly.
(
    echo @echo off
    echo "!PYTHON_EXE!" "!LAUNCHER_PY!" %%*
) > "!WRAPPER_BAT!"

if not exist "!WRAPPER_BAT!" (
    echo [ERROR] Failed to create launch_host.bat. Check folder permissions.
    pause
    goto :EOF
)
echo [OK] Created: launch_host.bat

:: ── 2. Escape backslashes for JSON ──────────────────────────────────────────
set "WRAPPER_JSON=!WRAPPER_BAT:\=\\!"

:: ── 3. Write mpv_launcher_host.json ─────────────────────────────────────────
(
    echo {
    echo   "name": "com.biraj.mpv_launcher",
    echo   "description": "Biraj MPV Launcher - opens URLs in your local MPV media player",
    echo   "path": "!WRAPPER_JSON!",
    echo   "type": "stdio",
    echo   "allowed_origins": [
    echo     "chrome-extension://!EXT_ID_CLEAN!/"
    echo   ]
    echo }
) > "!MANIFEST_JSON!"

if not exist "!MANIFEST_JSON!" (
    echo [ERROR] Failed to write mpv_launcher_host.json.
    pause
    goto :EOF
)
echo [OK] Created: mpv_launcher_host.json

:: ── 4. Register in Windows registry (HKCU — no admin needed) ────────────────
set "JSON_PATH=!MANIFEST_JSON!"
set "REG_VALUE=!JSON_PATH!"

:: Chrome
reg add "HKCU\Software\Google\Chrome\NativeMessagingHosts\com.biraj.mpv_launcher" ^
    /ve /t REG_SZ /d "!REG_VALUE!" /f >nul 2>&1
echo [OK] Registered for Google Chrome

:: Brave
reg add "HKCU\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.biraj.mpv_launcher" ^
    /ve /t REG_SZ /d "!REG_VALUE!" /f >nul 2>&1
echo [OK] Registered for Brave Browser

:: Microsoft Edge (bonus — same architecture)
reg add "HKCU\Software\Microsoft\Edge\NativeMessagingHosts\com.biraj.mpv_launcher" ^
    /ve /t REG_SZ /d "!REG_VALUE!" /f >nul 2>&1
echo [OK] Registered for Microsoft Edge


echo.
echo =======================================================================================================
echo  [SUCCESS] Native messaging host registered!
echo =======================================================================================================
echo.
echo   Next steps:
echo     1. Reload the extension in chrome://extensions  (click the refresh icon)
echo     2. Right-click any link in Chrome/Brave and choose "Open Link in MPV"
echo     3. Open any YouTube video and click the MPV button in the player controls
echo.
echo   Test without Chrome:
echo     python "!LAUNCHER_PY!" --test
echo.
echo =======================================================================================================
echo.
pause
goto :EOF


:: ═══════════════════════════════════════════════════════════════════════════════
::  UNINSTALL
:: ═══════════════════════════════════════════════════════════════════════════════
:UNINSTALL
echo.
echo [INFO] Removing native messaging host registration...

reg delete "HKCU\Software\Google\Chrome\NativeMessagingHosts\com.biraj.mpv_launcher"        /f >nul 2>&1
reg delete "HKCU\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.biraj.mpv_launcher" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Edge\NativeMessagingHosts\com.biraj.mpv_launcher"       /f >nul 2>&1

:: Remove generated files (but not the template or the Python script)
set "HOST_DIR=%~dp0"
if "!HOST_DIR:~-1!"=="\" set "HOST_DIR=!HOST_DIR:~0,-1!"

if exist "!HOST_DIR!\mpv_launcher_host.json" (
    del /f /q "!HOST_DIR!\mpv_launcher_host.json" >nul 2>&1
    echo [OK] Removed mpv_launcher_host.json
)
if exist "!HOST_DIR!\launch_host.bat" (
    del /f /q "!HOST_DIR!\launch_host.bat" >nul 2>&1
    echo [OK] Removed launch_host.bat
)

echo.
echo =======================================================================================================
echo  [SUCCESS] Native messaging host removed from Chrome, Brave, and Edge.
echo =======================================================================================================
echo.
echo   The extension will no longer communicate with MPV.
echo   To re-enable, run this script again and choose option [1].
echo.
pause
goto :EOF


:EXIT
endlocal
