#!/usr/bin/env bash
set +x
set -euo pipefail

if [[ $# -ne 2 ]]; then
    printf 'Usage: %s LOGINUSER DESTSERVER[,DESTSERVER...]\n' "$0" >&2
    exit 2
fi

loginuser=$1
if [[ ! "$loginuser" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*$ ]]; then
    printf 'Error: invalid login username.\n' >&2
    exit 2
fi

if [[ -z "$2" || "$2" == ,* || "$2" == *, || "$2" == *,,* ]]; then
    printf 'Error: the server list must not contain empty entries.\n' >&2
    exit 2
fi
IFS=',' read -r -a servers <<< "$2"
for destserver in "${servers[@]}"; do
    if [[ ! "$destserver" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
        printf 'Error: use hostnames or IPv4 addresses separated by commas, without spaces.\n' >&2
        exit 2
    fi
done

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

if ! command -v sshpass >/dev/null 2>&1; then
    printf 'Error: sshpass is required; install it before running this script.\n' >&2
    exit 1
fi

trap 'unset password' EXIT
if ! read -r -s -p "SSH password for ${loginuser}: " password; then
    printf '\nError: unable to read the SSH password.\n' >&2
    exit 1
fi
printf '\n' >&2
if [[ -z "$password" ]]; then
    printf 'Error: the SSH password must not be empty.\n' >&2
    exit 1
fi

for destserver in "${servers[@]}"; do
    remote="${loginuser}@${destserver}"
    printf 'Copying %s to %s:~/Downloads/\n' "${tarballs[0]}" "$remote"
    sshpass -d 3 ssh -o StrictHostKeyChecking=yes -- "$remote" \
        'mkdir -p "$HOME/Downloads"' 3< <(printf '%s\n' "$password")
    sshpass -d 3 scp -o StrictHostKeyChecking=yes -- \
        "${tarballs[0]}" "${remote}:~/Downloads/" 3< <(printf '%s\n' "$password")
    printf 'File transfer finished: %s to %s:~/Downloads/\n' "${tarballs[0]}" "$remote"
done
printf 'All file transfers finished successfully (%d host(s)).\n' "${#servers[@]}"
