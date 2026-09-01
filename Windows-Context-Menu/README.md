# Windows File Explorer Context Menu Integration — "Play with MPV as a Playlist"

<div align="center">

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../LICENSE)
[![Platform: Windows 10 / 11](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows)](https://microsoft.com/windows)
[![Author: Biraj Sarkar](https://img.shields.io/badge/Developer-Biraj%20Sarkar%20(@Biraj2004)-ff69b4.svg)](https://github.com/Biraj2004)

**Native Windows File Explorer context menu integration to launch folders, folder backgrounds, drives, or multi-selected video files directly into an automated natural ascending MPV playlist with the official MPV icon.**

[Overview](#overview) • [Prerequisites](#prerequisites) • [Quick Installation](#quick-installation) • [How to Use](#how-to-use) • [Behavior Matrix](#behavior-matrix) • [Uninstallation](#uninstallation) • [How It Works](#how-it-works)

</div>

---

## Overview

Just like VLC's *"Play with VLC media player"* context menu, this integration adds **"Play with MPV as a Playlist"** with the official MPV icon to Windows File Explorer. 

Combined with [`sort_playlist.lua`](../scripts/sort_playlist.lua) and [`single_instance.lua`](../scripts/single_instance.lua), this introduces clean **dual playback modes**:
- 🗂️ **"Play with MPV as a Playlist"**: Batches all selected files or folder contents into **1 single unified MPV window** with an automated natural ascending playlist (`01`, `02` ... `40`).
- 🪟 **Standard "Open" / Double-Click**: Retains normal independent multi-window behavior (each file opens in its own separate window).
- ✅ Auto-detects and attaches matching `.srt`/`.ass` subtitle files in the background without showing them in the playlist list.
- ✅ Excludes text notes (`command.txt`), metadata (`.nfo`), audios (`.mp3`), and images (`.jpg`).
- ✅ Operates strictly in user scope (`HKEY_CURRENT_USER\Software\Classes`) — **no Administrator privileges required**.

---

## Prerequisites

1. **Operating System**: Windows 10 or Windows 11 (64-bit).
2. **MPV Installed**: MPV installed in standard locations (e.g. `C:\Program Files\mpv\mpv.exe`, `C:\mpv\mpv.exe`, Scoop, or on system `PATH`).
3. **Configuration**: Config files (`mpv.conf`, `scripts/sort_playlist.lua`) placed in `%APPDATA%\mpv\` (or `portable_config/`).

---

## Quick Installation

Choose **either** Method 1 (Automated) or Method 2 (Manual Registry):

### Method 1: Automated 1-Click Installer (Recommended)
1. Double-click [`Setup_Play_with_MPV_Context_Menu.bat`](Setup_Play_with_MPV_Context_Menu.bat).
2. The script automatically detects your `mpv.exe` path across standard locations, Scoop, and system `PATH`.
3. Press `1` and hit <kbd>Enter</kbd>.
4. Done! The context menu option is immediately active.

### Method 2: Manual Registry Import
1. If your MPV is installed in `C:\Program Files\mpv\mpv.exe`:
   - Double-click [`Add_Play_with_MPV_Context_Menu.reg`](Add_Play_with_MPV_Context_Menu.reg).
   - Click **Yes** when prompted by Windows Registry Editor.
2. If your MPV is in a custom path (e.g. `C:\mpv\mpv.exe`):
   - Right-click [`Add_Play_with_MPV_Context_Menu.reg`](Add_Play_with_MPV_Context_Menu.reg) → **Edit**.
   - Replace `C:\\Program Files\\mpv\\mpv.exe` with your actual path, save, and double-click to import.

---

## How to Use

| Action | How to Do It | What Happens |
| :--- | :--- | :--- |
| **Play a Folder** | Right-click any single folder in File Explorer → Click **Play with MPV as a Playlist** | Launches MPV and queues all video episodes inside the folder in natural numerical order. |
| **Play Current Directory** | Open a folder → Right-click empty space in the background → Click **Play with MPV as a Playlist** | Plays all videos in the current open directory. |
| **Play Selected Videos** | Highlight 2 or more video files (`.mp4`, `.mkv`, etc.) → Right-click → Click **Play with MPV as a Playlist** | Batches the selected video files into one MPV playlist in natural ascending order. |
| **Play a USB / Drive** | Right-click an external drive or USB partition → Click **Play with MPV as a Playlist** | Scans and plays all video media on that drive. |

> [!NOTE]
> On **Windows 11**, if using the compact context menu, either click **Show more options** or press <kbd>Shift</kbd> + Right-click to display the full context menu instantly.

---

## Behavior Matrix

| Target | Shows Menu Option? | Explanation / Rule |
| :--- | :---: | :--- |
| **Single Folder** | ✅ **YES** | Matches `Directory\shell` with `AppliesTo="System.ItemCount:1"` |
| **Multiple Folders Selected** | ❌ **NO (Hidden)** | Automatically hidden when 2+ folders are selected to prevent multiple window clutter |
| **Single Video File** | ✅ **YES** | Matches `SystemFileAssociations\video` (`.mp4`, `.mkv`, `.avi`, `.webm`, `.mov`, `.ts`...) |
| **Multiple Video Files** | ✅ **YES** | Batches all selected videos into a single MPV player session (`MultiSelectModel="Player"`) |
| **Audio Files (`.mp3`, `.flac`...)** | ❌ **NO (Hidden)** | Excluded — reserved for your dedicated music player |
| **Images (`.jpg`, `.png`...)** | ❌ **NO (Hidden)** | Excluded — reserved for your photo viewer |
| **Subtitles & Text (`.srt`, `.txt`...)**| ❌ **NO (Hidden)** | Excluded from context menu |
| **Folder Background (Empty Space)** | ✅ **YES** | Matches `Directory\Background\shell` |
| **Single Drive / USB** | ✅ **YES** | Matches `Drive\shell` with `AppliesTo="System.ItemCount:1"` |

---

## Uninstallation

If you ever wish to remove the context menu entry:

- **Option A**: Run [`Setup_Play_with_MPV_Context_Menu.bat`](Setup_Play_with_MPV_Context_Menu.bat), press `2`, and hit <kbd>Enter</kbd>.
- **Option B**: Double-click [`Remove_Play_with_MPV_Context_Menu.reg`](Remove_Play_with_MPV_Context_Menu.reg) and click **Yes**.

---

## How It Works

1. **Windows Explorer Entry Point**:
   The registry entries create a lightweight shell command pointing to your `mpv.exe`:
   ```reg
   [HKEY_CURRENT_USER\Software\Classes\Directory\shell\PlayWithMPV]
   @="Play with MPV as a Playlist"
   "Icon"="\"C:\\Program Files\\mpv\\mpv.exe\",0"
   "AppliesTo"="System.ItemCount:1"

   [HKEY_CURRENT_USER\Software\Classes\Directory\shell\PlayWithMPV\command]
   @="\"C:\\Program Files\\mpv\\mpv.exe\" \"%1\""
   ```
2. **MPV Engine Processing**:
   When MPV receives the folder or files:
   - [`mpv.conf`](../mpv.conf) sets `directory-filter-types=video` and `autocreate-playlist=filter` to restrict scanning to video files.
   - [`sort_playlist.lua`](../scripts/sort_playlist.lua) detects the multi-file batch, cleans out any stray `.txt` or `.srt` entries, and arranges all video files into natural alphanumeric ascending order (`01`, `02`, ..., `40`).
   - `sub-auto=fuzzy` auto-detects and loads matching `.srt`/`.ass` subtitle files into the video track list during playback.

---

## Author & License

- **Developer**: [Biraj Sarkar](https://github.com/Biraj2004) ([@Biraj2004](https://github.com/Biraj2004))
- **Repository**: [biraj-mpv-conf](https://github.com/Biraj2004/biraj-mpv-conf)
- **License**: [Apache-2.0 License](../LICENSE)
