<#
viziotv.ps1 - talk to a Vizio OS / onn TV over its local control API (port 7345).
Works in Windows PowerShell 5.1 and PowerShell 7. No modules needed.

  .\viziotv.ps1 pair                      # one time: TV shows a PIN, type it here
  .\viziotv.ps1 info                      # model, power, current input, current app
  .\viziotv.ps1 dump                      # BACKUP: every setting menu -> backups\<time>.json  (run first)
  .\viziotv.ps1 settings picture          # list a settings menu (picture, audio, system, devices, ...)
  .\viziotv.ps1 settings                  # list top-level menus
  .\viziotv.ps1 options picture/picture_mode     # allowed values for one setting
  .\viziotv.ps1 set picture/picture_mode "Calibrated Dark"
  .\viziotv.ps1 apply profiles\example.json      # many settings at once, with a confirmation
  .\viziotv.ps1 inputs                    # list inputs;   .\viziotv.ps1 input HDMI-1
  .\viziotv.ps1 power on|off|toggle
  .\viziotv.ps1 key HOME|BACK|OK|UP|DOWN|LEFT|RIGHT|MENU|EXIT|VOL_UP|VOL_DOWN|MUTE_TOGGLE|PLAY|PAUSE|INPUT_NEXT
  .\viziotv.ps1 app                       # current app

Set the TV address once:  $env:VIZIO_IP = "192.168.1.158"   (or pass -Ip)
Every "set"/"apply" asks for a typed yes unless -Yes is given.
#>
[CmdletBinding()]
param(
  [Parameter(Position=0)] [string]$Command = "help",
  [Parameter(Position=1)] [string]$Arg1,
  [Parameter(Position=2)] [string]$Arg2,
  [string]$Ip = $env:VIZIO_IP,
  [int]$Port = 7345,
  [switch]$Yes
)
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $PSCommandPath
$StateDir = Join-Path $Here "state"; $BackupDir = Join-Path $Here "backups"
New-Item -ItemType Directory -Force -Path $StateDir, $BackupDir | Out-Null
$TokenFile = Join-Path $StateDir "token.json"

# The TV uses a self-signed certificate. On Windows PowerShell 5.1 a scriptblock
# validation callback only works for the first request in a session, so install a
# compiled callback instead.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::Expect100Continue = $false
if ($PSVersionTable.PSVersion.Major -lt 6) {
  if (-not ("VizioTrustAll" -as [type])) {
    Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
using System.Net.Security;
public static class VizioTrustAll {
  public static void Enable() {
    ServicePointManager.ServerCertificateValidationCallback = new RemoteCertificateValidationCallback(
      delegate(object s, X509Certificate c, X509Chain ch, SslPolicyErrors e) { return true; });
  }
}
"@
  }
  [VizioTrustAll]::Enable()
  $script:SkipCert = @{ DisableKeepAlive = $true }
} else { $script:SkipCert = @{ SkipCertificateCheck = $true; DisableKeepAlive = $true } }

if (-not $Ip -and (Test-Path $TokenFile)) { $Ip = (Get-Content $TokenFile | ConvertFrom-Json).ip }
if (-not $Ip) { throw "No TV address. Set `$env:VIZIO_IP = '192.168.1.158' or pass -Ip." }
$Base = "https://$Ip`:$Port"

function Get-Token {
  if (-not (Test-Path $TokenFile)) { throw "Not paired yet. Run: .\viziotv.ps1 pair" }
  (Get-Content $TokenFile | ConvertFrom-Json).token
}
function Invoke-Tv {
  param([string]$Method, [string]$Path, $Body = $null, [switch]$NoAuth)
  $headers = @{}
  if (-not $NoAuth) { $headers["AUTH"] = Get-Token }
  $p = @{ Method = $Method; Uri = "$Base/$Path"; Headers = $headers; ContentType = "application/json"; TimeoutSec = 10 } + $script:SkipCert
  if ($null -ne $Body) { $p.Body = ($Body | ConvertTo-Json -Depth 8 -Compress) }
  $r = Invoke-RestMethod @p
  if ($r.STATUS -and $r.STATUS.RESULT -ne "SUCCESS") { throw "TV said: $($r.STATUS.RESULT) - $($r.STATUS.DETAIL) ($Path)" }
  $r
}
function Confirm-Change([string]$what) {
  if ($Yes) { return $true }
  $a = Read-Host "$what  Type yes to apply"
  if ($a -ne "yes") { Write-Host "Skipped."; return $false }
  $true
}
function Get-Menu([string]$path) { (Invoke-Tv GET "menu_native/dynamic/tv_settings/$path").ITEMS }
function Show-Menu([string]$path) {
  $items = Get-Menu $path
  "{0,-28} {1,-32} {2,-14} {3}" -f "CNAME","NAME","TYPE","VALUE"
  foreach ($i in $items) {
    $v = $i.VALUE; if ($v -is [System.Management.Automation.PSCustomObject]) { $v = ($v | ConvertTo-Json -Compress) }
    "{0,-28} {1,-32} {2,-14} {3}" -f $i.CNAME, $i.NAME, ($i.TYPE -replace '^T_|_V1$',''), $v
  }
}
function Get-Options([string]$full) {
  $r = Invoke-Tv GET "menu_native/static/tv_settings/$full"
  $it = $r.ITEMS | Select-Object -First 1
  if ($it.ELEMENTS) { $it.ELEMENTS } elseif ($null -ne $it.MINIMUM) { "range $($it.MINIMUM)..$($it.MAXIMUM)" } else { $it }
}
function Set-Setting([string]$full, $value, [switch]$Quiet) {
  $parent = Split-Path $full -Parent; $cname = Split-Path $full -Leaf
  $parent = $parent -replace '\\','/'
  $item = Get-Menu $parent | Where-Object { $_.CNAME -eq $cname } | Select-Object -First 1
  if (-not $item) { throw "No setting '$cname' under '$parent'. Run: .\viziotv.ps1 settings $parent" }
  if ($item.TYPE -eq "T_VALUE_V1" -and $value -match '^-?\d+$') { $value = [int]$value }
  if (-not $Quiet) {
    if (-not (Confirm-Change "Set $full : '$($item.VALUE)' -> '$value'")) { return }
  }
  Invoke-Tv PUT "menu_native/dynamic/tv_settings/$full" @{ REQUEST = "MODIFY"; VALUE = $value; HASHVAL = $item.HASHVAL } | Out-Null
  $after = (Get-Menu $parent | Where-Object { $_.CNAME -eq $cname }).VALUE
  Write-Host ("  {0}: {1} -> {2}" -f $full, $item.VALUE, $after)
}
function Dump-Menu([string]$path, [int]$depth, $acc) {
  if ($depth -gt 6) { return }
  try { $items = Get-Menu $path } catch { return }
  foreach ($i in $items) {
    if ($i.TYPE -eq "T_MENU_V1") {
      $sub = if ($path) { "$path/$($i.CNAME)" } else { $i.CNAME }
      if ($sub -notmatch '^(network|cast|channels|system/reset|system/system_information|timers/.*clock)') { Dump-Menu $sub ($depth+1) $acc }
    } elseif ($i.CNAME) {
      $full = if ($path) { "$path/$($i.CNAME)" } else { $i.CNAME }
      $acc[$full] = @{ name = $i.NAME; type = $i.TYPE; value = $i.VALUE }
    }
  }
}
$Keys = @{ SEEK_FWD=@(2,0); SEEK_BACK=@(2,1); PAUSE=@(2,2); PLAY=@(2,3); DOWN=@(3,0); LEFT=@(3,1); OK=@(3,2); UP=@(3,8); RIGHT=@(3,7);
  BACK=@(4,0); SMARTCAST=@(4,3); CC_TOGGLE=@(4,4); INFO=@(4,6); MENU=@(4,8); HOME=@(4,15); VOL_DOWN=@(5,0); VOL_UP=@(5,1);
  MUTE_OFF=@(5,2); MUTE_ON=@(5,3); MUTE_TOGGLE=@(5,4); PIC_MODE=@(6,0); PIC_SIZE=@(6,2); INPUT_NEXT=@(7,1); CH_DOWN=@(8,0); CH_UP=@(8,1);
  CH_PREV=@(8,2); EXIT=@(9,0); POW_OFF=@(11,0); POW_ON=@(11,1); POW_TOGGLE=@(11,2) }
function Send-Key([string]$name) {
  $k = $Keys[$name.ToUpper()]; if (-not $k) { throw "Unknown key '$name'. Keys: $($Keys.Keys -join ', ')" }
  Invoke-Tv PUT "key_command/" @{ KEYLIST = @(@{ CODESET = $k[0]; CODE = $k[1]; ACTION = "KEYPRESS" }) } | Out-Null
  Write-Host "  sent $($name.ToUpper())"
}

switch ($Command.ToLower()) {
  "help" { Get-Content $PSCommandPath | Select-Object -Skip 1 | Select-Object -First 22 }
  "pair" {
    $devId = "onn-toolkit-" + [guid]::NewGuid().ToString().Substring(0,8)
    $r = Invoke-Tv PUT "pairing/start" @{ DEVICE_NAME = "Desktop toolkit"; DEVICE_ID = $devId } -NoAuth
    $tok = $r.ITEM.PAIRING_REQ_TOKEN
    Write-Host "The TV is now showing a PIN."
    $pin = Read-Host "Type the PIN from the TV"
    $r2 = Invoke-Tv PUT "pairing/pair" @{ DEVICE_ID = $devId; CHALLENGE_TYPE = 1; RESPONSE_VALUE = "$pin"; PAIRING_REQ_TOKEN = $tok } -NoAuth
    @{ ip = $Ip; token = $r2.ITEM.AUTH_TOKEN; device_id = $devId; paired = (Get-Date).ToString("s") } | ConvertTo-Json | Set-Content $TokenFile
    Write-Host "Paired. Token saved to $TokenFile"
  }
  "info" {
    $d = (Invoke-Tv GET "state/device/deviceinfo").ITEMS[0].VALUE
    "model:    $($d.MODEL_NAME)   version: $($d.VERSION)   serial: $($d.SERIAL_NUMBER)"
    "power:    " + $(if ((Invoke-Tv GET "state/device/power_mode").ITEMS[0].VALUE -eq 1) { "on" } else { "off/standby" })
    "input:    " + (Invoke-Tv GET "menu_native/dynamic/tv_settings/devices/current_input").ITEMS[0].VALUE
    try { $a = (Invoke-Tv GET "app/current").ITEM.VALUE; "app:      NAME_SPACE=$($a.NAME_SPACE) APP_ID=$($a.APP_ID)" } catch {}
  }
  "dump" {
    $acc = @{}
    Write-Host "Reading every settings menu (takes ~30s)..."
    Dump-Menu "" 0 $acc
    $acc["devices/current_input"] = @{ value = (Invoke-Tv GET "menu_native/dynamic/tv_settings/devices/current_input").ITEMS[0].VALUE }
    $f = Join-Path $BackupDir ("settings-" + (Get-Date).ToString("yyyyMMdd-HHmmss") + ".json")
    $acc | ConvertTo-Json -Depth 6 | Set-Content $f
    Write-Host "Saved $($acc.Count) settings to $f"
  }
  "settings" { Show-Menu ($Arg1 -replace '^/','') }
  "options"  { Get-Options $Arg1 }
  "set"      { Set-Setting $Arg1 $Arg2 }
  "apply" {
    $plan = Get-Content $Arg1 | ConvertFrom-Json
    Write-Host "Plan from $Arg1 :"
    $plan.PSObject.Properties | ForEach-Object { "  {0,-40} -> {1}" -f $_.Name, $_.Value }
    if (-not (Confirm-Change "Apply all $($plan.PSObject.Properties.Count) settings?")) { return }
    foreach ($p in $plan.PSObject.Properties) { try { Set-Setting $p.Name $p.Value -Quiet } catch { Write-Warning "$($p.Name): $_" } }
  }
  "inputs" {
    (Invoke-Tv GET "menu_native/dynamic/tv_settings/devices/name_input").ITEMS | ForEach-Object { "{0,-10} {1}" -f $_.CNAME, $_.VALUE.NAME }
    "current:   " + (Invoke-Tv GET "menu_native/dynamic/tv_settings/devices/current_input").ITEMS[0].VALUE
  }
  "input" {
    $cur = (Invoke-Tv GET "menu_native/dynamic/tv_settings/devices/current_input").ITEMS[0]
    Invoke-Tv PUT "menu_native/dynamic/tv_settings/devices/current_input" @{ REQUEST = "MODIFY"; VALUE = $Arg1; HASHVAL = $cur.HASHVAL } | Out-Null
    "input: $($cur.VALUE) -> $Arg1"
  }
  "power" { switch ($Arg1) { "on" { Send-Key POW_ON } "off" { Send-Key POW_OFF } default { Send-Key POW_TOGGLE } } }
  "key"   { Send-Key $Arg1 }
  "app"   { (Invoke-Tv GET "app/current").ITEM.VALUE }
  default { throw "Unknown command '$Command'. Run .\viziotv.ps1 help" }
}
