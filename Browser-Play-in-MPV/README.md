<div align="center">

# Browser-Play-in-MPV

**Open any link or YouTube video in your local [MPV media player](https://mpv.io/) — directly from Brave or Chrome.**

[![Part of biraj-mpv-conf](https://img.shields.io/badge/Part%20of-biraj--mpv--conf-blue?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Biraj2004/biraj-mpv-conf)
[![Browser](https://img.shields.io/badge/Browser-Chrome%20%2F%20Brave%20%2F%20Edge-informational?style=for-the-badge&logo=googlechrome&logoColor=white)]()
[![Manifest](https://img.shields.io/badge/Manifest-V3-success?style=for-the-badge)]()
[![License](https://img.shields.io/badge/License-Apache_2.0-blueviolet?style=for-the-badge)](../LICENSE)

*Seamlessly launch MPV at the exact YouTube timestamp — or stream any link — with one click.*

</div>

---

## What This Extension Does

**Two features, one click each:**

1. **Right-click any link** anywhere in the browser → **"Open Link in MPV"** — MPV opens and streams it. Works on YouTube links, direct video URLs, any streamable link.

2. **YouTube watch pages** — a **"▶ Play in MPV"** button is injected into the player controls bar (right side, next to fullscreen). Clicking it reads the **exact current second** of the video and hands off to MPV at that timestamp. Watch the first few minutes in-browser, then seamlessly continue in MPV.

**What it does NOT do:**
- Does not configure MPV — your `mpv.conf` and `yt-dlp.conf` handle everything (quality, cookies, subtitles, HDR, etc.)
- Does not run a background server or open any port
- Does not collect, store, or transmit any personal data, web history, or user activity off your device

---

## How It Works

```
Browser Extension (MV3)
  ↓  Chrome Native Messaging (local stdin/stdout pipe — no network)
mpv_launcher.py  →  mpv.exe <url> [--start=N]
```

Chrome's **Native Messaging API** spawns `mpv_launcher.py` on demand, passes a tiny JSON payload (`{url, time}`), and the script launches `mpv.exe`. No server. No port. No persistent process. The pipe closes the moment MPV starts.

---

## Prerequisites

> [!IMPORTANT]
> The extension is a **launcher only**. MPV + yt-dlp must be configured first for YouTube streaming to work. The extension itself cannot stream — it just tells MPV what to play.

### 1. MPV

Install MPV (shinchiro build — recommended):

```powershell
winget install --id shinchiro.mpv
```

> Extract/install to `C:\Program Files\mpv\` for zero-configuration compatibility with all biraj-mpv-conf tools.
>
> Download page: [github.com/zhongfly/mpv-winbuild/releases](https://github.com/zhongfly/mpv-winbuild/releases)

### 2. yt-dlp (required for YouTube and web streaming)

```powershell
winget install --id yt-dlp.yt-dlp
```

Then tell MPV to use it — add to your `mpv.conf`:
```ini
ytdl=yes
script-opts-append=ytdl_hook-ytdl_path=yt-dlp
ytdl-format=bestvideo[height<=?1440]+bestaudio/best[height<=?1440]/best
```

### 3. Cookies (for age-restricted / Premium-bitrate / members-only videos)

**Option A — Exported cookies file (recommended for Chrome/Brave/Edge):**

Chromium browsers lock their cookie database while running, making live extraction unreliable. Export your cookies once with **[Get cookies.txt LOCALLY](https://chrome.google.com/webstore/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)**, save the file, and add to your `yt-dlp.conf`:

```ini
--cookies "C:\Users\YourName\yt-cookies.txt"
```

**Option B — Live browser session (Firefox only):**
```ini
--cookies-from-browser firefox
```

---

## Recommended: Use biraj-mpv-conf (Works Out of the Box)

> [!TIP]
> **[biraj-mpv-conf](https://github.com/Biraj2004/biraj-mpv-conf)** is the complete MPV configuration suite this extension is built and tested against. It handles everything above — yt-dlp integration, quality profiles, cookies support, HDR tone-mapping, network resilience, modern UI — all pre-configured.
>
> After installing **biraj-mpv-conf**, the **only** change needed is updating the cookie path in `%APPDATA%\mpv\yt-dlp.conf`:
> ```ini
> --cookies "C:\Users\YourName\yt-cookies.txt"
> ```
> Everything else works out of the box.

**Full setup in 3 commands:**

```powershell
# 1. Install MPV
winget install --id shinchiro.mpv

# 2. Install yt-dlp
winget install --id yt-dlp.yt-dlp

# 3. Install biraj-mpv-conf (clone into MPV's config directory)
git clone https://github.com/Biraj2004/biraj-mpv-conf.git "$env:APPDATA\mpv"
```

Then update the cookie path in `%APPDATA%\mpv\yt-dlp.conf` and you're done.

---

## Installation

### Step 1 — Load the Extension

1. Open Chrome or Brave and navigate to `chrome://extensions`
2. Enable **Developer mode** (toggle in the top-right corner)
3. Click **"Load unpacked"**
4. Select the `extension/` folder inside `Browser-Play-in-MPV/`
5. The extension appears in your toolbar with the MPV icon

### Step 2 — Note Your Extension ID

On the `chrome://extensions` page, find **"Play in MPV"** and copy the **Extension ID** shown below its name.

> It looks like: `abcdefghijklmnopqrstuvwxyzabcdef` (32 lowercase letters)

### Step 3 — Register the Native Host

Run the install script (no admin rights needed):

```
Browser-Play-in-MPV\mpv_native_host\Install_Native_Host.bat
```

Choose **[1] Install**, paste your Extension ID when prompted.

The script:
- Finds Python and MPV on your system
- Creates a tiny `launch_host.bat` wrapper that Chrome calls
- Writes `mpv_launcher_host.json` with absolute paths
- Registers the host for Chrome, Brave, and Edge

### Step 4 — Verify

Test without Chrome:
```powershell
python "Browser-Play-in-MPV\mpv_native_host\mpv_launcher.py" --test
# Expected: {"success": true, "mpv_path": "C:\\Program Files\\mpv\\mpv.exe"}
```

Then reload the extension (`chrome://extensions` → click the ↻ refresh icon on the extension card).

---

## Usage

### Right-click any link → "Open Link in MPV"

Works on any link: YouTube videos, playlists, direct video URLs, stream URLs, etc.

### YouTube "Play in MPV" button

On any YouTube watch page, a **▶** button appears in the player controls (right side, next to the settings/fullscreen group). Click it at any point in the video — MPV opens at that exact second.

**Supported scenarios:**

| Scenario | Behaviour |
|---|---|
| Regular YouTube video | Opens in MPV at current timestamp |
| YouTube Playlist | Opens full playlist in MPV (yt-dlp extracts all entries) |
| YouTube Shorts | Converts to standard watch URL and opens in MPV |
| Live stream | Opens in MPV without a seek timestamp |
| Premiere (not yet live) | Button is present but disabled with a tooltip |

---

## Troubleshooting

**"Open Link in MPV" doesn't appear in the right-click menu**
- Make sure you're right-clicking on a *link* (blue underlined text or any `<a>` element), not on a blank area or image.

**Chrome notification: "Native host is not installed"**
- Run `Install_Native_Host.bat` and choose [1] Install.
- If you reloaded the extension (Extension ID changed), re-run the script with the new ID.

**Chrome notification: "MPV Not Found"**
- Install MPV: `winget install --id shinchiro.mpv`
- Or move your MPV folder to `C:\Program Files\mpv\`

**MPV opens but shows an error / black screen**
- YouTube requires yt-dlp: `winget install --id yt-dlp.yt-dlp`
- Check that your `yt-dlp.conf` has a valid `--cookies` path pointing to an exported cookies file.

**YouTube button doesn't appear**
- The player controls must be fully loaded. Wait for the video to start loading.
- Some YouTube A/B UI experiments can temporarily change the player DOM. The button retries for 10 seconds after page load.

**After moving the `Browser-Play-in-MPV/` folder**
- Re-run `Install_Native_Host.bat` — it bakes absolute paths into the manifest.

---

## Privacy & Security

This extension communicates only with your local machine using Chrome's Native Messaging API to launch the local MPV player. It does not collect, store, or transmit any personal data, web history, or user activity off your device.

**Permissions used and why:**

| Permission | Why |
|---|---|
| `contextMenus` | To add "Open Link in MPV" to the browser right-click menu |
| `nativeMessaging` | To communicate with the local `mpv_launcher.py` host |
| `notifications` | To show a setup reminder if the native host is not yet installed |

No `tabs`, no `history`, no `cookies`, no `storage`, no network requests from the extension itself.

---

## Credits

- **[biraj-mpv-conf](https://github.com/Biraj2004/biraj-mpv-conf)** by [Biraj Sarkar (@Biraj2004)](https://github.com/Biraj2004) — the full MPV configuration suite this extension is part of
- **[mpv](https://mpv.io/)** — the media player
- **[yt-dlp](https://github.com/yt-dlp/yt-dlp)** — the streaming backend
- **[mpv-winbuild](https://github.com/zhongfly/mpv-winbuild/releases)** by zhongfly — recommended Windows MPV builds
