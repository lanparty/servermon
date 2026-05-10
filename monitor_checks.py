"""
Lightweight monitor skeleton.

Checks:
  1. File server share path accessible?
     - TCP/445 open
     - SMB login
     - listdir(target share path)
  2. RDS on?
     - TCP/3389 open

Install:
  pip install smbprotocol pyyaml

Run:
  python3 monitor_checks.py monitor_config.yaml

This is intentionally simple for your agent to extend:
  - add DB write
  - add alert
  - add scheduler
  - add dashboard API
"""

import socket
import sys
import time
import yaml
from smbclient import register_session, listdir


def check_tcp(host: str, port: int, timeout: int = 3) -> dict:
    started = time.time()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return {
                "status": "ok",
                "latency_ms": round((time.time() - started) * 1000),
                "message": f"tcp {host}:{port} reachable",
            }
    except Exception as e:
        return {
            "status": "fail",
            "latency_ms": None,
            "message": f"tcp {host}:{port} failed: {e}",
        }


def check_smb_share(cfg: dict, timeout: int = 3) -> dict:
    host = cfg["host"]
    smb_server = cfg.get("smb_server", host)
    share_path = cfg["share_path"]
    username = cfg["username"]
    password = cfg["password"]

    tcp = check_tcp(host, 445, timeout=timeout)
    if tcp["status"] != "ok":
        return {
            "target": cfg["name"],
            "service": "smb_share",
            "status": "fail",
            "stage": "tcp_445",
            "message": tcp["message"],
        }

    started = time.time()

    try:
        register_session(
            smb_server,
            username=username,
            password=password,
            connection_timeout=timeout,
        )

        # This proves the specific target share path is accessible.
        # It does not enumerate all shares.
        listdir(share_path)

        return {
            "target": cfg["name"],
            "service": "smb_share",
            "status": "ok",
            "stage": "listdir",
            "latency_ms": round((time.time() - started) * 1000),
            "share_path": share_path,
            "message": "share path accessible",
        }

    except Exception as e:
        return {
            "target": cfg["name"],
            "service": "smb_share",
            "status": "fail",
            "stage": "smb_listdir",
            "share_path": share_path,
            "message": str(e),
        }


def check_rds(cfg: dict, timeout: int = 3) -> dict:
    host = cfg["host"]
    port = int(cfg.get("port", 3389))

    result = check_tcp(host, port, timeout=timeout)

    return {
        "target": cfg["name"],
        "service": "rds_tcp",
        "status": result["status"],
        "latency_ms": result["latency_ms"],
        "message": result["message"],
    }


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 monitor_checks.py monitor_config.yaml")
        sys.exit(2)

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    timeout = int(config.get("check_policy", {}).get("timeout_seconds", 3))

    results = [
        check_smb_share(config["file_server"], timeout=timeout),
        check_rds(config["rds_server"], timeout=timeout),
    ]

    for r in results:
        print(r)

    # Exit code useful for cron/systemd/agent wrapper
    if any(r["status"] != "ok" for r in results):
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
