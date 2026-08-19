# Security Policy

## Supported Versions

The `biraj-mpv-conf` configuration suite is actively maintained and tuned for modern releases of **mpv**.

| Version | Supported | Notes |
| :--- | :---: | :--- |
| **`mpv` v0.38+** | :white_check_mark: | Fully supported (Recommended) |
| **`mpv` v0.35 - v0.37** | :warning: | Partial compatibility (Some `gpu-next` and script options may require adjustments) |
| **`mpv` < v0.35** | :x: | Not supported |

---

## Security Considerations

This repository consists of mpv configuration files, Lua scripts, and script options designed for local media playback and web streaming. When using this configuration, please be aware of the following:

1. **Native File Dialogs (`scripts/open-file.lua`)**:
   - Uses native Windows PowerShell (`PresentationFramework` / `Microsoft.Win32.OpenFileDialog`) to render file picker dialogs without external binary dependencies.
   - The script is self-contained, runs with `-NoProfile`, and only passes user-selected file paths directly to mpv's `loadfile`, `sub-add`, and `audio-add` commands.

2. **Network Streaming (`yt-dlp`)**:
   - Streaming web content relies on `yt-dlp`. Always keep your `yt-dlp` executable updated to the latest release to ensure secure network operations and patched parsers.

3. **Third-Party Lua Scripts**:
   - All bundled Lua scripts (`modernz.lua`, `thumbfast.lua`, `pause_indicator_lite.lua`, `open-file.lua`) are vetted from reputable open-source community developers ([Samillion](https://github.com/Samillion), [po5](https://github.com/po5), [rossy](https://github.com/rossy)).
   - Do not add arbitrary unverified `.lua` or `.js` scripts into your `scripts/` directory without inspecting their source code.

---

## Reporting a Vulnerability

If you discover a potential security vulnerability, security loophole, or misconfiguration in this repository:

1. **Do NOT open a public GitHub issue** with sensitive exploit details.
2. Please report the issue privately via [GitHub Security Advisories](https://github.com/Biraj2004/biraj-mpv-conf/security/advisories/new) or by contacting the repository maintainer directly through their GitHub profile: [@Biraj2004](https://github.com/Biraj2004).
3. Include detailed steps to reproduce the issue, your operating system, your mpv version, and any relevant logs.

### Response Timeline
- **Acknowledgement**: We aim to acknowledge reports within 48 hours.
- **Triage & Remediation**: Vulnerabilities will be triaged and addressed promptly with an update pushed to the `main` branch.
