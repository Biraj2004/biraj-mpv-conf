#!/bin/bash
# =======================================================================================================
# GitHub      : https://github.com/Biraj2004
# Developer   : Biraj
# Description : Configures Stremio to add MPV player integration ("Play in MPV") on macOS.
#                - Automatically locates MPV across Homebrew (Apple Silicon & Intel), MacPorts, and /Applications.
#                - Detects active Stremio processes to prevent locked file conflicts during patching.
#                - Injects the MPV configuration and robust launch handler into Stremio's server.js.
#                - Automatically creates timestamped backups (.backup_YYYYMMDD_HHMMSS) before modifying.
#                - Re-running this script is SAFE: existing up-to-date configurations are skipped.
# =======================================================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
ROOT_DIR="$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
DARKGRAY='\033[1;30m'
NC='\033[0m' # Reset

echo -e "${GRAY}=======================================================================================================${NC}"
echo -e "${CYAN}                                 STREMIO SETUP TO PLAY IN MPV (macOS)${NC}"
echo -e "${GRAY}                      Developed by : Biraj${NC}"
echo -e "${GRAY}                      GitHub       : https://github.com/Biraj2004${NC}"
echo -e "${GRAY}=======================================================================================================${NC}"
echo
echo -e "${WHITE}[INFO] Working Folder   : $ROOT_DIR${NC}"
echo -e "${WHITE}[INFO] Target           : Stremio server.js (External Player Configuration)${NC}"
echo -e "${WHITE}[INFO] Action           : Add \"Play in MPV\" option next to \"Play in VLC\" in player menu${NC}"
echo -e "${WHITE}[INFO] Scope            : Local Stremio installation(s) on macOS${NC}"
echo -e "${WHITE}[INFO] Safety           : Full timestamped backup (.backup_*) created before modifying files${NC}"
echo
echo -e "${YELLOW}=======================================================================================================${NC}"
echo -e "${YELLOW} WARNING: This will configure Stremio to add MPV as an external player option.${NC}"
echo -e "${YELLOW}=======================================================================================================${NC}"
echo
read -r -p "Type Y and press Enter to proceed, or N to cancel : " CONFIRM
CONFIRM=$(echo "$CONFIRM" | tr -d '\r')

case "$CONFIRM" in
    [Yy]|[Yy][Ee][Ss])
        ;;
    *)
        echo
        echo -e "${YELLOW}[CANCELLED] Setup execution cancelled. No files or settings were modified. Exiting safely.${NC}"
        exit 0
        ;;
esac

echo
echo -e "${WHITE}[PROCESSING] Checking system prerequisites and locating MPV...${NC}"
echo -e "${GRAY}=======================================================================================================${NC}"

# 1. Locate MPV executable on macOS
MPV_PATH=""
if [ -n "$1" ] && [ -x "$1" ]; then
    MPV_PATH="$1"
fi

if [ -z "$MPV_PATH" ]; then
    if command -v mpv >/dev/null 2>&1; then
        MPV_PATH="$(command -v mpv)"
    elif [ -x "/opt/homebrew/bin/mpv" ]; then
        MPV_PATH="/opt/homebrew/bin/mpv"
    elif [ -x "/usr/local/bin/mpv" ]; then
        MPV_PATH="/usr/local/bin/mpv"
    elif [ -x "/opt/local/bin/mpv" ]; then
        MPV_PATH="/opt/local/bin/mpv"
    elif [ -x "/Applications/mpv.app/Contents/MacOS/mpv" ]; then
        MPV_PATH="/Applications/mpv.app/Contents/MacOS/mpv"
    elif [ -x "$HOME/Applications/mpv.app/Contents/MacOS/mpv" ]; then
        MPV_PATH="$HOME/Applications/mpv.app/Contents/MacOS/mpv"
    fi
fi

if [ -z "$MPV_PATH" ]; then
    echo -e "${RED}[ERROR] MPV was NOT found on this system.${NC}"
    echo
    echo "        This script will NOT modify Stremio until mpv is installed."
    echo
    echo "        Recommended setup (via Homebrew):"
    echo "          1. Install Homebrew (if not already installed): https://brew.sh"
    echo "          2. Install MPV:"
    echo "               brew install mpv"
    echo "          3. (Recommended) Apply the tuned config suite:"
    echo "               git clone --depth 1 https://github.com/Biraj2004/biraj-mpv-conf.git /tmp/biraj-mpv-conf"
    echo "               mkdir -p ~/.config/mpv"
    echo "               cp -f /tmp/biraj-mpv-conf/*.conf ~/.config/mpv/"
    echo "               cp -rf /tmp/biraj-mpv-conf/scripts /tmp/biraj-mpv-conf/script-opts /tmp/biraj-mpv-conf/fonts ~/.config/mpv/ 2>/dev/null || true"
    echo "               rm -rf /tmp/biraj-mpv-conf"
    echo "          4. Run this script again."
    echo
    exit 1
fi

echo -e "${WHITE}[INFO] MPV Executable   : $MPV_PATH${NC}"
echo

# 2. Check if Stremio is currently running
if pgrep -f "Stremio" >/dev/null 2>&1; then
    echo -e "${YELLOW}=======================================================================================================${NC}"
    echo -e "${YELLOW} WARNING: Stremio is currently running.${NC}"
    echo -e "${YELLOW} Close it fully before continuing, otherwise changes may get overwritten when Stremio exits.${NC}"
    echo -e "${YELLOW}=======================================================================================================${NC}"
    echo
    read -r -p "Type Y to continue anyway, or N to cancel : " STREMIO_CONFIRM
    STREMIO_CONFIRM=$(echo "$STREMIO_CONFIRM" | tr -d '\r')
    case "$STREMIO_CONFIRM" in
        [Yy]|[Yy][Ee][Ss])
            ;;
        *)
            echo
            echo -e "${YELLOW}[CANCELLED] Setup cancelled to prevent file lock conflict. Exiting safely.${NC}"
            exit 0
            ;;
    esac
    echo
fi

# 3. Locate server.js on macOS
TARGETS=()
CANDIDATE_PATHS=(
    "/Applications/Stremio.app/Contents/Resources/server.js"
    "/Applications/Stremio.app/Contents/MacOS/server.js"
    "$HOME/Applications/Stremio.app/Contents/Resources/server.js"
    "$HOME/Applications/Stremio.app/Contents/MacOS/server.js"
    "/Applications/Stremio-4.app/Contents/Resources/server.js"
    "$HOME/Library/Application Support/Smart Code ltd/Stremio/server.js"
    "$HOME/Library/Application Support/stremio/server.js"
)

for cpath in "${CANDIDATE_PATHS[@]}"; do
    if [ -f "$cpath" ]; then
        TARGETS+=("$cpath")
    fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
    # Fallback search inside /Applications and ~/Applications
    while IFS= read -r found; do
        [ -n "$found" ] && TARGETS+=("$found")
    done < <(find /Applications "$HOME/Applications" -maxdepth 5 -name "server.js" 2>/dev/null | grep -i "stremio")
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo -e "${RED}[ERROR] Could not locate Stremio's server.js on this system.${NC}"
    echo -e "${YELLOW}        Make sure Stremio is installed, then try again.${NC}"
    exit 1
fi

echo -e "${WHITE}[INFO] Found ${#TARGETS[@]} Stremio installation(s):${NC}"
for i in "${!TARGETS[@]}"; do
    idx=$((i + 1))
    echo -e "${WHITE}  [$idx] ${TARGETS[$i]}${NC}"
done
echo

PATCHED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

# 4. Patch engine using Node.js or Python3
for target in "${TARGETS[@]}"; do
    echo -e "${GRAY}-------------------------------------------------------------------------------------------------------${NC}"
    echo -e "${CYAN}[PROCESSING] Target: $target${NC}"

    # Use node or python3 to patch
    PATCH_RESULT=""
    if command -v node >/dev/null 2>&1; then
        PATCH_RESULT=$(node -e '
const fs = require("fs");
const rawArgs = process.argv.slice(1).filter(a => a !== "[eval]" && a !== "-e");
const filePath = rawArgs[0];
const mpvPath = rawArgs[1] || "/usr/local/bin/mpv";

try {
    let content = fs.readFileSync(filePath, "utf8");
    const orig = content;
    
    // 1. Build MPV darwin path array
    const darwinPaths = [mpvPath, "/opt/homebrew/bin/mpv", "/usr/local/bin/mpv", "/opt/local/bin/mpv", "/sw/bin/mpv", "/Applications/mpv.app/Contents/MacOS/mpv"];
    const uniqueDarwin = [...new Set(darwinPaths)].map(p => `"${p}"`).join(", ");
    
    const mpvEntry = `mpv: {
                title: "MPV",
                args: [ "--no-terminal" ],
                subArg: "--sub-file=",
                timeArg: "--start=",
                playArg: "",
                darwin: {
                    path: [ ${uniqueDarwin} ]
                },
                linux: {
                    path: [ "/usr/bin/mpv", "/usr/local/bin/mpv", "/var/lib/flatpak/exports/bin/io.mpv.Mpv", "/snap/bin/mpv" ]
                },
                win32: {
                    path: [ "\"C:\\\\Program Files\\\\mpv\\\\mpv.exe\"", "\"C:\\\\Program Files (x86)\\\\mpv\\\\mpv.exe\"", "\"C:\\\\Program Files\\\\mpv.net\\\\mpvnet.exe\"", "\"C:\\\\Program Files (x86)\\\\mpv.net\\\\mpvnet.exe\"", "\"C:\\\\mpv\\\\mpv.exe\"" ]
                }
            }`;

    if (/mpv:\s*\{[\s\S]*?darwin:\s*\{[\s\S]*?path:\s*\[[\s\S]*?\]\s*\}\s*\}/.test(content)) {
        content = content.replace(/mpv:\s*\{[\s\S]*?darwin:\s*\{[\s\S]*?path:\s*\[[\s\S]*?\]\s*\}\s*\}/, mpvEntry);
    } else {
        const vlcMatch = content.match(/(vlc:\s*\{[\s\S]*?win32:\s*\{[\s\S]*?\}\s*\})/);
        if (vlcMatch) {
            content = content.replace(vlcMatch[0], vlcMatch[0] + ",\n            " + mpvEntry);
        }
    }

    const improvedLaunch = `var playerBin = /^".*"$/.test(playerPaths[0]) ? playerPaths[0] : "\"" + playerPaths[0] + "\"", wrappedSrc = "\"" + src + "\"", quoteValue = function(value) {
                                            return "\"" + value.replace(/"/gi, "\\\"") + "\"";
                                        }, subsCmd = subsFile && players[player].subArg && players[player].subArg.length > 0 ? players[player].subArg + quoteValue(subsFile) : "", argsCmd = players[player].args && players[player].args.length > 0 ? players[player].args.join(" ") : "", timeSec = parseInt(time / 1e3), timeCmd = players[player].timeArg && players[player].timeArg.length > 0 && !isNaN(timeSec) && timeSec > 0 ? players[player].timeArg + timeSec : "", playCmd = players[player].playArg && players[player].playArg.length > 0 ? players[player].playArg + wrappedSrc : wrappedSrc, fullCmd = [playerBin, timeCmd, argsCmd, subsCmd, playCmd].filter(Boolean).join(" ");`;

    const launchRegex = /var\s+(?:playerBin\s*=.*?,)?\s*wrappedSrc\s*=\s*'"'\s*\+\s*src\s*\+\s*'"'\s*,[\s\S]*?fullCmd\s*=\s*(?:\[playerBin[\s\S]*?\]\.filter\(Boolean\)\.join\(" "\)|playerPaths\[0\]\s*\+\s*" "[\s\S]*?;)/;
    content = content.replace(launchRegex, improvedLaunch);

    if (content === orig) {
        console.log("SKIPPED");
    } else {
        const now = new Date();
        const ts = now.getFullYear() + String(now.getMonth()+1).padStart(2,"0") + String(now.getDate()).padStart(2,"0") + "_" + String(now.getHours()).padStart(2,"0") + String(now.getMinutes()).padStart(2,"0") + String(now.getSeconds()).padStart(2,"0");
        const backup = filePath + ".backup_" + ts;
        fs.copyFileSync(filePath, backup);
        fs.writeFileSync(filePath, content, "utf8");
        console.log("PATCHED:" + backup);
    }
} catch(err) {
    console.log("ERROR:" + err.message);
}
' "$target" "$MPV_PATH")
    elif command -v python3 >/dev/null 2>&1; then
        PATCH_RESULT=$(python3 -c '
import sys, re, datetime, shutil

rawArgs = [a for a in sys.argv[1:] if a != "-c"]
filePath = rawArgs[0] if len(rawArgs) > 0 else ""
mpvPath = rawArgs[1] if len(rawArgs) > 1 else "/usr/local/bin/mpv"

try:
    with open(filePath, "r", encoding="utf-8") as f:
        content = f.read()
    orig = content
    
    darwinPaths = [mpvPath, "/opt/homebrew/bin/mpv", "/usr/local/bin/mpv", "/opt/local/bin/mpv", "/sw/bin/mpv", "/Applications/mpv.app/Contents/MacOS/mpv"]
    seen = []
    for p in darwinPaths:
        if p not in seen:
            seen.append(p)
    uniqueDarwin = ", ".join(["\"" + p + "\"" for p in seen])
    
    mpvEntry = f"""mpv: {{
                title: "MPV",
                args: [ "--no-terminal" ],
                subArg: "--sub-file=",
                timeArg: "--start=",
                playArg: "",
                darwin: {{
                    path: [ {uniqueDarwin} ]
                }},
                linux: {{
                    path: [ "/usr/bin/mpv", "/usr/local/bin/mpv", "/var/lib/flatpak/exports/bin/io.mpv.Mpv", "/snap/bin/mpv" ]
                }},
                win32: {{
                    path: [ "\"C:\\\\Program Files\\\\mpv\\\\mpv.exe\"", "\"C:\\\\Program Files (x86)\\\\mpv\\\\mpv.exe\"", "\"C:\\\\Program Files\\\\mpv.net\\\\mpvnet.exe\"", "\"C:\\\\Program Files (x86)\\\\mpv.net\\\\mpvnet.exe\"", "\"C:\\\\mpv\\\\mpv.exe\"" ]
                }}
            }}"""

    if re.search(r"mpv:\s*\{[\s\S]*?darwin:\s*\{[\s\S]*?path:\s*\[[\s\S]*?\]\s*\}\s*\}", content):
        content = re.sub(r"mpv:\s*\{[\s\S]*?darwin:\s*\{[\s\S]*?path:\s*\[[\s\S]*?\]\s*\}\s*\}", mpvEntry, content)
    else:
        vlcMatch = re.search(r"(vlc:\s*\{[\s\S]*?win32:\s*\{[\s\S]*?\}\s*\})", content)
        if vlcMatch:
            content = content[:vlcMatch.end()] + ",\n            " + mpvEntry + content[vlcMatch.end():]

    improvedLaunch = "var playerBin = /^\\\".*\\\"$/.test(playerPaths[0]) ? playerPaths[0] : \\\"\\\\\\\"\\\" + playerPaths[0] + \\\"\\\\\\\"\\\", wrappedSrc = \\\"\\\\\\\"\\\" + src + \\\"\\\\\\\"\\\", quoteValue = function(value) { return \\\"\\\\\\\"\\\" + value.replace(/\\\"/gi, \\\"\\\\\\\\\\\\\\\"\\\") + \\\"\\\\\\\"\\\"; }, subsCmd = subsFile && players[player].subArg && players[player].subArg.length > 0 ? players[player].subArg + quoteValue(subsFile) : \"\", argsCmd = players[player].args && players[player].args.length > 0 ? players[player].args.join(\" \") : \"\", timeSec = parseInt(time / 1e3), timeCmd = players[player].timeArg && players[player].timeArg.length > 0 && !isNaN(timeSec) && timeSec > 0 ? players[player].timeArg + timeSec : \"\", playCmd = players[player].playArg && players[player].playArg.length > 0 ? players[player].playArg + wrappedSrc : wrappedSrc, fullCmd = [playerBin, timeCmd, argsCmd, subsCmd, playCmd].filter(Boolean).join(\" \");"

    launchRegex = re.compile(r"var\s+(?:playerBin\s*=.*?,)?\s*wrappedSrc\s*=\s*'\x22'\s*\+\s*src\s*\+\s*'\x22'\s*,[\s\S]*?fullCmd\s*=\s*(?:\[playerBin[\s\S]*?\]\.filter\(Boolean\)\.join\(\x22 \x22\)|playerPaths\[0\]\s*\+\s*\x22 \x22[\s\S]*?;)")
    content = launchRegex.sub(improvedLaunch, content)

    if content == orig:
        print("SKIPPED")
    else:
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup = filePath + ".backup_" + ts
        shutil.copyfile(filePath, backup)
        with open(filePath, "w", encoding="utf-8") as f:
            f.write(content)
        print("PATCHED:" + backup)
    except Exception as e:
        print("ERROR:" + str(e))
' "$target" "$MPV_PATH")
    else
        PATCH_RESULT="ERROR:Neither Node.js nor Python3 was found to safely patch server.js"
    fi

    if [[ "$PATCH_RESULT" == PATCHED:* ]]; then
        BACKUP_FILE="${PATCH_RESULT#PATCHED:}"
        PATCHED_COUNT=$((PATCHED_COUNT + 1))
        echo -e "${GREEN}[SUCCESS] Backup created: $BACKUP_FILE${NC}"
        echo -e "${GREEN}[SUCCESS] mpv player entry added/updated successfully.${NC}"
    elif [ "$PATCH_RESULT" == "SKIPPED" ]; then
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        echo -e "${DARKGRAY}[SKIP]    Already configured and up to date - no changes required.${NC}"
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
        ERR_MSG="${PATCH_RESULT#ERROR:}"
        echo -e "${RED}[ERROR]   $ERR_MSG${NC}"
    fi
done

echo
echo -e "${GRAY}-------------------------------------------------------------------------------------------------------${NC}"
printf "${GREEN}[SUMMARY] Patched       : %d${NC}\n" "$PATCHED_COUNT"
printf "${GREEN}[SUMMARY] Already OK    : %d${NC}\n" "$SKIPPED_COUNT"
if [ "$FAILED_COUNT" -gt 0 ]; then
    printf "${YELLOW}[SUMMARY] Failed/Warned : %d${NC}\n" "$FAILED_COUNT"
else
    printf "${GREEN}[SUMMARY] Failed/Warned : %d${NC}\n" "$FAILED_COUNT"
fi

if [ "$FAILED_COUNT" -eq 0 ] || [ "$PATCHED_COUNT" -gt 0 ]; then
    echo -e "${GREEN}[SUCCESS] Stremio MPV setup completed successfully.${NC}"
    echo -e "${GREEN}          Restart Stremio - \"Play in MPV\" should now appear next to \"Play in VLC\".${NC}"
else
    echo -e "${RED}[ERROR]   Stremio MPV patching could not be applied.${NC}"
fi

echo -e "${GRAY}-------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GRAY}=======================================================================================================${NC}"
echo -e "${GREEN}[FINISHED] Script execution finished. GitHub: https://github.com/Biraj2004${NC}"
echo -e "${GRAY}=======================================================================================================${NC}"
echo

if [ "$FAILED_COUNT" -gt 0 ] && [ "$PATCHED_COUNT" -eq 0 ]; then
    exit 1
fi
exit 0
