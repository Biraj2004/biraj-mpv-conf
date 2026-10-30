# Security & Privacy Policy

## Supported Versions

The `biraj-mpv-conf` configuration suite is actively maintained and tuned for modern releases of **mpv**.

| Version | Supported | Notes |
| :--- | :---: | :--- |
| **`mpv` v0.38+** | :white_check_mark: | Fully supported (Recommended) |
| **`mpv` v0.35 - v0.37** | :warning: | Partial compatibility (Some `gpu-next` and script options may require adjustments) |
| **`mpv` < v0.35** | :x: | Not supported |

---

## Privacy, Native Execution & Offline Safety Guarantee

### Official Disclaimer & Privacy Statement

`biraj-mpv-conf` is built strictly with an **offline-first, privacy-by-design** philosophy. Your personal media, viewing habits, system environment, and captured frames remain entirely confidential, private, and within your control:

1. **100% Native & Local Execution**:
   - Every script, configuration file, and post-processing utility executes exclusively on your local computer hardware.
   - There are **no remote servers**, **no background daemons**, **no tracking cookies**, and **no cloud services** involved in the core player operation.

2. **Zero Telemetry, Analytics, or Tracking**:
   - The suite does **not** collect, monitor, log, or track your media playback history, file paths, hardware identifiers, or usage habits.
   - Absolutely **no data is transmitted, shared, uploaded, or sold** to any third-party server, developer server, or analytics endpoint.

3. **Complete Frame Capture Privacy (Zero GPS Geolocation)**:
   - Frame captures (`s`, `S`, `Ctrl+s`) extract technical stream properties strictly from the local file currently loaded in mpv (e.g. resolution, timestamps, color gamut, camera make/model).
   - **Zero Geolocation Exposure**: Any GPS coordinates, altitude data, or location tags present in your original camera recordings (e.g. iPhone MOV or Android MP4) are **completely stripped and omitted** from captured frames. Captured images will never expose where a photo or video was taken or drop a location pin on photo-sharing platforms.

4. **Transparent & Fully Auditable Open-Source Code**:
   - Every script in this repository is written in human-readable, plain-text Lua (`.lua`), Python (`.py`), and batch scripts (`.bat`).
   - There are **zero obfuscated binaries**, **zero proprietary DLLs**, and **zero hidden executables**. Every line of code can be freely audited, inspected, and verified by the community.

---

## Security Considerations

This repository consists of mpv configuration files, Lua scripts, and script options designed for local media playback and web streaming. When using this configuration, please note:

1. **Native File Dialogs (`scripts/open-file.lua`)**:
   - Uses native Windows PowerShell (`PresentationFramework` / `Microsoft.Win32.OpenFileDialog`) to render file picker dialogs without external binary dependencies.
   - The script is self-contained, runs with `-NoProfile`, and only passes user-selected file paths directly to mpv's `loadfile`, `sub-add`, and `audio-add` commands.

2. **Network Streaming (`yt-dlp`)**:
   - Streaming web content relies on `yt-dlp`. Always keep your `yt-dlp` executable updated to the latest release to ensure secure network operations and patched parsers.

3. **Third-Party Lua Scripts**:
   - All bundled Lua scripts (`modernz.lua`, `thumbfast.lua`, `pause_indicator_lite.lua`, `open-file.lua`) are vetted from reputable open-source community developers ([Samillion](https://github.com/Samillion), [po5](https://github.com/po5), [rossy](https://github.com/rossy)).
   - Do not add arbitrary unverified `.lua` or `.js` scripts into your `scripts/` directory without inspecting their source code.

4. **Frame Capture & Privacy Safeguards (`scripts/screenshot_metadata.lua` & `utils/process_capture.py`)**:
   - Frame captures operate 100% locally and offline without external network or telemetry calls.
   - All geolocation data (GPS coordinates, altitude, location tags) is strictly stripped and omitted from frame captures to protect personal privacy.
   - Only technical stream properties present within the local video container (camera make/model, timestamps, colorimetry, codec, resolution) are embedded.

---

## Reporting a Vulnerability

If you discover a potential security vulnerability, security loophole, or misconfiguration in this repository:

1. **Do NOT open a public GitHub issue** with sensitive exploit details.
2. Please report the issue privately via [GitHub Security Advisories](https://github.com/Biraj2004/biraj-mpv-conf/security/advisories/new) or by contacting the repository maintainer directly through their GitHub profile: [@Biraj2004](https://github.com/Biraj2004).
3. Include detailed steps to reproduce the issue, your operating system, your mpv version, and any relevant logs.

### Response Timeline
- **Acknowledgement**: We aim to acknowledge reports within 48 hours.
- **Triage & Remediation**: Vulnerabilities will be triaged and addressed promptly with an update pushed to the `main` branch.
