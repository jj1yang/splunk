#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    printf 'Usage: %s LOGINUSER DESTSERVER\n' "$0" >&2
    exit 2
fi

loginuser=$1
destserver=$2
remote="${loginuser}@${destserver}"

shopt -s nullglob
tarballs=(./splunk-*.tgz ./splunkforwarder-*.tgz)

if (( ${#tarballs[@]} == 0 )); then
    printf 'Error: no Splunk tarball found in the current directory.\n' >&2
    exit 1
fi

if (( ${#tarballs[@]} > 1 )); then
    printf 'Error: found multiple Splunk tarballs; leave only the desired tarball in the current directory.\n' >&2
    exit 1
fi

ssh -- "$remote" 'mkdir -p "$HOME/Downloads"'
scp -- "${tarballs[0]}" "${remote}:~/Downloads/"
