/**
 * stremio.js — Content script for Stremio Web ("Play in MPV")
 * Part of: biraj-mpv-conf | github.com/Biraj2004/biraj-mpv-conf
 *
 * Injects "Play in MPV" directly into Stremio Web's stream context menus
 * and in-player options menus on https://web.stremio.com/ and https://app.strem.io/.
 *
 * Designed for clean React reconciliation:
 *  - Single debounced scan via requestAnimationFrame (no render cycles or DOM spam).
 *  - Creates a clean, isolated option element with dedicated icon container.
 *  - Dispatches native copy click exactly once (no duplicate toasts or multiple copies).
 *  - Nonce-authenticated main-world bridge.
 *
 * Zero network calls. No external dependencies. Purely DOM + messaging.
 */

(function () {
  'use strict';

  const MPV_CLASS = 'biraj-stremio-mpv-option';

  // Crisp circular purple MPV badge matching extension branding
  const MPV_SVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
      width="20" height="20" style="display:block; flex-shrink:0;" aria-hidden="true">
    <defs>
      <linearGradient id="stremioMpvGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#8B5CF6"/>
        <stop offset="100%" stop-color="#4C1D95"/>
      </linearGradient>
    </defs>
    <circle cx="12" cy="12" r="11" fill="url(#stremioMpvGrad)"/>
    <circle cx="12" cy="12" r="10.5" fill="none" stroke="#A78BFA" stroke-width="0.8" opacity="0.6"/>
    <polygon points="9.5,7 16.8,12 9.5,17" fill="#FFFFFF"/>
  </svg>`;

  let pendingResolver = null;
  let pendingTimer = null;
  let scanScheduled = false;

  // Listen for captured stream URLs from stremio_bridge.js in the main world
  window.addEventListener('message', (event) => {
    if (event.source !== window || !event.data) return;

    if (
      event.data.source === 'PLAY_IN_MPV_BRIDGE' &&
      event.data.type === 'CAPTURED_STREAM_URL'
    ) {
      const url = event.data.url;
      if (typeof url === 'string' && /^(https?|http|magnet):/i.test(url)) {
        if (pendingResolver) {
          pendingResolver(url);
          pendingResolver = null;
          if (pendingTimer) {
            clearTimeout(pendingTimer);
            pendingTimer = null;
          }
        }
      }
    }
  });

  /** Display a floating toast directly in Stremio Web. */
  function showStremioToast(message, type = 'info') {
    try {
      let toast = document.getElementById('biraj-stremio-toast');
      if (!toast) {
        toast = document.createElement('div');
        toast.id = 'biraj-stremio-toast';
        document.body.appendChild(toast);
      }
      toast.textContent = message;
      toast.className = `biraj-stremio-toast-visible biraj-stremio-toast-${type}`;
      clearTimeout(toast._hideTimer);
      toast._hideTimer = setTimeout(() => {
        toast.className = '';
      }, 2500);
    } catch (e) {}
  }

  /** Helper to find option elements by text content or title. */
  function findOption(menu, query) {
    const q = query.toLowerCase();
    const items = menu.querySelectorAll(
      '[class*="context-menu-option-container"], [class*="option-container"], [class*="option"]'
    );
    for (const item of items) {
      if (item.classList.contains(MPV_CLASS)) continue;

      const title = (item.getAttribute('title') || '').toLowerCase();
      const text = (item.textContent || '').toLowerCase();
      if (title.includes(q) || text.includes(q)) {
        return item;
      }
    }
    return null;
  }

  /** Check if extension context is valid and runtime is available. */
  function isExtensionValid() {
    try {
      return typeof chrome !== 'undefined' &&
             Boolean(chrome?.runtime) &&
             typeof chrome.runtime.sendMessage === 'function' &&
             Boolean(chrome.runtime.id);
    } catch {
      return false;
    }
  }

  /** Send message to background service worker with automatic retry. */
  function sendMessageWithRetry(msg, maxAttempts = 3) {
    if (!isExtensionValid()) return;
    let attempts = 0;
    function trySend() {
      if (!isExtensionValid()) return;
      attempts++;
      try {
        chrome.runtime.sendMessage(msg, (response) => {
          const err = chrome.runtime?.lastError;
          if (err && attempts < maxAttempts) {
            setTimeout(trySend, 200 * attempts);
          }
        });
      } catch (e) {
        // Context invalidated
      }
    }
    trySend();
  }

  /**
   * Firmly pauses Stremio Web playback and prevents auto-resume during MPV handoff.
   */
  function pauseStremioPlayback() {
    const pauseAllMedia = () => {
      const media = document.querySelectorAll('video, audio');
      media.forEach((el) => {
        try {
          if (!el.paused) el.pause();
          el.muted = true;
        } catch (e) {}
      });
    };

    // 1. Immediate pause and mute
    pauseAllMedia();

    // 2. Click native UI pause button if active in Stremio's player bar
    try {
      const pauseBtns = document.querySelectorAll(
        'button[title*="Pause" i], button[aria-label*="Pause" i], [class*="play-pause"], [class*="play-button"]'
      );
      for (const btn of pauseBtns) {
        const label = (btn.getAttribute('title') || btn.getAttribute('aria-label') || '').toLowerCase();
        if (label.includes('pause')) {
          btn.click();
          break;
        }
      }
    } catch (e) {}

    // 3. Document-level capturing listener:
    // Stremio's options menu closing event often triggers video.play() on unmount.
    // Intercept and halt any play event during the handoff window.
    const interceptPlay = (evt) => {
      try {
        if (evt.target && typeof evt.target.pause === 'function') {
          evt.target.pause();
          evt.target.muted = true;
        }
      } catch (e) {}
    };

    document.addEventListener('play', interceptPlay, { capture: true });

    // 4. Polling safeguard during the handoff transition window (1.5s)
    let checks = 0;
    const interval = setInterval(() => {
      pauseAllMedia();
      checks++;
      if (checks > 20) {
        clearInterval(interval);
      }
    }, 75);

    // 5. Clean up interceptor after MPV launch window and allow audio on user-initiated play
    setTimeout(() => {
      document.removeEventListener('play', interceptPlay, { capture: true });
      document.querySelectorAll('video, audio').forEach((el) => {
        const restoreAudioOnManualPlay = () => {
          el.muted = false;
          el.removeEventListener('play', restoreAudioOnManualPlay);
        };
        el.addEventListener('play', restoreAudioOnManualPlay, { once: true });
      });
    }, 2000);
  }

  /** Injects "Play in MPV" into a detected Stremio menu. */
  function injectIntoMenu(menu) {
    if (!menu) return;

    // Strict deduplication guard
    if (menu.dataset.mpvInjected === 'true' || menu.querySelector(`.${MPV_CLASS}`)) {
      return;
    }

    // Locate the "Play" or "Copy Stream Link" reference option
    const playBtn = findOption(menu, 'play') || findOption(menu, 'ctx_play');
    const copyStreamBtn = findOption(menu, 'copy stream link')
                       || findOption(menu, 'stream link')
                       || findOption(menu, 'link')
                       || findOption(menu, 'download link')
                       || findOption(menu, 'download video');

    const refOption = playBtn || copyStreamBtn;
    if (!refOption) return;

    // Mark menu as processed immediately to prevent re-entrant injection
    menu.dataset.mpvInjected = 'true';

    // Construct clean, isolated option element
    const mpvOption = document.createElement('div');
    mpvOption.className = refOption.className;
    mpvOption.classList.add(MPV_CLASS);
    mpvOption.setAttribute('title', 'Play in MPV');
    mpvOption.setAttribute('role', 'button');
    mpvOption.setAttribute('tabindex', '0');

    // Dedicated icon container with explicit layout
    const iconWrap = document.createElement('div');
    iconWrap.className = 'biraj-mpv-icon-wrap';
    iconWrap.innerHTML = MPV_SVG;

    // Clean label element copying Stremio's native typography
    const labelDiv = document.createElement('div');
    const refLabel = refOption.querySelector('[class*="label"]');
    if (refLabel && refLabel.className) {
      labelDiv.className = refLabel.className;
    }
    labelDiv.textContent = 'Play in MPV';

    mpvOption.appendChild(iconWrap);
    mpvOption.appendChild(labelDiv);

    // Single click handler
    mpvOption.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();

      if (!isExtensionValid()) {
        showStremioToast('Extension reloaded. Please refresh the page (F5).', 'warning');
        return;
      }

      // Extract title
      const titleEl = menu.querySelector('[class*="title"]');
      let title = titleEl ? titleEl.textContent.trim() : '';
      if (!title) {
        title = (document.title || '').replace(/\s*-\s*Stremio.*$/i, '').trim();
      }

      // Check current playback timestamp BEFORE pausing
      const video = document.querySelector('video');
      const time = (video && Number.isFinite(video.currentTime) && video.currentTime > 2)
        ? Math.floor(video.currentTime)
        : 0;

      // Check if video already has a direct HTTP/HTTPS stream URL (not a blob)
      const directVideoSrc = video && video.currentSrc && !video.currentSrc.startsWith('blob:') && /^(https?|http):/i.test(video.currentSrc)
        ? video.currentSrc
        : null;

      // Firmly pause and mute web player
      pauseStremioPlayback();

      function sendUrl(targetUrl) {
        if (!targetUrl) {
          showStremioToast('Could not retrieve stream link.', 'error');
          return;
        }
        sendMessageWithRetry({ action: 'play_in_mpv', url: targetUrl, time, title });
      }

      function dismissMenu() {
        setTimeout(() => {
          const activeMenu = document.querySelector('[class*="context-menu-content"], [class*="options-menu-container"]');
          if (activeMenu) {
            document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', bubbles: true }));
          }
        }, 150);
      }

      if (directVideoSrc) {
        sendUrl(directVideoSrc);
        dismissMenu();
        return;
      }

      const targetCopyBtn = findOption(menu, 'copy stream link')
                         || findOption(menu, 'stream link')
                         || findOption(menu, 'link')
                         || findOption(menu, 'download link')
                         || findOption(menu, 'download video');

      if (!targetCopyBtn) {
        showStremioToast('Stream option not found.', 'warning');
        dismissMenu();
        return;
      }

      const capturePromise = new Promise((resolve) => {
        pendingResolver = resolve;
        pendingTimer = setTimeout(() => {
          if (pendingResolver === resolve) {
            pendingResolver = null;
            resolve(null);
          }
        }, 1200);
      });

      // Dispatch click to trigger Stremio's clipboard write
      try {
        targetCopyBtn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
        targetCopyBtn.click();
      } catch (err) {}

      capturePromise.then((capturedUrl) => {
        if (capturedUrl) {
          sendUrl(capturedUrl);
          return;
        }

        // Fallback: try reading clipboard if permissions permit
        if (navigator.clipboard && navigator.clipboard.readText) {
          navigator.clipboard.readText().then((clipText) => {
            if (typeof clipText === 'string' && /^(https?|http|magnet):/i.test(clipText.trim())) {
              sendUrl(clipText.trim());
            } else {
              showStremioToast('Could not capture stream link.', 'warning');
            }
          }).catch(() => {
            showStremioToast('Could not capture stream link.', 'warning');
          });
        } else {
          showStremioToast('Could not capture stream link.', 'warning');
        }
      });

      dismissMenu();
    });

    // Placement: right after "Play", or before "Copy Stream Link"
    if (playBtn && playBtn.parentNode === menu) {
      playBtn.after(mpvOption);
    } else if (copyStreamBtn && copyStreamBtn.parentNode === menu) {
      copyStreamBtn.before(mpvOption);
    } else {
      menu.appendChild(mpvOption);
    }
  }

  /** Scan active DOM for visible context or options menus (debounced via rAF). */
  function scanMenus() {
    const menus = document.querySelectorAll(
      '[class*="context-menu-content"], [class*="options-menu-container"]'
    );
    for (const menu of menus) {
      injectIntoMenu(menu);
    }
  }

  function requestScan() {
    if (scanScheduled) return;
    scanScheduled = true;
    requestAnimationFrame(() => {
      scanScheduled = false;
      scanMenus();
    });
  }

  // Observe DOM for dynamic popup menus rendered by Stremio
  const observer = new MutationObserver(() => {
    requestScan();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });

  // User interaction triggers (lightweight debounced scan)
  ['pointerdown', 'mouseup', 'contextmenu'].forEach((evt) => {
    document.addEventListener(evt, () => {
      requestScan();
    }, { capture: true, passive: true });
  });

  // SPA navigation triggers
  window.addEventListener('hashchange', requestScan);
  window.addEventListener('popstate', requestScan);

  // Initial check
  requestScan();
})();
