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

  let activeNonce = null;
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
      if (activeNonce && event.data.nonce === activeNonce) {
        const url = event.data.url;
        activeNonce = null;

        if (pendingResolver && typeof url === 'string' && /^(https?|http|magnet):/i.test(url)) {
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

  /** Send message to background service worker with automatic retry. */
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

      const targetCopyBtn = findOption(menu, 'copy stream link')
                         || findOption(menu, 'stream link')
                         || findOption(menu, 'link')
                         || findOption(menu, 'download link')
                         || findOption(menu, 'download video');

      if (!targetCopyBtn) return;

      // Extract title
      const titleEl = menu.querySelector('[class*="title"]');
      let title = titleEl ? titleEl.textContent.trim() : '';
      if (!title) {
        title = (document.title || '').replace(/\s*-\s*Stremio.*$/i, '').trim();
      }

      // Check current playback timestamp
      const video = document.querySelector('video');
      const time = (video && Number.isFinite(video.currentTime) && video.currentTime > 2)
        ? Math.floor(video.currentTime)
        : 0;

      // Pause web player to prevent concurrent audio
      if (video && !video.paused) {
        try { video.pause(); } catch (err) {}
      }

      // Cryptographic nonce authentication
      const nonceArr = new Uint32Array(2);
      crypto.getRandomValues(nonceArr);
      const nonce = nonceArr[0].toString(36) + nonceArr[1].toString(36);
      activeNonce = nonce;

      document.documentElement.setAttribute('data-mpv-nonce', nonce);

      const capturePromise = new Promise((resolve) => {
        pendingResolver = resolve;
        pendingTimer = setTimeout(() => {
          if (pendingResolver === resolve) {
            pendingResolver = null;
            activeNonce = null;
            resolve(null);
          }
        }, 800);
      });

      // Trigger native copy action EXACTLY ONCE (prevents duplicate toasts)
      targetCopyBtn.click();

      capturePromise.then((capturedUrl) => {
        if (!capturedUrl) {
          if (navigator.clipboard && navigator.clipboard.readText) {
            navigator.clipboard.readText().then((clipText) => {
              if (typeof clipText === 'string' && /^(https?|http|magnet):/i.test(clipText.trim())) {
                sendMessageWithRetry({ action: 'play_in_mpv', url: clipText.trim(), time, title });
              }
            }).catch(() => {});
          }
          return;
        }

        sendMessageWithRetry({ action: 'play_in_mpv', url: capturedUrl, time, title });
      });

      // Dismiss menu cleanly
      setTimeout(() => {
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', bubbles: true }));
      }, 80);
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
