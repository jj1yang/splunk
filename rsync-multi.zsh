#!/bin/zsh

# USAGE
#   1. Install sshpass, ssh, and rsync locally, and rsync on every server.
#   2. Edit servers, username, source_dir, destination, and transfer_timeout below.
#      Optional arguments: --dry-run (-n), --help (-h).
#   3. Ensure destination exists and is writable on every remote server.
#   4. Connect to each server with: ssh your_username@server
#      Verify its host-key fingerprint through a trusted source before accepting.
#   5. Run: ~/rsync-multi.zsh
#      Enter the shared SSH password when prompted; input is hidden.
#      Preview: ~/rsync-multi.zsh --dry-run
#      Dry runs still connect and authenticate, but do not modify remote files.
#
# Copies the source file, or directory with its contents, to each server.
# Reruns transfer changed files; destination-only files are not deleted.
# Failures do not stop other servers; a final report lists failed transfers.
# Exit status: 0 = all succeeded, 1 = setup/transfer failure,
#              130 = interrupted (SIGINT), 143 = terminated (SIGTERM).

# Comma-separated hostnames or IP addresses, without spaces or empty entries.
# All servers use the same username and password.
servers="jyang03u.sv.splunk.com"

# SSH account used on every server.
username="jimy"

# Absolute path to the local file or directory to send.
# For a directory, the directory itself is copied, not just its contents.
# Keep paths with spaces or parentheses quoted.
source_dir="/Users/jimyang2/Downloads/SP108HowtoSpinupLabstoPracticeandReproduceCustomerIssues (2).pdf"

# Existing absolute directory on each remote server, or "~" for its SSH home.
# Example: source /data/photos and destination /backup creates /backup/photos.
# For compatibility with older rsync versions, avoid whitespace and shell
# metacharacters in this remote path.
destination="~"

# Maximum time without transfer I/O before rsync fails (seconds).
transfer_timeout=120

integer dry_run=0
typeset -a rsync_options
rsync_options=(-az --partial --progress)
mode_label="Transfer"

for argument in "$@"; do
  case "$argument" in
    --dry-run|-n)
      dry_run=1
      ;;
    --help|-h)
      printf 'Usage: %s [--dry-run|-n] [--help|-h]\n' "$0"
      printf '\nOptions:\n'
      printf '  --dry-run, -n  Preview changes over SSH without modifying remote files.\n'
      printf '  --help, -h     Show these instructions and exit.\n'
      printf '\nSetup:\n'
      printf '  1. Install sshpass, ssh, and rsync locally; install rsync on each server.\n'
      printf '  2. Edit the configuration variables in this script:\n'
      printf '       servers          Comma-separated hosts, no spaces or empty entries.\n'
      printf '       username         Shared SSH username.\n'
      printf '       source_dir       Existing absolute local file or directory, not /.\n'
      printf '       destination      Existing writable absolute remote directory, or ~.\n'
      printf '                        Absolute paths use letters, digits, _, ., /, and -.\n'
      printf '       transfer_timeout Positive number of seconds without transfer I/O.\n'
      printf '  3. Connect with ssh your_username@server to verify each host key.\n'
      printf '     Check fingerprints through a trusted source before accepting.\n'
      printf '\nExamples:\n'
      printf '  %s --dry-run  # Preview planned changes first.\n' "$0"
      printf '  %s            # Perform transfers.\n' "$0"
      printf '\nEnter the shared SSH password at the hidden prompt.\n'
      printf 'Dry runs also connect and authenticate to each server.\n'
      printf 'Copies the source file, or directory with all files and subdirectories.\n'
      printf 'Reruns transfer changed files; destination-only files are not deleted.\n'
      printf 'Failures do not stop other servers; a final report lists failures.\n'
      printf '\nExit status: 0 = success/help, 1 = setup or transfer failure,\n'
      printf '             130 = interrupted, 143 = terminated.\n'
      exit 0
      ;;
    *)
      printf 'ERROR: Unknown argument: %s\n' "$argument" >&2
      printf 'Usage: %s [--dry-run|-n] [--help|-h]\n' "$0" >&2
      exit 1
      ;;
  esac
done

if (( dry_run )); then
  rsync_options+=(--dry-run --itemize-changes)
  mode_label="Dry run"
fi

# A relative "." destination is the remote SSH user's home directory.
# Do not expand "~" locally: it must refer to the remote account's home.
remote_destination="$destination"
if [[ "$destination" == '~' ]]; then
  remote_destination="."
fi

for dependency in rsync sshpass ssh; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'ERROR: Missing dependency: %s\n' "$dependency" >&2
    exit 1
  fi
done

if [[ ( ! -f "$source_dir" && ! -d "$source_dir" ) || "$source_dir" != /* || "$source_dir" == / ]]; then
  printf 'ERROR: Source must be an existing absolute file or directory other than /.\n' >&2
  exit 1
fi

if [[ -z "$servers" || -z "$username" || ( "$destination" != /* && "$destination" != '~' ) ]]; then
  printf 'ERROR: Set servers, username, and an absolute destination path or ~.\n' >&2
  exit 1
fi

# Restrict remote paths because older rsync versions pass them through a shell.
if [[ "$destination" != '~' && "$destination" == *[^a-zA-Z0-9_./-]* ]]; then
  printf 'ERROR: Destination may contain only letters, digits, _, ., /, and -.\n' >&2
  exit 1
fi

if [[ "$transfer_timeout" != <-> ]] || (( transfer_timeout <= 0 )); then
  printf 'ERROR: transfer_timeout must be a positive integer.\n' >&2
  exit 1
fi

typeset -a hosts failed_hosts failed_codes failed_times
hosts=("${(@s:,:)servers}")

if [[ "$servers" == ,* || "$servers" == *, || "$servers" == *,,* ]]; then
  printf 'ERROR: The server list contains an empty entry.\n' >&2
  exit 1
fi

for host in "${hosts[@]}"; do
  if [[ -z "$host" || "$host" == *[[:space:]]* || "$host" == -* ]]; then
    printf 'ERROR: Invalid server entry: %s\n' "$host" >&2
    exit 1
  fi
done

# Read the shared password without displaying it or storing it in this file.
# sshpass reads it from the environment rather than a command-line argument.
trap 'unset SSHPASS' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

read -rs "SSHPASS?SSH password: " || exit 1
printf '\n'
export SSHPASS

integer succeeded=0
integer started=$SECONDS

if (( dry_run )); then
  printf '\nDRY RUN: Previewing changes only; no files will be transferred.\n'
fi

for host in "${hosts[@]}"; do
  printf '\n=== %s: %s ===\n' "$mode_label" "$host"
  transfer_started=$SECONDS

  # Archive mode preserves metadata; compression reduces network traffic.
  # Partial files are retained for retries. Destination-only files are NOT
  # deleted. No trailing slash on source means copy the directory itself.
  # SSH keepalives detect broken connections without bypassing host-key checks.
  if sshpass -e rsync "${rsync_options[@]}" \
    --timeout="$transfer_timeout" \
    -e "ssh -o ConnectTimeout=15 -o ConnectionAttempts=1 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=yes" \
    -- "${source_dir%/}" "$username@$host:${remote_destination%/}/" \
    </dev/null; then
    (( succeeded += 1 ))
    printf 'SUCCESS: %s (%ds)\n' \
      "$host" "$(( SECONDS - transfer_started ))"
  else
    # Capture the failure immediately, then continue with the next server.
    result=$?
    elapsed=$(( SECONDS - transfer_started ))
    failed_hosts+=("$host")
    failed_codes+=("$result")
    failed_times+=("$elapsed")
    printf 'FAILED: %s (exit %d, %ds)\n' \
      "$host" "$result" "$elapsed" >&2
  fi
done

unset SSHPASS
failure_count=${#failed_hosts[@]}

printf '\n========== %s summary ==========\n' "$mode_label"
printf 'Source:      %s\n' "$source_dir"
printf 'Destination: %s\n' "$destination"
printf 'Total:       %d\n' "${#hosts[@]}"
printf 'Succeeded:   %d\n' "$succeeded"
printf 'Failed:      %d\n' "$failure_count"
printf 'Elapsed:     %ds\n' "$(( SECONDS - started ))"

if (( failure_count > 0 )); then
  printf '\nFailed servers:\n'
  for (( i = 1; i <= failure_count; i++ )); do
    printf '  %s — exit %d, %ds\n' \
      "${failed_hosts[i]}" "${failed_codes[i]}" "${failed_times[i]}"
  done
  printf '\nReview the errors above, then rerun to retry.\n'
  exit 1
fi

if (( dry_run )); then
  printf '\nAll dry runs completed successfully. No files were transferred.\n'
else
  printf '\nAll transfers completed successfully.\n'
fi
exit 0
