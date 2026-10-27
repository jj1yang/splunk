#!/usr/bin/env bash
# Export lab server IP addresses for the current shell.
# Must be sourced; a normal execution cannot change the parent environment.
#
#   source ./set-lab-ips.sh
#
# Public addresses are for SSH/SCP from outside the lab.
# Private addresses are the in-lab 10.0.1.0/24 addresses.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf 'Source this file so the variables persist in the current shell:\n  source %q\n' "$0" >&2
  exit 1
fi

# Public IPs
export SH1=18.222.205.188
export MC1=3.16.143.153
export IDX1=18.220.190.150
export IDX2=18.219.231.192
export UF1=18.216.108.44

# Private IPs
export SH1_PRIV=10.0.1.1
export MC1_PRIV=10.0.1.7
export IDX1_PRIV=10.0.1.2
export IDX2_PRIV=10.0.1.3
export UF1_PRIV=10.0.1.5

# Comma-delimited public list, in the same order as the variables above.
export LAB_SERVERS="${SH1},${MC1},${IDX1},${IDX2},${UF1}"

printf 'Lab IPs exported:\n'
printf '  SH1=%s  SH1_PRIV=%s\n' "$SH1" "$SH1_PRIV"
printf '  MC1=%s   MC1_PRIV=%s\n' "$MC1" "$MC1_PRIV"
printf '  IDX1=%s IDX1_PRIV=%s\n' "$IDX1" "$IDX1_PRIV"
printf '  IDX2=%s IDX2_PRIV=%s\n' "$IDX2" "$IDX2_PRIV"
printf '  UF1=%s   UF1_PRIV=%s\n' "$UF1" "$UF1_PRIV"
printf '  LAB_SERVERS=%s\n' "$LAB_SERVERS"
