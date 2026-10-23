#!/usr/bin/env bash
# Step 0: connect, confirm the device, and back up everything we might change.
# This step changes NOTHING on the TV.
#
#   TV_ADDR=192.168.1.50 ./00-backup.sh
source "$(dirname "$0")/lib/common.sh"

bold "== Step 0: connect and back up =="
tv_connect
tv_identity
assert_onn

stamp="$(date +%Y%m%d-%H%M%S)"
serial="$(tv_prop ro.serialno | tr -c 'A-Za-z0-9\n' '_')"
out="$BACKUP_DIR/${serial:-unknown}-$stamp"
mkdir -p "$out"

echo
bold "Writing backup to $out"
tvq getprop                                                  > "$out/getprop.txt"
{
  echo "brand=$(tv_prop ro.product.brand)"
  echo "manufacturer=$(tv_prop ro.product.manufacturer)"
  echo "model=$(tv_prop ro.product.model)"
  echo "device=$(tv_prop ro.product.device)"
  echo "android=$(tv_prop ro.build.version.release)"
  echo "sdk=$(tv_prop ro.build.version.sdk)"
  echo "build=$(tv_prop ro.build.display.id)"
  echo "serial=$(tv_prop ro.serialno)"
  echo "backup_time=$stamp"
} > "$out/device.txt"

# Package lists: full (with APK path), enabled, disabled, system, third-party.
tvq pm list packages --user 0 -f      | sort > "$out/packages-all.txt"
tvq pm list packages --user 0 -e      | sort > "$out/packages-enabled.txt"
tvq pm list packages --user 0 -d      | sort > "$out/packages-disabled.txt"
tvq pm list packages --user 0 -s      | sort > "$out/packages-system.txt"
tvq pm list packages --user 0 -3      | sort > "$out/packages-third-party.txt"
# Apps visible on the launcher (what the stock home shows as "apps").
tvq cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER \
  | grep '/' | sort > "$out/launcher-visible-activities.txt" || true
# Home (launcher) candidates and the current default home.
tvq cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME \
  | grep '/' | sort > "$out/home-activities.txt" || true
tvq cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME \
  | grep '/' | tail -1 > "$out/home-default.txt" || true
# Animation scales and a few globals we touch.
{
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    printf '%s=%s\n' "$k" "$(tvq settings get global "$k")"
  done
} > "$out/settings-animation.txt"
tvq dumpsys tv_input        > "$out/tv_inputs.txt"
tvq cmd netpolicy list restrict-background-blacklist > "$out/netpolicy-restrict-background.txt" 2>/dev/null || true
tvq dumpsys package -f      > "$out/dumpsys-package.txt" 2>/dev/null || true

# Keep a pointer to the most recent backup for the other steps / restore.
mkdir -p "$STATE_DIR"
printf '%s\n' "$out" > "$STATE_DIR/last_backup"

echo
green "Backup complete."
printf '  %-28s %s\n' "device + Android version:" "$out/device.txt"
printf '  %-28s %s (%s packages)\n' "full package list:" "$out/packages-all.txt" "$(wc -l < "$out/packages-all.txt")"
printf '  %-28s %s\n' "currently disabled:" "$out/packages-disabled.txt"
printf '  %-28s %s\n' "stock home activity:" "$(cat "$out/home-default.txt")"
printf '  %-28s %s\n' "HDMI / TV inputs:" "$out/tv_inputs.txt"
echo
yellow "Keep the backups/ folder. restore.sh uses it to put the TV back exactly."
