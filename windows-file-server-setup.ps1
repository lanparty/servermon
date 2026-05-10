<#
Purpose:
  Prepare Windows File Server for lightweight monitoring from a Linux/Python monitor.

What this script does:
  1. Starts and enables SMB server service: LanmanServer
  2. Allows ICMP ping from monitor server
  3. Allows SMB TCP/445 from monitor server
  4. Validates that target SMB share exists
  5. Optionally grants READ permission to a monitor user on the SMB share

Run as Administrator.

Example:
  powershell -ExecutionPolicy Bypass -File .\windows-file-server-setup.ps1 `
    -MonitorIP "192.168.1.50" `
    -ShareName "finance" `
    -MonitorUser "DOMAIN\svc_monitor" `
    -GrantShareRead

Notes:
  - This script does NOT create the share.
  - This script does NOT change NTFS permissions unless you do it manually.
  - For readonly availability check, the monitor user needs at least:
      Share permission: Read
      NTFS permission: Read/List folder
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$MonitorIP,

    [Parameter(Mandatory=$true)]
    [string]$ShareName,

    [string]$MonitorUser,

    [switch]$GrantShareRead
)

Write-Host "=== File Server Monitoring Setup ==="

# 1. Ensure SMB Server service is running
Write-Host "[1/5] Enabling LanmanServer..."
Set-Service -Name LanmanServer -StartupType Automatic
Start-Service -Name LanmanServer

$svc = Get-Service LanmanServer
Write-Host "LanmanServer status: $($svc.Status)"

# 2. Allow ICMP Echo Request from monitor IP
Write-Host "[2/5] Allowing ICMP from $MonitorIP..."

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

# 3. Allow SMB TCP/445 from monitor IP
Write-Host "[3/5] Allowing SMB TCP/445 from $MonitorIP..."

$smbRuleName = "MONITOR Allow SMB 445 from $MonitorIP"

if (-not (Get-NetFirewallRule -DisplayName $smbRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
        -DisplayName $smbRuleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 445 `
        -RemoteAddress $MonitorIP `
        -Action Allow | Out-Null
} else {
    Write-Host "SMB rule already exists."
}

# 4. Validate share exists
Write-Host "[4/5] Validating SMB share: $ShareName"

$share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue

if (-not $share) {
    Write-Error "Share '$ShareName' not found. Existing shares:"
    Get-SmbShare | Select-Object Name, Path
    exit 1
}

Write-Host "Share found:"
$share | Select-Object Name, Path, Description | Format-List

# 5. Optionally grant share-level read permission
Write-Host "[5/5] Checking optional share permission..."

if ($GrantShareRead) {
    if (-not $MonitorUser) {
        Write-Error "-GrantShareRead requires -MonitorUser"
        exit 1
    }

    Write-Host "Granting SHARE-level Read permission to $MonitorUser on $ShareName..."
    Grant-SmbShareAccess `
        -Name $ShareName `
        -AccountName $MonitorUser `
        -AccessRight Read `
        -Force | Out-Null

    Write-Host "Share permission granted."
    Write-Warning "You still need NTFS Read/List permission on path: $($share.Path)"
} else {
    Write-Host "Skipped permission grant. Use -GrantShareRead if needed."
}

Write-Host ""
Write-Host "=== Done ==="
Write-Host "Monitor should test: \\$env:COMPUTERNAME\$ShareName"
Write-Host "Required from Linux monitor:"
Write-Host "  - TCP 445 reachable"
Write-Host "  - SMB login succeeds"
Write-Host "  - listdir/read access to target share succeeds"
