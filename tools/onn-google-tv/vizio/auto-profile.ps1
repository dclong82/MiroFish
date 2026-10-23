<#
auto-profile.ps1 - pick day or night picture profile by the clock and apply it,
but only when the TV is on and showing the Stream Box (HDMI 1) input, so the
settings never land on a different input. Safe to run as often as you like:
it does nothing when the right profile is already active.

  .\auto-profile.ps1              # decide and apply (no prompts)
  .\auto-profile.ps1 -WhatIf      # just say what it would do
Edit the two hours below to taste.
#>
param([switch]$WhatIf)
$DayStartHour   = 7     # day profile from 07:00
$NightStartHour = 20    # night profile from 20:00
$InputName      = "Stream Box"

$Here = Split-Path -Parent $PSCommandPath
$tool = Join-Path $Here "viziotv.ps1"
$log  = Join-Path $Here "state\auto-profile.log"
function Log($m) { $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm"), $m; Add-Content $log $line; Write-Host $line }

$h = (Get-Date).Hour
$want = if ($h -ge $DayStartHour -and $h -lt $NightStartHour) { "day" } else { "night" }
$profile = Join-Path $Here "profiles\$want.json"
$wantMode = (Get-Content $profile -Raw | ConvertFrom-Json)."picture/picture_mode"

try {
  $power = & $tool settings "system/power" 2>$null | Out-Null
  $info  = & $tool settings "hdmi_and_gaming/hdmi_device_info" 2>$null
} catch { Log "TV not reachable; skipping"; exit 0 }
$cur = ($info | Select-String '^current_input\s+\S.*?\s{2,}STRING\s+(.*)$' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() })
if (-not $cur) { $cur = ($info | Select-String 'current_input' | ForEach-Object { ($_ -split '\s{2,}')[-1].Trim() }) }
if ($cur -ne $InputName) { Log "TV is on '$cur', not '$InputName'; skipping"; exit 0 }

$pic = & $tool settings picture 2>$null
$mode = ($pic | Select-String '^picture_mode' | ForEach-Object { ($_ -split '\s{2,}')[-1].Trim() }) -replace '\*$',''
if ($mode -eq $wantMode) { Log "already $want ($mode)"; exit 0 }

if ($WhatIf) { Log "would apply $want profile (current mode: $mode)"; exit 0 }
Log "applying $want profile (current mode: $mode)"
& $tool apply $profile -Yes | Out-Null
Log "done"
