#!/usr/bin/env bash
# Shared helpers for the onn Google TV clean-up toolkit.
# Sourced by every step script. Nothing here changes the TV.

set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${TOOLKIT_DIR}/state"
BACKUP_DIR="${TOOLKIT_DIR}/backups"
CONF_FILE="${TOOLKIT_DIR}/packages.conf"

TV_ADDR="${TV_ADDR:-}"          # e.g. 192.168.1.50 or 192.168.1.50:5555
ADB_BIN="${ADB_BIN:-adb}"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
die()    { red "ERROR: $*" >&2; exit 1; }

# Every step must be run with the TV address, either as $TV_ADDR or
# saved from a previous step in state/tv_addr.
load_tv_addr() {
  if [[ -z "$TV_ADDR" && -f "$STATE_DIR/tv_addr" ]]; then
    TV_ADDR="$(<"$STATE_DIR/tv_addr")"
  fi
  [[ -n "$TV_ADDR" ]] || die "Set TV_ADDR=192.168.x.x (or run 00-backup.sh first)."
  [[ "$TV_ADDR" == *:* ]] || TV_ADDR="${TV_ADDR}:5555"
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$TV_ADDR" > "$STATE_DIR/tv_addr"
}

require_adb() {
  command -v "$ADB_BIN" >/dev/null 2>&1 \
    || die "adb not found. Install Android platform-tools: https://developer.android.com/tools/releases/platform-tools"
}

# adb over the network. Handles the 'unauthorized' state (the TV shows an
# 'Allow USB debugging?' dialog that must be accepted with the remote).
tv_connect() {
  require_adb
  load_tv_addr
  "$ADB_BIN" connect "$TV_ADDR" >/dev/null 2>&1 || true
  local state tries=0
  while :; do
    state="$("$ADB_BIN" -s "$TV_ADDR" get-state 2>/dev/null || true)"
    case "$state" in
      device) break ;;
      *)
        tries=$((tries + 1))
        if [[ $tries -eq 1 ]]; then
          yellow "Waiting for the TV at $TV_ADDR (state: '${state:-none}')."
          yellow "If the TV shows 'Allow USB debugging?', select 'Always allow' with the remote."
        fi
        [[ $tries -lt 30 ]] || die "Could not reach $TV_ADDR as an authorized adb device. Check the IP, that the TV is on, and that USB debugging is enabled."
        sleep 2
        "$ADB_BIN" connect "$TV_ADDR" >/dev/null 2>&1 || true
        ;;
    esac
  done
}

# Run a shell command on the TV, with CR stripped (older adb emits CRLF).
tv() { "$ADB_BIN" -s "$TV_ADDR" shell "$@" | tr -d '\r'; }
tvq() { "$ADB_BIN" -s "$TV_ADDR" shell "$@" 2>/dev/null | tr -d '\r' || true; }

tv_prop() { tvq getprop "$1"; }

tv_identity() {
  bold "Device"
  printf '  brand:        %s\n' "$(tv_prop ro.product.brand)"
  printf '  manufacturer: %s\n' "$(tv_prop ro.product.manufacturer)"
  printf '  model:        %s\n' "$(tv_prop ro.product.model)"
  printf '  device:       %s\n' "$(tv_prop ro.product.device)"
  printf '  Android:      %s (SDK %s)\n' "$(tv_prop ro.build.version.release)" "$(tv_prop ro.build.version.sdk)"
  printf '  build:        %s\n' "$(tv_prop ro.build.display.id)"
  printf '  serial:       %s\n' "$(tv_prop ro.serialno)"
}

# Refuse to proceed unless this looks like an onn device, unless the user
# explicitly overrides with ALLOW_ANY_DEVICE=1.
assert_onn() {
  local b m
  b="$(tv_prop ro.product.brand | tr '[:upper:]' '[:lower:]')"
  m="$(tv_prop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')"
  if [[ "$b" != *onn* && "$m" != *onn* && "${ALLOW_ANY_DEVICE:-0}" != 1 ]]; then
    die "This does not look like an onn device (brand='$b', manufacturer='$m'). Re-run with ALLOW_ANY_DEVICE=1 only if you are sure."
  fi
}

# Typed confirmation gate. Every step that changes the TV calls this.
confirm() {
  local prompt="${1:-Proceed?}" answer
  if [[ "${ASSUME_YES:-0}" == 1 ]]; then yellow "$prompt  [auto-yes]"; return 0; fi
  printf '\n%s  Type "yes" to continue, anything else to stop: ' "$prompt"
  read -r answer
  [[ "$answer" == "yes" ]] || { yellow "Stopped. Nothing was changed by this prompt."; return 1; }
}

# Per-item yes/no (used for the "ask me" list). Returns 0 for yes.
ask_yn() {
  local prompt="$1" answer
  printf '%s [y/N]: ' "$prompt"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

pkg_installed() { tvq pm list packages --user 0 "$1" | grep -qx "package:$1"; }
pkg_enabled()   { tvq pm list packages --user 0 -e "$1" | grep -qx "package:$1"; }
pkg_uid()       { tvq dumpsys package "$1" | sed -n 's/^ *userId=\([0-9]*\).*/\1/p' | head -1; }

# Protected package patterns. Nothing matching these is ever disabled,
# whatever the plan says. Covers boot, WiFi, Bluetooth, the remote, HDMI /
# TV inputs / CEC, Play Services, Play Store, settings, input methods,
# and the core OS.
PROTECTED_RE='^(android|com\.android\.(systemui|settings|tv\.settings|providers\..*|bluetooth.*|wifi.*|nfc|phone|server\.telecom|shell|packageinstaller|permissioncontroller|inputdevices|location\.fused|keychain|certinstaller|externalstorage|mtp|se|cts\..*|vending|tv|tv\..*|dreams\.basic|inputmethod.*|backupconfirm|statementservice|companiondevicemanager|dynsystem|localtransport|managedprovisioning|ons|proxyhandler|sharedstoragebackup|soundpicker|storagemanager|traceur|vpndialogs|wallpaperbackup|bips|htmlviewer|captiveportallogin|networkstack.*|cellbroadcast.*|carrierconfig|carrierdefaultapp|calllogbackup|emergency|egg|intentresolver|credentialmanager|devicelockcontroller|safetycenter|uwb|virtualmachine|wifi\.dialog|wifi\.resources|connectivity\.resources|ipsec|modulemetadata|adservices\.api|ondevicepersonalization\..*|health\.connect|federatedcompute|rkpd|sdksandbox|hotspot2\..*|printspooler)|com\.google\.android\.(gms.*|gsf|ext\..*|tv\.(settings|inputs|frameworkpackagestubs|remote\.service\.tvremote|setupwizard)|tungsten\.overscan|onetimeinitializer|permissioncontroller|modulemetadata|captiveportallogin|networkstack.*|cellbroadcast.*|adservices.*|ondevicepersonalization|wifi\..*|overlay\..*|webview|packageinstaller|inputmethod\..*|tvlauncher|apps\.tv\.launcherx\.overlay.*|as|as\.oss|bluetooth|bluetooth\..*|hotspot2\..*|rkpd|sdksandbox|safetycenter|uwb|federatedcompute|health\.connect|devicelockcontroller|virtualization\..*|art|conscrypt|ipsec|tzdata.*|media.*|mediaprovider.*|permission.*|resolv|tethering|wifi.*|appsearch|scheduling|extservices|configupdater|nearby\..*|cts\..*)|com\.google\.mainline\..*|com\.(droidlogic|amlogic|mediatek|mtk|realtek|rtk|novatek|mstar|sei|skyworth|tcl|hisense|synaptics|marvell|broadcom)(\..*)?|.*(tvinput|hdmi|cec|bluetooth|btservice|wifi|remote.*(service|controller|pairing)|inputmethod|keyboard|leanbackime|gboard|setupwizard|frameworkres|overlay|resources)[^ ]*$|com\.google\.android\.tv\.remote\.service\.?.*cec.*)$'

# Explicit keep list (apps you asked to keep). Also never disabled.
KEEP_LIST=(
  com.netflix.ninja                      # Netflix
  com.google.android.youtube.tv          # YouTube
  com.amazon.amazonvideo.livingroom      # Prime Video
  com.disney.disneyplus                  # Disney+
  com.wbd.stream                         # Max
  com.hbo.hbonow                         # Max (older package name)
  com.android.vending                    # Google Play Store
  com.google.android.gms                 # Google Play Services
  com.google.android.gsf                 # Google Services Framework
  com.android.tv.settings                # Settings (Android TV)
  com.google.android.tv.settings         # Settings (Google TV variant, if present)
  com.google.android.tvlauncher          # classic Android TV home, kept as a fallback home
  me.efesser.flauncher                   # FLauncher (installed by step 20)
  com.spocky.projengmenu                 # Projectivy (if you installed it yourself)
)

is_protected() {
  local p="$1" k
  for k in "${KEEP_LIST[@]}"; do [[ "$p" == "$k" ]] && return 0; done
  [[ "$p" =~ $PROTECTED_RE ]]
}

# Read packages.conf lines of the form:  category|package|reason
# Skips comments/blank lines. Echoes "category<TAB>package<TAB>reason".
read_conf() {
  [[ -f "$CONF_FILE" ]] || die "Missing $CONF_FILE"
  grep -Ev '^\s*(#|$)' "$CONF_FILE" | awk -F'|' 'NF>=3 {gsub(/^[ \t]+|[ \t]+$/,"",$1);gsub(/^[ \t]+|[ \t]+$/,"",$2); sub(/^[ \t]+/,"",$3); print $1 "\t" $2 "\t" $3}'
}

latest_backup() {
  ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | head -1 | sed 's:/$::'
}

record() { # record <file> <line>  -- append a line to a state file, de-duplicated
  mkdir -p "$STATE_DIR"
  touch "$STATE_DIR/$1"
  grep -qxF "$2" "$STATE_DIR/$1" || printf '%s\n' "$2" >> "$STATE_DIR/$1"
}
