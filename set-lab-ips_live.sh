#!/usr/bin/env bash
# Export lab server IP addresses for the current shell.
# Must be sourced; a normal execution cannot change the parent environment.
#
#   source ./set-lab-ips_live.sh
#
# Public addresses are for SSH/SCP from outside the lab.
# Private addresses are for communication between lab servers.

if { [[ -n "${BASH_VERSION-}" ]] && [[ "${BASH_SOURCE[0]}" == "$0" ]]; } ||
   { [[ -n "${ZSH_VERSION-}" ]] && [[ "${ZSH_EVAL_CONTEXT-}" != *:file ]]; }; then
  printf 'Source this file so the variables persist in the current shell:\n  source %q\n' "$0" >&2
  exit 1
fi

# Override LAB_SERVER_FILE to load another table with the same columns.
# Credentials are loaded at source time, never embedded in this script.
export LAB_SERVER_FILE="${LAB_SERVER_FILE:-$HOME/Downloads/new_lab_server.md}"
if ! _lab_settings=$(python3 - "$LAB_SERVER_FILE" <<'PY'
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
    columns = [header.index(name) for name in (
        "role", "public ip", "private ip",
        "splunk user name", "password", "ssh username",
    )]
    hosts = ("sh1", "mc1", "idx1", "idx2", "uf1")
    records = {}
    for row in rows[1:]:
        host = row[columns[0]].lower()
        if host in hosts:
            if host in records:
                raise ValueError("Duplicate host")
            records[host] = tuple(row[i] for i in columns[1:])
    if set(records) != set(hosts):
        raise ValueError("Missing required hosts")
    credentials = {record[2:] for record in records.values()}
    if len(credentials) != 1:
        raise ValueError("Hosts do not share credentials")
    admin, password, login = credentials.pop()
    if not all((admin, password, login)):
        raise ValueError("Empty credentials")
    settings = []
    for host in hosts:
        public, private = records[host][:2]
        ipaddress.IPv4Address(public)
        ipaddress.IPv4Address(private)
        settings.extend(((host.upper(), public), (host.upper() + "_PRIV", private)))
    settings.append(("LAB_SERVERS", ",".join(records[host][0] for host in hosts)))
    settings.extend((
        ("ADMIN_USER", admin), ("ADMIN_PASSWORD", password),
        ("LOGIN_USER", login), ("LOGIN_PASSWORD", password),
        ("SSHPASS", password),
    ))
    for name, value in settings:
        print(f"export {name}={shlex.quote(value)}")
except (OSError, ValueError, IndexError):
    print("Cannot load lab settings; check the table, hosts, IPs, and shared credentials.",
          file=sys.stderr)
    sys.exit(1)
PY
); then
  unset _lab_settings
  return 1
fi
eval "$_lab_settings"
unset _lab_settings

printf 'Lab IPs exported:\n'
printf '  SH1=%s  SH1_PRIV=%s\n' "$SH1" "$SH1_PRIV"
printf '  MC1=%s   MC1_PRIV=%s\n' "$MC1" "$MC1_PRIV"
printf '  IDX1=%s IDX1_PRIV=%s\n' "$IDX1" "$IDX1_PRIV"
printf '  IDX2=%s IDX2_PRIV=%s\n' "$IDX2" "$IDX2_PRIV"
printf '  UF1=%s   UF1_PRIV=%s\n' "$UF1" "$UF1_PRIV"
printf '  LAB_SERVERS=%s\n' "$LAB_SERVERS"
printf '  Admin/login credentials loaded (passwords hidden).\n'
