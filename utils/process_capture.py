#!/usr/bin/env python3
"""
process_capture.py - High-Performance Ultra HDR (ISO 21496-1) & Metadata Injector for mpv
Part of biraj-mpv-conf (https://github.com/Biraj2004/biraj-mpv-conf)

Converts captured frames into standard ISO 21496-1 / Google Ultra HDR / Apple HDR Gain Map JPEGs:
  - Base Image: Tone-mapped sRGB JPEG (100% accurate, non-washed-out on SDR displays, Windows Photos, WhatsApp, etc.)
  - Gain Map: Embedded auxiliary image with MPF APP2 (0xFFE2) and XMP APP1 (hdrgm:Version="1.0") for native HDR displays (Apple Photos, Google Photos, HDR screens)
  - EXIF Metadata: Injected into primary APP1 segment (Make, Model, DateTime, Description, Software)
  - Privacy: Frame captures NEVER include GPS data (kept strictly exclusive to original media)
  - File Size: ~1.5 - 2.5 MB (95% smaller than raw 41MB PNG)
"""

import sys
import os
import io
import re
import math
import json
import struct
from pathlib import Path

# Safe optional imports
try:
    from PIL import Image, ExifTags
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

try:
    import numpy as np
    import sdr_to_hdr
    HAS_ULTRA_HDR = True
except ImportError:
    HAS_ULTRA_HDR = False


def normalize_datetime(dt_str):
    """Normalizes ISO or QuickTime date strings to standard EXIF 'YYYY:MM:DD HH:MM:SS' format."""
    if not dt_str:
        return None
    m = re.search(r'(\d{4})[-:.](\d{2})[-:.](\d{2})[T\s](\d{2}):(\d{2}):(\d{2})', str(dt_str))
    if m:
        y, mo, d, h, mi, s = m.groups()
        return f"{y}:{mo}:{d} {h}:{mi}:{s}"
    return None


def build_exif_app1(meta):
    """
    Builds a standard JPEG APP1 segment containing EXIF IFD0.
    Returns bytes or b''.
    NOTE: GPS data is strictly excluded from frame captures.
    """
    if not HAS_PIL:
        return b''

    exif = Image.Exif()

    make = meta.get("make") or ""
    model = meta.get("model") or ""
    creation_time = meta.get("creation_time") or ""
    filename = meta.get("filename") or ""
    time_str = meta.get("time_str") or ""
    hdr_format = meta.get("hdr_format") or "SDR"

    # Primary IFD tags
    if make:
        exif[ExifTags.Base.Make] = make
    if model:
        exif[ExifTags.Base.Model] = model

    normalized_date = normalize_datetime(creation_time)
    if normalized_date:
        exif[ExifTags.Base.DateTime] = normalized_date

    exif[ExifTags.Base.Software] = "mpv (biraj-mpv-conf)"
    exif[ExifTags.Base.ImageDescription] = f"{filename} @ {time_str} [{hdr_format}]"

    try:
        exif_bytes = exif.tobytes()
        if exif_bytes:
            # JPEG APP1 segment: 0xFFE1 + 2-byte length + payload
            return b'\xff\xe1' + struct.pack('>H', len(exif_bytes) + 2) + exif_bytes
    except Exception as e:
        sys.stderr.write(f"EXIF serialization warning: {e}\n")

    return b''


def process_capture(file_path_str, meta):
    target_path = Path(file_path_str)
    if not target_path.exists():
        sys.stderr.write(f"Error: file not found: {file_path_str}\n")
        return 1

    base_bytes = target_path.read_bytes()
    if len(base_bytes) < 4 or base_bytes[:2] != b'\xff\xd8':
        sys.stderr.write(f"Error: not a valid JPEG: {file_path_str}\n")
        return 1

    is_hdr = bool(meta.get("is_hdr", False))
    exif_app1 = build_exif_app1(meta)

    if is_hdr and HAS_ULTRA_HDR and HAS_PIL:
        try:
            # 1. Load tone-mapped SDR uint8 image from base JPEG
            with Image.open(io.BytesIO(base_bytes)) as im:
                sdr_uint8 = np.array(im.convert('RGB'), dtype=np.uint8)

            # 2. Linearize & compute HDR representation
            sdr_lin = sdr_to_hdr.srgb_to_linear(sdr_uint8.astype(np.float32) / 255.0)
            sdr_white = 203.0
            peak_nits = float(meta.get("peak_nits") or 1000.0)
            if peak_nits < 300.0:
                peak_nits = 1000.0

            hdr_nits = sdr_to_hdr.inverse_tone_map(sdr_lin, sdr_white, peak_nits)
            hdr_bt2020 = np.clip(hdr_nits @ sdr_to_hdr.BT709_TO_BT2020.T, 0.0, peak_nits)

            # 3. Compute gain map and encode
            gain_log2, gain_min, gain_max = sdr_to_hdr.compute_gain_map(sdr_lin, hdr_bt2020, sdr_white)
            hdr_capacity = math.log2(peak_nits / sdr_white)
            xmp_app1 = sdr_to_hdr._xmp_hdrgm(gain_min, gain_max, hdr_capacity)

            gm_raw = sdr_to_hdr.encode_gain_map(gain_log2, gain_min, gain_max, quality=85)
            gainmap_jpeg = gm_raw[:2] + xmp_app1 + gm_raw[2:]

            # 4. Assemble Multi-Picture Format (MPF APP2)
            E = len(exif_app1)
            A = len(xmp_app1)
            B = len(base_bytes)
            G = len(gainmap_jpeg)

            primary_size = E + A + B + 90
            gainmap_offset = B + 80
            mpf_app2 = sdr_to_hdr._mpf_app2(primary_size, G, gainmap_offset)

            # Final layout: SOI + EXIF APP1 + XMP APP1 + MPF APP2 + base_jpeg[2:] + gainmap_jpeg
            final_data = b'\xff\xd8' + exif_app1 + xmp_app1 + mpf_app2 + base_bytes[2:] + gainmap_jpeg

            tmp_path = target_path.with_name(f"{target_path.stem}.tmp{target_path.suffix}")
            tmp_path.write_bytes(final_data)
            tmp_path.replace(target_path)

            print(f"Ultra HDR JPEG created: {target_path.name} ({len(final_data) // 1024} KB)")
            return 0
        except Exception as e:
            sys.stderr.write(f"Ultra HDR processing error: {e}. Falling back to SDR EXIF injection.\n")

    # SDR or fallback: inject EXIF APP1 directly into JPEG
    if exif_app1:
        final_data = b'\xff\xd8' + exif_app1 + base_bytes[2:]
        tmp_path = target_path.with_name(f"{target_path.stem}.tmp{target_path.suffix}")
        tmp_path.write_bytes(final_data)
        tmp_path.replace(target_path)
        print(f"SDR JPEG metadata injected: {target_path.name} ({len(final_data) // 1024} KB)")
    else:
        print(f"JPEG capture ready: {target_path.name}")

    return 0


def main():
    if len(sys.argv) < 2:
        print("Usage: process_capture.py <file_path> [<json_metadata>]")
        return 1

    file_path = sys.argv[1]
    meta = {}
    if len(sys.argv) >= 3:
        try:
            meta = json.loads(sys.argv[2])
        except Exception as e:
            sys.stderr.write(f"Warning: JSON metadata parse error: {e}\n")

    return process_capture(file_path, meta)


if __name__ == "__main__":
    sys.exit(main())
