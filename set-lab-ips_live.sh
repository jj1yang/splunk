#!/usr/bin/env bash
# Export the current lab IPs and shared credentials.
# Usage: source ./set-lab-ips_live.sh
# Requires Python 3. Passwords are never stored in this script or displayed.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf 'Source this file:\n  source %q\n' "$0" >&2
  exit 1
fi
if [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
  printf 'Source this file: source ./set-lab-ips_live.sh\n' >&2
  exit 1
fi

export LAB_SERVER_FILE="$HOME/Downloads/lab_server (1).md"

# Capture shell-quoted exports so credential values do not reach the console.
if ! _lab_exports=$(python3 - "$LAB_SERVER_FILE" <<'PY'
import ipaddress
import shlex
import sys
from pathlib import Path

try:
    rows = [
        [cell.strip() for cell in line.strip().strip("|").split("|")]
        for line in Path(sys.argv[1]).read_text().splitlines()
        if line.strip().startswith("|")
    ]
    header = [cell.lower() for cell in rows[0]]
    required = ("role", "public ip", "private ip", "splunk user name",
                "password", "ssh username")
    columns = {name: header.index(name) for name in required}
    hosts = ("sh1", "mc1", "idx1", "idx2", "uf1")
    records = {}
    for row in rows[1:]:
        role = row[columns["role"]].lower()
        if role in hosts:
            if role in records:
                raise ValueError("Duplicate host")
            records[role] = {name: row[index] for name, index in columns.items()}
    if set(records) != set(hosts):
        raise ValueError("Missing required hosts")

    exports = {}
    credentials = set()
    for host in hosts:
        record = records[host]
        public = str(ipaddress.IPv4Address(record["public ip"]))
        private = str(ipaddress.IPv4Address(record["private ip"]))
        exports[host.upper()] = public
        exports[host.upper() + "_PRIV"] = private
        credentials.add((record["splunk user name"], record["password"],
                         record["ssh username"]))
    if len(credentials) != 1:
        raise ValueError("Hosts do not share credentials")
    admin, password, login = credentials.pop()
    if not all((admin, password, login)):
        raise ValueError("Empty credentials")
    exports.update(
        LAB_SERVERS=",".join(exports[host.upper()] for host in hosts),
        ADMIN_USER=admin, ADMIN_PASSWORD=password,
        LOGIN_USER=login, LOGIN_PASSWORD=password, SSHPASS=password,
    )
    for name, value in exports.items():
        print(f"export {name}={shlex.quote(value)}")
except (OSError, ValueError, IndexError):
    print("Cannot load lab settings; check the Markdown file, headers, and hosts.",
          file=sys.stderr)
    sys.exit(1)
PY
); then
  unset _lab_exports
  return 1
fi
eval "$_lab_exports"
unset _lab_exports

# Public addresses are for external SSH/SCP; _PRIV addresses are for lab traffic.
printf 'Lab IPs exported:\n'
printf '  SH1=%s  SH1_PRIV=%s\n' "$SH1" "$SH1_PRIV"
printf '  MC1=%s  MC1_PRIV=%s\n' "$MC1" "$MC1_PRIV"
printf '  IDX1=%s IDX1_PRIV=%s\n' "$IDX1" "$IDX1_PRIV"
printf '  IDX2=%s IDX2_PRIV=%s\n' "$IDX2" "$IDX2_PRIV"
printf '  UF1=%s  UF1_PRIV=%s\n' "$UF1" "$UF1_PRIV"
printf '  LAB_SERVERS=%s\n' "$LAB_SERVERS"
printf '  ADMIN_USER=%s LOGIN_USER=%s (passwords hidden)\n' "$ADMIN_USER" "$LOGIN_USER"
