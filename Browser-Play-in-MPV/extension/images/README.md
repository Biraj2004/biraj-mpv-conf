# Chrome Web Store Promotional & Screenshot Assets

This directory contains promotional and screenshot assets for submitting the extension to the Chrome Web Store, Brave, and Edge Add-ons stores.

---

## Asset Directory

| File | Purpose | Resolution |
|---|---|---|
| `promotional_tile_1280x800.jpg` | Large promotional tile for the store listing header | 1280x800 px |
| `screenshot_context_menu.jpg` | Store Screenshot #1: Native right-click context menu | 1280x800 px |
| `screenshot_youtube_button.jpg` | Store Screenshot #2: YouTube player controls timestamp button | 1280x800 px |
| `screenshot_stremio_menu.jpg` | Store Screenshot #3: Stremio Web one-click stream launch | 1280x800 px |
| `icon_source_reference.jpg` | High-resolution master reference artwork (1024x1024) | 1024x1024 px |

---

## Chrome Web Store Upload Checklist

- **Store Icon**: Upload `../icons/icon128.png` (128x128 PNG).
- **Small Tile (Optional)**: 440x280 PNG (can be cropped from `promotional_tile_1280x800.jpg`).
- **Large Promotional Tile**: Upload `promotional_tile_1280x800.jpg` (1280x800 JPG).
- **Screenshots**: Upload `screenshot_youtube_button.jpg`, `screenshot_stremio_menu.jpg`, and `screenshot_context_menu.jpg`.

---

## Suggested Store Listing Copy

### Short Summary (132 characters max)
```
Open YouTube, Stremio Web, and any web video directly in your local MPV player. Zero latency, instant window, and zero background RAM.
```

### Detailed Description
```
Play in MPV provides a zero-latency bridge between Chromium browsers (Chrome, Brave, Edge) and your local MPV media player.

FEATURES:

1. INSTANT YOUTUBE INTEGRATION
A native Play button is seamlessly integrated into YouTube player controls on standard Watch pages and YouTube Shorts. Clicking it pauses the browser player, preserves the exact video title, and launches MPV at that exact second.

2. ONE-CLICK STREMIO WEB STREAMING
Adds a native "Play in MPV" button directly into Stremio Web (web.stremio.com & app.strem.io) stream context menus and player controls. Directly captures stream URLs in 0 ms, locks background browser audio, and prevents duplicate network bandwidth usage.

3. UNIVERSAL CONTEXT MENU & TOOLBAR ACTION
Right-click any webpage, video tag, audio element, hyperlink, or highlighted URL text to dispatch it immediately to MPV. You can also click the toolbar action icon to send the current tab's video directly to MPV.

4. ULTRA-FAST INSTANT WINDOW LAUNCH
Leverages MPV's immediate window rendering (--force-window=immediate) and independent Windows process detachment. MPV renders its window in under 100 ms while streams buffer asynchronously in the background.

5. ZERO BACKGROUND RESOURCE OVERHEAD
No persistent background servers. No open network ports. No localhost daemon. Communicates purely on-demand using the Chrome Native Messaging API and exits immediately after dispatching playback.

6. FULL PLAYBACK FIDELITY
The extension only passes the media URL, title, and timestamp. Your local mpv.conf, GPU-next shaders, HDR tone-mapping, subtitle styling, and yt-dlp configurations handle playback quality without alteration or quality degradation.

PRIVACY & SECURITY:
- Strict local-only communication: Zero telemetry, zero analytics, zero data leaving your machine.
- Hardened native launcher: Validates protocols (http, https, magnet) and isolates options using argument delimiters to prevent injection.

Part of the biraj-mpv-conf suite:
https://github.com/Biraj2004/biraj-mpv-conf
Documentation:
https://biraj2004.github.io/biraj-mpv-conf/extension.html
```
