/**
 * youtube.js — Content script for "Play in MPV" extension
 * Part of: biraj-mpv-conf | github.com/Biraj2004/biraj-mpv-conf
 *
 * Injects a "Play in MPV" button into YouTube's player right-side controls.
 * On click, reads the current video timestamp and sends it to the service worker.
 *
 * Fully dynamic across all YouTube SPA client-side navigations:
 *  - Home feed to video
 *  - Recommendation / sidebar clicks
 *  - Search results to video
 *  - Shorts to Watch and vice versa
 *  - History back / forward
 *  - Automatic reconnection retry if background service worker was sleeping
 *
 * Zero network calls. No external dependencies. Purely DOM + messaging.
 */

(function () {
  'use strict';

  // ─── Constants ────────────────────────────────────────────────────────────

  const BUTTON_ID      = 'biraj-mpv-btn';
  const MAX_WAIT_MS    = 8000;
  const RETRY_DELAY_MS = 300;

  // Inline SVG: MPV's native play-in-circle logo mark (matches extension icon)
  const MPV_SVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
      width="22" height="22" fill="currentColor" aria-hidden="true">
    <path d="M12 2C6.477 2 2 6.477 2 12s4.477 10 10 10 10-4.477 10-10S17.523 2 12 2z
             M9.5 7.5l7 4.5-7 4.5V7.5z"/>
  </svg>`;


  // ─── State ────────────────────────────────────────────────────────────────

  let retryTimer   = null;
  let retryElapsed = 0;
  let heartbeatTimer = null;


  // ─── URL & Video ID Helpers ───────────────────────────────────────────────

  function isVideoPage() {
    const p = window.location.pathname;
    return p.startsWith('/watch') || p.startsWith('/shorts/');
  }

  function getVideoId() {
    const loc = window.location;

    // 1. /shorts/VIDEO_ID
    const shortsMatch = loc.pathname.match(/^\/shorts\/([A-Za-z0-9_-]+)/);
    if (shortsMatch && shortsMatch[1]) {
      return shortsMatch[1];
    }

    // 2. /watch?v=VIDEO_ID search params
    const searchParams = new URLSearchParams(loc.search);
    const v = searchParams.get('v');
    if (v) return v;

    // 3. Fallback: <ytd-watch-flexy video-id="...">
    const flexy = document.querySelector('ytd-watch-flexy');
    const flexyId = flexy ? flexy.getAttribute('video-id') : null;
    if (flexyId) return flexyId;

    // 4. Fallback: YouTube internal player API
    try {
      const player = document.getElementById('movie_player');
      if (player && typeof player.getVideoData === 'function') {
        const data = player.getVideoData();
        if (data && data.video_id) return data.video_id;
      }
    } catch (e) {}

    // 5. Fallback: meta tag
    const meta = document.querySelector('meta[itemprop="videoId"]');
    if (meta && meta.content) return meta.content;

    return null;
  }

  function getCanonicalUrl() {
    const loc = window.location;
    const vid = getVideoId();

    if (vid) {
      const list = new URLSearchParams(loc.search).get('list');
      return list
        ? `https://www.youtube.com/watch?v=${vid}&list=${list}`
        : `https://www.youtube.com/watch?v=${vid}`;
    }

    return loc.href;
  }


  // ─── Player State Helpers ─────────────────────────────────────────────────

  function isLiveStream() {
    return !!(
      document.querySelector('.ytp-live-badge')             ||
      document.querySelector('.ytp-time-display.ytp-live') ||
      document.querySelector('[class*="ytp-live-badge"]')
    );
  }

  /** Returns the integer second to pass as --start, or 0 to omit it. */
  function getStartTime() {
    if (isLiveStream()) return 0;

    // 1. Try movie_player API first if available in page context
    try {
      const player = document.getElementById('movie_player');
      if (player && typeof player.getCurrentTime === 'function') {
        const ct = player.getCurrentTime();
        if (typeof ct === 'number' && isFinite(ct) && ct > 0) {
          return Math.floor(ct);
        }
      }
    } catch (e) {}

    // 2. Query HTML5 video element
    const video = document.querySelector('video.html5-main-video')
               || document.querySelector('video.video-stream')
               || document.querySelector('video');

    if (!video || video.readyState < 1) return 0;

    const ct = isFinite(video.currentTime) ? video.currentTime : 0;
    if (ct <= 0) return 0;

    return Math.floor(ct);
  }

  /** Pause all active HTML5 playback on YouTube to prevent duplicate audio */
  function pauseYouTubePlayback() {
    // 1. Pause all HTML5 video elements directly
    const videos = document.querySelectorAll('video');
    videos.forEach((v) => {
      try {
        if (!v.paused) v.pause();
      } catch (e) {}
    });

    // 2. Call movie_player internal API if exposed
    try {
      const player = document.getElementById('movie_player');
      if (player && typeof player.pauseVideo === 'function') {
        player.pauseVideo();
      }
    } catch (e) {}
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
    docTitle = docTitle.replace(/^\(\d+\)\s*/, '');
    docTitle = docTitle.replace(/\s*-\s*YouTube$/, '');
    return docTitle.trim();
  }


  // ─── Robust Messaging ─────────────────────────────────────────────────────

  /** Send message to background service worker with automatic retry if worker was idle. */
  function sendMessageWithRetry(msg, maxAttempts = 3) {
    let attempts = 0;
    function trySend() {
      attempts++;
      chrome.runtime.sendMessage(msg, (response) => {
        const err = chrome.runtime.lastError;
        if (err && attempts < maxAttempts) {
          setTimeout(trySend, 200 * attempts);
        }
      });
    }
    trySend();
  }


  // ─── Button Creation & Injection ──────────────────────────────────────────

  function createButton() {
    const btn = document.createElement('button');
    btn.id        = BUTTON_ID;
    btn.className = 'ytp-button';
    btn.setAttribute('aria-label', 'Play in MPV');
    btn.setAttribute('title',      'Play in MPV');
    btn.innerHTML = MPV_SVG;

    btn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();

      // Read exact current timestamp BEFORE anything else
      const time  = getStartTime();
      const url   = getCanonicalUrl();
      const title = getVideoTitle();

      // Immediately pause YouTube playback so it doesn't play simultaneously with MPV
      pauseYouTubePlayback();
      setTimeout(pauseYouTubePlayback, 80);

      // Visual feedback click flash
      btn.style.opacity = '0.5';
      setTimeout(() => { btn.style.opacity = ''; }, 200);

      sendMessageWithRetry({ action: 'play_in_mpv', url, time, title });
    });

    return btn;
  }

  /** Inject the button into .ytp-right-controls. Returns true if present or successfully injected. */
  function injectButton() {
    const existing = document.getElementById(BUTTON_ID);
    const rightControls = document.querySelector('.ytp-right-controls');

    if (!rightControls) return false;

    // If button already exists and is inside rightControls, all good
    if (existing && rightControls.contains(existing)) {
      return true;
    }

    // Remove stray button if parent got destroyed/recreated
    if (existing) {
      existing.remove();
    }

    // Insert as first item in right-side controls
    rightControls.insertBefore(createButton(), rightControls.firstChild);
    return true;
  }


  // ─── State Synchronization ────────────────────────────────────────────────

  function stopRetry() {
    if (retryTimer) {
      clearInterval(retryTimer);
      retryTimer   = null;
      retryElapsed = 0;
    }
  }

  function syncState() {
    if (!isVideoPage()) {
      stopRetry();
      document.getElementById(BUTTON_ID)?.remove();
      return;
    }

    // Immediate attempt
    if (injectButton()) {
      stopRetry();
      return;
    }

    // If not ready, retry with polling
    if (!retryTimer) {
      retryElapsed = 0;
      retryTimer = setInterval(() => {
        retryElapsed += RETRY_DELAY_MS;
        if (injectButton() || retryElapsed >= MAX_WAIT_MS || !isVideoPage()) {
          stopRetry();
        }
      }, RETRY_DELAY_MS);
    }
  }


  // ─── Observers & Navigation Listeners ─────────────────────────────────────

  // Continuous MutationObserver catches dynamic player insertion during SPA route changes
  const domObserver = new MutationObserver(() => {
    if (isVideoPage()) {
      const existing = document.getElementById(BUTTON_ID);
      const rightControls = document.querySelector('.ytp-right-controls');
      if (rightControls && (!existing || !rightControls.contains(existing))) {
        syncState();
      }
    } else {
      document.getElementById(BUTTON_ID)?.remove();
    }
  });

  domObserver.observe(document.body, {
    childList: true,
    subtree: true,
  });

  // YouTube custom navigation events
  ['yt-navigate-finish', 'yt-page-data-updated', 'yt-player-updated', 'spemp-video-updated'].forEach((evt) => {
    window.addEventListener(evt, () => {
      setTimeout(syncState, 100);
      setTimeout(syncState, 400);
    });
  });

  // History & URL changes
  window.addEventListener('popstate', () => {
    setTimeout(syncState, 150);
  });

  // Periodic heartbeat as a safety net (every 600ms on video pages)
  if (!heartbeatTimer) {
    heartbeatTimer = setInterval(() => {
      if (isVideoPage()) {
        const rightControls = document.querySelector('.ytp-right-controls');
        const existing = document.getElementById(BUTTON_ID);
        if (rightControls && (!existing || !rightControls.contains(existing))) {
          syncState();
        }
      }
    }, 600);
  }

  // Initial boot
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', syncState);
  } else {
    syncState();
  }
})();
