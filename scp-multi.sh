#!/bin/bash
# Copies each source itself into an EXISTING directory on every server.
# Bash 3.2+ alternative to rsync-multi.sh.
# Requires OpenSSH ssh/scp and sshpass locally; modern scp uses remote SFTP.
# Verify each host fingerprint using a trusted source before accepting it
# with ssh. Unknown/changed host keys are rejected here.
#
# SCP overwrites existing files, does not skip unchanged files, does not resume,
# and provides no transactional rollback. Failed runs can leave partial files.
# No automatic retries: repeating a transfer can overwrite destination files.
# Symlinks and special files are rejected, including inside source directories.
# No shell preflight can eliminate races if sources change during transfer.

set +xv
set -o pipefail
shopt -s nullglob dotglob
script_name="$0"

# Defaults copied from the existing rsync script. Edit or override with flags.
servers="jyang03u.sv.splunk.com"
username="jimy"
sources=(
  "/Users/jimyang2/Downloads/SP108HowtoSpinupLabstoPracticeandReproduceCustomerIssues (2).pdf"
)
destination="~"
port=22
connect_timeout=15

usage() {
  printf '%s\n' \
    "Usage: $script_name [options] [--] [source ...]" \
    "" \
    "Copies multiple local files/directories recursively to every listed host." \
    "Positional sources replace the configured sources array." \
    "" \
    "  --servers HOST,HOST    Shared destination hosts (DNS names or IPv4)." \
    "  --user USER            Shared SSH username." \
    "  --destination DIR      Existing remote directory: absolute path or ~." \
    "  --port PORT            Shared SSH port (default: 22)." \
    "  --connect-timeout SEC  SSH connection timeout (default: 15)." \
    "  --dry-run, -n          Local validation and preview; NO network/prompt." \
    "  --help, -h             Show help without validation or connections." \
    "" \
    "Remote absolute paths allow only letters, digits, _, ., / and -." \
    "Each source is copied by name into DIR; trailing source slashes are ignored." \
    "Source names must be distinct. Symlinks and special files are rejected." \
    "All hosts share the username, password, port, and destination directory." \
    "No destination directories are created; existing files may be overwritten." \
    "" \
    "Install sshpass and OpenSSH; verify host keys separately before transferring." \
    "Password input is hidden. For automation, supply SSHPASS in the environment" \
    "from a secret manager; never put a password on the command line." \
    "Connection timeout and SSH keepalives detect many network failures, but" \
    "there is no total transfer deadline or SCP transfer-I/O timeout." \
    "" \
    "Examples:" \
    "  $script_name -n --servers host1,host2 --destination /tmp -- ./file ./folder" \
    "  $script_name --servers host1,host2 --user alice -- ./file ./folder" \
    "" \
    "Tests: python3 -m unittest -v test_scp_multi.py" \
    "Exit: 0 success/preview/help; 1 validation/transfer failure; 130 INT; 143 TERM."
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# Handlers also clean up passwords inherited from automation.
trap 'unset SSHPASS' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

dry_run=0
supplied_sources=()
hosts=()
ssh_options=()
failed_hosts=()
failed_codes=()
while (( $# )); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run|-n) dry_run=1; shift ;;
    --servers|--user|--destination|--port|--connect-timeout)
      (( $# >= 2 )) || die "Missing value for $1."
      [[ -n "$2" && "$2" != --* ]] || die "Missing value for $1."
      case "$1" in
        --servers) servers="$2" ;;
        --user) username="$2" ;;
        --destination) destination="$2" ;;
        --port) port="$2" ;;
        --connect-timeout) connect_timeout="$2" ;;
      esac
      shift 2
      ;;
    --) shift; supplied_sources+=("$@"); break ;;
    -*) die "Unknown option: $1. Use -- before source names beginning with -." ;;
    *) supplied_sources+=("$1"); shift ;;
  esac
done
(( ${#supplied_sources[@]} )) && sources=("${supplied_sources[@]}")
(( ${#sources[@]} )) || die "At least one source is required."

# Restrict shell-interpreted remote values even though modern scp uses SFTP.
[[ -n "$username" && "$username" != -* &&
   "$username" != *[^a-zA-Z0-9_.-]* ]] || die "Invalid SSH username."
[[ "$destination" == '~' ||
   ( "$destination" == /* && "$destination" != *[^a-zA-Z0-9_./-]* ) ]] ||
  die "Destination must be ~ or an absolute path using letters, digits, _, ., / and -."
[[ "$port" =~ ^[0-9]+$ && ${#port} -le 5 ]] || die "Port must be an integer from 1 to 65535."
(( port = 10#$port ))
(( port >= 1 && port <= 65535 )) || die "Port must be an integer from 1 to 65535."
[[ "$connect_timeout" =~ ^[0-9]+$ && ${#connect_timeout} -le 5 ]] ||
  die "Connection timeout must be an integer from 1 to 86400."
(( connect_timeout = 10#$connect_timeout ))
(( connect_timeout >= 1 && connect_timeout <= 86400 )) ||
  die "Connection timeout must be an integer from 1 to 86400."
[[ -n "$servers" && "$servers" != ,* && "$servers" != *, &&
   "$servers" != *,,* ]] || die "Server list contains an empty entry."
[[ "$servers" != *$'\n'* && "$servers" != *$'\r'* ]] || die "Invalid server list."
IFS=, read -r -a hosts <<< "$servers"
# Indexed arrays retain compatibility with macOS's Bash 3.2.
seen_hosts=()
seen_names=()
for host in "${hosts[@]}"; do
  [[ "$host" != -* && "$host" != *[^a-zA-Z0-9_.-]* ]] ||
    die "Invalid host: $host. Use DNS names or IPv4 without spaces."
  for seen in "${seen_hosts[@]}"; do
    [[ "$seen" != "$host" ]] || die "Duplicate host: $host."
  done
  seen_hosts+=("$host")
done

# Check hidden entries as well. Do not follow symlinks while walking sources.
validate_tree() {
  local entry="$1" child
  [[ ! -L "$entry" ]] || die "Symlinks are not supported: $entry"
  if [[ -d "$entry" ]]; then
    [[ -r "$entry" && -x "$entry" ]] || die "Unreadable directory: $entry"
    for child in "$entry"/*; do
      validate_tree "$child"
    done
  elif [[ -f "$entry" ]]; then
    [[ -r "$entry" ]] || die "Unreadable file: $entry"
  else
    die "Missing source or unsupported special file: $entry"
  fi
}

# Lexically normalize paths using builtins (no GNU realpath needed).
# Do not resolve symlinks; validation rejects selected/nested links.
normalize_source() {
  local input="$1" part
  local -a components stack
  components=()
  stack=()
  [[ "$input" == /* ]] || input="$PWD/$input"
  # Preserve newlines in filenames by reading through a NUL delimiter.
  IFS=/ read -r -d '' -a components < <(printf '%s\0' "$input")
  for part in "${components[@]}"; do
    case "$part" in
      ''|.) ;;
      ..) (( ${#stack[@]} )) && unset 'stack[${#stack[@]}-1]' ;;
      *) stack+=("$part") ;;
    esac
  done
  absolute=""
  for part in "${stack[@]}"; do
    absolute="$absolute/$part"
  done
  [[ -n "$absolute" ]] || absolute="/"
}

normalized_sources=()
for source in "${sources[@]}"; do
  # Reject explicit symlinks before normalizing away a possible trailing slash.
  stripped="$source"
  while [[ "$stripped" == */ && "$stripped" != / ]]; do
    stripped="${stripped%/}"
  done
  [[ -n "$stripped" ]] || die "Empty source path."
  [[ ! -L "$stripped" ]] || die "Symlinks are not supported: $stripped"
  normalize_source "$stripped"
  [[ "$absolute" != / ]] || die "Refusing to copy the filesystem root."
  validate_tree "$absolute"
  name="${absolute##*/}"
  for seen in "${seen_names[@]}"; do
    [[ "$seen" != "$name" ]] || die "Sources have the same destination name: $name"
  done
  seen_names+=("$name")
  normalized_sources+=("$absolute")
done
sources=("${normalized_sources[@]}")
remote_destination="$destination"
[[ "$destination" == '~' ]] && remote_destination="."

printf 'Sources (copied by name, recursively):\n'
printf '  %s\n' "${sources[@]}"
printf 'Remote directory: %s\nHosts:\n' "$destination"
printf '  %s\n' "${hosts[@]}"
if (( dry_run )); then
  printf '\nDRY RUN: local validation only; no network or password prompt.\n'
  printf 'Remote access, host keys, free space and destination contents are NOT checked.\n'
  exit 0
fi

for dependency in sshpass ssh scp; do
  command -v "$dependency" >/dev/null 2>&1 || die "Missing dependency: $dependency"
done
if [[ -z "${SSHPASS-}" ]]; then
  [[ -t 0 ]] || die "No interactive terminal; supply SSHPASS securely in the environment."
  IFS= read -r -s -p 'SSH password: ' SSHPASS || die "Could not read SSH password."
  printf '\n'
fi
[[ -n "$SSHPASS" ]] || die "Password must not be empty."
export SSHPASS

ssh_options=(
  -o "ConnectTimeout=$connect_timeout"
  -o ConnectionAttempts=1
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
  -o StrictHostKeyChecking=yes
  -o NumberOfPasswordPrompts=1
)
succeeded=0
started=$SECONDS
for host in "${hosts[@]}"; do
  printf '\n=== Transfer: %s ===\n' "$host"
  transfer_started=$SECONDS
  # The allowlist above makes single-quoting this remote shell path safe.
  # Preflight avoids scp treating a nonexistent directory as a renamed file.
  if sshpass -e ssh "${ssh_options[@]}" -p "$port" \
    "$username@$host" \
    "test -d '$remote_destination' && test -w '$remote_destination' && test -x '$remote_destination'" \
    </dev/null; then
    if sshpass -e scp "${ssh_options[@]}" -P "$port" -r -p \
      -- "${sources[@]}" "$username@$host:${remote_destination%/}/" </dev/null; then
      (( succeeded += 1 ))
      printf 'SUCCESS: %s (%ds)\n' "$host" "$(( SECONDS - transfer_started ))"
      continue
    else
      result=$?
      printf 'ERROR: SCP failed for %s (exit %d). Partial files may remain.\n' "$host" "$result" >&2
    fi
  else
    result=$?
    printf 'ERROR: Remote preflight failed for %s (exit %d). Check authentication,\n' "$host" "$result" >&2
    printf 'host keys, connectivity and destination directory permissions.\n' >&2
  fi
  failed_hosts+=("$host")
  failed_codes+=("$result")
done
unset SSHPASS
printf '\n========== Transfer summary ==========\n'
printf 'Total: %d  Succeeded: %d  Failed: %d  Elapsed: %ds\n' \
  "${#hosts[@]}" "$succeeded" "${#failed_hosts[@]}" "$(( SECONDS - started ))"
if (( ${#failed_hosts[@]} )); then
  for (( i = 0; i < ${#failed_hosts[@]}; i++ )); do
    printf '  FAILED: %s (exit %d)\n' "${failed_hosts[i]}" "${failed_codes[i]}"
  done
  printf 'Review errors before retrying; SCP copies all selected files again.\n'
  exit 1
fi
printf 'All transfers completed successfully.\n'
exit 0
