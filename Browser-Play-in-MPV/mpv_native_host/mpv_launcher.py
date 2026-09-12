#!/usr/bin/env python3
"""
mpv_launcher.py — Chrome Native Messaging host for "Play in MPV"
Part of: biraj-mpv-conf | github.com/Biraj2004/biraj-mpv-conf

Protocol
--------
Chrome Native Messaging uses length-prefixed JSON on stdin/stdout:
  [4 bytes little-endian uint32 = message length][UTF-8 JSON payload]

Security Measures:
  - Input validation: Only allows http, https, and magnet schemes.
  - Option injection prevention: Flags end with '--' delimiter before target URL.
  - Subprocess execution: List-based arguments (never shell=True).
  - Sanitization: Removes dangerous quotes, newlines, and control characters.
  - Process isolation: Detached process with closed descriptors.

Self-test (no Chrome needed):
  python mpv_launcher.py --test
"""

import json
import os
import struct
import subprocess
import sys
from typing import Optional


# ──────────────────────────────────────────────────────────────────────────────
# Native Messaging I/O  (binary stdin / stdout — do NOT use print())
# ──────────────────────────────────────────────────────────────────────────────

def _read_message() -> Optional[dict]:
    """Read one length-prefixed JSON message from stdin. Returns None on EOF."""
    raw_len = sys.stdin.buffer.read(4)
    if len(raw_len) < 4:
        return None
    msg_len = struct.unpack('<I', raw_len)[0]
    if msg_len > 1048576:  # Max 1 MB payload protection
        return None
    raw_msg = sys.stdin.buffer.read(msg_len)
    if not raw_msg:
        return None
    return json.loads(raw_msg.decode('utf-8'))


def _write_message(payload: dict) -> None:
    """Write one length-prefixed JSON message to stdout."""
    encoded = json.dumps(payload, separators=(',', ':')).encode('utf-8')
    sys.stdout.buffer.write(struct.pack('<I', len(encoded)))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()


# ──────────────────────────────────────────────────────────────────────────────
# MPV discovery
# ──────────────────────────────────────────────────────────────────────────────

# Ordered list of known install locations (after PATH check)
_KNOWN_PATHS: list[str] = [
    r'C:\Program Files\mpv\mpv.exe',
    r'C:\mpv\mpv.exe',
    os.path.expandvars(r'%LOCALAPPDATA%\Programs\mpv\mpv.exe'),
    os.path.expandvars(r'%USERPROFILE%\scoop\apps\mpv\current\mpv.exe'),
    os.path.expandvars(r'%USERPROFILE%\scoop\shims\mpv.exe'),
]


def _find_mpv() -> Optional[str]:
    """Return the absolute path to mpv.exe, or None if not found."""
    # 1. Check each directory in PATH
    for directory in os.environ.get('PATH', '').split(os.pathsep):
        clean_dir = directory.strip().strip('"')
        if not clean_dir:
            continue
        candidate = os.path.join(clean_dir, 'mpv.exe')
        if os.path.isfile(candidate):
            return candidate

    # 2. Check known install locations
    for path in _KNOWN_PATHS:
        if os.path.isfile(path):
            return path

    return None


# ──────────────────────────────────────────────────────────────────────────────
# Launch
# ──────────────────────────────────────────────────────────────────────────────

import datetime

def _log(msg: str) -> None:
    try:
        log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'launcher.log')
        with open(log_path, 'a', encoding='utf-8') as f:
            f.write(f'[{datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] {msg}\n')
    except Exception:
        pass

# Windows process creation flags: DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP
_DETACHED_PROCESS = 0x00000008          # Detach from parent console
_CREATE_NEW_PROCESS_GROUP = 0x00000200  # Independent process group

def _launch_mpv(url: str, time: int, title: str = '') -> dict:
    """
    Spawn mpv with the given URL and optional start time and media title.
    Returns a result dict: {success, error?, detail?, hint?}
    """
    mpv = _find_mpv()
    if not mpv:
        _log(f'ERROR: mpv.exe not found for url: {url}')
        return {
            'success': False,
            'error':   'mpv_not_found',
            'hint':    (
                'Install MPV to C:\\Program Files\\mpv\\ '
                'or add mpv.exe to your system PATH, '
                'then re-run Install_Native_Host.bat.'
            ),
        }

    # Build argument list safely
    # --force-window=immediate ensures the player window appears immediately
    # while streams or yt-dlp load in the background
    args = [mpv, '--force-window=immediate']
    if time > 0:
        args.append(f'--start={time}')
    if title:
        args.append(f'--force-media-title={title}')

    # Security delimiter: instructs mpv that all subsequent args are media targets,
    # never options/flags (guards against any argument-injection attack)
    args.append('--')
    args.append(url)

    # Set working directory to MPV config directory or MPV executable directory
    config_dir = os.path.expandvars(r'%APPDATA%\mpv')
    launch_cwd = config_dir if os.path.isdir(config_dir) else os.path.dirname(mpv)
    env = os.environ.copy()

    _log(f'Launching: {args} in cwd: {launch_cwd}')
    try:
        subprocess.Popen(
            args,
            cwd=launch_cwd,
            env=env,
            creationflags=_DETACHED_PROCESS | _CREATE_NEW_PROCESS_GROUP,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        _log('Launch successful (process spawned)')
        return {'success': True}
    except OSError as exc:
        _log(f'ERROR: subprocess.Popen failed: {exc}')
        return {
            'success': False,
            'error':   'launch_failed',
            'detail':  str(exc),
        }


# ──────────────────────────────────────────────────────────────────────────────
# Self-test  (python mpv_launcher.py --test)
# ──────────────────────────────────────────────────────────────────────────────

def _run_test() -> None:
    """Print a diagnostic JSON result without requiring Chrome."""
    mpv = _find_mpv()
    if mpv:
        result = {'success': True, 'mpv_path': mpv}
    else:
        result = {
            'success': False,
            'error':   'mpv_not_found',
            'hint':    'Install MPV to C:\\Program Files\\mpv\\ or add it to PATH.',
        }
    print(json.dumps(result, indent=2))


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main() -> None:
    if '--test' in sys.argv:
        _run_test()
        return

    # ── Read message ────────────────────────────────────────────────────────
    try:
        message = _read_message()
    except (json.JSONDecodeError, struct.error, UnicodeDecodeError):
        _write_message({'success': False, 'error': 'invalid_json'})
        return
    except Exception:
        _write_message({'success': False, 'error': 'read_error'})
        return

    if message is None:
        _log('Received empty message (EOF)')
        _write_message({'success': False, 'error': 'empty_message'})
        return

    _log(f'Received payload: {message}')

    # ── Validate fields ─────────────────────────────────────────────────────
    raw_url = message.get('url', '')
    if not isinstance(raw_url, str):
        _write_message({'success': False, 'error': 'invalid_url_type'})
        return

    url = raw_url.strip()

    # Strict URL validation: must start with safe protocol and not be a CLI switch
    if not (url.startswith('http://') or url.startswith('https://') or url.startswith('magnet:')):
        _write_message({'success': False, 'error': 'disallowed_protocol'})
        return

    if url.startswith('-') or url.startswith('/'):
        _write_message({'success': False, 'error': 'malformed_url'})
        return

    # Sanity-check time: must be non-negative integer within 240 hours
    raw_time = message.get('time', 0)
    if isinstance(raw_time, (int, float)) and 0 <= raw_time < 864000:
        time = int(raw_time)
    else:
        time = 0

    # Sanity-check title: max 300 characters, strip leading dashes, escape quotes/newlines
    raw_title = message.get('title', '')
    if isinstance(raw_title, str) and raw_title.strip():
        clean_title = raw_title.replace('"', "'").replace('\n', ' ').replace('\r', '').strip()
        clean_title = clean_title.lstrip('-').strip()[:300]
        title = clean_title
    else:
        title = ''

    # ── Launch ──────────────────────────────────────────────────────────────
    result = _launch_mpv(url, time, title)
    _write_message(result)


if __name__ == '__main__':
    main()
