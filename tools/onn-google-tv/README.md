# onn Google TV clean-up toolkit

Reversible debloat, clean launcher, and speed settings for a Walmart onn Google TV,
driven over network adb from a laptop on the same WiFi.

**Safety rules baked in**

- Nothing is ever uninstalled. Every change is `pm disable-user --user 0` or a `settings put`,
  both reversible with `restore.sh`.
- A protected pattern list in `lib/common.sh` refuses to disable anything to do with boot, WiFi,
  Bluetooth, the remote, HDMI / TV inputs / CEC, Google Play Services, the Play Store, Settings,
  or keyboards, even if a plan lists it.
- Every step prints its plan and waits for a typed `yes` before touching the TV.
- Step 0 writes a full backup (model, Android version, every package, current home, animation
  scales, inputs) before anything else runs.
- Ambiguous packages are in an "ask me" group and default to **keep**.

## Requirements (on the laptop)

- Same WiFi as the TV.
- `adb` from Android platform-tools on the PATH.
- `curl` (only to fetch FLauncher from F-Droid; or pass your own APK).
- bash. macOS and Linux work as-is; on Windows use Git Bash or WSL.
- On the TV: Settings > System > About > tap "Android TV OS build" 7 times, then
  Settings > System > Developer options > USB debugging = On.

## Run it

```bash
cd tools/onn-google-tv
TV_ADDR=192.168.1.50 ./run-all.sh      # replace with your TV's IP
```

`run-all.sh` runs the five steps in order. Each one stops for approval. Or run them one at a time:

| Step | Script | What it does | Changes the TV? |
|---|---|---|---|
| 0 | `00-backup.sh` | Connects, prints brand/model/Android version, saves full package list and current settings to `backups/` | No |
| 1 | `10-debloat.sh` | Shows three groups (auto-disable, ask-me, other home-screen apps), then disables the ones you approve and blocks their background data | After `yes` |
| 2 | `20-launcher.sh` | Downloads FLauncher from F-Droid, installs it, sets it as home, then (after `yes`) disables the stock Google TV home so the Home button opens FLauncher | After `yes` |
| 3 | `30-speed.sh` | Window / transition / animator scale to 0.5, background restrictions for disabled apps | After `yes` |
| 4 | `40-reboot-verify.sh` | Reboots, waits for boot, checks home, WiFi, Bluetooth, Play Services, lists what changed, reminds you to turn USB debugging off | Reboot only |

`./10-debloat.sh --plan` prints the plan for this TV and changes nothing.

## What gets disabled (see `packages.conf` for the full reasoning)

- **Google TV home and recommendations:** `com.google.android.apps.tv.launcherx` (sponsored rows, "For You", autoplay, watch-tracking recommendations), `com.google.android.tungsten.setupwraith` (forces the stock home back), `com.google.android.tvrecommendations`.
- **Usage reporting:** `com.google.android.feedback`, `com.google.android.tv.bugreportsender`, `com.google.android.partnersetup`, `com.google.android.apps.tv.dreamx` (promo screensaver).
- **Bundled Google apps:** Google TV/Play Movies, YouTube Music, YouTube Kids, Play Games, calendar sync.
- **Ask-me group, default keep:** Assistant/voice search (`katniss`), Chromecast built-in (`mediashell`), Backdrop screensaver, TalkBack, text-to-speech.
- **Other apps on the home screen** (Walmart/onn preloads such as Tubi, Pluto, Peacock, Paramount+): discovered live on your TV and asked one by one.

Kept no matter what: Netflix, YouTube, Prime Video, Disney+, Max, Google Play Store, Play Services,
Settings, the classic Android TV launcher (fallback home), and everything in the protected pattern.

Two privacy toggles have no adb switch and are done with the remote:
Settings > Privacy > Usage & diagnostics = Off, and Settings > Privacy > Ads > delete advertising ID.

## Launcher notes

FLauncher is open source and comes from F-Droid (`me.efesser.flauncher`). Projectivy is closed
source and only on the Play Store, so it is not downloaded; if you install it from the Play Store
yourself, `LAUNCHER_PKG=com.spocky.projengmenu ./20-launcher.sh --set-home-only` makes it home.

FLauncher only lists enabled apps, so the debloat step already trims it. Hide anything else with
long-press > Hide. It cannot make per-HDMI-input tiles; keep the system Inputs / Live TV tile, and
the Input button on the onn remote keeps working. Step 2 prints the inputs it found.

## Restore

```bash
./restore.sh                    # re-enable everything this toolkit disabled, reset animations,
                                # stock Google TV home back, reboot
./restore.sh --all              # also re-enable every other disabled package on the TV
./restore.sh --remove-launcher  # additionally uninstall FLauncher (the only thing installed)
```

## Files

- `state/` what was changed (package list, uids, settings). Used by restore. Not committed.
- `backups/<serial>-<time>/` the pre-change snapshot. Keep it. Not committed.
- `downloads/` the FLauncher APK. Not committed.
