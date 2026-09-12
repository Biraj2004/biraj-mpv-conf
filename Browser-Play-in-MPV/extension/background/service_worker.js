/**
 * service_worker.js — Background service worker for "Play in MPV" extension
 * Part of: biraj-mpv-conf | github.com/Biraj2004/biraj-mpv-conf
 *
 * Responsibilities:
 *  - Creates and handles the "Open Link in MPV" context menu (links only).
 *  - Receives launch requests from the YouTube content script.
 *  - Relays payloads to the local native messaging host (mpv_launcher.py).
 *  - Shows a Chrome notification if the host is not yet installed.
 *
 * Zero network calls. Purely event-driven. No persistent state.
 */

'use strict';

const NATIVE_HOST    = 'com.biraj.mpv_launcher';
const MENU_ITEM_ID   = 'biraj-open-link-in-mpv';

// ─── Tracking params stripped from non-YouTube URLs ────────────────────────
const TRACKING_PARAMS = [
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
  'utm_id', 'fbclid', 'gclid', 'msclkid', 'mc_cid', 'mc_eid', 'ref',
  '_ga', 'igshid',
];

// Schemes that must never be sent to mpv
const BLOCKED_SCHEMES = new Set([
  'chrome-extension:', 'chrome:', 'moz-extension:',
  'blob:', 'data:', 'javascript:', 'about:',
]);


// ─── Context menu ──────────────────────────────────────────────────────────

chrome.runtime.onInstalled.addListener(() => {
  // Remove any stale menus from a previous install/reload then recreate.
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id:       MENU_ITEM_ID,
      title:    'Open Link in MPV',
      contexts: ['link'],   // Only fires when right-clicking a hyperlink
    });
  });
});

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId !== MENU_ITEM_ID) return;

  const url = sanitizeUrl(info.linkUrl);
  if (!url) return;

  sendToMpv(url, 0);
});


// ─── Messages from content script (YouTube button) ─────────────────────────

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.action !== 'play_in_mpv') return false;

  const url = sanitizeUrl(msg.url);
  if (!url) {
    sendResponse({ success: false, error: 'invalid_url' });
    return false;
  }

  const rawTime = msg.time;
  const time = (Number.isFinite(rawTime) && rawTime > 1)
    ? Math.floor(rawTime)
    : 0;

  sendToMpv(url, time);
  sendResponse({ success: true });
  return false; // synchronous response; no async needed
});


// ─── Core: send to native host ─────────────────────────────────────────────

function sendToMpv(url, time) {
  const payload = { action: 'open', url, time };

  chrome.runtime.sendNativeMessage(NATIVE_HOST, payload, (response) => {
    const err = chrome.runtime.lastError;

    if (err) {
      const msg = err.message ?? '';
      // "Specified native messaging host not found" — host not installed
      if (msg.includes('not found') || msg.includes('Native host')) {
        notifySetupRequired();
      } else {
        console.error('[Play in MPV] Native host error:', msg);
      }
      return;
    }

    if (response && !response.success) {
      console.error('[Play in MPV] Launch failed:', response.error, response.detail ?? '');
      if (response.error === 'mpv_not_found') {
        notifyMpvMissing();
      }
    }
  });
}


// ─── URL sanitisation ──────────────────────────────────────────────────────

function sanitizeUrl(raw) {
  if (!raw) return null;

  let parsed;
  try {
    parsed = new URL(raw);
  } catch {
    return null;
  }

  // Block internal browser URLs
  if (BLOCKED_SCHEMES.has(parsed.protocol)) return null;

  // For non-YouTube links, strip tracking query params
  const isYouTube = parsed.hostname.endsWith('youtube.com')
                 || parsed.hostname === 'youtu.be';

  if (!isYouTube) {
    TRACKING_PARAMS.forEach(p => parsed.searchParams.delete(p));
  }

  return parsed.toString();
}


// ─── Notifications ─────────────────────────────────────────────────────────

function notifySetupRequired() {
  chrome.notifications.create({
    type:    'basic',
    iconUrl: 'icons/icon48.png',
    title:   'Play in MPV — Setup Required',
    message: 'The native host is not installed. '
           + 'Run Install_Native_Host.bat from the mpv_native_host/ folder to complete setup.',
  });
}

function notifyMpvMissing() {
  chrome.notifications.create({
    type:    'basic',
    iconUrl: 'icons/icon48.png',
    title:   'Play in MPV — MPV Not Found',
    message: 'mpv.exe was not detected. '
           + 'Install MPV to C:\\Program Files\\mpv\\ or add it to your system PATH, '
           + 'then re-run Install_Native_Host.bat.',
  });
}
