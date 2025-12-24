param(
  [string]$OutDir = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'log-pull-output')
)

$ErrorActionPreference = 'Stop'

# Elevate to admin to ensure Security log access; relaunch self if needed.
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'powershell.exe'
  $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -OutDir "{1}"' -f $PSCommandPath, $OutDir)
  $psi.Verb = 'runas'
  try {
    [System.Diagnostics.Process]::Start($psi) | Out-Null
  } catch {
    Write-Host 'Admin privileges are required to read Security logs.'
  }
  exit
}

$logs = @('System','Application','Security')
$windows = @(
  @{ Days = 1; Label = '1d' },
  @{ Days = 7; Label = '7d' }
)

if (-not (Test-Path $OutDir)) {
  New-Item -ItemType Directory -Path $OutDir | Out-Null
}

# Capture last boot time for escalation context.
$bootInfo = $null
try {
  $bootInfo = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
} catch {
  $bootInfo = "Error: $($_.Exception.Message)"
}

# Collect events for a single log and time window, then write detailed and summary files.
function Write-Events {
  param(
    [string]$LogName,
    [int]$Days,
    [string]$Label
  )

  $start = (Get-Date).AddDays(-$Days)
  $outFile = Join-Path $OutDir ("{0}-Errors-{1}.txt" -f $LogName, $Label)
  $sumFile = Join-Path $OutDir ("{0}-Summary-{1}.txt" -f $LogName, $Label)
  $errFile = Join-Path $OutDir ("{0}-Errors-{1}.err" -f $LogName, $Label)

  try {
    $events = Get-WinEvent -FilterHashtable @{
      LogName = $LogName
      Level = 1,2,3
      StartTime = $start
    } -ErrorAction Stop

    if ($events.Count -eq 0) {
      Set-Content -Path $outFile -Value "No Critical/Error/Warning events found in the last $Days day(s)."
    } else {
      $lines = $events | Sort-Object TimeCreated | ForEach-Object {
        $msg = ($_.Message -replace "\s+", " ").Trim()
        "{0:u} | {1} | {2} | {3}" -f $_.TimeCreated, $_.LevelDisplayName, $_.ProviderName, $msg
      }
      Set-Content -Path $outFile -Value $lines
    }

    # Summary: counts by level and top sources
    $levelCounts = $events | Group-Object LevelDisplayName | Sort-Object Count -Descending
    $sourceCounts = $events | Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 10
    $eventIdCounts = $events | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 10

    $summary = @()
    $summary += "Summary for $LogName ($Label)"
    $summary += "==========================="
    if ($events.Count -eq 0) {
      $summary += "No events found."
    } else {
      $summary += "Total events: $($events.Count)"
      $summary += ""
      $summary += "By level:"
      foreach ($g in $levelCounts) { $summary += ("  {0}: {1}" -f $g.Name, $g.Count) }
      $summary += ""
      $summary += "Top sources:"
      foreach ($g in $sourceCounts) { $summary += ("  {0}: {1}" -f $g.Name, $g.Count) }
      $summary += ""
      $summary += "Top event IDs:"
      foreach ($g in $eventIdCounts) { $summary += ("  {0}: {1}" -f $g.Name, $g.Count) }
    }

    Set-Content -Path $sumFile -Value $summary
    Remove-Item -Path $errFile -ErrorAction SilentlyContinue
  } catch {
    Set-Content -Path $errFile -Value $_.Exception.Message
    Set-Content -Path $outFile -Value "Error: $($_.Exception.Message)"
    Set-Content -Path $sumFile -Value "Error: $($_.Exception.Message)"
  }
}

$allEvents = @{}
$totalSteps = ($logs.Count * $windows.Count) + $windows.Count
$step = 0

foreach ($log in $logs) {
  foreach ($w in $windows) {
    $step++
    $pct = [int](($step / $totalSteps) * 100)
    Write-Progress -Activity 'Pulling Event Viewer data' -Status ("{0} {1}" -f $log, $w.Label) -PercentComplete $pct
    Write-Events -LogName $log -Days $w.Days -Label $w.Label
    $allEvents["$($w.Label)"] = @()
  }
}

foreach ($w in $windows) {
  $step++
  $pct = [int](($step / $totalSteps) * 100)
  Write-Progress -Activity 'Building summaries' -Status ("All logs {0}" -f $w.Label) -PercentComplete $pct
  $start = (Get-Date).AddDays(-$w.Days)
  $events = @()
  foreach ($log in $logs) {
    try {
      $events += Get-WinEvent -FilterHashtable @{
        LogName = $log
        Level = 1,2,3
        StartTime = $start
      } -ErrorAction Stop
    } catch {
      # Keep going; per-log errors are handled above.
    }
  }

  # Aggregate summaries across all logs for the same time window.
  $sumFile = Join-Path $OutDir ("AllLogs-Summary-{0}.txt" -f $w.Label)
  $levelCounts = $events | Group-Object LevelDisplayName | Sort-Object Count -Descending
  $sourceCounts = $events | Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 10
  $eventIdCounts = $events | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 10

  $summary = @()
  $summary += "Summary for All Logs ($($w.Label))"
  $summary += "==========================="
  $summary += ("Last boot time: {0}" -f $bootInfo)
  $summary += ""
  if ($events.Count -eq 0) {
    $summary += "No events found."
  } else {
    $summary += "Total events: $($events.Count)"
    $summary += ""
    $summary += "By level:"
    foreach ($g in $levelCounts) { $summary += ("  {0}: {1}" -f $g.Name, $g.Count) }
    $summary += ""
    $summary += "Top sources:"
    foreach ($g in $sourceCounts) { $summary += ("  {0}: {1}" -f $g.Name, $g.Count) }
    $summary += ""
    $summary += "Top event IDs:"
    foreach ($g in $eventIdCounts) { $summary += ("  {0}: {1}" -f $g.Name, $g.Count) }
  }

  Set-Content -Path $sumFile -Value $summary
}

Write-Host "Done. Output: $OutDir"
