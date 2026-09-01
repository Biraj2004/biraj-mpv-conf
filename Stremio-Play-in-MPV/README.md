# Stremio Desktop MPV Integration — "Play in MPV"

<div align="center">

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../LICENSE)
[![Platform: Windows & macOS](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS-0078D6.svg?logo=windows&logoColor=white)](https://stremio.com)
[![Author: Biraj Sarkar](https://img.shields.io/badge/Developer-Biraj%20Sarkar%20(@Biraj2004)-ff69b4.svg)](https://github.com/Biraj2004)

**Automated 1-click installer suite to integrate MPV as a native external media player ("Play in MPV") directly inside the Stremio desktop application alongside VLC.**

[Overview](#overview) • [Prerequisites](#prerequisites) • [Quick Installation](#quick-installation) • [How to Use](#how-to-use) • [Safety & Backup Architecture](#safety--backup-architecture) • [How It Works](#how-it-works)

</div>

---

## Overview

Stremio's built-in web player is convenient, but lacks advanced features like GPU tone-mapping, HDR10+/Dolby Vision passthrough, 400MB demuxer caching, and custom subtitle rendering. 

By default, Stremio only includes an option for *"Play in VLC"*. This integration patches Stremio's local server engine to add **"Play in MPV"**, seamlessly forwarding streams, torrents, and subtitles directly to your custom `biraj-mpv-conf` setup with zero quality loss.

- ✅ **One-Click Automated Setup**: Detects MPV and patches Stremio without requiring manual coding.
- ✅ **Cross-Platform Support**: Dedicated installers for **Windows 10/11** (`.bat`) and **macOS** (`.sh` for Apple Silicon & Intel).
- ✅ **Full Configuration Support**: Launches streams with all your `mpv.conf` settings, ModernZ OSC, RAM cache, and HDR tone-mapping intact.
- ✅ **Zero-Risk Safety**: Automatically creates timestamped backups (`.backup_YYYYMMDD_HHMMSS`) before any file modification.

---

## Prerequisites

1. **Stremio Desktop**: Installed on Windows or macOS ([stremio.com](https://www.stremio.com/)).
2. **MPV Installed**:
   - **Windows**: In standard locations (`C:\Program Files\mpv\`, `C:\mpv\`, `%LOCALAPPDATA%\Programs\mpv\`, Scoop, or system `PATH`).
   - **macOS**: Installed via Homebrew (`brew install --cask mpv`), MacPorts, or placed in `/Applications/mpv.app`.
3. **biraj-mpv-conf**: Configuration files placed in `%APPDATA%\mpv\` (Windows) or `~/.config/mpv/` (macOS).

---

## Quick Installation

### Windows (1-Click)
1. Close Stremio if it is currently running.
2. Double-click [`Win_Setup_Stremio_To_Play_In_MPV.bat`](Win_Setup_Stremio_To_Play_In_MPV.bat).
3. The script will automatically locate your `mpv.exe` and Stremio `server.js`.
4. Type `Y` and hit <kbd>Enter</kbd>.
5. Done! Launch Stremio to enjoy MPV integration.

### macOS (Terminal)
1. Close Stremio if it is running.
2. Open Terminal in this folder and make the script executable:
   ```bash
   chmod +x macOS_Setup_Stremio_To_Play_In_MPV.sh
   ./macOS_Setup_Stremio_To_Play_In_MPV.sh
   ```
3. Type `Y` and press <kbd>Enter</kbd>.
4. Done!

---

## How to Use

1. Open **Stremio** and start playing any movie, anime episode, or series.
2. Click the **Player Settings (gear / 3-dots icon)** in the bottom right corner (or right-click the video).
3. Select **"Play in MPV"** (listed next to *"Play in VLC"*).
4. MPV will immediately launch the stream with:
   - Full 400MB forward RAM cache + 25s readahead.
   - Dynamic HDR10+ / Dolby Vision tone-mapping.
   - Anti-spam audio & subtitle track cycling (<kbd>v</kbd> / <kbd>j</kbd> / <kbd>b</kbd>).
   - High-contrast 50px styled subtitles.

---

## Safety & Backup Architecture

| Feature | How It Protects Your System |
| :--- | :--- |
| **Automatic Timestamped Backups** | Before modifying `server.js`, a full copy named `server.js.backup_YYYYMMDD_HHMMSS` is saved in the same directory. |
| **Process Conflict Detection** | Detects active `stremio.exe` or `stremio-runtime` processes to prevent file lock errors during patching. |
| **Idempotent / Safe Re-Runs** | If Stremio is already patched with the latest handler, re-running the script safely detects this and skips modification. |
| **Path Auto-Resolution** | Dynamically scans standard installation trees, 64-bit/32-bit Program Files, LocalAppData, and package managers (Scoop/Homebrew). |

---

## How It Works

Stremio uses a local Node.js background streaming server (`server.js`) to handle video torrent streams and external player forwarding.

1. **Detection**: The setup script locates `server.js` inside Stremio's application directory (`%LOCALAPPDATA%\Programs\LNV\Stremio-4\` on Windows or `/Applications/Stremio.app/` on macOS).
2. **Injection**: It injects an external player definition and launch handler for MPV:
   ```javascript
   {
       name: "MPV",
       title: "Play in MPV",
       args: [streamUrl]
   }
   ```
3. **Execution**: When you click *"Play in MPV"*, Stremio passes the local caching stream URL (`http://127.0.0.1:11470/...`) directly into `mpv.exe`, enabling high-performance playback.

---

## Author & License

- **Developer**: [Biraj Sarkar](https://github.com/Biraj2004) ([@Biraj2004](https://github.com/Biraj2004))
- **Repository**: [biraj-mpv-conf](https://github.com/Biraj2004/biraj-mpv-conf)
- **License**: [Apache-2.0 License](../LICENSE)
