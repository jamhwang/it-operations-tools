<#
# Net-Collect.ps1
## Purpose
# Collects system, adapter, IP, DNS, routes, and firewall baseline data.
## Outputs
# - Logs to Desktop\NetDiag_YYYY-MM-DD_HH-mm-ss\
# - collect.txt is the main log
# - raw\ contains command outputs for deeper review
## Functions
# - Ensure-Admin: Relaunches the script as admin if needed.
# - Write-Log: Writes to screen and collect log.
# - Save-Raw: Runs a command and saves full output to raw\.
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

$logFile = Join-Path $LogRoot 'collect.txt'

<#
.SYNOPSIS
Writes a line to screen and collect log.

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

Write-Log 'Collect started.'
Write-Log "Log root: $LogRoot"

Write-Progress -Id $progressId -Activity 'Network Collect' -Status 'Reading system info' -PercentComplete 20
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    Write-Log "Host: $($cs.Name)"
    Write-Log "OS: $($os.Caption) $($os.Version)"
    Write-Log "Uptime: $([math]::Round(($os.LocalDateTime - $os.LastBootUpTime).TotalHours, 2)) hours"
} catch {
    Write-Log 'Failed to read basic system info.'
}

Write-Progress -Id $progressId -Activity 'Network Collect' -Status 'Reading adapter status' -PercentComplete 40
try {
    $adaptersUp = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    $adapterNames = ($adaptersUp | Select-Object -ExpandProperty Name) -join ', '
    if (-not $adapterNames) { $adapterNames = 'None' }
    Write-Log "Adapters up: $adapterNames"
} catch {
    Write-Log 'Failed to read adapter status.'
}

Write-Progress -Id $progressId -Activity 'Network Collect' -Status 'Reading IP configuration' -PercentComplete 60
try {
    $configs = Get-NetIPConfiguration
    foreach ($cfg in $configs) {
        $ipv4 = ($cfg.IPv4Address | Select-Object -ExpandProperty IPv4Address) -join ', '
        $gw = $cfg.IPv4DefaultGateway.NextHop
        $dns = ($cfg.DnsServer.ServerAddresses) -join ', '
        Write-Log "Interface: $($cfg.InterfaceAlias)"
        Write-Log "  IPv4: $ipv4"
        Write-Log "  Gateway: $gw"
        Write-Log "  DNS: $dns"
    }
} catch {
    Write-Log 'Failed to read IP configuration.'
}

Write-Progress -Id $progressId -Activity 'Network Collect' -Status 'Saving raw outputs' -PercentComplete 80
Save-Raw 'ipconfig_all.txt' { ipconfig /all }
Save-Raw 'route_print.txt' { route print }
Save-Raw 'get_netipconfiguration.txt' { Get-NetIPConfiguration | Format-List * }
Save-Raw 'get_netadapter.txt' { Get-NetAdapter | Format-List * }
Save-Raw 'dnsclient.txt' { Get-DnsClientServerAddress -AddressFamily IPv4 | Format-List * }
Save-Raw 'firewall_profile.txt' { Get-NetFirewallProfile | Format-List * }
Save-Raw 'netsh_interface_ip_show_config.txt' { netsh interface ip show config }
Save-Raw 'netsh_wlan_show_interfaces.txt' { netsh wlan show interfaces }
Save-Raw 'vpn_connections.txt' { Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue | Format-List * }

Write-Log 'Collect completed.'
Write-Progress -Id $progressId -Activity 'Network Collect' -Completed
Read-Host 'Press Enter to close'
