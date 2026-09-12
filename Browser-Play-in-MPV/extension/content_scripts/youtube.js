/**
 * youtube.js — Content script for "Play in MPV" extension
 * Part of: biraj-mpv-conf | github.com/Biraj2004/biraj-mpv-conf
 *
 * Injects a "Play in MPV" button into YouTube's player right-side controls.
 * On click, reads the current video timestamp and sends it to the service worker.
 *
 * Handles:
 *  - YouTube SPA navigation (yt-navigate-finish)
 *  - Live streams (no --start timestamp)
 *  - Shorts (converts /shorts/ID → /watch?v=ID)
 *  - Playlists (preserves list= param)
 *  - Premieres (button disabled with tooltip)
 *  - Button deduplication on re-renders
 *  - video.readyState guard before reading currentTime
 *
 * Zero network calls. No external dependencies. Purely DOM + messaging.
 */

(function () {
  'use strict';

  // ─── Constants ────────────────────────────────────────────────────────────

  const BUTTON_ID      = 'biraj-mpv-btn';
  const MAX_WAIT_MS    = 10000;   // Stop retrying after 10 s
  const RETRY_DELAY_MS = 400;     // Poll interval for controls bar

  // Inline SVG: MPV's native play-in-circle logo mark (matches extension icon)
  const MPV_SVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
      width="22" height="22" fill="currentColor" aria-hidden="true">
    <path d="M12 2C6.477 2 2 6.477 2 12s4.477 10 10 10 10-4.477 10-10S17.523 2 12 2z
             M9.5 7.5l7 4.5-7 4.5V7.5z"/>
  </svg>`;


  // ─── State ────────────────────────────────────────────────────────────────

  let retryTimer   = null;
  let retryElapsed = 0;


  // ─── URL helpers ──────────────────────────────────────────────────────────

  function getCanonicalUrl() {
    const loc = window.location;

    // /shorts/VIDEO_ID  →  standard watch URL
    const shortsMatch = loc.pathname.match(/^\/shorts\/([A-Za-z0-9_-]+)/);
    if (shortsMatch) {
      return `https://www.youtube.com/watch?v=${shortsMatch[1]}`;
    }

    // /watch  →  keep only v= and list= (strip all other params)
    if (loc.pathname === '/watch') {
      const src    = new URLSearchParams(loc.search);
      const clean  = new URLSearchParams();
      const v      = src.get('v');
      const list   = src.get('list');
      if (v)    clean.set('v',    v);
      if (list) clean.set('list', list);
      return `https://www.youtube.com/watch?${clean.toString()}`;
    }

    return loc.href;
  }


  // ─── Player state helpers ─────────────────────────────────────────────────

  function isLiveStream() {
    return !!(
      document.querySelector('.ytp-live-badge')          ||
      document.querySelector('.ytp-time-display.ytp-live') ||
      document.querySelector('[class*="ytp-live-badge"]')
    );
  }

  function isPremiere() {
    return !!(
      document.querySelector('.ytp-upcoming-thumbnail')  ||
      document.querySelector('[class*="upcoming"]')
    );
  }

  /** Returns the integer second to pass as --start, or 0 to omit it. */
  function getStartTime() {
    if (isLiveStream()) return 0;   // Live streams: no seek point

    // Prefer the YouTube video element (avoids ads / background music)
    const video = document.querySelector('video.html5-main-video')
               || document.querySelector('video.video-stream')
               || document.querySelector('video');

    if (!video || video.readyState < 1) return 0;   // Not ready

    const ct  = isFinite(video.currentTime) ? video.currentTime : 0;
    const dur = isFinite(video.duration)    ? video.duration    : 0;

    if (ct < 2)                  return 0;           // Near start: omit
    if (dur > 0 && ct > dur - 2) return Math.max(0, Math.floor(dur) - 2);

    return Math.floor(ct);
  }


  /** Extracts the clean video title from YouTube DOM or document.title. */
  function getVideoTitle() {
    const h1 = document.querySelector(
      'h1.ytd-watch-metadata yt-formatted-string, #above-the-fold #title h1, h1.title.ytd-video-primary-info-renderer'
    );
    if (h1 && h1.textContent && h1.textContent.trim()) {
      return h1.textContent.trim();
    }
    let docTitle = document.title || '';
    docTitle = docTitle.replace(/^\(\d+\)\s*/, '');    // Strip notification counter like "(1) "
    docTitle = docTitle.replace(/\s*-\s*YouTube$/, ''); // Strip " - YouTube" suffix
    return docTitle.trim();
  }


  // ─── Button ───────────────────────────────────────────────────────────────

  function createButton() {
    const btn = document.createElement('button');
    btn.id        = BUTTON_ID;
    btn.className = 'ytp-button';
    btn.setAttribute('aria-label', 'Play in MPV');
    btn.setAttribute('title',      'Play in MPV');
    btn.innerHTML = MPV_SVG;

    btn.addEventListener('click', (e) => {
      e.stopPropagation();

      if (isPremiere()) {
        btn.setAttribute('title', 'Video is not yet available');
        return;
      }

      const url   = getCanonicalUrl();
      const time  = getStartTime();
      const title = getVideoTitle();

      // Send to service worker — fire-and-forget (no response needed)
      chrome.runtime.sendMessage({ action: 'play_in_mpv', url, time, title }, () => {
        // Suppress "no listener" error when SW is still waking up;
        // the SW will handle it once active.
        void chrome.runtime.lastError;
      });
    });

    return btn;
  }

  /** Inject the button into .ytp-right-controls. Returns true if successful. */
  function injectButton() {
    if (document.getElementById(BUTTON_ID)) return true;   // Already present

    const rightControls = document.querySelector('.ytp-right-controls');
    if (!rightControls) return false;

    // Insert as left-most item in the right controls group
    rightControls.insertBefore(createButton(), rightControls.firstChild);
    return true;
  }


  // ─── Injection with retry ─────────────────────────────────────────────────

  function stopRetry() {
    if (retryTimer) {
      clearInterval(retryTimer);
      retryTimer   = null;
      retryElapsed = 0;
    }
  }

  function startInjection() {
    stopRetry();

    // Remove any leftover button from the previous page
    document.getElementById(BUTTON_ID)?.remove();

    // Try immediately — controls may already exist (fast page)
    if (injectButton()) return;

    // Poll until controls appear or we time-out
    retryTimer = setInterval(() => {
      retryElapsed += RETRY_DELAY_MS;

      if (injectButton() || retryElapsed >= MAX_WAIT_MS) {
        stopRetry();
      }
    }, RETRY_DELAY_MS);
  }

  function init() {
    const path = window.location.pathname;
    const isWatch  = path.startsWith('/watch');
    const isShorts = path.startsWith('/shorts/');
    if (!isWatch && !isShorts) {
      stopRetry();
      document.getElementById(BUTTON_ID)?.remove();
      return;
    }

    startInjection();
  }


  // ─── Navigation listeners ─────────────────────────────────────────────────

  // YouTube SPA: fires on every client-side navigation
  window.addEventListener('yt-navigate-finish', () => {
    setTimeout(init, 150);
  });

  // YouTube SPA: fires when new video metadata/playlist data updates
  window.addEventListener('yt-page-data-updated', () => {
    setTimeout(init, 150);
  });

  // Fallback for popstate (history.back / forward)
  window.addEventListener('popstate', () => {
    setTimeout(init, 150);
  });

  // Initial page load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
