#!/usr/bin/env bash
# Step 3: animation scales to 0.5 and background restrictions. Reversible.
#   ./30-speed.sh
#   ANIM_SCALE=0 ./30-speed.sh     # animations fully off
source "$(dirname "$0")/lib/common.sh"
ANIM_SCALE="${ANIM_SCALE:-0.5}"

bold "== Step 3: speed settings =="
tv_connect
tv_identity
assert_onn
[[ -f "$STATE_DIR/last_backup" ]] || die "No backup found. Run 00-backup.sh first."

echo "Current animation scales:"
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
  printf '  %-28s %s\n' "$k" "$(tvq settings get global "$k")"
done
echo
echo "Planned:"
echo "  window_animation_scale     -> $ANIM_SCALE"
echo "  transition_animation_scale -> $ANIM_SCALE"
echo "  animator_duration_scale    -> $ANIM_SCALE"
echo "  background data + background run blocked for every package in state/disabled.txt"
confirm "Apply?" || exit 0

for k in window_animation_scale transition_animation_scale animator_duration_scale; do
  tv settings put global "$k" "$ANIM_SCALE"
done
record settings.txt "window_animation_scale transition_animation_scale animator_duration_scale"

if [[ -f "$STATE_DIR/disabled.txt" ]]; then
  while read -r p; do
    [[ -n "$p" ]] || continue
    uid="$(pkg_uid "$p")"
    if [[ -n "$uid" ]]; then
      tvq cmd netpolicy add restrict-background-blacklist "$uid" >/dev/null
      record netpolicy-uids.txt "$p $uid"
    fi
    tvq cmd appops set "$p" RUN_IN_BACKGROUND ignore >/dev/null
    tvq cmd appops set "$p" RUN_ANY_IN_BACKGROUND ignore >/dev/null
  done < "$STATE_DIR/disabled.txt"
fi

echo
green "Applied. New animation scales:"
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
  printf '  %-28s %s\n' "$k" "$(tvq settings get global "$k")"
done
echo
yellow "Two toggles only exist in the TV's UI (no adb key). Do them with the remote:"
echo "  Settings > Privacy > Usage & diagnostics      -> Off"
echo "  Settings > Privacy > Ads                      -> Delete advertising ID / opt out"
