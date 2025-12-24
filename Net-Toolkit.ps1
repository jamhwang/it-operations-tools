<#
# Net-Toolkit.ps1
## Purpose
# Runs the full troubleshooting workflow: collect -> reachability -> optional fixes.
## Outputs
# - Logs to Desktop\NetDiag_YYYY-MM-DD_HH-mm-ss\
# - summary.txt is the main timeline log
## Functions
# - Ensure-Admin: Relaunches the script as admin if needed.
# - Write-Log: Writes to screen and summary log.
#>
param(
    [switch]$RunFix,
    [switch]$AutoFix
)

<#
.SYNOPSIS
Ensures the script runs elevated.

.DESCRIPTION
- Checks the current token for admin.
- If not admin, relaunches PowerShell with the same arguments.
#>
function Ensure-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($RunFix) { $args += " -RunFix" }
        if ($AutoFix) { $args += " -AutoFix" }
        Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList $args
        exit
    }
}

Ensure-Admin

$progressId = 1

$desktop = [Environment]::GetFolderPath('Desktop')
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$LogRoot = Join-Path $desktop "NetDiag_$timestamp"
New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null

$summaryLog = Join-Path $LogRoot 'summary.txt'

<#
.SYNOPSIS
Writes a line to screen and summary log.

.DESCRIPTION
- Keeps screen and file output in sync.
- Adds a timestamp for quick scanning.
#>
function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -Path $summaryLog -Value $line
}

Write-Log 'Net-Toolkit started.'
Write-Log "Log root: $LogRoot"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$collectScript = Join-Path $scriptRoot 'Net-Collect.ps1'
$reachScript = Join-Path $scriptRoot 'Net-Reachability.ps1'
$fixScript = Join-Path $scriptRoot 'Net-Fix.ps1'

if (-not (Test-Path $collectScript)) { Write-Log "Missing: $collectScript"; exit 1 }
if (-not (Test-Path $reachScript)) { Write-Log "Missing: $reachScript"; exit 1 }
if (-not (Test-Path $fixScript)) { Write-Log "Missing: $fixScript"; exit 1 }

& $collectScript -LogRoot $LogRoot
Write-Progress -Id $progressId -Activity 'Network Toolkit' -Status 'Reachability checks' -PercentComplete 60
& $reachScript -LogRoot $LogRoot

$doFix = $RunFix
if (-not $RunFix) {
    $resp = Read-Host 'Run fix steps now? (Y/N)'
    if ($resp -match '^[Yy]') { $doFix = $true }
}

if ($doFix) {
    Write-Progress -Id $progressId -Activity 'Network Toolkit' -Status 'Fix steps' -PercentComplete 90
    if ($AutoFix) {
        & $fixScript -LogRoot $LogRoot -AutoFix
    } else {
        & $fixScript -LogRoot $LogRoot
    }
} else {
    Write-Log 'Fix steps skipped.'
}

Write-Log 'Net-Toolkit completed.'
Write-Log "Logs saved to $LogRoot"
Write-Progress -Id $progressId -Activity 'Network Toolkit' -Completed
Read-Host 'Press Enter to close'
