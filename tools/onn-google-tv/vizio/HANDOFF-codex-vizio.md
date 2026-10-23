# Handoff: tune my onn TV (Vizio OS) over its local API — run on my desktop

The TV is an onn set running Vizio's OS at **192.168.1.158**, API on port 7345 (confirmed open).
It is NOT Android: no adb, no app removal, no launcher. This API only reaches what the TV's own
menus reach. The goal is: back up every setting, turn off tracking, set a clean fast picture,
boot straight into the Xumo box's HDMI input, and leave a way to put it all back.

## Ground rules
1. Use `tools/onn-google-tv/vizio/viziotv.ps1`. Do not rewrite it. Read it first.
2. `dump` (backup) before any change. Show me the backup file path.
3. Every `set` / `apply` prompts for a typed `yes`. Never pass `-Yes`. Show me the plan first.
4. Change only picture, audio, system/power, privacy, and input settings. Do not touch
   network, reset, channels/tuner, or parental controls.
5. If a setting name (cname) from the example profile does not exist on this TV, drop it and
   tell me; do not guess at substitutes.

## Setup (Windows PowerShell, repo already cloned)
```powershell
cd MiroFish\tools\onn-google-tv\vizio
Set-ExecutionPolicy -Scope Process Bypass
$env:VIZIO_IP = "192.168.1.158"
.\viziotv.ps1 pair          # TV shows a PIN; type it when asked
.\viziotv.ps1 info          # model, firmware, power, input
```

## Steps — stop after each and show me the output
1. **Backup**: `.\viziotv.ps1 dump`. Report the file path and the number of settings saved.
2. **Discover**: run and show me
   `.\viziotv.ps1 settings`, `.\viziotv.ps1 settings picture`, `.\viziotv.ps1 settings picture/more_picture`
   (or whatever the advanced picture submenu is called on this set), `.\viziotv.ps1 settings audio`,
   `.\viziotv.ps1 settings system`, `.\viziotv.ps1 settings system/power` (or similar),
   any privacy menu you find under system, and `.\viziotv.ps1 inputs`.
3. **Propose**: write `profiles\onn.json` using only cnames that exist, targeting:
   - picture: Calibrated Dark (or Calibrated), color temperature Warm, sharpness 0,
     reduce judder 0, reduce blur 0, clear action Off, noise reduction Off, film mode Auto,
     local dimming High, ambient/auto brightness Off.
   - audio: volume leveling as I decide, surround Off on TV speakers.
   - system/power: quick start On; "input at power on" = the Xumo's HDMI input (from `inputs`).
   - privacy: viewing data Off, interest-based ads Off, if exposed here.
   Show me the proposed file and the `options` output for any value you are not sure of.
   Note: picture settings are per input. Switch to the Xumo input first
   (`.\viziotv.ps1 input HDMI-1` or whichever) so they land on the right input.
4. **Apply** after my yes: `.\viziotv.ps1 apply profiles\onn.json`. Show before -> after lines.
5. **Verify**: `.\viziotv.ps1 settings picture` and `info` again. Then `.\viziotv.ps1 dump`
   a second time so I have an "after" snapshot.

## Restore
To undo one setting: `.\viziotv.ps1 set <cname> <old value>` using the value from the first
backup JSON. To undo everything: build `profiles\restore.json` from the first backup
(same "cname": value shape, only the keys we changed) and `apply` it.

## Final report
- Model and firmware version. Backup file paths (before and after).
- Exact settings changed, old -> new.
- Anything from the target list that does not exist on this TV.
- Which input the TV now powers on to.
