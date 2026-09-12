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
Open YouTube, Stremio Web, and any web video directly in your local MPV player. Seamless timestamp sync with zero background RAM.
```

### Detailed Description
```
Play in MPV provides a zero-latency bridge between Chromium browsers and your local MPV media player.

FEATURES:

1. YOUTUBE TIMESTAMP INTEGRATION
A clean Play button appears in YouTube player controls on Watch and Shorts pages. Clicking it instantly launches MPV at that exact second, letting you seamlessly continue watching in your local media player.

2. STREMIO WEB INTEGRATION
Adds a native "Play in MPV" option directly into Stremio Web (web.stremio.com) stream context menus and player menus. Automatically pauses browser playback and hands off streams with zero manual copying.

3. UNIVERSAL CONTEXT MENU
Right-click any link, video, audio element, or highlighted URL to stream it in MPV immediately.

4. SEAMLESS COMPATIBILITY
The extension only passes the media URL, title, and timestamp. Your local mpv.conf, shaders, tone-mapping, subtitles, and yt-dlp.conf configurations handle playback quality without alteration.

5. ZERO BACKGROUND RESOURCE CONSUMPTION
No persistent background server. No open network ports. Communicates locally on demand using the Chrome Native Messaging API and exits immediately after launch.

PRIVACY:
This extension communicates strictly with your local computer to spawn MPV. It does not collect, log, or transmit any browsing data or telemetry.

Part of the biraj-mpv-conf suite:
https://github.com/Biraj2004/biraj-mpv-conf
Documentation:
https://biraj2004.github.io/biraj-mpv-conf/extension.html
```
