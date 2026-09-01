@echo off
setlocal EnableDelayedExpansion
title Setup "Play with MPV as a Playlist" Context Menu - by Biraj2004
cd /d "%~dp0"

:: =======================================================================================================
:: GitHub      : https://github.com/Biraj2004/biraj-mpv-conf
:: Developer   : Biraj Sarkar (@Biraj2004)
:: License     : Apache-2.0
:: Description : Adds or removes "Play with MPV as a Playlist" from Windows File Explorer context menu.
::                - Uses the official default mpv.exe (C:\Program Files\mpv\mpv.exe).
::                - Standard "Open": Opens normal separate independent MPV windows.
::                - "Play with MPV as a Playlist": Batches files into 1 single unified MPV window.
:: =======================================================================================================

echo =======================================================================================================
echo                         SETUP "PLAY WITH MPV AS A PLAYLIST" CONTEXT MENU
echo                       Developed by : Biraj Sarkar
echo                       GitHub       : https://github.com/Biraj2004/biraj-mpv-conf
echo =======================================================================================================
echo.
echo  [1] Add "Play with MPV as a Playlist" to File Explorer context menu
echo  [2] Remove "Play with MPV as a Playlist" from File Explorer context menu
echo  [3] Exit
echo.
echo =======================================================================================================
set "CHOICE="
set /p CHOICE=Choose an option [1, 2, or 3] and press Enter: 

if "%CHOICE%"=="1" goto :INSTALL
if "%CHOICE%"=="2" goto :UNINSTALL
if "%CHOICE%"=="3" goto :EXIT
goto :EXIT

:INSTALL
echo.
echo [INFO] Searching for standard mpv.exe...
set "MPV_EXE="
if exist "C:\Program Files\mpv\mpv.exe" set "MPV_EXE=C:\Program Files\mpv\mpv.exe"
if not defined MPV_EXE if exist "C:\mpv\mpv.exe" set "MPV_EXE=C:\mpv\mpv.exe"
if not defined MPV_EXE if exist "%LOCALAPPDATA%\Programs\mpv\mpv.exe" set "MPV_EXE=%LOCALAPPDATA%\Programs\mpv\mpv.exe"
if not defined MPV_EXE if exist "%USERPROFILE%\scoop\apps\mpv\current\mpv.exe" set "MPV_EXE=%USERPROFILE%\scoop\apps\mpv\current\mpv.exe"

if not defined MPV_EXE (
    for /f "delims=" %%I in ('where mpv.exe 2^>nul') do (
        set "MPV_EXE=%%I"
        goto :FOUND_MPV
    )
)

:FOUND_MPV
if not defined MPV_EXE (
    echo [WARNING] mpv.exe not detected automatically. Defaulting to: C:\Program Files\mpv\mpv.exe
    set "MPV_EXE=C:\Program Files\mpv\mpv.exe"
) else (
    echo [SUCCESS] Found MPV at: "!MPV_EXE!"
)

echo [INFO] Registering Windows Context Menu across SystemFileAssociations and Folders...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$mpv = '!MPV_EXE!';" ^
    "$fk = 'HKCU:\Software\Classes\Directory\shell\PlayWithMPV';" ^
    "New-Item -Path $fk -Force | Out-Null;" ^
    "Set-ItemProperty -Path $fk -Name '(Default)' -Value 'Play with MPV as a Playlist';" ^
    "Set-ItemProperty -Path $fk -Name 'Icon' -Value ('\"' + $mpv + '\",0');" ^
    "Set-ItemProperty -Path $fk -Name 'MultiSelectModel' -Value 'Player';" ^
    "New-Item -Path \"$fk\command\" -Force | Out-Null;" ^
    "Set-ItemProperty -Path \"$fk\command\" -Name '(Default)' -Value ('\"' + $mpv + '\" --script-opts-append=single_instance-enabled=yes \"%1\"');" ^
    "$foldk = 'HKCU:\Software\Classes\Folder\shell\PlayWithMPV';" ^
    "New-Item -Path $foldk -Force | Out-Null;" ^
    "Set-ItemProperty -Path $foldk -Name '(Default)' -Value 'Play with MPV as a Playlist';" ^
    "Set-ItemProperty -Path $foldk -Name 'Icon' -Value ('\"' + $mpv + '\",0');" ^
    "Set-ItemProperty -Path $foldk -Name 'MultiSelectModel' -Value 'Player';" ^
    "New-Item -Path \"$foldk\command\" -Force | Out-Null;" ^
    "Set-ItemProperty -Path \"$foldk\command\" -Name '(Default)' -Value ('\"' + $mpv + '\" --script-opts-append=single_instance-enabled=yes \"%1\"');" ^
    "$bgk = 'HKCU:\Software\Classes\Directory\Background\shell\PlayWithMPV';" ^
    "New-Item -Path $bgk -Force | Out-Null;" ^
    "Set-ItemProperty -Path $bgk -Name '(Default)' -Value 'Play with MPV as a Playlist';" ^
    "Set-ItemProperty -Path $bgk -Name 'Icon' -Value ('\"' + $mpv + '\",0');" ^
    "New-Item -Path \"$bgk\command\" -Force | Out-Null;" ^
    "Set-ItemProperty -Path \"$bgk\command\" -Name '(Default)' -Value ('\"' + $mpv + '\" --script-opts-append=single_instance-enabled=yes \"%V\"');" ^
    "$dk = 'HKCU:\Software\Classes\Drive\shell\PlayWithMPV';" ^
    "New-Item -Path $dk -Force | Out-Null;" ^
    "Set-ItemProperty -Path $dk -Name '(Default)' -Value 'Play with MPV as a Playlist';" ^
    "Set-ItemProperty -Path $dk -Name 'Icon' -Value ('\"' + $mpv + '\",0');" ^
    "Set-ItemProperty -Path $dk -Name 'MultiSelectModel' -Value 'Player';" ^
    "New-Item -Path \"$dk\command\" -Force | Out-Null;" ^
    "Set-ItemProperty -Path \"$dk\command\" -Name '(Default)' -Value ('\"' + $mpv + '\" --script-opts-append=single_instance-enabled=yes \"%1\"');" ^
    "$vk = 'HKCU:\Software\Classes\SystemFileAssociations\video\shell\PlayWithMPV';" ^
    "New-Item -Path $vk -Force | Out-Null;" ^
    "Set-ItemProperty -Path $vk -Name '(Default)' -Value 'Play with MPV as a Playlist';" ^
    "Set-ItemProperty -Path $vk -Name 'Icon' -Value ('\"' + $mpv + '\",0');" ^
    "Set-ItemProperty -Path $vk -Name 'MultiSelectModel' -Value 'Player';" ^
    "New-Item -Path \"$vk\command\" -Force | Out-Null;" ^
    "Set-ItemProperty -Path \"$vk\command\" -Name '(Default)' -Value ('\"' + $mpv + '\" --script-opts-append=single_instance-enabled=yes \"%1\"');" ^
    "$videoExts = @('.mkv', '.mp4', '.avi', '.webm', '.mov', '.ts', '.m2ts', '.flv', '.wmv', '.m4v', '.3gp', '.ogv', '.vob', '.dav', '.y4m', '.asf', '.f4v', '.rmvb', '.divx');" ^
    "foreach ($ext in $videoExts) {" ^
    "    $ek = \"HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\PlayWithMPV\";" ^
    "    New-Item -Path $ek -Force | Out-Null;" ^
    "    Set-ItemProperty -Path $ek -Name '(Default)' -Value 'Play with MPV as a Playlist';" ^
    "    Set-ItemProperty -Path $ek -Name 'Icon' -Value ('\"' + $mpv + '\",0');" ^
    "    Set-ItemProperty -Path $ek -Name 'MultiSelectModel' -Value 'Player';" ^
    "    New-Item -Path \"$ek\command\" -Force | Out-Null;" ^
    "    Set-ItemProperty -Path \"$ek\command\" -Name '(Default)' -Value ('\"' + $mpv + '\" --script-opts-append=single_instance-enabled=yes \"%1\"');" ^
    "}"

echo.
echo =======================================================================================================
echo  [SUCCESS] "Play with MPV as a Playlist" context menu is now active!
echo =======================================================================================================
echo.
pause
goto :EOF

:UNINSTALL
echo.
echo [INFO] Removing context menu entries from registry...
reg delete "HKCU\Software\Classes\Directory\shell\PlayWithMPV" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Folder\shell\PlayWithMPV" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\PlayWithMPV" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Drive\shell\PlayWithMPV" /f >nul 2>&1
reg delete "HKCU\Software\Classes\SystemFileAssociations\video\shell\PlayWithMPV" /f >nul 2>&1
reg delete "HKCU\Software\Classes\SystemFileAssociations\audio\shell\PlayWithMPV" /f >nul 2>&1

for %%E in (.mkv .mp4 .avi .webm .mov .ts .m2ts .flv .wmv .m4v .3gp .ogv .vob .dav .y4m .asf .f4v .rmvb .divx) do (
    reg delete "HKCU\Software\Classes\SystemFileAssociations\%%E\shell\PlayWithMPV" /f >nul 2>&1
)

echo.
echo =======================================================================================================
echo  [SUCCESS] "Play with MPV as a Playlist" context menu has been removed.
echo =======================================================================================================
echo.
pause
goto :EOF

:EXIT
endlocal
