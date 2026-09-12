# extension/images/ — Chrome Web Store Assets

This folder contains promotional and screenshot images for submitting the extension to the Chrome Web Store (or Brave/Edge Add-ons stores).

## Files

| File | Purpose | Required Size |
|---|---|---|
| `promotional_tile_1280x800.jpg` | Large promotional tile shown on the store listing page | 1280×800px |
| `screenshot_context_menu.jpg` | Screenshot #1 — "Open Link in MPV" right-click context menu | 1280×800px or 640×400px |
| `screenshot_youtube_button.jpg` | Screenshot #2 — "Play in MPV" button in the YouTube player controls | 1280×800px or 640×400px |
| `icon_source_reference.jpg` | Source artwork for the extension icon — reference only, not uploaded | — |

## Chrome Web Store Upload Notes

- **Store icon** (128×128 PNG): Use `../icons/icon128.png`
- **Small tile** (440×280 PNG): Crop from `promotional_tile_1280x800.jpg` if needed
- **Large tile** (920×680 PNG): Resize `promotional_tile_1280x800.jpg`
- **Screenshots**: Upload `screenshot_context_menu.jpg` and `screenshot_youtube_button.jpg` as the two main screenshots

## Suggested Store Description (short, 132 chars)

```
Open any link in MPV. Inject a "Play in MPV" button into YouTube — launches at your exact timestamp. Zero network calls.
```

## Suggested Store Description (full)

```
Play in MPV adds two things to Chrome and Brave:

▶ RIGHT-CLICK ANY LINK → "Open Link in MPV"
Right-clicking any hyperlink shows "Open Link in MPV". MPV opens and streams it — YouTube videos, playlists, direct video URLs, anything yt-dlp can handle.

▶ YOUTUBE TIMESTAMP BUTTON
On any YouTube watch page, a Play ▶ button appears in the video player controls. Click it at any moment — MPV opens at that exact second. Watch the first few minutes in-browser, then seamlessly continue in MPV.

WORKS WITH YOUR MPV CONFIG
The extension only passes the URL and timestamp. Your existing mpv.conf and yt-dlp.conf handle video quality, cookies, subtitles, HDR tone-mapping, and everything else — unchanged.

ZERO BACKGROUND PROCESSES
No server. No port. No persistent process. Uses Chrome's Native Messaging API — a local pipe that exists only while MPV is starting up.

PRIVACY
This extension communicates only with your local machine to launch the local MPV player. It does not collect, store, or transmit any personal data, web history, or user activity off your device.

PART OF biraj-mpv-conf
Built and tested as part of the biraj-mpv-conf ultra-optimized MPV configuration suite.
github.com/Biraj2004/biraj-mpv-conf

SETUP REQUIRED
A one-time setup step is needed: load the extension, run Install_Native_Host.bat, and paste your Extension ID. See the GitHub README for full instructions.
```
