#!/usr/bin/env bash
# Export lab server IP addresses for the current shell.
# Must be sourced; a normal execution cannot change the parent environment.
#
#   source ./set-lab-ips_live.sh
#
# Public addresses are for SSH/SCP from outside the lab.
# Private addresses are for communication between lab servers.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf 'Source this file so the variables persist in the current shell:\n  source %q\n' "$0" >&2
  exit 1
fi

# Public IPs
export SH1=3.142.209.169
export MC1=13.59.209.237
export IDX1=18.221.198.180
export IDX2=18.117.241.45

# Private IPs
export SH1_PRIV=10.0.107.114
export MC1_PRIV=10.0.109.1
export IDX1_PRIV=10.0.90.227
export IDX2_PRIV=10.0.100.26

# Comma-delimited public list, in the same order as the variables above.
export LAB_SERVERS="${SH1},${MC1},${IDX1},${IDX2}"

printf 'Lab IPs exported:\n'
printf '  SH1=%s  SH1_PRIV=%s\n' "$SH1" "$SH1_PRIV"
printf '  MC1=%s   MC1_PRIV=%s\n' "$MC1" "$MC1_PRIV"
printf '  IDX1=%s IDX1_PRIV=%s\n' "$IDX1" "$IDX1_PRIV"
printf '  IDX2=%s IDX2_PRIV=%s\n' "$IDX2" "$IDX2_PRIV"
printf '  LAB_SERVERS=%s\n' "$LAB_SERVERS"
