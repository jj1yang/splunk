# Multi-source, multi-server SCP
`scp-multi.sh` copies multiple local files and directories recursively to multiple remote servers, sequentially. All servers share one SSH username, password, port, and destination directory.

This is a separate alternative to `rsync-multi.sh`. Both transfer scripts have been converted from zsh to Bash and renamed to `.sh`; their configured transfer defaults are retained.

## Requirements
- Run locally with Bash 3.2 or newer (macOS and Ubuntu). Do not invoke with `sh`; Ubuntu uses dash for `/bin/sh`.
- Install `sshpass`, `ssh`, and `scp` locally and make them available on `PATH`.
- Remote servers must support SSH command execution for the destination preflight. Modern OpenSSH SCP also requires the remote SFTP subsystem.
- The destination directory must already exist and be writable and searchable by the SSH account.
- No initial SSH connection or manual host-key acceptance is required; see the host-key behavior below.
- Python 3 is needed only to run the automated tests.

### SSH host-key behavior
Both the SSH preflight and SCP transfers use `StrictHostKeyChecking=no` and `UserKnownHostsFile=/dev/null`. The script does not create or update `~/.ssh/known_hosts`. This disables persistent server-identity verification and reduces protection against server impersonation; use only with trusted hosts and networks.

## Quick start
Run these examples from the directory containing the script. Replace server names and source paths with your actual values.

### Show help
```bash
./scp-multi.sh --help
```

### Preview without connecting
```bash
./scp-multi.sh --dry-run \
  --servers "server1,server2" \
  --user archStudent \
  --destination /tmp \
  -- ./file.tgz "./folder with spaces" ./another-file.conf
```

The preview validates local sources and configuration and displays the transfer plan. It does not prompt for a password, check installed transfer dependencies, connect to servers, compare destination files, or verify remote permissions or free space.

### Perform the transfers
```bash
./scp-multi.sh \
  --servers "server1,server2" \
  --user archStudent \
  --destination /tmp \
  -- ./file.tgz "./folder with spaces" ./another-file.conf
```

Enter the shared SSH password once at the hidden prompt.

If the executable permission is unavailable, invoke the script with `bash ./scp-multi.sh` and the same arguments.

## Configuration
Edit the defaults near the top of `scp-multi.sh`, or override them on the command line:

- `servers`: Comma-separated DNS names or IPv4 addresses. No spaces, empty entries, duplicate entries, embedded usernames, or IPv6 addresses.
- `username`: Shared SSH account. Allowed characters are letters, digits, underscores, dots, and hyphens; it cannot start with a hyphen.
- `sources`: Bash array of local file and directory paths. Relative paths are resolved from the invocation's working directory. Quote paths containing spaces or shell metacharacters.
- `destination`: Existing absolute remote directory, or the literal `~` for the remote user's home. Absolute paths allow only letters, digits, underscores, dots, slashes, and hyphens.
- `port`: Shared SSH port, from `1` through `65535`; default `22`.
- `connect_timeout`: SSH connection timeout, from `1` through `86400` seconds; default `15`.

The initial server, username, source file, and home-directory destination were copied from the existing rsync script. Review them before running without overrides.

To configure multiple sources inside the script, use an array such as:

```bash
sources=(
  "/Users/jimyang2/Downloads/package.tgz"
  "/Users/jimyang2/Documents/configuration"
  "/Users/jimyang2/Documents/file with spaces.conf"
)
```

Command-line source arguments replace the entire configured array; they do not append to it. With no positional sources, the configured array is used.

## Options
- `--servers HOST,HOST`: Override the destination hosts.
- `--user USER`: Override the shared SSH username.
- `--destination DIR`: Override the shared remote directory.
- `--port PORT`: Override the shared SSH port.
- `--connect-timeout SEC`: Override the SSH connection timeout.
- `--dry-run`, `-n`: Validate locally and display an offline preview.
- `--help`, `-h`: Display help and exit without connecting.
- `--`: End option parsing. Everything after it is a source path, including names beginning with `-`.

Options take separate values, such as `--port 2222`, not `--port=2222`. Place options before `--`.

For the remote home directory, quote the tilde so the local shell does not expand it:

```bash
./scp-multi.sh --destination '~' -- ./file.txt ./folder
```

The script sends the home destination as `./`. A destination such as `~/uploads` is not supported; use its absolute remote path instead.

## Transfer behavior
- Every selected source is sent to every server.
- A directory itself is copied, including nested directories and hidden entries. For example, source `./photos` and destination `/backup` produce `/backup/photos`.
- Trailing source slashes are ignored; `./photos/` also copies the directory by name.
- Sources must have distinct final names. Selecting both `/data/a/config` and `/data/b/config` is rejected to prevent collisions.
- SCP uses `-r` for recursive copying and `-p` to preserve modification times, access times, and permission modes where supported. It does not preserve all ownership, ACL, or extended-attribute metadata.
- Existing destination files may be overwritten. Existing directories can be merged; destination-only files are not deleted.
- A separate SSH connection checks that the remote destination is a writable, searchable directory before SCP is attempted.
- A preflight failure skips SCP for that server. A failed SCP or preflight does not prevent attempts on later servers.
- There are no automatic retries, destination creation, checksum verification, or rollback.

Use separate invocations if servers need different usernames, ports, or destination paths.

## Validation and safety checks
Before transferring, the script rejects:

- Missing, empty, unreadable, or unsupported local sources.
- The filesystem root `/` as a source.
- Symlinks selected as sources or encountered within source trees, including broken links and cycles.
- Special files such as FIFOs.
- Directories that cannot be read or searched.
- Duplicate source names or duplicate server entries.
- Invalid server lists, usernames, destination paths, ports, and timeout values.
- Missing transfer dependencies.
- Missing passwords when running without an interactive terminal.

Local validation recursively walks source directories, including hidden entries, so validation may take time for large trees. Keep sources stable during validation and transfer: these checks cannot eliminate races if files change.

Remote preflight checks only the destination directory's existence and basic access. It does not guarantee sufficient space, quotas, permissions on existing destination children, or successful completion.

## Password handling
The normal interactive path prompts once with input hidden. The password is exported as `SSHPASS` and supplied to `sshpass -e`, rather than placed in command-line arguments.

For automation, provide a nonempty `SSHPASS` environment variable using a secret manager or another secure mechanism. Do not embed passwords in the script, this guide, shell history, or command-line arguments.

The script unsets its own `SSHPASS` on exit. It cannot unset a variable exported by the calling shell; the caller must clean up its own environment. Environment variables are not a secret vault and may be accessible to appropriately privileged processes.

## Timeouts and interruptions
- SSH connection attempts use `ConnectTimeout` and `ConnectionAttempts=1`.
- Keepalives use `ServerAliveInterval=15` and `ServerAliveCountMax=3`.
- These settings help detect unreachable or broken connections; they are not a total transfer deadline or a transfer-I/O inactivity timeout.
- SIGINT and SIGTERM handlers request exit statuses `130` and `143`, respectively.
- Interrupted runs do not produce the normal final summary. SCP may leave partial destination files.

## Summary and exit status
Normal completion prints total servers, successes, failures, and elapsed time. Failed hosts are listed with their underlying command exit codes; detailed errors appear during each attempt.

- `0`: All transfers succeeded, an offline preview completed, or help was displayed.
- `1`: Validation failed or at least one server attempt failed.
- `130`: Interrupted by SIGINT after handlers were installed.
- `143`: Terminated by SIGTERM after handlers were installed.

Validation failures exit before the transfer summary. A server is counted as successful only if its entire SCP invocation exits successfully.

## Automated tests
Run the test suite from the directory containing both files:

```bash
python3 ./test_scp_multi.py -v
```

Or use unittest:

```bash
python3 -m unittest -v test_scp_multi.py
```

Check Bash syntax independently:

```bash
bash -n ./scp-multi.sh
```

The suite uses temporary fixtures and fake `sshpass`, `ssh`, and `scp` executables on an isolated `PATH`. No real credentials or network connections are used.

Coverage includes:
- Multiple sources and servers; spaces, parentheses, and dash-prefixed source names.
- Recursive validation, hidden entries, symlinks, special files, and permission errors.
- Invalid configuration, missing dependencies, and missing noninteractive passwords.
- Remote path formatting, port and timeout handling, and SSH safety options.
- Continued processing after preflight or transfer failures, summary counts, and exit codes.
- Offline preview, help, password exclusion from logged arguments/output, and signal handling.

The Bash migration includes SCP regressions and a separate rsync regression suite. Run both with `python3 -m unittest -v test_scp_multi test_rsync_multi`. Set `BASH_UNDER_TEST` to an absolute Bash executable to test another version. Permission tests are skipped when run as root. Live SSH/SFTP behavior, actual copied contents, and interactive password entry have not been end-to-end verified by this mocked suite.

## Troubleshooting
- **Missing dependency:** Install the named command and ensure it is available on `PATH`.
- **Invalid or unreadable source:** Check spelling, quoting, existence, permissions, and nested entries.
- **Duplicate destination name:** Rename one selected source or use separate invocations.
- **Symlink rejected:** Select the intended real file or directory explicitly, or use another tool if link preservation is required.
- **Host-key error:** Both SSH and SCP should use `StrictHostKeyChecking=no` and `UserKnownHostsFile=/dev/null`. If an error persists, check the effective SSH configuration, including system-wide known-host entries or additional host-key policies.
- **Authentication failure:** Check the shared username/password and the server's SSH authentication policy. Multi-factor or unusual interactive authentication may not work with `sshpass`.
- **Remote preflight failure:** Check connectivity, host keys, authentication, shell-command access, and destination existence and permissions.
- **SCP/SFTP failure:** Confirm the remote SFTP subsystem is available, sufficient disk space exists, and existing destination files can be written. The script does not force legacy SCP mode.
- **No terminal:** Run interactively or supply `SSHPASS` securely through the environment.
- **Partial transfer:** Inspect the remote files and correct the error before rerunning. SCP copies selected files again; it does not resume or skip unchanged files.

## When to use rsync instead
Use the existing rsync utility for recurring synchronization, skipping unchanged files, or reusing partial transfers. This SCP utility is intended for straightforward copies and does not reproduce rsync's incremental-transfer behavior.


## Migration from zsh
`scp-multi.zsh` is now `scp-multi.sh`, with a `#!/bin/bash` shebang. Update saved invocations to use the new name. Bash 3.2+ is supported without GNU-only path utilities. The configured defaults and SCP transfer behavior are retained. Do not invoke this script with `sh`.
