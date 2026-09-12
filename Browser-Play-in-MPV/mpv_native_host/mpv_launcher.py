#!/usr/bin/env python3
"""
mpv_launcher.py — Chrome Native Messaging host for "Play in MPV"
Part of: biraj-mpv-conf | github.com/Biraj2004/biraj-mpv-conf

Protocol
--------
Chrome Native Messaging uses length-prefixed JSON on stdin/stdout:
  [4 bytes little-endian uint32 = message length][UTF-8 JSON payload]

This script:
  1. Reads one JSON message from stdin.
  2. Finds mpv.exe (PATH → known install locations).
  3. Launches mpv with the given URL and optional --start=N timestamp.
  4. Writes a JSON result back to stdout.
  5. Exits.

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
        candidate = os.path.join(directory.strip('"'), 'mpv.exe')
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

# Windows process creation flags
_DETACHED_PROCESS = 0x00000008   # Detach from parent's console
_CREATE_NO_WINDOW = 0x08000000   # No new console window


def _launch_mpv(url: str, time: int, title: str = '') -> dict:
    """
    Spawn mpv with the given URL and optional start time and media title.
    Returns a result dict: {success, error?, detail?, hint?}
    """
    mpv = _find_mpv()
    if not mpv:
        return {
            'success': False,
            'error':   'mpv_not_found',
            'hint':    (
                'Install MPV to C:\\Program Files\\mpv\\ '
                'or add mpv.exe to your system PATH, '
                'then re-run Install_Native_Host.bat.'
            ),
        }

    # Build args as a list — never via a shell string (injection-safe)
    args = [mpv]
    if time > 1:
        args.append(f'--start={time}')
    if title:
        args.append(f'--force-media-title={title}')
    args.append(url)

    try:
        subprocess.Popen(
            args,
            creationflags=_DETACHED_PROCESS | _CREATE_NO_WINDOW,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            close_fds=True,
        )
        return {'success': True}
    except OSError as exc:
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
        _write_message({'success': False, 'error': 'empty_message'})
        return

    # ── Validate fields ─────────────────────────────────────────────────────
    url = message.get('url', '')
    if not isinstance(url, str):
        url = ''
    url = url.strip()

    if not url:
        _write_message({'success': False, 'error': 'missing_url'})
        return

    # Sanity-check time: must be a non-negative number within a reasonable range
    raw_time = message.get('time', 0)
    if isinstance(raw_time, (int, float)) and 0 <= raw_time < 864000:
        time = int(raw_time)
    else:
        time = 0

    # Sanity-check title: must be a string up to 300 characters, no dangerous quotes or newlines
    raw_title = message.get('title', '')
    if isinstance(raw_title, str) and raw_title.strip():
        title = raw_title.replace('"', "'").replace('\n', ' ').replace('\r', '').strip()[:300]
    else:
        title = ''

    # ── Launch ──────────────────────────────────────────────────────────────
    result = _launch_mpv(url, time, title)
    _write_message(result)


if __name__ == '__main__':
    main()
