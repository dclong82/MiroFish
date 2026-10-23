#!/usr/bin/env bash
# One-command restore: re-enable every package this toolkit disabled, lift the
# background restrictions, put animation scales back, set the stock Google TV
# home as default, and reboot.
#
#   ./restore.sh                        # restore from state/ (what we changed)
#   ./restore.sh --all                  # also re-enable EVERY disabled package on the TV
#   ./restore.sh --remove-launcher      # additionally uninstall FLauncher (the only thing we installed)
#   TV_ADDR=192.168.1.50 ./restore.sh   # if state/tv_addr is missing
source "$(dirname "$0")/lib/common.sh"

ALL=0; RM_LAUNCHER=0
for a in "$@"; do case "$a" in --all) ALL=1;; --remove-launcher) RM_LAUNCHER=1;; esac; done

bold "== Restore to stock =="
tv_connect
tv_identity

bk="$( [[ -f "$STATE_DIR/last_backup" ]] && cat "$STATE_DIR/last_backup" || latest_backup )"
[[ -n "$bk" && -d "$bk" ]] && echo "Using backup: $bk" || yellow "No backup folder found; falling back to Android defaults."

declare -a PKGS
[[ -s "$STATE_DIR/disabled.txt" ]] && mapfile -t PKGS < "$STATE_DIR/disabled.txt"
if [[ $ALL -eq 1 ]]; then
  while read -r l; do PKGS+=("${l#package:}"); done < <(tvq pm list packages --user 0 -d)
fi
# Always include the stock home pair, whatever the state file says.
PKGS+=(com.google.android.apps.tv.launcherx com.google.android.tungsten.setupwraith)
mapfile -t PKGS < <(printf '%s\n' "${PKGS[@]}" | grep -v '^$' | sort -u)

echo; bold "Will re-enable (${#PKGS[@]}):"; printf '  %s\n' "${PKGS[@]}"
echo "Will reset animation scales, clear background restrictions, set stock home, reboot."
[[ $RM_LAUNCHER -eq 1 ]] && yellow "Will UNINSTALL me.efesser.flauncher (--remove-launcher)."
confirm "Restore now?" || exit 0

for p in "${PKGS[@]}"; do
  pkg_installed "$p" || continue
  if tv pm enable --user 0 "$p" | grep -q 'new state: enabled'; then green "  enabled: $p"; else red "  failed:  $p"; fi
  tvq cmd appops reset "$p" >/dev/null
  uid="$(pkg_uid "$p")"
  [[ -n "$uid" ]] && tvq cmd netpolicy remove restrict-background-blacklist "$uid" >/dev/null
done
# UIDs recorded at disable time (in case a uid changed).
if [[ -s "$STATE_DIR/netpolicy-uids.txt" ]]; then
  while read -r _ uid; do [[ -n "$uid" ]] && tvq cmd netpolicy remove restrict-background-blacklist "$uid" >/dev/null; done < "$STATE_DIR/netpolicy-uids.txt"
fi

# Animation scales: backed-up values, else 1.0.
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
  v="$( [[ -f "$bk/settings-animation.txt" ]] && sed -n "s/^$k=//p" "$bk/settings-animation.txt" || true)"
  [[ -n "$v" && "$v" != "null" ]] || v=1.0
  tv settings put global "$k" "$v"; echo "  $k=$v"
done

# Stock home back.
stock_home="$( [[ -f "$bk/home-default.txt" ]] && cat "$bk/home-default.txt" || true)"
[[ -n "$stock_home" ]] || stock_home="$(tvq cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME | grep '^com.google.android.apps.tv.launcherx/' | head -1)"
if [[ -n "$stock_home" ]]; then
  tv cmd package set-home-activity "$stock_home" || true
  green "  default home: $stock_home"
else
  yellow "  could not determine stock home activity; the TV will pick it after reboot."
fi

if [[ $RM_LAUNCHER -eq 1 ]] && pkg_installed me.efesser.flauncher; then
  "$ADB_BIN" -s "$TV_ADDR" uninstall me.efesser.flauncher && green "  uninstalled me.efesser.flauncher"
fi

mkdir -p "$STATE_DIR/restored-$(date +%Y%m%d-%H%M%S)"
mv "$STATE_DIR"/{disabled,netpolicy-uids,settings,installed,debloat-plan}.txt "$STATE_DIR"/restored-*/ 2>/dev/null || true

echo; green "Restore applied. Rebooting the TV."
"$ADB_BIN" -s "$TV_ADDR" reboot || true
echo "After it comes back: Settings > System > About > Developer options > USB debugging -> Off."
