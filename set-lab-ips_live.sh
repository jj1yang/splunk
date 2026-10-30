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
export SH1=18.117.196.63
export MC1=18.117.126.203
export IDX1=3.17.128.209
export IDX2=3.135.234.166
export UF1=18.222.208.84

# Private IPs
export SH1_PRIV=10.0.118.160
export MC1_PRIV=10.0.127.57
export IDX1_PRIV=10.0.94.150
export IDX2_PRIV=10.0.98.134
export UF1_PRIV=10.0.81.215

# Comma-delimited public list, in the same order as the variables above.
export LAB_SERVERS="${SH1},${MC1},${IDX1},${IDX2},${UF1}"

printf 'Lab IPs exported:\n'
printf '  SH1=%s  SH1_PRIV=%s\n' "$SH1" "$SH1_PRIV"
printf '  MC1=%s   MC1_PRIV=%s\n' "$MC1" "$MC1_PRIV"
printf '  IDX1=%s IDX1_PRIV=%s\n' "$IDX1" "$IDX1_PRIV"
printf '  IDX2=%s IDX2_PRIV=%s\n' "$IDX2" "$IDX2_PRIV"
printf '  UF1=%s   UF1_PRIV=%s\n' "$UF1" "$UF1_PRIV"
printf '  LAB_SERVERS=%s\n' "$LAB_SERVERS"
