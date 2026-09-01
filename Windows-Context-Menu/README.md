# Windows File Explorer Context Menu Integration — "Play with MPV as a Playlist"

<div align="center">

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../LICENSE)
[![Platform: Windows 10 / 11](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows)](https://microsoft.com/windows)
[![Author: Biraj Sarkar](https://img.shields.io/badge/Developer-Biraj%20Sarkar%20(@Biraj2004)-ff69b4.svg)](https://github.com/Biraj2004)

**Pure native Windows File Explorer context menu integration to launch folders, desktop folder shortcuts, drives, or multi-selected video files directly into an automated natural ascending MPV playlist with the official MPV icon.**

[Overview](#overview) • [Prerequisites](#prerequisites) • [Quick Installation](#quick-installation) • [How to Use](#how-to-use) • [Behavior Matrix](#behavior-matrix) • [Uninstallation](#uninstallation) • [How It Works](#how-it-works)

</div>

---

## Overview

Just like VLC's *"Play with VLC media player"* context menu, this integration adds **"Play with MPV as a Playlist"** with the official MPV icon to Windows File Explorer. 

Combined with [`sort_playlist.lua`](../scripts/sort_playlist.lua) and [`single_instance.lua`](../scripts/single_instance.lua), this introduces clean **dual playback modes**:
- 🗂️ **"Play with MPV as a Playlist"**: Batches all selected files or folder contents into **1 single unified MPV window** with an automated natural ascending playlist (`01`, `02` ... `40`).
- 🪟 **Standard "Open" / Double-Click**: Retains normal independent multi-window behavior (each file opens in its own separate window).
- ⚡ **Pure Native Architecture**: Directly invokes the official `mpv.exe` without any third-party wrapper binaries.
- 🧹 **Automatic Deduplication & Filtering**: Purges duplicate entries and non-video files (`.txt`, `.nfo`, `.pdf`) automatically in the background.
- 🛡️ **Zero Desktop Pollution**: Multi-file batch selection loads strictly the highlighted items and never scans the parent directory.
- 🔒 **User Scope**: Operates strictly in user scope (`HKEY_CURRENT_USER\Software\Classes`) — **no Administrator privileges required**.

---

## Prerequisites

1. **Operating System**: Windows 10 or Windows 11 (64-bit).
2. **MPV Installed**: Placed in `C:\Program Files\mpv\mpv.exe` (or `C:\mpv\mpv.exe`, Scoop, or on system `PATH`).
3. **Configuration**: Config files (`mpv.conf`, `scripts/`) placed in `%APPDATA%\mpv\` (or `portable_config/`).

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
| **Play a Folder / Shortcut** | Right-click any folder or desktop folder shortcut → Click **Play with MPV as a Playlist** | Launches MPV and queues all video episodes inside the folder in natural numerical order. |
| **Play Selected Videos** | Highlight 2 or more video files (`.mp4`, `.mkv`, etc.) → Right-click → Click **Play with MPV as a Playlist** | Batches the selected video files into one MPV playlist in natural ascending order (`S04E11` &rarr; `S04E12` &rarr; `S04E13`). |
| **Play a USB / Drive** | Right-click an external drive or USB partition → Click **Play with MPV as a Playlist** | Scans and plays all video media on that drive. |
| **Standard Multi-Window** | Highlight multiple files &rarr; Right-click &rarr; Click standard **Open** | Opens each file in its own independent MPV player window. |

> [!NOTE]
> On **Windows 11**, if using the compact context menu, either click **Show more options** or press <kbd>Shift</kbd> + Right-click to display the full context menu instantly.

---

## Behavior Matrix

| Target | Shows Menu Option? | Explanation / Rule |
| :--- | :---: | :--- |
| **Folders & Folder Shortcuts** | ✅ **YES** | Matches `Directory\shell` and `Folder\shell` |
| **Single Video File** | ✅ **YES** | Matches `SystemFileAssociations\video` and direct video extensions (`.mp4`, `.mkv`, `.avi`, `.webm`, `.mov`, `.ts`...) |
| **Multiple Video Files** | ✅ **YES** | Batches all selected videos into a single MPV player session (`MultiSelectModel="Player"`) |
| **Single Drive / USB** | ✅ **YES** | Matches `Drive\shell` |
| **Empty Desktop / Folder Background** | ❌ **NO (Clean)** | Excluded — keeps the right-click *View / Sort by / Refresh* menu clean |
| **Audio Files (`.mp3`, `.flac`...)** | ❌ **NO (Hidden)** | Excluded — reserved for your dedicated music player |
| **Images (`.jpg`, `.png`...)** | ❌ **NO (Hidden)** | Excluded — reserved for your photo viewer |
| **Documents (`.pdf`, `.txt`, `.docx`...)** | ❌ **NO (Hidden)** | Excluded from context menu |

---

## Uninstallation

If you ever wish to remove the context menu entry:

- **Option A**: Run [`Setup_Play_with_MPV_Context_Menu.bat`](Setup_Play_with_MPV_Context_Menu.bat), press `2`, and hit <kbd>Enter</kbd>.
- **Option B**: Double-click [`Remove_Play_with_MPV_Context_Menu.reg`](Remove_Play_with_MPV_Context_Menu.reg) and click **Yes**.

---

## How It Works

1. **Windows Explorer Entry Point**:
   The registry entries create a lightweight shell command pointing directly to your official `mpv.exe`:
   ```plaintext
   "C:\Program Files\mpv\mpv.exe" --script-opts-append=single_instance-enabled=yes "%1"
   ```

2. **Atomic Lock-Synchronized IPC Coordination ([`single_instance.lua`](../scripts/single_instance.lua))**:
   When Windows launches parallel processes for multi-selected files:
   - Process 1 creates the Windows Named Pipe (`\\.\pipe\mpvsocket_playlist`) and acts as the master instance.
   - Secondary processes wait for the pipe with a 30ms retry loop, forward their file paths via JSON IPC (`loadfile <path> append-play`), and terminate in ~10ms.

3. **Smart In-Memory Deduplication & Natural Sorting ([`sort_playlist.lua`](../scripts/sort_playlist.lua))**:
   The master player listens for playlist events, strips any duplicate entries, and sorts items in natural alphanumeric order (`1` &rarr; `2` &rarr; `10`).
