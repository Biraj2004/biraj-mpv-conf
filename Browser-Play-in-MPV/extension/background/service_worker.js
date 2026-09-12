/**
 * service_worker.js — Background service worker for "Play in MPV" extension
 * Part of: biraj-mpv-conf | github.com/Biraj2004/biraj-mpv-conf
 *
 * Responsibilities:
 *  - Creates and handles the "Play in MPV" context menu.
 *  - Receives launch requests from YouTube and Stremio content scripts.
 *  - Sanitizes and validates all payloads against strict protocol allowlists.
 *  - Relays payloads to the local native messaging host (mpv_launcher.py).
 *  - Shows a Chrome notification if the host is not yet installed or MPV is missing.
 *
 * Zero network calls. Purely event-driven. No persistent state.
 */

'use strict';

const NATIVE_HOST    = 'com.biraj.mpv_launcher';
const MENU_ITEM_ID   = 'biraj-open-link-in-mpv';

// Strict protocol allowlist — only streamable web protocols allowed
const ALLOWED_SCHEMES = new Set(['http:', 'https:', 'magnet:']);

// Tracking params stripped from general web URLs
const TRACKING_PARAMS = [
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
  'utm_id', 'fbclid', 'gclid', 'msclkid', 'mc_cid', 'mc_eid', 'ref',
  '_ga', 'igshid',
];

// Anti-spam / double-click debounce
let lastLaunchTime = 0;
let lastLaunchUrl  = '';


// ─── Context menu ──────────────────────────────────────────────────────────

function setupContextMenu() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id:       MENU_ITEM_ID,
      title:    'Play in MPV',
      contexts: ['link', 'selection', 'video', 'audio'],
    });
  });
}

chrome.runtime.onInstalled.addListener(setupContextMenu);
chrome.runtime.onStartup.addListener(setupContextMenu);

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId !== MENU_ITEM_ID) return;

  let rawUrl = '';
  if (info.linkUrl) {
    rawUrl = info.linkUrl;
  } else if (info.srcUrl) {
    rawUrl = info.srcUrl;
  } else if (info.selectionText) {
    let text = info.selectionText.trim().replace(/^["'<(\[]+|["'>)\]]+$/g, '');
    if (/^https?:\/\//i.test(text) || /^magnet:\?/i.test(text)) {
      rawUrl = text;
    } else if (/^(?:www\.|youtube\.com|youtu\.be|[a-zA-Z0-9-]+\.[a-zA-Z]{2,})/i.test(text)) {
      rawUrl = 'https://' + text;
    }
  }

  const url = sanitizeUrl(rawUrl);
  if (!url) return;

  sendToMpv(url, 0);
});


// ─── Messages from content scripts ─────────────────────────────────────────

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.action !== 'play_in_mpv') return false;

  const url = sanitizeUrl(msg.url);
  if (!url) {
    sendResponse({ success: false, error: 'invalid_url' });
    return false;
  }

  const rawTime = msg.time;
  const time = (Number.isFinite(rawTime) && rawTime > 0)
    ? Math.floor(rawTime)
    : 0;

  const title = (typeof msg.title === 'string' && msg.title.trim())
    ? msg.title.trim().slice(0, 300)
    : '';

  sendToMpv(url, time, title);
  sendResponse({ success: true });
  return false;
});


// ─── Core: send to native host ─────────────────────────────────────────────

function sendToMpv(url, time, title = '') {
  // Prevent duplicate execution if clicked twice in rapid succession (< 500ms)
  const now = Date.now();
  if (url === lastLaunchUrl && (now - lastLaunchTime) < 500) {
    return;
  }
  lastLaunchTime = now;
  lastLaunchUrl  = url;

  const payload = { action: 'open', url, time, title };

  chrome.runtime.sendNativeMessage(NATIVE_HOST, payload, (response) => {
    const err = chrome.runtime.lastError;

    if (err) {
      const msg = err.message ?? '';
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
  if (!raw || typeof raw !== 'string') return null;

  let parsed;
  try {
    parsed = new URL(raw.trim());
  } catch {
    return null;
  }

  // Enforce strict protocol allowlist (http, https, magnet)
  if (!ALLOWED_SCHEMES.has(parsed.protocol)) return null;

  // Prevent leading dashes or spaces that could be misused
  const cleanUrl = parsed.toString().trim();
  if (cleanUrl.startsWith('-')) return null;

  // For non-YouTube and non-localhost links, strip tracking query params
  const isYouTube = parsed.hostname.endsWith('youtube.com') || parsed.hostname === 'youtu.be';
  const isLocalHost = parsed.hostname === '127.0.0.1' || parsed.hostname === 'localhost';

  if (!isYouTube && !isLocalHost) {
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
