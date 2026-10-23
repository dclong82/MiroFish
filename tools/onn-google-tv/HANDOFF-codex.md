# Handoff: clean up my Walmart onn Google TV over adb (run on my laptop)

You are running on my laptop, which is on the same home WiFi as the TV.
The TV's IP is 192.168.X.X (I will fill this in). USB debugging is on.

## Ground rules (non-negotiable)

1. Use the existing toolkit in `tools/onn-google-tv/` of this repo. Do not rewrite it.
   Read `README.md`, `packages.conf`, and `lib/common.sh` first.
2. Never uninstall anything. The only disable mechanism is `pm disable-user --user 0`.
   The only install is FLauncher from F-Droid (step 2).
3. Never touch packages needed for boot, WiFi, Bluetooth, the remote, HDMI / TV inputs / CEC,
   Google Play Services, the Play Store, or Settings. `lib/common.sh` has a protected
   pattern that refuses these; do not edit or bypass it. If a package is not clearly safe,
   ask me instead of guessing.
4. Keep Netflix, YouTube, Prime Video, Disney+, Max, and Google Play Store.
5. Every step that changes the TV must stop and show me the plan first. The scripts already
   prompt for a typed `yes`; never set `ASSUME_YES=1`, never pipe `yes` into a script.
6. Do not run raw `adb shell pm disable` / `pm uninstall` commands outside the scripts.

## Setup

```bash
git clone -b claude/onn-google-tv-optimize-1bh0o4 https://github.com/dclong82/MiroFish
cd MiroFish/tools/onn-google-tv
adb version            # needs Android platform-tools; install if missing
export TV_ADDR=192.168.X.X
```

If adb is missing: macOS `brew install android-platform-tools`; Linux `sudo apt install adb`;
Windows use Git Bash or WSL and the platform-tools zip from developer.android.com.

## Steps, in order. Stop after each and show me the output before the next.

**Step 0, backup (changes nothing)**
```bash
./00-backup.sh
```
Show me the device block (brand, model, Android version) and the path of the backup folder.
If the brand check fails, stop and tell me; do not use `ALLOW_ANY_DEVICE=1` without asking.

**Step 1, debloat plan, then apply**
```bash
./10-debloat.sh --plan
```
Show me all three groups exactly as printed:
- A: auto-disable (ads, tracking, bundled Google apps)
- B: ask-me-first (Assistant, Chromecast, screensaver, TalkBack, TTS). Default is keep.
- C: other apps on the home screen found on this TV (Walmart/onn preloads).
Wait for my answer on B and C. Then run `./10-debloat.sh` and answer the prompts exactly as
I told you. Report what was disabled and anything that failed.

**Step 2, launcher**
```bash
./20-launcher.sh
```
It downloads FLauncher from F-Droid, installs it, and sets it as home. If the F-Droid download
fails, download the APK from https://f-droid.org/packages/me.efesser.flauncher and run
`APK=/path/to/file.apk ./20-launcher.sh`. Before answering the second prompt (disable the stock
Google TV home), confirm with me that FLauncher is showing on the TV. Show me the HDMI inputs
list it prints.

**Step 3, speed**
```bash
./30-speed.sh
```
Animation scales to 0.5 and background restrictions for the disabled apps. Show me the
before/after scales. Remind me of the two manual toggles it prints (Privacy > Usage &
diagnostics, Privacy > Ads).

**Step 4, reboot and verify**
```bash
./40-reboot-verify.sh
```
Show me the checks block (home, WiFi, Bluetooth, Play Services, Play Store, animation scales)
and the "what changed" list.

## If anything goes wrong at any point

```bash
./restore.sh
```
re-enables everything the toolkit disabled, resets animations, puts the stock Google TV home
back, and reboots. Run it on my say-so, or immediately if the TV fails to boot or loses WiFi,
Bluetooth, the remote, or inputs.

## Final report I want from you

- Device: brand, model, Android version.
- Backup folder path.
- Exact list of packages disabled, grouped A / B / C.
- Launcher installed and confirmed as default home (yes/no), stock home disabled (yes/no).
- Animation scales before and after.
- Reboot result and the verify checks.
- Reminder: turn USB debugging off (Settings > System > About > Developer options), then
  `adb disconnect $TV_ADDR`.
