<#
Purpose:
  Prepare Windows RDS/RDP Server for lightweight monitoring from a Linux/Python monitor.

What this script does:
  1. Enables Remote Desktop
  2. Starts and enables TermService
  3. Allows ICMP ping from monitor server
  4. Allows RDP TCP/3389 from monitor server
  5. Optionally allows RDP UDP/3389 from monitor server

Run as Administrator.

Example:
  powershell -ExecutionPolicy Bypass -File .\windows-rds-server-setup.ps1 `
    -MonitorIP "192.168.1.50"

With UDP:
  powershell -ExecutionPolicy Bypass -File .\windows-rds-server-setup.ps1 `
    -MonitorIP "192.168.1.50" `
    -AllowUdp3389

Monitor scope:
  - For your stated need "RDS onไหม", TCP/3389 is enough.
  - UDP/3389 is useful for real RDP performance, but not required for basic availability.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$MonitorIP,

    [switch]$AllowUdp3389
)

Write-Host "=== RDS/RDP Monitoring Setup ==="

# 1. Enable Remote Desktop
Write-Host "[1/5] Enabling Remote Desktop..."

Set-ItemProperty `
    -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" `
    -Value 0

$fDeny = Get-ItemProperty `
    -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections"

Write-Host "fDenyTSConnections: $($fDeny.fDenyTSConnections) ; expected 0"

# 2. Ensure TermService is running
Write-Host "[2/5] Enabling TermService..."

Set-Service -Name TermService -StartupType Automatic
Start-Service -Name TermService

$svc = Get-Service TermService
Write-Host "TermService status: $($svc.Status)"

# 3. Allow ICMP Echo Request from monitor IP
Write-Host "[3/5] Allowing ICMP from $MonitorIP..."

$icmpRuleName = "MONITOR Allow ICMP from $MonitorIP"

if (-not (Get-NetFirewallRule -DisplayName $icmpRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
        -DisplayName $icmpRuleName `
        -Direction Inbound `
        -Protocol ICMPv4 `
        -IcmpType 8 `
        -RemoteAddress $MonitorIP `
        -Action Allow | Out-Null
} else {
    Write-Host "ICMP rule already exists."
}

# 4. Allow RDP TCP/3389 from monitor IP
Write-Host "[4/5] Allowing RDP TCP/3389 from $MonitorIP..."

$rdpTcpRuleName = "MONITOR Allow RDP TCP 3389 from $MonitorIP"

if (-not (Get-NetFirewallRule -DisplayName $rdpTcpRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
        -DisplayName $rdpTcpRuleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 3389 `
        -RemoteAddress $MonitorIP `
        -Action Allow | Out-Null
} else {
    Write-Host "RDP TCP rule already exists."
}

# 5. Optionally allow UDP/3389
Write-Host "[5/5] Optional UDP/3389..."

if ($AllowUdp3389) {
    $rdpUdpRuleName = "MONITOR Allow RDP UDP 3389 from $MonitorIP"

    if (-not (Get-NetFirewallRule -DisplayName $rdpUdpRuleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
            -DisplayName $rdpUdpRuleName `
            -Direction Inbound `
            -Protocol UDP `
            -LocalPort 3389 `
            -RemoteAddress $MonitorIP `
            -Action Allow | Out-Null
    } else {
        Write-Host "RDP UDP rule already exists."
    }
} else {
    Write-Host "Skipped UDP/3389. TCP/3389 is enough for basic availability check."
}

Write-Host ""
Write-Host "=== Done ==="
Write-Host "Monitor should test:"
Write-Host "  - ping this server"
Write-Host "  - TCP connect to port 3389"
