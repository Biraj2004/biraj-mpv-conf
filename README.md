<div align="center">

# biraj-mpv-conf

**A refined, ultra-optimized, and modern configuration suite for [mpv media player](https://mpv.io/).**

[![mpv](https://img.shields.io/badge/mpv-v0.38%2B-blue?style=for-the-badge&logo=mpv&logoColor=white)](https://mpv.io/)
[![Renderer](https://img.shields.io/badge/Renderer-gpu--next-success?style=for-the-badge&logo=vulkan&logoColor=white)](https://mpv.io/manual/master/#options-vo)
[![Hardware Acceleration](https://img.shields.io/badge/HW%20Dec-auto--safe-informational?style=for-the-badge&logo=windows&logoColor=white)](https://mpv.io/manual/master/#options-hwdec)
[![UI Theme](https://img.shields.io/badge/UI-ModernZ%20(Fluent%2FMaterial)-orange?style=for-the-badge)](https://github.com/Samillion/ModernZ)
[![Security Policy](https://img.shields.io/badge/Security-Policy-brightgreen?style=for-the-badge&logo=shieldsdotio&logoColor=white)](SECURITY.md)
[![License](https://img.shields.io/badge/License-Apache_2.0-blueviolet?style=for-the-badge)](LICENSE)

<br/>

*Bridges the gap between mpv's lightweight performance and a sleek, feature-rich modern media player experience.*

[Live Documentation Website](https://biraj2004.github.io/biraj-mpv-conf/) • [Quick Start / Installation](#installation) • [Visual Showcase](#visual-showcase) • [How to Play](#how-to-play--usage-guide) • [Key Features](#key-features) • [Keybindings](#keyboard--mouse-shortcuts) • [Smart Profiles](#smart-automation-profiles) • [HDR & Tone-Mapping](#hdr--dolby-vision-playback) • [Customization](#customization) • [Credits](#credits--acknowledgements)

---

</div>

## Overview

**`biraj-mpv-conf`** elevates mpv from a minimalist, command-line-driven player into a polished desktop media powerhouse. Designed with performance, aesthetics, and convenience in mind, it combines next-generation video rendering pipelines with a modern Fluent/Material user interface, interactive right-click context menus, fast hover thumbnails, native file pickers, dynamic audio normalization, and smart contextual profiles.

---

## Visual Showcase

<div align="center">

### Modern Interface & Visual Scrubbing

| ModernZ OSC & Center Pause Indicator | Thumbfast Hover Preview & Subtitles |
| :---: | :---: |
| [![ModernZ OSC & Center Pause Indicator](screenshots/modernz-osc-pause-indicator.jpg)](screenshots/modernz-osc-pause-indicator.jpg) | [![Thumbfast Hover Preview & Subtitles](screenshots/thumbfast-hover-preview-subtitles.jpg)](screenshots/thumbfast-hover-preview-subtitles.jpg) |
| *ModernZ Fluent controller, chapter title, stream download button, center pause badge & format badge.* | *Instant seekbar hover thumbnail preview (`thumbfast`) with high-contrast, black-outlined subtitle rendering.* |

### Real-Time Engine & Playback Performance

| 4K HDR10+ Playback Statistics (`gpu-next`) | 1080p SDR Video Playback Statistics |
| :---: | :---: |
| [![4K HDR10+ Stats Overlay](screenshots/stats-overlay-4k-hdr10plus.jpg)](screenshots/stats-overlay-4k-hdr10plus.jpg) | [![1080p SDR Stats Overlay](screenshots/stats-overlay-1080p-sdr.jpg)](screenshots/stats-overlay-1080p-sdr.jpg) |
| *`gpu-next` rendering pipeline, D3D11VA HW decode, 144 Hz display sync, and HDR10+ peak brightness metadata.* | *1080p AVC decoding, frame timings, 0 dropped frames, WASAPI audio output, and chapter indexing.* |

### Format Detection & Interactive Stream Diagnostics

| Dynamic HDR10+ Format Badge Overlay | Interactive Console & Stream Log Overlay |
| :---: | :---: |
| [![HDR10+ Format Badge Overlay](screenshots/hdr10plus-badge-overlay.jpg)](screenshots/hdr10plus-badge-overlay.jpg) | [![Interactive Console & Stream Log](screenshots/interactive-console-stream-log.jpg)](screenshots/interactive-console-stream-log.jpg) |
| *Top-right floating badge (`hdr_badge.lua`) automatically announcing detected HDR10+ format on start.* | *Interactive REPL console (`~`), automatic profile switching, ModernZ URL detection, and yt-dlp log stream.* |

### Smart Playlist Sorting & Native File Dialog

| Natural Ascending Playlist Sorter | Native File Picker Dialog (Unicode Support) |
| :---: | :---: |
| [![Playlist Menu Ascending Sort](screenshots/playlist-menu-ascending-sort.jpg)](screenshots/playlist-menu-ascending-sort.jpg) | [![Native File Picker Dialog](screenshots/native-file-picker-dialog.jpg)](screenshots/native-file-picker-dialog.jpg) |
| *Interactive playlist selection menu automatically arranged in natural numerical ascending order (EP1 &rarr; EP2 &rarr; EP3 &rarr; EP3.1).* | *Windows native file picker dialog (<kbd>Ctrl</kbd>+<kbd>O</kbd>) supporting Unicode characters, curly quotes, and special symbols.* |

</div>

---

## Installation

### Step 0: Download & Set Up MPV on Windows (Standard Location)

To ensure 100% plug-and-play compatibility across Windows File Explorer context menus ([`Windows-Context-Menu/`](Windows-Context-Menu/)), Stremio desktop player hooks ([`Stremio-Play-in-MPV/`](Stremio-Play-in-MPV/)), and batch scripts, set up MPV in the standard Windows directory:

1. **Download MPV for Windows**:
   - Download the latest 64-bit build from **[zhongfly mpv-winbuild releases](https://github.com/zhongfly/mpv-winbuild/releases)** (or [shinchiro builds](https://sourceforge.net/projects/mpv-player-windows/files/)).
2. **Extract, Rename, and Place in `C:\Program Files\mpv\`**:
   - Extract the downloaded archive (e.g. `mpv-x86_64-v3-*.7z` or `.zip`).
   - Rename the extracted folder to **`mpv`** and move it directly to **`C:\Program Files\`**.
   - Your primary executable will reside at:
     ```plaintext
     C:\Program Files\mpv\mpv.exe
     ```
3. **Register File Types & Protocols**:
   - Inside `C:\Program Files\mpv\`, right-click **`mpv-register.bat`** &rarr; click **Run as administrator** to register video extensions and protocols with Windows.

> [!IMPORTANT]
> **Standard Paths Used Across This Suite:**
> - **Player Executable:** `C:\Program Files\mpv\mpv.exe`
> - **Configuration Directory:** `C:\Users\<YourUsername>\AppData\Roaming\mpv\` (accessible via `%APPDATA%\mpv`)
> 
> *If you previously installed or extracted MPV into a different location (such as `C:\mpv\`, `%LOCALAPPDATA%\Programs\mpv\`, or a custom drive), simply move/rename that folder to `C:\Program Files\mpv\` so all context menus, registry scripts, and external tools work instantly without manual configuration.*

---

### Step 1: Install Configuration & Scripts

### Full Target Paths on Windows

| Mode | Target Directory | Description |
| :--- | :--- | :--- |
| **Standard (Roaming)** | `C:\Users\<YourUsername>\AppData\Roaming\mpv\` | Default configuration location for installed mpv builds (accessible via `%APPDATA%\mpv`). |
| **Portable** | `C:\<PathToMpv>\portable_config\` | Used for standalone/portable mpv installations. |

---

### Method 1: Standard Installation (Windows) — *Recommended*

#### Option A: Quick Install via PowerShell (Fastest)
Open **PowerShell** and run the following command to download and place only the necessary configuration files and scripts into `%APPDATA%\mpv`:
```powershell
$temp = "$env:TEMP\biraj-mpv-conf"
git clone --depth 1 https://github.com/Biraj2004/biraj-mpv-conf.git $temp
New-Item -ItemType Directory -Force -Path "$env:APPDATA\mpv"
Copy-Item "$temp\mpv.conf", "$temp\input.conf", "$temp\menu.conf" -Destination "$env:APPDATA\mpv\" -Force
Copy-Item "$temp\fonts", "$temp\scripts", "$temp\script-opts" -Destination "$env:APPDATA\mpv\" -Recurse -Force
Remove-Item -Recurse -Force $temp
```

#### Option B: Manual Extraction (ZIP)
1. Download this repository as a ZIP archive: [**Download ZIP**](https://github.com/Biraj2004/biraj-mpv-conf/archive/refs/heads/main.zip).
2. Press <kbd>Win</kbd> + <kbd>R</kbd>, type `%APPDATA%\mpv`, and press **Enter** (or navigate to `C:\Users\<YourUsername>\AppData\Roaming\mpv\`).
3. Copy **only the necessary configuration folders and files** (`fonts/`, `scripts/`, `script-opts/`, `mpv.conf`, `input.conf`, `menu.conf`) from the extracted folder directly into `%APPDATA%\mpv\`. *(You do not need to copy repository docs, screenshots, or license files into mpv).*
4. Your resulting `%APPDATA%\mpv\` directory should look cleanly like this:
   ```plaintext
   C:\Users\<YourUsername>\AppData\Roaming\mpv\
   ├── fonts/
   │   └── modernz-icons.ttf
   ├── script-opts/
   │   ├── hdr_badge.conf
   │   ├── modernz.conf
   │   ├── pause_indicator_lite.conf
   │   ├── resume_indicator.conf
   │   └── thumbfast.conf
   ├── scripts/
   │   ├── hdr_badge.lua
   │   ├── modernz.lua
   │   ├── open-file.lua
   │   ├── pause_indicator_lite.lua
   │   ├── resume_indicator.lua
   │   ├── sort_playlist.lua
   │   └── thumbfast.lua
   ├── input.conf
   ├── menu.conf
   └── mpv.conf
   ```
5. **Install Icons Font**: Open `fonts/` inside your mpv directory, double-click `modernz-icons.ttf`, and click **Install**.

---

### Method 2: Portable Installation (All-in-One Folder)

If you are using a portable mpv build (e.g., extracted to `C:\mpv\` or a USB drive):
1. Navigate to your mpv root directory (where `mpv.exe` resides).
2. Create a folder named `portable_config` if one does not exist.
3. Copy **only the necessary configuration files and folders** directly into `portable_config`:
   ```plaintext
   C:\mpv\portable_config\
   ├── fonts/
   │   └── modernz-icons.ttf
   ├── script-opts/
   │   ├── hdr_badge.conf
   │   ├── modernz.conf
   │   ├── pause_indicator_lite.conf
   │   ├── resume_indicator.conf
   │   └── thumbfast.conf
   ├── scripts/
   │   ├── hdr_badge.lua
   │   ├── modernz.lua
   │   ├── open-file.lua
   │   ├── pause_indicator_lite.lua
   │   ├── resume_indicator.lua
   │   ├── sort_playlist.lua
   │   └── thumbfast.lua
   ├── input.conf
   ├── menu.conf
   └── mpv.conf
   ```
4. Install `fonts/modernz-icons.ttf` onto your system to enable vector icons.

---

### Method 3: Linux / macOS

While pre-tuned for Windows workflows with PowerShell dialogs and native Direct3D hardware acceleration, this configuration works smoothly on Linux and macOS:
1. Clone or extract the repository to `~/.config/mpv/`.
2. *(Optional)* In `mpv.conf`, verify or adjust the hardware decoding backend if needed:
   - **Linux**: `hwdec=auto-safe` (or explicitly `hwdec=vaapi` / `hwdec=nvdec`).
   - **macOS**: `hwdec=auto-safe` (or `hwdec=videotoolbox`).

---

## How to Play & Usage Guide

### 1. Playing Local Media Files & Folders
- **Drag & Drop**: Drag any video, audio track, image, or entire directory directly onto the mpv window.
- **Native File Dialog (<kbd>Ctrl</kbd> + <kbd>O</kbd>)**: Press <kbd>Ctrl</kbd> + <kbd>O</kbd> (or right-click $\rightarrow$ **Open** $\rightarrow$ **Open File**) to open the native Windows File Explorer picker. Select single or multiple files to load into the playlist.
- **Default Player Integration**: Right-click any media file in Windows File Explorer $\rightarrow$ **Open with** $\rightarrow$ **Choose another app** $\rightarrow$ select **mpv** and check *"Always use this app"*.

### 2. Streaming Online URLs (YouTube, Twitch, Playlists & Web Videos)
- **Drag & Drop URL**: Copy any video/stream or playlist link from your web browser and drag/drop it directly into the mpv window.
- **Playlists Support**: Automatically extracts and plays all playlist items when opening/pasting playlist URLs (`youtube.com/playlist?list=...` or `watch?v=...&list=...`).
- **Command Line / Terminal**:
  ```powershell
  # Stream video (automatically plays 2K 1440p -> 1080p -> 720p best available)
  mpv "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

  # Stream a full YouTube playlist
  mpv "https://www.youtube.com/playlist?list=PLrEnWoR732-BHrPp_Pm8_VleD68f9n14-"

  # Stream capped at 1080p Full HD
  mpv --profile=q-1080p "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

  # Stream capped at 720p HD
  mpv --profile=q-720p "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  ```
- **Switch Stream Quality On-The-Fly**:
  - **Right-Click**: Navigate to **Video** $\rightarrow$ **YT-Stream Quality** and select `720p`, `1080p`, `1440p`, or `Best`.
  - **Keyboard**: Press <kbd>Ctrl</kbd> + <kbd>y</kbd> to cycle between stream resolutions (720p $\rightarrow$ 1080p $\rightarrow$ 1440p $\rightarrow$ Best).
  - *The stream instantly reloads at the new resolution and resumes from your current second.*
- **One-Click Stream Download**: Click the download button on the ModernZ controller bar to save the online video directly to `~/Downloads/MPV-Downloads`.

### 3. Setting Up YouTube Cookies (Unlocking Full 1080p & 1440p Streaming)
YouTube enforces session authentication on separate high-definition adaptive streams (DASH/HLS). Without cookies, YouTube blocks direct stream requests with HTTP 403 Forbidden or falls back to 360p. Supplying your cookies allows mpv to stream high-definition 1080p Full HD and 1440p 2K with hardware decoding.

#### Method 1: Exporting `cookies.txt` (Works with Chrome, Brave, Edge, Opera, Firefox)
1. Install a cookie exporter extension in your browser:
   - **Cookie-Editor** (Chrome / Edge / Firefox / Brave) or **Get cookies.txt LOCALLY**.
2. Open [YouTube](https://www.youtube.com) in your browser and ensure you are signed in.
3. Open the extension and click **Export** $\rightarrow$ **Export as Netscape** (or **Export as cookies.txt**).
4. Save the file as `cookies.txt` inside your mpv configuration directory:
   ```plaintext
   C:\Users\<YourUsername>\AppData\Roaming\mpv\cookies.txt
   ```
5. In `mpv.conf`, enable the cookie path:
   ```ini
   ytdl-raw-options-append=cookies=C:\Users\<YourUsername>\AppData\Roaming\mpv\cookies.txt
   ```

#### Method 2: Direct Browser Session (Firefox)
If you use Mozilla Firefox, you can read cookies directly without exporting a file:
```ini
ytdl-raw-options-append=cookies-from-browser=firefox
```

> [!NOTE]
> `cookies.txt` is automatically excluded in `.gitignore` so your personal authentication tokens will never be committed or uploaded to GitHub.

### 4. Adding Subtitles & External Audio Tracks
- **Drag & Drop**: Drag any `.srt`, `.ass`, `.vtt`, or `.sub` file directly onto the playing video.
- **Native Subtitle Dialog (<kbd>Ctrl</kbd> + <kbd>S</kbd>)**: Opens Windows Explorer to browse and attach subtitles.
- **Native Audio Track Dialog (<kbd>Ctrl</kbd> + <kbd>A</kbd>)**: Opens Windows Explorer to add secondary audio tracks (e.g. commentary, alternative dubs).
- **Quick Track Cycling**:
  - Press <kbd>v</kbd> / <kbd>Shift</kbd> + <kbd>v</kbd> (<kbd>V</kbd>) *(or standard mpv <kbd>j</kbd> / <kbd>J</kbd>)* to cycle subtitle tracks forward / backward *(VLC & MPV standard, anti-spam debounced, instant 0ms OSD, includes Off/None state)*.
  - Press <kbd>b</kbd> to cycle audio languages forward or <kbd>Shift</kbd> + <kbd>b</kbd> (<kbd>B</kbd>) backward *(or standard mpv <kbd>_</kbd> / <kbd>#</kbd>)* *(VLC & MPV standard, loops languages, anti-spam debounced, instant 0ms OSD)*.

### 5. Essential Playback Controls
- **Play / Pause**: <kbd>Space</kbd> or <kbd>Media Play/Pause</kbd>
- **Exact Seeking**: <kbd>→</kbd> / <kbd>←</kbd> (6s exact) • <kbd>Media Forward/Rewind</kbd> (15s exact) • <kbd>Home</kbd> (beginning)
- **Volume & Mute**: <kbd>↑</kbd> / <kbd>↓</kbd> (±5%) • <kbd>m</kbd> (Mute)
- **Toggle Fullscreen**: <kbd>f</kbd> or **Double Click Left Mouse**
- **Context Menu**: <kbd>Right Click</kbd> or <kbd>g</kbd> <kbd>m</kbd>
- **Night Mode Audio Normalization**: <kbd>y</kbd> or <kbd>N</kbd> (balances loud explosions & quiet dialogue)
- **Real-Time Performance Stats**: <kbd>i</kbd> (fps, dropped frames, decoder, HDR nits)

---

## Key Features

### Modern UI and Fluent On-Screen Controller
- **[ModernZ](https://github.com/Samillion/ModernZ) OSC Interface**: Replaces the default interface with a clean, responsive On-Screen Controller styled with Fluent/Material vector icons.
- **Translucent Minimalist OSD**: Dark pill-box OSD overlays with crisp typography (`osd-duration=2500` 2.5s readable duration, `osd-playing-msg-duration=2500` 2.5s startup filename duration), eliminating disruptive double seekbars (`osd-bar=no`).
- **Sleek Pause / Play Indicator**: Minimalist, non-distracting center pause/unpause visual flash indicators ([`pause_indicator_lite`](https://github.com/Samillion/ModernZ/tree/main/extras/pause-indicator-lite)).
- **Action-Based Controls & State-Based Overlay Philosophy**:
  - **Bottom OSC Control Bar (Action-Based — YouTube/VLC Standard)**: The interactive buttons follow the standard media player trigger philosophy, displaying the **action to be performed on click** (e.g. shows `▶` Play when paused to resume, and `||` Pause when playing to pause).
  - **Center Canvas Overlay (State-Based)**: The center display functions as an immediate **status feedback indicator**, displaying the **current playback state** (e.g. shows `||` Pause icon when paused, and flashes `▶` Play triangle when playback starts/resumes).

### Next-Gen GPU Video Rendering & Tone-Mapping
- **`gpu-next` Engine**: Utilizes mpv's latest libplacebo-powered rendering backend for exceptional color accuracy, high-bitdepth pipelines, and HDR processing.
- **HDR10 & Dolby Vision (DV) Support**: Automatically tone-maps HDR10 and Dolby Vision (Profiles 5 & 8) to SDR on standard displays, preserving highlight details and color saturation without washed-out tones. Subtitles retain crisp `#FFFFFF` white on SDR displays (`blend-subtitles=no`, `sub-hdr-peak=150`). Passes dynamic metadata on native HDR monitors (`target-colorspace-hint=yes`).
- **Dynamic HDR / DV / SDR Format Badge**: Minimalist floating overlay badge (`DV`, `HDR10+`, `HDR10`, `HLG`, `SDR`) in the top-right corner that announces the detected color format of the incoming media stream.
- **Auto-Safe Hardware Decoding (`hwdec=auto-safe`)**: Automatically negotiates the fastest, low-CPU/low-power video decoding pipeline (`d3d11va`, `nvdec`, `vaapi`) with safe fallback mechanisms and 16 extra VRAM buffers (`hwdec-extra-frames=16`).
- **Debanding & Temporal Dithering**: Eliminates color banding artifacts and gradient compression in dark scenes, anime, and compressed web video streams (`deband=yes`, `temporal-dither=yes`).
- **High-Fidelity Scaling**: Sigmoid upscaling and correct color-space downscaling algorithms for sharp playback without ringing artifacts.

> [!NOTE]
> **File Format vs. Screen Support**: The badge indicates the **color format received from the video file itself** (e.g. `DV` indicates a Dolby Vision file stream), **not** that your physical display panel supports native Dolby Vision. On standard SDR monitors, mpv automatically decodes the DV/HDR stream and tone-maps it into vivid, accurate SDR in real-time.

### Instant Seekbar Hover Thumbnails
- Integrated with **[`thumbfast`](https://github.com/po5/thumbfast)** to provide instant, real-time visual preview thumbnails when hovering or scrubbing along the seekbar.

### Rich Right-Click Context Menu
- Full-featured **contextual GUI menu** (`menu.conf`) accessible on right-click or via <kbd>g</kbd> <kbd>m</kbd>:
  - Toggle audio/subtitle streams with dedicated `Off / None` option, secondary subtitles, and audio devices.
  - Enable **Night Mode Audio Normalization** directly from the audio menu.
  - Choose HDR Tone-Mapping curves (*Auto libplacebo, BT.2390, Spline, Reinhard, Clip*).
  - Switch ModernZ layouts (*Default, Compact, Mini, Seekbar*) and icon styles (*Fluent, Material*).
  - Adjust playback speed (*0.25x* to *8.0x*), A-B looping, aspect ratios, zoom, and rotation.
  - View real-time playback statistics, drop frames, and media information.
  - Quick-copy media file paths, titles, or active subtitle text to the clipboard.

### Multi-File Playlist Natural Ascending Sorting & Video Filter
- **Strictly Video-Only Drag & Drop Filtering ([`sort_playlist.lua`](scripts/sort_playlist.lua))**: When dragging & dropping multiple files, batches, or folders into mpv, non-video files (`.txt`, `.nfo`, `.srt`, `.mp3`, `.jpg`, `.png`, `.part`, etc.) are automatically filtered out in a single high-speed pass so the playlist contains only playable video episodes.
- **Auto-Attached Subtitles**: Matching subtitle files (`.srt`, `.ass`, `.vtt`) are automatically detected and loaded directly into the active video's subtitle tracks via fuzzy matching (`sub-auto=fuzzy`) without cluttering the playlist list as separate entries.
- **Ultra-Fast & Accurate Natural Ascending Sort**: Precomputed cached keys format numbers with high-precision padding (`padnum`), sorting complex numbers (`01`, `02` ... `10`, `10.5`, `100`), brackets, and titles in under 2ms.
- **Defensive Safety Architecture**: Includes re-entrancy concurrency locks (`is_sorting`), debounced event coalescing (`80ms`), memory batch safety caps (`MAX_SORT_LIMIT = 5000`), protected exception boundaries (`pcall`), and non-video batch detection to prevent crashes or freezing.
- **"Play with MPV as a Playlist" Windows Explorer Context Menu ([`Windows-Context-Menu/`](Windows-Context-Menu/))**: Right-click any single folder, opened folder background, single external drive, or video files in Windows File Explorer to immediately open and play all videos in that folder as a naturally sorted playlist with the official MPV icon. Includes a 1-click installer ([`Setup_Play_with_MPV_Context_Menu.bat`](Windows-Context-Menu/Setup_Play_with_MPV_Context_Menu.bat)), standalone registry scripts, and documentation in [`Windows-Context-Menu/README.md`](Windows-Context-Menu/README.md).
- **Natural Ascending File Dialog Loading ([`open-file.lua`](scripts/open-file.lua))**: Selecting multiple files via <kbd>Ctrl</kbd>+<kbd>O</kbd> automatically sorts them in ascending order before adding them to the playlist.
- **On-Demand Playlist Sorter (<kbd>K</kbd> / Context Menu)**: Instant shortcut (`sort_playlist/sort-playlist`) to re-sort any active playlist into natural ascending order on demand.

### Native Windows File and Track Selectors
- **PowerShell / WPF Native Dialogs** ([`open-file.lua`](https://github.com/Samillion/ModernZ/tree/main/extras/open-file)): Seamlessly browse and open files (<kbd>Ctrl</kbd>+<kbd>O</kbd>), load external subtitles (<kbd>Ctrl</kbd>+<kbd>S</kbd>), or attach secondary audio tracks (<kbd>Ctrl</kbd>+<kbd>A</kbd>) using standard Windows File Explorer dialogs with natural ascending sort.

### Smart Dynamic Profiles & Audio Normalization
- **Night Mode Audio Normalization (<kbd>N</kbd> / <kbd>y</kbd>)**: Real-time `dynaudnorm` filter balancing quiet dialogue and loud sound effects during late-night viewing.
- **Fast 150ms WASAPI Audio Buffer (`audio-buffer=0.15`)**: Fast buffer fill time on track switches while remaining 100% immune to audio underruns and crackles.
- **Zero-Delay Persistence Safeguards**: Any manual audio/subtitle delay applied to defective media is automatically isolated—never saved to resume files and reset to 0.000ms on the next video.
- **Picture-in-Picture (`[Window-PiP]`)**: Automatically scales the OSC and enables a persistent progress bar when floating on-top in windowed mode.
- **Auto-Pause on Minimize (`[Minimized]`)**: Automatically pauses video when the player window is minimized to conserve system resources.
- **Windows Taskbar Progress Indicator (`[Video]`)**: Displays live playback completion progress directly on the Windows taskbar icon.
- **Dedicated Image Viewer Mode (`[Image]`)**: Automatically converts mpv into an image viewer with cursor-centric mouse zoom (<kbd>Wheel Up/Down</kbd>), image recentering (<kbd>0</kbd>), and infinite display duration.

### Advanced Subtitle & Audio Management
- **Anti-Spam Smart Track Cycler ([`cycle_audio.lua`](scripts/cycle_audio.lua))**: 0ms instant visual OSD response with 25ms decoder coalescing, preventing decoder thrashing, audio pops, and video freezes during rapid key spamming. Features seamless GUI menu synchronization and type-safe track matching.
- **Pixel-Perfect Subtitle Geometry (`sub-ass-use-video-data=all`)**: Modern mpv v0.39+ standard passing full video resolution and aspect ratio to `libass` for 100% accurate signs, rotations, and Gaussian blurs with 0 startup warnings.
- **Universal Subtitle Styling**: Renders crisp, high-contrast subtitles (`sub-font-size=50`, `sub-border-size=1.8`, `sub-shadow-offset=1.5`, `sub-shadow-color=0/0/0/0.5`, `#FFFFFF` with `#000000` outline and drop-shadow) guaranteeing immediate readability in both dark and bright scenes.
- **Original Anime Typesetting & Positioning (`sub-ass-override=no`)**: Fully preserves author-intended ASS styling, top-screen song lyrics (`{\an8}`), signs, and typesetting for anime, while plain `.srt` and `.vtt` subtitles use your configured custom size and styling (`sub-margin-y=36`).
- **Locked Subtitle Baseline**: Subtitles remain fixed to the video frame (`sub-use-margins=no`, `sub-ass-force-margins=no`) and never jitter or jump when the seekbar/OSC appears.
- **Zero-Lag Subtitle Switching (`demuxer-mkv-subtitle-preroll=no`)**: Prevents backward demuxer seeking on track changes for instant switching.
- **Smart Directory Search**: Automatically scans `sub/`, `subs/`, `subtitles/`, `srt/`, `ass/`, and `vtt/` subdirectories.
- **Subtitles Off by Default**: Clean view on launch (`sid=no`), easily enabled when needed via <kbd>v</kbd> or right-click menu.
- **Multi-Language Priority**: Default subtitle matching priority for English (`slang=en,enm`) and audio stream selection for Hindi, English, and Japanese (`alang=hi,en,ja`).

### High-Speed Streaming & Extended Format Support
- Integrated **`yt-dlp`** hook for seamless YouTube and web video streaming with one-click downloads to `~/Downloads/MPV-Downloads`.
- **Smart Stream & Seek Buffer**: 400 MiB forward cache + 200 MiB back-buffer + 25s deep readahead with RAM caching (cache-on-disk=no, demuxer-seekable-cache=yes, cache-pause=yes, cache-pause-wait=3) for smooth 4K REMUX, network streaming, and jitter-free auto-pause recovery.
- **Stremio & External Player Integration ([`Stremio-Play-in-MPV/`](Stremio-Play-in-MPV/))**: Includes automated one-click setup scripts ([`Win_Setup_Stremio_To_Play_In_MPV.bat`](Stremio-Play-in-MPV/Win_Setup_Stremio_To_Play_In_MPV.bat) and [`macOS_Setup_Stremio_To_Play_In_MPV.sh`](Stremio-Play-in-MPV/macOS_Setup_Stremio_To_Play_In_MPV.sh)) and complete documentation in [`Stremio-Play-in-MPV/README.md`](Stremio-Play-in-MPV/README.md) to seamlessly add *"Play in MPV"* into Stremio desktop.
- **Dynamic Stream Quality Selection**: Switch resolution on the fly (**720p HD, 1080p Full HD, 1440p 2K, or Best Fallback**) via right-click (**Video → YT-Stream Quality**), cycling shortcut (<kbd>Ctrl</kbd>+<kbd>y</kbd>), or profiles (`[q-720p]`, `[q-1080p]`, `[q-1440p]`, `[q-best]`).
- Comprehensive support for modern image (`AVIF`, `JXL`, `WEBP`, `QOI`, `HEIC`), audio (`FLAC`, `OPUS`, `ALAC`, `M4A`), and video containers (`MKV`, `MP4`, `WebM`, `M2TS`, `DAV`).

---

## Repository Structure

```plaintext
biraj-mpv-conf/
├── mpv.conf                  # Core configuration (renderer, cache, audio, video, profiles)
├── input.conf                # Custom keybindings, mouse shortcuts, and script triggers
├── menu.conf                 # Right-click context menu definitions
├── Windows-Context-Menu/     # Windows File Explorer context menu integration installers
│   ├── Add_Play_with_MPV_Context_Menu.reg    # Registry script to add "Play with MPV as a Playlist"
│   ├── Remove_Play_with_MPV_Context_Menu.reg # Registry script to remove the context menu
│   ├── Setup_Play_with_MPV_Context_Menu.bat  # 1-click installer and path auto-detector
│   ├── mpv-launcher.cs                       # C# source for mutex-synchronized multi-select IPC launcher
│   ├── mpv-launcher.exe                      # Lightweight (~6KB) 0-overhead single-instance playlist forwarder
│   └── README.md                             # Context menu setup guide and behavior matrix
├── Stremio-Play-in-MPV/      # Automated "Play in MPV" integration installers for Stremio
│   ├── Win_Setup_Stremio_To_Play_In_MPV.bat   # Windows Stremio external player setup script
│   ├── macOS_Setup_Stremio_To_Play_In_MPV.sh # macOS Stremio external player setup script
│   └── README.md                             # Stremio desktop integration guide and architecture
├── fonts/
│   └── modernz-icons.ttf     # Fluent & Material vector icons for ModernZ
├── scripts/
│   ├── cycle_audio.lua       # Zero-lag VLC & MPV audio / subtitle cycler with anti-spam debouncing
│   ├── hdr_badge.lua         # Dynamic HDR/DV/SDR format badge overlay
│   ├── modernz.lua           # Modern On-Screen Controller (OSC)
│   ├── open-file.lua         # Native Windows open file/subtitle/audio dialogs (with ascending sorting)
│   ├── pause_indicator_lite.lua # Translucent center pause/resume indicator
│   ├── resume_indicator.lua  # Clean OSD notification when resuming files e.g. "Resuming: (14:22 / 24:00)"
│   ├── sort_playlist.lua     # Natural alphanumeric ascending video playlist sorter & filter
│   └── thumbfast.lua         # High-performance seekbar thumbnail engine
├── script-opts/
│   ├── hdr_badge.conf        # Configuration for dynamic format badge
│   ├── modernz.conf          # Configuration for ModernZ UI theme, layout, fonts
│   ├── pause_indicator_lite.conf # Configuration for pause visual effects
│   ├── resume_indicator.conf # Configuration for on-screen resume notifications
│   └── thumbfast.conf        # Configuration for thumbnail caching and size
├── screenshots/
│   ├── hdr10plus-badge-overlay.jpg         # Dynamic HDR10+ format badge overlay
│   ├── interactive-console-stream-log.jpg  # Interactive console with yt-dlp & decoder logs
│   ├── modernz-osc-pause-indicator.jpg     # ModernZ OSC interface & center pause indicator
│   ├── stats-overlay-1080p-sdr.jpg         # Real-time stats overlay on 1080p SDR playback
│   ├── stats-overlay-4k-hdr10plus.jpg      # Real-time stats overlay on 4K HDR10+ playback
│   └── thumbfast-hover-preview-subtitles.jpg # Seekbar thumbnail preview & styled subtitles
├── biraj-mpv-key-binding.pdf # 1-page visual shortcuts manual (XeLaTeX)
├── biraj-mpv-guide.pdf       # Comprehensive reference guide (XeLaTeX)
├── keybindings-chart.jpg     # Visual keyboard & mouse shortcuts cheat sheet (300 DPI)
├── SECURITY.md               # Security policy and vulnerability disclosure
├── LICENSE                   # Apache 2.0 Open Source License
└── README.md                 # Documentation
```

---

## Keyboard & Mouse Shortcuts

<div align="center">

![Keyboard & Mouse Shortcuts Cheat Sheet](keybindings-chart.jpg)

</div>

### Mouse Controls
| Input | Action |
| :--- | :--- |
| **Double Click Left** | Toggle Fullscreen |
| **Right Click** | Open Context Menu (`menu.conf`) |
| **Mouse Hover Seekbar** | Show Fast Hover Thumbnail Preview (`thumbfast`) |
| **Scroll Wheel (Image Mode)** | Cursor-centric Zoom In / Zoom Out (±10%) |

---

### Playback & Navigation
| Shortcut | Action |
| :--- | :--- |
| <kbd>Space</kbd> / <kbd>Media Play/Pause</kbd> | Toggle Play / Pause |
| <kbd>→</kbd> / <kbd>←</kbd> | Seek forward / backward **6 seconds** (exact with OSD bar) |
| <kbd>Media Forward</kbd> / <kbd>Media Rewind</kbd> | Seek forward / backward **15 seconds** (exact with OSD bar) |
| <kbd>Home</kbd> | Seek to beginning of media (0s) |
| <kbd>.</kbd> / <kbd>,</kbd> | Frame step forward / backward |
| <kbd>n</kbd> / <kbd>p</kbd> *(or Media Next/Prev)* | Next / Previous playlist item |
| <kbd>k</kbd> | **Open interactive playlist selection menu** |
| <kbd>Shift</kbd> + <kbd>k</kbd> (<kbd>K</kbd>) | Sort active playlist in natural ascending order |
| <kbd>q</kbd> / <kbd>Alt+F4</kbd> | Quit mpv (remembers watch history & playback position) |

---

### Audio & Night Mode
| Shortcut | Action |
| :--- | :--- |
| <kbd>b</kbd> / <kbd>Shift</kbd> + <kbd>b</kbd> (<kbd>B</kbd>) *(or <kbd>_</kbd> / <kbd>#</kbd>)* | Cycle audio tracks forward / backward *(VLC & MPV standard, zero-lag debounced)* |
| <kbd>N</kbd> / <kbd>y</kbd> | **Toggle Night Mode Audio Normalization** (`dynaudnorm`) |
| <kbd>↑</kbd> / <kbd>↓</kbd> *(or Media Vol Up/Down)* | Volume up / down (+5% / -5%) |
| <kbd>m</kbd> / <kbd>Media Mute</kbd> | Toggle Mute |
| <kbd>Ctrl</kbd> + <kbd>a</kbd> | Open Native File Dialog to add Audio track |

---

### Subtitles
| Shortcut | Action |
| :--- | :--- |
| <kbd>v</kbd> / <kbd>Shift</kbd> + <kbd>v</kbd> (<kbd>V</kbd>) *(or <kbd>j</kbd> / <kbd>J</kbd>)* | Cycle subtitle tracks forward / backward *(VLC & MPV standard, includes Off/None, zero-lag)* |
| <kbd>r</kbd> | Raise subtitle position up (`sub-pos -1`) |
| <kbd>t</kbd> | Move subtitle position down (`sub-pos +1`) |
| <kbd>Ctrl</kbd> + <kbd>s</kbd> | Open Native File Dialog to add Subtitle track |

---

### Video, Performance & Screenshots
| Shortcut | Action |
| :--- | :--- |
| <kbd>l</kbd> | **Toggle Dynamic Format Badge (DV / HDR10+ / HDR / SDR)** |
| <kbd>Ctrl</kbd> + <kbd>y</kbd> | **Cycle Streaming Quality (*720p → 1080p → 1440p → Best*)** |
| <kbd>d</kbd> | Toggle Debanding filter on/off |
| <kbd>i</kbd> | Toggle Real-Time Performance & Dropped Frame Statistics |
| <kbd>Alt</kbd> + <kbd>h</kbd> | Cycle HDR Tone-Mapping curves (*Auto, BT.2390, Spline, Reinhard, Clip*) |
| <kbd>s</kbd> | Take Screenshot (saved to `~/Pictures/MPV-Screenshots/`) |
| <kbd>Shift</kbd> + <kbd>s</kbd> (<kbd>S</kbd>) | Take Screenshot **without subtitles** |

---

### Window, UI & Dialogs
| Shortcut | Action |
| :--- | :--- |
| <kbd>f</kbd> | Toggle Fullscreen |
| <kbd>Esc</kbd> | Exit Fullscreen |
| <kbd>Tab</kbd> | Cycle ModernZ OSC visibility |
| <kbd>g</kbd> <kbd>m</kbd> | Open GUI menu |
| <kbd>Ctrl</kbd> + <kbd>p</kbd> | **Open Profile Selector interactive menu** |
| <kbd>Alt</kbd> + <kbd>p</kbd> | **Apply `[high-quality]` EWA Lanczos scaling profile** |
| <kbd>Ctrl</kbd> + <kbd>o</kbd> | Open Native File Dialog to load Media file(s) |

---

### Image Viewer Mode
| Shortcut | Action |
| :--- | :--- |
| <kbd>Wheel Up</kbd> | Smooth Cursor-Centric Zoom In (+10%) |
| <kbd>Wheel Down</kbd> | Smooth Cursor-Centric Zoom Out (-10%) |
| <kbd>0</kbd> | Reset Image Position & Center Alignment |

---

## HDR & Dolby Vision Playback

This configuration utilizes **`vo=gpu-next`** with mpv's **libplacebo** rendering engine:

1. **On Standard SDR Displays (e.g. Laptops & Regular Monitors)**:
   - HDR10 and Dolby Vision (Profile 5 and Profile 8.1) video streams are **dynamically tone-mapped into the standard sRGB / BT.709 color gamut**.
   - Highlights and shadows are compressed cleanly, preventing the dull, washed-out appearance typical of unmapped HDR content.
   - `hdr-compute-peak=auto` dynamically assesses peak brightness for optimal scene contrast.
2. **On Windows HDR Displays**:
   - `target-colorspace-hint=yes` automatically signals the Windows Display Subsystem to pass wide-gamut (BT.2020) and high-peak brightness metadata directly to your HDR monitor or TV.

> [!IMPORTANT]
> **Performance Note on Heavy 4K UHD Blu-ray REMUX (60GB+):**
> - **Standard Content (SDR, HDR10, HDR10+, Web-DL Dolby Vision Profile 5/8)**: Plays flawlessly with **0 frame drops**, instant seeking, and real-time color tone-mapping.
> - **Extreme High-Bitrate 4K UHD Blu-ray REMUX (60GB+ / 80–100+ Mbps)**: Very large 60GB+ Blu-ray REMUX files featuring dual-layer Dolby Vision (Profile 7 MEL/FEL) combined with heavy HEVC bitrates can occasionally experience minor initial buffering or a slight loss of frames (~150–200 dropped frames during heavy seek bursts or high-complexity scene initialization) depending on hardware decoder/SSD bandwidth. Normal playback stabilizes immediately thereafter. All other standard Dolby Vision, HDR10, HDR10+, and SDR files play smoothly with zero dropped frames.

### Reference Test Hardware & Benchmark Environment
All configurations, shader algorithms, and real-time playback benchmarks were profiled and verified on the following reference test system:

| Component | Hardware Specification |
| :--- | :--- |
| **CPU** | Intel Core i5-10300H @ 2.50GHz (4 Cores / 8 Threads, up to 4.50GHz Turbo) |
| **Dedicated GPU** | NVIDIA GeForce GTX 1650 Ti (4GB GDDR6 VRAM) |
| **Integrated GPU** | Intel UHD Graphics 630 |
| **System Memory (RAM)** | 16 GB DDR4 |
| **Operating System** | Microsoft Windows 10 Home (64-bit) |
| **Storage** | PCIe NVMe SSD |
| **MPV Engine Build** | Windows git builds by [zhongfly](https://github.com/zhongfly/mpv-winbuild/releases) (`gpu-next`, `libplacebo`, `d3d11va`, `Vulkan`) |

> [!NOTE]
> **File Format vs. Screen Support**: The format badge indicates the **color format received from the video file itself** (e.g. `DV` indicates a Dolby Vision file stream), **not** that your physical display panel supports native Dolby Vision. On standard SDR monitors, mpv automatically decodes the DV/HDR stream and tone-maps it into vivid, accurate SDR in real-time.

---

## Smart Automation Profiles

This configuration leverages mpv's conditional profiles for zero-friction playback automation:

```mermaid
graph TD
    A[Open Media in mpv] --> B{Media Type / State}
    B -->|Playing Video| C[Profile: Video<br/>Enables Windows Taskbar Progress]
    B -->|Opening Image| D[Profile: Image<br/>Cursor Zoom, Aspect Ignore, Infinite Display]
    B -->|Window Minimized| E[Profile: Minimized<br/>Auto-Pause Video Playback]
    B -->|Pinned On Top & Windowed| F[Profile: Window-PiP<br/>Borderless, 1.8x Scaled OSC, Progress Bar]
```

1. **`[Window-PiP]`**:
   - **Trigger**: When `ontop=yes` and windowed (not fullscreen).
   - **Behavior**: Strips borders, scales OSC size by `1.8x` for effortless control in mini windows, and keeps progress bar active.
2. **`[Minimized]`**:
   - **Trigger**: When the mpv window is minimized (excluding audio album art).
   - **Behavior**: Pauses video playback automatically and resumes upon restoration.
3. **`[Video]`**:
   - **Trigger**: Active video track with duration > 0.
   - **Behavior**: Activates Windows taskbar progress tracking.
   - **Initial State**: Windowed by default (`fullscreen=no`, autofit 85%, centered). Toggle fullscreen anytime via <kbd>f</kbd> or double-click.
4. **`[Image]`**:
   - **Trigger**: Still images (`png`, `jpg`, `webp`, `avif`, `jxl`, `svg`, `qoi`, etc.).
   - **Behavior**: Holds display duration infinitely, centers view, and activates cursor-anchored zoom bindings.

---

## Customization & Optional Profiles

### 1. Optional Profiles (High-End GPUs & Night Audio)
In [`mpv.conf`](mpv.conf), you can activate optional profiles on-demand:
```ini
# To launch mpv with high-end EWA Lanczos scaling (for dedicated GPUs):
# mpv --profile=high-quality "video.mkv"

# To launch mpv with dynamic audio normalizer active:
# mpv --profile=night-audio "movie.mkv"
```

### 2. Changing Hardware Acceleration
In [`mpv.conf`](mpv.conf):
```ini
# Default: Auto-Safe (Automatically picks best stable hardware decoder)
hwdec=auto-safe

# For Direct3D 11 specifically on Windows:
# hwdec=d3d11va

# For NVIDIA GPUs with NVDEC:
# hwdec=nvdec

# For Linux (Intel / AMD):
# hwdec=vaapi

# For Apple Silicon:
# hwdec=videotoolbox
```

### 3. Audio & Subtitle Language Priorities
In [`mpv.conf`](mpv.conf):
```ini
# Prioritize subtitle language (comma separated):
slang=en,enm

# Prioritize audio language (comma separated):
alang=hi,en,ja
```

### 4. Subtitle Typography & Positioning
In [`mpv.conf`](mpv.conf):
```ini
sub-font-size=50
sub-color="#FFFFFF"
sub-border-size=1.8
sub-border-color="#000000"
sub-shadow-offset=1.5
sub-shadow-color=0/0/0/0.5
sub-border-style=outline-and-shadow
sub-margin-y=36
sub-ass-override=no
```

### 5. Screenshot Directory & Format
In [`mpv.conf`](mpv.conf):
```ini
screenshot-format=jpeg
screenshot-jpeg-quality=99
screenshot-directory=~/Pictures/MPV-Screenshots
screenshot-template=%F-(%P)-%n
```

### 6. ModernZ OSC Layout & Theme
You can change the OSC theme directly from the right-click context menu or by editing [`script-opts/modernz.conf`](script-opts/modernz.conf):
```ini
layout=default        # Options: default, compact, mini, seekbar
icon_theme=fluent     # Options: fluent, material
icon_style=mixed      # Options: mixed, filled, outline
```

---

## Credits & Acknowledgements

### Author & Maintainer
- **[Biraj Sarkar](https://github.com/Biraj2004)** ([@Biraj2004](https://github.com/Biraj2004)):
  - **`cycle_audio.lua`**: Custom zero-lag audio & subtitle cycler supporting both VLC and MPV standard shortcuts with 0ms visual OSD feedback, 25ms anti-spam debouncing, type-safety, and seamless GUI menu synchronization.
  - **`sort_playlist.lua`**: Custom natural alphanumeric ascending video playlist sorting engine and automated non-video media filter with seamless background reordering and OSD feedback.
  - **`hdr_badge.lua` & `resume_indicator.lua`**: Dynamic floating format badge overlay (HDR10+, Dolby Vision, SDR) and clean on-screen resume notifications ("Resuming at (14:22)").
  - **Unicode UTF-8 Dialog Integration (`open-file.lua`)**: PowerShell UTF-8 console output fix preserving special symbols, apostrophes, and curly quotes in filenames.
  - **Performance & Subtitle Architecture**: 400MB demuxer seek buffer (with 200MB back-cache, 25s readahead, zero SSD wear), `gpu-next` tone-mapping pipeline, night mode normalization profiles, and precision anime subtitle typography.
  - **Cheatsheets & Documentation Website**: Interactive GitHub Pages documentation and reference manuals.

### Upstream Open-Source Projects
- **[mpv](https://mpv.io/)** ([mpv-player/mpv](https://github.com/mpv-player/mpv)): The core, high-performance open-source media player engine.
- **[mpv-winbuild](https://github.com/zhongfly/mpv-winbuild/releases)** by [zhongfly](https://github.com/zhongfly): Cutting-edge, automated Windows builds of mpv with full `gpu-next`, `libplacebo`, and Vulkan/D3D11 support.
- **[ModernZ](https://github.com/Samillion/ModernZ)** by [Samillion](https://github.com/Samillion): Modern On-Screen Controller (OSC) replacement with fluent vector iconography.
- **[thumbfast](https://github.com/po5/thumbfast)** by [po5](https://github.com/po5): High-performance on-the-fly seekbar thumbnail generator for mpv.
- **[pause_indicator_lite](https://github.com/Samillion/ModernZ/tree/main/extras/pause-indicator-lite)** by [Samillion](https://github.com/Samillion): Lightweight center pause/resume indicator.
- **[open-file](https://github.com/Samillion/ModernZ/tree/main/extras/open-file)** maintained by [Samillion](https://github.com/Samillion) (fork of [mpv-open-file-dialog](https://github.com/rossy/mpv-open-file-dialog) by [rossy](https://github.com/rossy)): Seamless native Windows Open File dialog integration.
- **[yt-dlp](https://github.com/yt-dlp/yt-dlp)**: High-speed video downloader and streaming backend.
- **[FFmpeg](https://ffmpeg.org/)** & **[libplacebo](https://code.videolan.org/videolan/libplacebo)**: Foundational video decoding, debanding, and tone-mapping rendering engines.

---

## Security

Please refer to the [SECURITY.md](SECURITY.md) policy document for supported versions and instructions on reporting security vulnerabilities.

---

## License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.
