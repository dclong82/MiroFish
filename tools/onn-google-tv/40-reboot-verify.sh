#!/usr/bin/env bash
# Step 4: reboot the TV, confirm it comes back, and summarise what changed.
source "$(dirname "$0")/lib/common.sh"

bold "== Step 4: reboot and verify =="
tv_connect
confirm "Reboot the TV now?" || exit 0
"$ADB_BIN" -s "$TV_ADDR" reboot || true
echo "Rebooting. Waiting for it to come back (up to 3 minutes)..."
sleep 15
deadline=$((SECONDS + 180))
until [[ "$(tvq getprop sys.boot_completed)" == "1" ]]; do
  [[ $SECONDS -lt $deadline ]] || die "TV did not report boot completed. Power-cycle it; if it still fails, run restore.sh."
  "$ADB_BIN" connect "$TV_ADDR" >/dev/null 2>&1 || true
  sleep 5
done
sleep 10
green "Boot completed."

echo
bold "Checks"
home="$(tvq cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | grep '/' | tail -1)"
focus="$(tvq dumpsys window | sed -n 's/.*mCurrentFocus=\(.*\)/\1/p' | head -1)"
printf '  %-22s %s\n' "default home:" "$home"
printf '  %-22s %s\n' "window in focus:" "$focus"
printf '  %-22s %s\n' "wifi:" "$(tvq dumpsys wifi | grep -m1 -E 'Wi-Fi is|mWifiEnabled' )"
printf '  %-22s %s\n' "bluetooth:" "$(tvq settings get global bluetooth_on | sed 's/^1$/on/;s/^0$/off/')"
printf '  %-22s %s\n' "play services:" "$(pkg_enabled com.google.android.gms && echo enabled || echo DISABLED)"
printf '  %-22s %s\n' "play store:" "$(pkg_enabled com.android.vending && echo enabled || echo DISABLED)"
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
  printf '  %-22s %s\n' "$k:" "$(tvq settings get global "$k")"
done

echo
bold "What changed (from state/):"
if [[ -s "$STATE_DIR/disabled.txt" ]]; then
  echo "  Disabled (pm disable-user --user 0):"; sed 's/^/    /' "$STATE_DIR/disabled.txt"
fi
[[ -s "$STATE_DIR/installed.txt" ]] && { echo "  Installed:"; sed 's/^/    /' "$STATE_DIR/installed.txt"; }
[[ -s "$STATE_DIR/settings.txt" ]]  && echo "  Settings changed: $(cat "$STATE_DIR/settings.txt")"
echo
bold "Still disabled on the TV right now:"
tvq pm list packages --user 0 -d | sed 's/^package:/    /'

echo
yellow "Reminder: turn USB debugging back OFF when you are done:"
echo "  Settings > System > About > (Android TV OS build) > Developer options > USB debugging -> Off"
echo "  then:  adb disconnect $TV_ADDR"
