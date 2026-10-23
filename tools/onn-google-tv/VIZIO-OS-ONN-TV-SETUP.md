# onn TV (Vizio OS) — best possible setup checklist

This onn set runs Vizio's smart TV software, not Google TV. There is no adb, no
developer options, no sideloading, and no way to disable apps below what the menus
expose. Everything here is done with the remote, and everything is reversible from
the same menu. Menu names vary a little between firmware versions; if a name is not
exact, it is next to the one listed.

Two layers:
- **Layer 1** makes the TV itself as clean and fast as Vizio OS allows (20 minutes).
- **Layer 2** replaces the Vizio home screen entirely with an external streaming box
  and the adb toolkit in this folder. This is the only route to a truly custom,
  ad-free home screen.

---

## Layer 1 — the TV itself

### 1. Privacy: stop tracking and ad personalization (biggest win)
Settings > Privacy & Legal
- [ ] **Viewing Data** → Off. This is ACR (automatic content recognition); it watches
      everything on every input, including HDMI, and reports it.
- [ ] **Interest-Based Ads / Advertising** → Off, then **Reset Advertising ID**.
- [ ] **Usage / diagnostic data** (if listed) → Off.
- [ ] Decline any "personalized recommendations" or "Vizio account" prompts.

### 2. Home screen: trim what you can
On the home screen:
- [ ] Highlight each app tile you do not use, press the ★ / options button (or hold OK)
      → **Remove** or **Hide**. Do this for Watch Free+ tiles, Tubi, Pluto, DirecTV,
      Apple TV (if unused), shopping/Walmart tiles, and any preload you did not ask for.
- [ ] Use **Move** to put Netflix, YouTube, Prime Video, Disney+, Max first.
- [ ] Sponsored rows ("Top Picks", promos) cannot be removed on this OS. The Apps &
      Inputs row is the only one you control. Layer 2 fixes this.
- [ ] Settings > System > **Manage Input List** → hide inputs you do not use and rename
      the ones you do (e.g. "HDMI 1" → "Apple TV", "HDMI 2" → "PS5").

### 3. Power and speed
Settings > System > Power
- [ ] **Power Mode: Quick Start** → On if you want instant wake and HDMI-CEC wake from
      the streaming box/console; Off (Eco) if you want lowest standby power. Quick Start
      is the "fast" choice.
- [ ] **Input at Power On** → set to the input you actually use (your streaming box or
      the Home screen). With Layer 2, set this to the box's HDMI port so you never see
      the Vizio home screen.
- [ ] Settings > System > **Sleep Timer** → Off unless wanted.
- [ ] Settings > System > Time → auto, correct time zone (affects guide/EPG).

### 4. HDMI, gaming, and inputs
Settings > HDMI & Gaming
- [ ] For each HDMI port with a console or PC: **Game Mode / Game Low Latency** → Auto
      (or On), **VRR** → On if the TV supports it, **ALLM** → On.
- [ ] **HDMI Mode / Full UHD Color** → "Auto" or "2.1" on the port used by a 4K HDR
      device or console, otherwise the TV may fall back to limited color/60 Hz.
- [ ] **CEC** → On, with **Device Discovery** / **Power Control** On. This lets the
      streaming box remote turn the TV on/off and control volume, so the Vizio remote
      can go in a drawer.
- [ ] **eARC/ARC** → On on the port a soundbar is connected to (usually HDMI 1 or
      the port labelled eARC).

### 5. Picture: set once per input
Settings > Picture (settings are saved per input; do this on the input you watch most)
- [ ] **Picture Mode** → *Calibrated* for daytime, *Calibrated Dark* for a dark room.
      Avoid *Vivid* (oversaturated, crushes detail).
- [ ] **Backlight** → to taste; **Brightness** 50 / **Contrast** ~45–50 / **Color** 50 /
      **Tint** 0 / **Sharpness** 0–10 (high sharpness adds halos).
- [ ] Advanced Picture → **Color Temperature** → *Warm* (most accurate; looks yellow for
      a day, then everything else looks blue).
- [ ] Advanced Picture → **Reduce Judder** 0, **Reduce Blur** 0, **Clear Action** Off.
      This kills the soap-opera motion smoothing.
- [ ] **Reduce Noise / Reduce Block Noise** → Off (softens the picture).
- [ ] **Active Full Array / Local Dimming** → High (if present).
- [ ] **Film Mode** → Auto. **Gamma** → 2.2 (bright room) or 2.4 (dark room).
- [ ] **Auto Brightness Control / Ambient Light Sensor** → Off for consistent picture.
- [ ] **HDR** → leave Auto; the TV switches when HDR content arrives.
- [ ] Repeat for the game console input, with Game Mode on.

### 6. Audio
Settings > Audio
- [ ] **TV Speakers** → Off if using a soundbar via eARC; **Digital Audio Out** →
      Bitstream (Dolby) for a soundbar, PCM if the bar has trouble.
- [ ] **Volume Leveling** → On for late-night viewing (flattens loud ads); Off for movies.
- [ ] **Surround / Virtual:X** → Off on TV speakers (it hollows out dialogue); try On
      with a soundbar.
- [ ] **Lip Sync** → adjust only if dialogue is off.
- [ ] Bluetooth and Remote → pair headphones here if you want private listening.

### 7. Live TV and Watch Free+
- [ ] If you have no antenna: Settings > Antenna Channels → skip/clear the scan so the
      Live row stops prompting.
- [ ] If you have an antenna: run the scan once, then in the channel list hide the
      shopping and foreign-language channels you never watch.
- [ ] Watch Free+ cannot be uninstalled; hiding its tile and never opening it is the limit.

### 8. Updates and accounts
- [ ] Settings > System > TV Information / Check for Updates → install the current
      firmware once, then leave auto-update on (security fixes; also sometimes adds
      the newer game/HDMI options).
- [ ] Do not sign in to a Vizio account unless you want the phone app; it is not required
      for anything above.

### 9. Network-level ad and tracking blocking (optional, whole house)
If you run a router that supports custom DNS, or a Pi-hole / AdGuard Home / NextDNS:
- [ ] Point the TV (or the whole network) at a DNS filter with a smart-TV blocklist
      (NextDNS and AdGuard Home both have "Smart TV" / Vizio tracker lists).
- [ ] This blocks Vizio and Inscape telemetry endpoints the Privacy menu does not cover,
      and most home-screen ad calls. If an app stops loading, whitelist its domain.

---

## Layer 2 — replace the Vizio home screen with your own (the real "custom" answer)

The Vizio OS home screen cannot be replaced. The fix is to never look at it:

1. **Buy a streaming box** and plug it into HDMI 1:
   - *onn 4K Pro Google TV box* (~$50): runs real Google TV, so the adb toolkit in this
     folder (`00-backup.sh` … `restore.sh`) applies to it exactly: reversible debloat,
     FLauncher as home, 0.5 animation scale, restore script. Cheapest route.
   - *Apple TV 4K* (~$130): fastest, no ads on its home screen out of the box, no
     tinkering needed or possible. Best if you want zero maintenance.
   - *NVIDIA Shield TV Pro* (~$200): Android TV, fastest Android box, same toolkit
     applies, best for Plex/emulation/local media.
2. Settings > System > Power > **Input at Power On** → HDMI 1.
3. Settings > HDMI & Gaming > **CEC** → On so the box's remote powers the TV and
   controls volume. Put the Vizio remote away.
4. On the TV, set Picture for the HDMI 1 input as in step 5.
5. On a Google TV box, run the toolkit from the desktop:
   ```bash
   cd MiroFish/tools/onn-google-tv
   export TV_ADDR=<box IP>      # from the box: Settings > Network & Internet > your WiFi > IP
   ./run-all.sh
   ```
   (`assert_onn` passes on the onn 4K Pro; for a Shield use `ALLOW_ANY_DEVICE=1`.)

Result: the TV turns on straight into a launcher that shows only your apps and your
inputs, no sponsored rows, no watch tracking, and the TV's own tracking is off underneath.

---

## Restore to stock (Layer 1)
Every item above is a menu toggle; flip it back. For a full reset:
Settings > System > **Reset to Factory Settings** (also clears the privacy opt-outs, so
redo step 1 afterwards).
