#!/usr/bin/env bash
# Step 2: install FLauncher (open source, from F-Droid) and make it the home
# screen. Then, with your approval, disable the stock Google TV home so the
# Home button goes to FLauncher.
#
#   ./20-launcher.sh                      # fetch FLauncher from F-Droid
#   APK=/path/to/flauncher.apk ./20-launcher.sh   # use an APK you downloaded
#
# Projectivy Launcher is closed source and only on the Play Store, so it is
# not fetched here. If you prefer it, install it from the Play Store on the
# TV and run:  LAUNCHER_PKG=com.spocky.projengmenu ./20-launcher.sh --set-home-only
source "$(dirname "$0")/lib/common.sh"

LAUNCHER_PKG="${LAUNCHER_PKG:-me.efesser.flauncher}"
FDROID_ID="me.efesser.flauncher"
SET_HOME_ONLY=0; [[ "${1:-}" == "--set-home-only" ]] && SET_HOME_ONLY=1

bold "== Step 2: clean launcher =="
tv_connect
tv_identity
assert_onn
[[ -f "$STATE_DIR/last_backup" ]] || die "No backup found. Run 00-backup.sh first."

if [[ $SET_HOME_ONLY -eq 0 ]]; then
  dl="$TOOLKIT_DIR/downloads"; mkdir -p "$dl"
  if [[ -z "${APK:-}" ]]; then
    bold "Fetching FLauncher from F-Droid"
    command -v curl >/dev/null || die "curl is required to download from F-Droid (or pass APK=/path/to.apk)."
    meta="$(curl -fsSL "https://f-droid.org/api/v1/packages/$FDROID_ID")" \
      || die "F-Droid API request failed. Download the APK from https://f-droid.org/packages/$FDROID_ID and re-run with APK=/path/to/file.apk"
    vcode="$(printf '%s' "$meta" | sed -n 's/.*"suggestedVersionCode":\([0-9]*\).*/\1/p')"
    [[ -n "$vcode" ]] || die "Could not read suggestedVersionCode from F-Droid."
    APK="$dl/${FDROID_ID}_${vcode}.apk"
    [[ -s "$APK" ]] || curl -fL -o "$APK" "https://f-droid.org/repo/${FDROID_ID}_${vcode}.apk" || die "Download failed."
    echo "  APK: $APK (versionCode $vcode)"
    echo "  Verify the signer yourself if you like: F-Droid signs with its own key; see https://f-droid.org/packages/$FDROID_ID"
  fi
  [[ -s "$APK" ]] || die "APK not found: $APK"

  confirm "Install $APK on the TV (adb install -r, nothing is removed)?" || exit 0
  "$ADB_BIN" -s "$TV_ADDR" install -r "$APK"
  record installed.txt "$LAUNCHER_PKG"
fi

pkg_installed "$LAUNCHER_PKG" || die "$LAUNCHER_PKG is not installed on the TV."

# Find the launcher's HOME activity and set it as default home.
home_act="$(tvq cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME | grep "^$LAUNCHER_PKG/" | head -1)"
[[ -n "$home_act" ]] || die "$LAUNCHER_PKG does not expose a HOME activity."
bold "Setting default home to $home_act"
tv cmd package set-home-activity "$home_act" || yellow "set-home-activity returned an error; continuing (the stock home disable below usually fixes it)."
tv am start -n "$home_act" >/dev/null || true

echo
bold "Now check the TV: FLauncher should be on screen. Press Home on the remote."
yellow "On Google TV the Home button keeps opening the stock home until it is disabled."
echo "The next action disables the stock Google TV home (com.google.android.apps.tv.launcherx)"
echo "and its fallback (com.google.android.tungsten.setupwraith) with pm disable-user --user 0."
echo "restore.sh re-enables both and sets the stock home back."
if confirm "Disable the stock Google TV home so the Home button opens FLauncher?"; then
  for p in com.google.android.apps.tv.launcherx com.google.android.tungsten.setupwraith; do
    pkg_installed "$p" || { echo "  not present: $p"; continue; }
    if tv pm disable-user --user 0 "$p" | grep -q 'new state: disabled'; then
      record disabled.txt "$p"; green "  disabled: $p"
    else red "  FAILED: $p"; fi
  done
  tv am start -n "$home_act" >/dev/null || true
fi

echo
bold "FLauncher configuration (on the TV, with the remote):"
cat <<'TXT'
  1. Apps the debloat step disabled no longer appear; FLauncher lists only enabled apps.
  2. To hide any remaining app: long-press its tile > Hide.  To reorder: long-press > Move.
  3. HDMI inputs: keep the system "Inputs" / "Live TV" tile visible. FLauncher cannot create
     per-input tiles itself; the inputs discovered on this TV are listed below and the
     Input button on the onn remote still switches directly.
  4. Settings tile: FLauncher shows the system Settings app; leave it visible.
TXT
echo
bold "HDMI / TV inputs detected on this TV:"
tvq dumpsys tv_input | grep -E 'HDMI|inputId|mLabel' | sed 's/^ */  /' | head -40 || echo "  (none reported by dumpsys tv_input)"
echo
green "Launcher step done. Current default home: $(tvq cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | grep '/' | tail -1)"
