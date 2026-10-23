<#
schedule.ps1 - install or remove a Windows scheduled task that runs
auto-profile.ps1 every 30 minutes while you are logged in.

  .\schedule.ps1 -Install
  .\schedule.ps1 -Uninstall
  .\schedule.ps1 -Status
#>
param([switch]$Install, [switch]$Uninstall, [switch]$Status)
$Name = "onn TV day-night picture"
$Here = Split-Path -Parent $PSCommandPath
$script = Join-Path $Here "auto-profile.ps1"

if ($Install) {
  $action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
  $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 3650)
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
  Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
  Write-Host "Installed task '$Name': runs auto-profile.ps1 every 30 minutes. Log: state\auto-profile.log"
} elseif ($Uninstall) {
  Unregister-ScheduledTask -TaskName $Name -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "Removed task '$Name'."
} else {
  Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue | Select-Object TaskName, State | Format-Table
  if (Test-Path (Join-Path $Here "state\auto-profile.log")) { Get-Content (Join-Path $Here "state\auto-profile.log") -Tail 10 }
}
