#!/usr/bin/env bash
# Step 1: show the disable plan, get approval, then disable with
# "pm disable-user --user 0" only. Nothing is uninstalled.
#
#   ./10-debloat.sh            # interactive, shows plan first
#   ./10-debloat.sh --plan     # only print the plan, change nothing
source "$(dirname "$0")/lib/common.sh"

PLAN_ONLY=0; [[ "${1:-}" == "--plan" ]] && PLAN_ONLY=1

bold "== Step 1: debloat (reversible disable) =="
tv_connect
tv_identity
assert_onn
[[ -f "$STATE_DIR/last_backup" ]] || die "No backup found. Run 00-backup.sh first."

declare -a PLAN_PKGS PLAN_WHY ASK_PKGS ASK_WHY DISC_PKGS
declare -A SEEN

# 1. Items from packages.conf that are present and enabled.
while IFS=$'\t' read -r cat pkg why; do
  SEEN["$pkg"]=1
  [[ "$cat" == launcher ]] && continue          # handled by 20-launcher.sh
  pkg_installed "$pkg" || continue
  pkg_enabled   "$pkg" || continue
  if is_protected "$pkg"; then yellow "  refusing (protected): $pkg"; continue; fi
  case "$cat" in
    ask) ASK_PKGS+=("$pkg"); ASK_WHY+=("$why") ;;
    *)   PLAN_PKGS+=("$pkg"); PLAN_WHY+=("[$cat] $why") ;;
  esac
done < <(read_conf)

# 2. Discover launcher-visible apps (what shows on the home screen) that are
#    not in the keep list and not already planned. These are the Walmart/onn
#    preloads and bundled streaming apps. Each is asked individually.
while read -r line; do
  pkg="${line%%/*}"
  [[ -n "$pkg" && -z "${SEEN[$pkg]:-}" ]] || continue
  SEEN["$pkg"]=1
  is_protected "$pkg" && continue
  pkg_enabled "$pkg" || continue
  DISC_PKGS+=("$pkg")
done < <(tvq cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER | grep '/' | sort -u)

echo
bold "A. Will disable (ads / tracking / bundled) -- ${#PLAN_PKGS[@]} present on this TV:"
for i in "${!PLAN_PKGS[@]}"; do printf '  %-45s %s\n' "${PLAN_PKGS[$i]}" "${PLAN_WHY[$i]}"; done
[[ ${#PLAN_PKGS[@]} -gt 0 ]] || echo "  (none present / all already disabled)"

echo
bold "B. Ask-me-first (trade-offs) -- ${#ASK_PKGS[@]} present:"
for i in "${!ASK_PKGS[@]}"; do printf '  %-45s %s\n' "${ASK_PKGS[$i]}" "${ASK_WHY[$i]}"; done
[[ ${#ASK_PKGS[@]} -gt 0 ]] || echo "  (none present)"

echo
bold "C. Other apps visible on the home screen, not in your keep list -- ${#DISC_PKGS[@]} found:"
for p in "${DISC_PKGS[@]}"; do
  label="$(tvq dumpsys package "$p" | sed -n 's/.*versionName=\([^ ]*\).*/v\1/p' | head -1)"
  printf '  %-45s %s\n' "$p" "$label"
done
[[ ${#DISC_PKGS[@]} -gt 0 ]] || echo "  (none)"

echo
bold "Kept untouched (never disabled by any step):"
printf '  %s\n' "${KEEP_LIST[@]}" | sed 's/ *#.*//'
echo "  + everything matching the protected pattern (boot, WiFi, Bluetooth, remote, HDMI/inputs/CEC, GMS, settings, IMEs)."

{
  echo "# plan generated $(date)"
  for i in "${!PLAN_PKGS[@]}"; do echo "A ${PLAN_PKGS[$i]} ${PLAN_WHY[$i]}"; done
  for i in "${!ASK_PKGS[@]}";  do echo "B ${ASK_PKGS[$i]} ${ASK_WHY[$i]}"; done
  for p in "${DISC_PKGS[@]}";  do echo "C $p"; done
} > "$STATE_DIR/debloat-plan.txt"
echo; echo "Plan saved to $STATE_DIR/debloat-plan.txt"

[[ $PLAN_ONLY -eq 0 ]] || exit 0

declare -a TODO
if [[ ${#PLAN_PKGS[@]} -gt 0 ]]; then
  confirm "Disable all of group A (${#PLAN_PKGS[@]} packages)?" && TODO+=("${PLAN_PKGS[@]}")
fi
if [[ ${#ASK_PKGS[@]} -gt 0 ]]; then
  echo; bold "Group B, one at a time (default is keep):"
  for i in "${!ASK_PKGS[@]}"; do
    ask_yn "  disable ${ASK_PKGS[$i]} ? (${ASK_WHY[$i]})" && TODO+=("${ASK_PKGS[$i]}")
  done
fi
if [[ ${#DISC_PKGS[@]} -gt 0 ]]; then
  echo; bold "Group C, one at a time (default is keep):"
  for p in "${DISC_PKGS[@]}"; do ask_yn "  disable $p ?" && TODO+=("$p"); done
fi

[[ ${#TODO[@]} -gt 0 ]] || { yellow "Nothing selected. No changes made."; exit 0; }

echo; bold "Final list (${#TODO[@]}):"; printf '  %s\n' "${TODO[@]}"
confirm "Apply with 'pm disable-user --user 0' and block background data for these?" || exit 0

ok=0; fail=0
for p in "${TODO[@]}"; do
  if is_protected "$p"; then red "  SKIP protected: $p"; continue; fi
  if tv pm disable-user --user 0 "$p" | grep -q 'new state: disabled'; then
    record disabled.txt "$p"
    # Block background data + background execution for the disabled app
    # (belt and braces; a disabled app cannot run, but this survives a
    # re-enable by a system update until restore.sh clears it).
    uid="$(pkg_uid "$p")"
    if [[ -n "$uid" ]]; then
      tvq cmd netpolicy add restrict-background-blacklist "$uid" >/dev/null
      record netpolicy-uids.txt "$p $uid"
    fi
    tvq cmd appops set "$p" RUN_IN_BACKGROUND ignore >/dev/null
    tvq cmd appops set "$p" RUN_ANY_IN_BACKGROUND ignore >/dev/null
    green "  disabled: $p"; ok=$((ok+1))
  else
    red "  FAILED:   $p"; fail=$((fail+1))
  fi
done
echo; green "Disabled $ok package(s), $fail failure(s). Recorded in $STATE_DIR/disabled.txt"
