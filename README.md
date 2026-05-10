# Lightweight Windows Service Monitoring

Scope:
1. File server: check whether one specific SMB share path is accessible.
2. RDS server: check whether RDS/RDP is on by TCP/3389.

## Files

### Windows server side

- `windows-file-server-setup.ps1`
  - Run on the Windows File Server.
  - Enables SMB service.
  - Opens ICMP and TCP/445 from the Linux monitor IP.
  - Validates the target share exists.
  - Optionally grants share-level read permission.

- `windows-rds-server-setup.ps1`
  - Run on the Windows RDS server.
  - Enables Remote Desktop.
  - Starts TermService.
  - Opens ICMP and TCP/3389 from the Linux monitor IP.

### Linux monitor side

- `monitor_config.yaml`
  - Target config.

- `monitor_checks.py`
  - Rough Python skeleton.
  - Checks SMB share path via `listdir`.
  - Checks RDS via TCP connect to 3389.

## File Server Example

Run PowerShell as Administrator:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows-file-server-setup.ps1 `
  -MonitorIP "192.168.1.50" `
  -ShareName "finance" `
  -MonitorUser "DOMAIN\svc_monitor" `
  -GrantShareRead
```

Manual permission requirement:
- Share permission: Read
- NTFS permission: Read/List folder

## RDS Server Example

Run PowerShell as Administrator:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows-rds-server-setup.ps1 `
  -MonitorIP "192.168.1.50"
```

## Linux Monitor Example

```bash
pip install smbprotocol pyyaml
python3 monitor_checks.py monitor_config.yaml
```

## Security Notes

Recommended:
- Restrict firewall source to the monitor server IP.
- Use a dedicated `svc_monitor` account.
- For file share availability only, use readonly permission.
- Do not store plaintext password long-term; replace YAML password with env/secret manager later.
# servermon
