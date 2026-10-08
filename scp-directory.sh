#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    printf 'Usage: %s LOGINUSER DESTSERVER DIRECTORY\n' "$0" >&2
    exit 2
fi

loginuser=$1
destserver=$2
directory=$3
remote="${loginuser}@${destserver}"

if [[ ! -d "$directory" ]]; then
    printf 'Error: directory not found in the current directory: %s\n' "$directory" >&2
    exit 1
fi

if [[ "$directory" != /* ]]; then
    directory="./$directory"
fi

scp -r -- "$directory" "${remote}:~/"
