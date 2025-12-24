<#
# Net-Reachability.ps1
## Purpose
# Checks gateway, DNS, and external reachability to classify the failure.
## Outputs
# - Logs to Desktop\NetDiag_YYYY-MM-DD_HH-mm-ss\
# - reachability.txt is the main log
## Functions
# - Ensure-Admin: Relaunches the script as admin if needed.
# - Write-Log: Writes to screen and reachability log.
# - Test-Ping: ICMP reachability check with logging.
# - Test-Dns: DNS resolution check with logging.
#>
param(
    [string]$LogRoot
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
        Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList $args
        exit
    }
}

Ensure-Admin

$progressId = 1

$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $LogRoot) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $LogRoot = Join-Path $desktop "NetDiag_$timestamp"
}

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$rawDir = Join-Path $LogRoot 'raw'
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

$logFile = Join-Path $LogRoot 'reachability.txt'

<#
.SYNOPSIS
Writes a line to screen and reachability log.

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
Ping test with logging.

.DESCRIPTION
- Uses Test-Connection to check reachability.
- Logs the result for quick triage.
#>
function Test-Ping {
    param([string]$Target)
    if (-not $Target) { return $null }
    $ok = Test-Connection -ComputerName $Target -Count 2 -Quiet -ErrorAction SilentlyContinue
    Write-Log "Ping $Target: $ok"
    return $ok
}

<#
.SYNOPSIS
DNS resolution test with logging.

.DESCRIPTION
- Uses Resolve-DnsName to check resolution.
- Logs the result for quick triage.
#>
function Test-Dns {
    param([string]$Name)
    if (-not $Name) { return $null }
    $ok = $false
    try {
        Resolve-DnsName -Name $Name -ErrorAction Stop | Out-Null
        $ok = $true
    } catch {
        $ok = $false
    }
    Write-Log "Resolve $Name: $ok"
    return $ok
}

Write-Log 'Reachability started.'
Write-Log "Log root: $LogRoot"

Write-Progress -Id $progressId -Activity 'Network Reachability' -Status 'Reading gateway and DNS' -PercentComplete 20
$gateway = $null
$dnsServers = @()
$internalDomain = $env:USERDNSDOMAIN

try {
    $cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1
    if ($cfg) {
        $gateway = $cfg.IPv4DefaultGateway.NextHop
    }
} catch {}

try {
    $dnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses
} catch {}

Write-Log "Default gateway: $gateway"
Write-Log "DNS servers: $($dnsServers -join ', ')"
Write-Log "Internal domain: $internalDomain"

Write-Progress -Id $progressId -Activity 'Network Reachability' -Status 'Pinging gateway and DNS' -PercentComplete 40
$gatewayOk = Test-Ping $gateway
$dnsServerOk = $null
if ($dnsServers.Count -gt 0) {
    $dnsServerOk = Test-Ping $dnsServers[0]
}

Write-Progress -Id $progressId -Activity 'Network Reachability' -Status 'Testing external reachability' -PercentComplete 60
$externalIpOk = Test-Ping '1.1.1.1'
$externalDnsOk = Test-Dns 'www.microsoft.com'
$msNCSI = Test-Dns 'dns.msftncsi.com'
$internalDnsOk = $null
if ($internalDomain) {
    $internalDnsOk = Test-Dns $internalDomain
}

Write-Progress -Id $progressId -Activity 'Network Reachability' -Status 'Analyzing results' -PercentComplete 80
$issues = @()
if (-not $gateway) { $issues += 'No default gateway detected.' }
if ($gateway -and $gatewayOk -eq $false) { $issues += 'Default gateway unreachable.' }
if ($externalIpOk -eq $false) { $issues += 'Cannot reach external IP (1.1.1.1).'
}
if ($externalDnsOk -eq $false -and $msNCSI -eq $false) { $issues += 'External DNS resolution failed.' }
if ($internalDomain -and $internalDnsOk -eq $false) { $issues += 'Internal DNS resolution failed.' }
if ($gatewayOk -eq $true -and $externalIpOk -eq $false) { $issues += 'Possible upstream or outbound block.' }
if ($externalIpOk -eq $true -and $externalDnsOk -eq $false) { $issues += 'Likely DNS issue.' }

if ($issues.Count -eq 0) {
    Write-Log 'No obvious reachability issues detected.'
} else {
    Write-Log 'Issues detected:'
    foreach ($issue in $issues) { Write-Log "- $issue" }
}

$verdict = 'OK'
if (-not $gateway) {
    $verdict = 'No default gateway'
} elseif ($gatewayOk -eq $false) {
    $verdict = 'Gateway unreachable'
} elseif ($externalIpOk -eq $false -and $gatewayOk -eq $true) {
    $verdict = 'Upstream or outbound block'
} elseif ($externalIpOk -eq $true -and $externalDnsOk -eq $false -and $msNCSI -eq $false) {
    $verdict = 'DNS resolution issue'
} elseif ($internalDomain -and $internalDnsOk -eq $false) {
    $verdict = 'Internal DNS resolution issue'
} elseif ($issues.Count -gt 0) {
    $verdict = 'See issues'
}

Write-Log "Verdict: $verdict"
$summaryPath = Join-Path $LogRoot 'summary.txt'
if (Test-Path $summaryPath) {
    $summaryLine = "[{0}] Verdict: {1}" -f (Get-Date -Format 'HH:mm:ss'), $verdict
    Add-Content -Path $summaryPath -Value $summaryLine
}

Write-Log 'Reachability completed.'
Write-Progress -Id $progressId -Activity 'Network Reachability' -Completed
Read-Host 'Press Enter to close'
