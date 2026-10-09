#!/usr/bin/env bash
set +x
set -euo pipefail

if [[ $# -ne 3 ]]; then
    printf 'Usage: %s LOGINUSER DESTSERVER[,DESTSERVER...] DIRECTORY\n' "$0" >&2
    exit 2
fi

loginuser=$1
directory=$3

if [[ ! "$loginuser" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*$ ]]; then
    printf 'Error: invalid login username.\n' >&2
    exit 2
fi

if [[ -z "$2" || "$2" == ,* || "$2" == *, || "$2" == *,,* || "$2" == *$'\n'* ]]; then
    printf 'Error: the server list must not contain empty entries or newlines.\n' >&2
    exit 2
fi
IFS=',' read -r -a servers <<< "$2"
for destserver in "${servers[@]}"; do
    if [[ ! "$destserver" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
        printf 'Error: use hostnames or IPv4 addresses separated by commas, without spaces.\n' >&2
        exit 2
    fi
done

if [[ ! -d "$directory" ]]; then
    printf 'Error: directory not found in the current directory: %s\n' "$directory" >&2
    exit 1
fi

if [[ "$directory" != /* ]]; then
    directory="./$directory"
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
    sshpass -d 3 scp -o StrictHostKeyChecking=yes -r -- \
        "$directory" "${remote}:~/" 3< <(printf '%s\n' "$password")
done
