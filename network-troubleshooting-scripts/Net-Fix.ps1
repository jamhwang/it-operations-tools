<#
# Net-Fix.ps1
## Purpose
# Runs optional remediation steps (flush DNS, renew IP, reset stack).
## Outputs
# - Logs to Desktop\NetDiag_YYYY-MM-DD_HH-mm-ss\
# - fix.txt is the main log
# - raw\ contains command outputs for deeper review
## Functions
# - Ensure-Admin: Relaunches the script as admin if needed.
# - Write-Log: Writes to screen and fix log.
# - Confirm-Action: Y/N gate for each fix step.
# - Save-Raw: Runs a command and saves full output to raw\.
#>
param(
    [string]$LogRoot,
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
        if ($LogRoot) { $args += " -LogRoot `"$LogRoot`"" }
        if ($AutoFix) { $args += " -AutoFix" }
        Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList $args
        exit
    }
}

Ensure-Admin

$progressId = 1
$step = 0
$totalSteps = 9

$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $LogRoot) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $LogRoot = Join-Path $desktop "NetDiag_$timestamp"
}

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$rawDir = Join-Path $LogRoot 'raw'
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

$logFile = Join-Path $LogRoot 'fix.txt'

<#
.SYNOPSIS
Writes a line to screen and fix log.

.DESCRIPTION
- Keeps screen and file output in sync.
- Adds a timestamp for quick scanning.
#>
function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

<#
.SYNOPSIS
Prompts before running a fix step.

.DESCRIPTION
- Returns true automatically if -AutoFix was used.
- Otherwise asks the tech for Y/N confirmation.
#>
function Confirm-Action {
    param([string]$Prompt)
    if ($AutoFix) { return $true }
    $resp = Read-Host "$Prompt (Y/N)"
    return ($resp -match '^[Yy]')
}

<#
.SYNOPSIS
Saves a command's full output to raw\.

.DESCRIPTION
- Runs the provided scriptblock.
- Writes output or errors to a file for deep review.
#>
function Save-Raw {
    param(
        [string]$Name,
        [scriptblock]$Block
    )
    $path = Join-Path $rawDir $Name
    try {
        & $Block | Out-String | Out-File -FilePath $path -Encoding ASCII
    } catch {
        $_ | Out-String | Out-File -FilePath $path -Encoding ASCII
    }
}

Write-Log 'Fix steps started.'
Write-Log "Log root: $LogRoot"

$step++
Write-Progress -Id $progressId -Activity 'Network Fix' -Status 'Flush DNS cache' -PercentComplete (($step / $totalSteps) * 100)
if (Confirm-Action 'Flush DNS cache') {
    Write-Log 'Running ipconfig /flushdns'
    Save-Raw 'flushdns.txt' { ipconfig /flushdns }
}

$step++
Write-Progress -Id $progressId -Activity 'Network Fix' -Status 'Register DNS' -PercentComplete (($step / $totalSteps) * 100)
if (Confirm-Action 'Register DNS') {
    Write-Log 'Running ipconfig /registerdns'
    Save-Raw 'registerdns.txt' { ipconfig /registerdns }
}

$step++
Write-Progress -Id $progressId -Activity 'Network Fix' -Status 'Release and renew IP' -PercentComplete (($step / $totalSteps) * 100)
if (Confirm-Action 'Release and renew IP (will drop connection briefly)') {
    Write-Log 'Running ipconfig /release and /renew'
    Save-Raw 'release.txt' { ipconfig /release }
    Save-Raw 'renew.txt' { ipconfig /renew }
}

$step++
Write-Progress -Id $progressId -Activity 'Network Fix' -Status 'Reset Winsock' -PercentComplete (($step / $totalSteps) * 100)
if (Confirm-Action 'Reset Winsock (reboot recommended after)') {
    Write-Log 'Running netsh winsock reset'
    Save-Raw 'winsock_reset.txt' { netsh winsock reset }
}

$step++
Write-Progress -Id $progressId -Activity 'Network Fix' -Status 'Reset IP stack' -PercentComplete (($step / $totalSteps) * 100)
if (Confirm-Action 'Reset IP stack (reboot recommended after)') {
    Write-Log 'Running netsh int ip reset'
    Save-Raw 'ip_reset.txt' { netsh int ip reset }
}

$step++
Write-Progress -Id $progressId -Activity 'Network Fix' -Status 'Restart network adapters' -PercentComplete (($step / $totalSteps) * 100)
if (Confirm-Action 'Restart all network adapters') {
    Write-Log 'Restarting network adapters'
    Save-Raw 'restart_adapters.txt' { Get-NetAdapter | Restart-NetAdapter -Confirm:$false }
}

$step++
Write-Progress -Id $progressId -Activity 'Network Fix' -Status 'Toggle network interfaces' -PercentComplete (($step / $totalSteps) * 100)
if (Confirm-Action 'Disable then enable all network adapters') {
    Write-Log 'Disabling network adapters'
    Save-Raw 'disable_adapters.txt' { Get-NetAdapter | Disable-NetAdapter -Confirm:$false }
    Start-Sleep -Seconds 3
    Write-Log 'Enabling network adapters'
    Save-Raw 'enable_adapters.txt' { Get-NetAdapter | Enable-NetAdapter -Confirm:$false }
}

$step++
Write-Progress -Id $progressId -Activity 'Network Fix' -Status 'Restart DNS Client service' -PercentComplete (($step / $totalSteps) * 100)
if (Confirm-Action 'Restart DNS Client service (Dnscache)') {
    Write-Log 'Restarting DNS Client service'
    Save-Raw 'restart_dnscache.txt' { Restart-Service -Name 'Dnscache' -Force }
}

$step++
Write-Progress -Id $progressId -Activity 'Network Fix' -Status 'Clear proxy settings' -PercentComplete (($step / $totalSteps) * 100)
if (Confirm-Action 'Clear WinHTTP and user proxy settings') {
    Write-Log 'Clearing WinHTTP proxy'
    Save-Raw 'winhttp_reset_proxy.txt' { netsh winhttp reset proxy }
    Write-Log 'Clearing user proxy settings'
    Save-Raw 'user_proxy_clear.txt' {
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0 -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -ErrorAction SilentlyContinue
        Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select-Object ProxyEnable, ProxyServer
    }
}

Write-Log 'Fix steps completed.'
Write-Progress -Id $progressId -Activity 'Network Fix' -Completed
Read-Host 'Press Enter to close'
