#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    printf 'Usage: %s LOGINUSER DESTSERVER\n' "$0" >&2
    exit 2
fi

loginuser=$1
destserver=$2
remote="${loginuser}@${destserver}"

if [[ ! -f ./GITHUB_SSH_SETUP.md ]]; then
    printf 'Error: GITHUB_SSH_SETUP.md not found in the current directory.\n' >&2
    exit 1
fi

scp -- ./GITHUB_SSH_SETUP.md "${remote}:~/"
