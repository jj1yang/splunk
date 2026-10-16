# Multi-server rsync script
`rsync-multi.sh` copies a local file or a directory including its files and subdirectories, to multiple SSH servers sequentially. All servers use the same username and password.

## Requirements
- Run locally with Bash 3.2 or newer (macOS and Ubuntu), not `sh`.
- Install `sshpass`, `ssh`, and `rsync` locally.
- Install `rsync` on each remote server.
- Ensure the remote destination exists and is writable by the SSH account.
- Connect to each server using `ssh your_username@server` first. Verify the host-key fingerprint through a trusted source before accepting it. The script rejects unknown or changed host keys.

## Configuration
Edit the variables near the top of `rsync-multi.sh`:
- `servers`: Comma-separated hostnames or IP addresses; currently `jyang03u.sv.splunk.com`. Do not include spaces or empty entries.
- `username`: SSH username shared by all servers; currently `jimy`.
- `source_dir`: Existing absolute local file or directory, other than `/`, such as `/Users/jimyang2/Documents/photos`.
- `destination`: Currently `"~"`, meaning the remote SSH user's home directory. It is sent as `./` to avoid expanding the local home directory. An existing absolute directory such as `/backup` is also supported; absolute paths may contain only letters, digits, underscores, dots, slashes, and hyphens.
- `transfer_timeout`: Positive number of seconds without rsync transfer I/O before a transfer fails; defaults to `120`.

The configured target is `jimy@jyang03u.sv.splunk.com` with its remote home directory as the destination. Review `source_dir`, which retains the configured PDF path, and replace it with the local file or directory to copy before running. The script prompts for the shared password with input hidden. For noninteractive automation, supply `SSHPASS` securely in the environment. Do not put passwords in the script, README, shell history, or command-line arguments. The script cannot clear an environment variable in its calling shell; clean that up separately.

## Usage
The script is executable. From the directory containing it, display help:

```bash
./rsync-multi.sh --help
```

Preview planned changes before transferring:

```bash
./rsync-multi.sh --dry-run
```

Perform transfers:

```bash
./rsync-multi.sh
```

Alternatively, invoke it with `bash ./rsync-multi.sh`.

### Options
- `--help`, `-h`: Display setup and usage instructions, then exit successfully without checking dependencies, prompting for a password, or connecting to servers.
- `--dry-run`, `-n`: Connect and authenticate to each server, compare files, and show itemized planned changes without transferring files or modifying remote files.
- Unknown arguments produce an error and exit with status `1`.

Combining `--dry-run --help` displays help and exits; it does not perform a dry run.

## Transfer behavior
- The source directory itself is copied. For example, source `/data/photos` and destination `/backup` produce `/backup/photos`.
- Archive mode preserves directory structure and supported metadata; compression reduces network traffic.
- Subsequent runs normally skip files whose size and modification time are unchanged. This is not a full content-checksum comparison.
- Partial files are retained to assist retries.
- Destination-only files are not deleted; the script does not use `--delete`.
- Each server is attempted even if an earlier server fails.
- SSH connection timeout is 15 seconds. Keepalives help detect broken connections.

## Summary and exit status
The final report shows the mode, source, destination, number of servers, successes, failures, and total elapsed time. Failed servers are listed with their command exit codes and individual elapsed times. Detailed error messages appear during each attempt.

- `0`: All server attempts succeeded, or help was displayed.
- `1`: Configuration/dependency validation failed, or at least one server attempt failed.
- `130`: Interrupted by SIGINT after signal handlers are installed.
- `143`: Terminated by SIGTERM after signal handlers are installed.

Early validation failures exit before the transfer summary. Interrupted runs do not produce a final summary. A successful dry run reports successful previews, not completed transfers.

## Troubleshooting
- **Missing dependency:** Install the named program and ensure it is available on `PATH`.
- **Source validation failure:** Set `source_dir` to an existing absolute file or directory other than `/`.
- **Host-key verification failure:** Independently verify the server fingerprint and resolve its known-host entry before retrying; do not disable verification.
- **Authentication failure:** Check the shared username/password and the server's SSH authentication policy.
- **Remote errors:** Confirm that remote rsync is installed and the destination exists and is writable.
- **Failed transfer:** Review the error above the summary, correct the issue, then rerun. Existing unchanged files are normally skipped.

## Automated tests
Run both mocked regression suites from this directory:

```bash
python3 -m unittest -v test_scp_multi test_rsync_multi
```

Check syntax:

```bash
bash -n ./rsync-multi.sh
bash -n ./scp-multi.sh
```

Tests use temporary configuration copies and fake transfer executables. No real servers are contacted, and no real credentials are used. Set `BASH_UNDER_TEST` to an absolute Bash executable to test a different Bash version. Live transfers have not been verified.

## Migration from zsh
`rsync-multi.zsh` is now `rsync-multi.sh`, with a `#!/bin/bash` shebang. Update saved commands or scheduled jobs to use the new name. Configuration defaults and rsync transfer behavior are preserved. Bash 3.2+ is supported; this is not a POSIX-sh script.


## Historical verification of the original zsh version
The following record is preserved from the previous repository README. It describes the original zsh script, not end-to-end validation of the Bash migration.

On October 16, 2026, the configured PDF transfer completed successfully after remote rsync was installed and correct authentication was supplied:
- Transferred size: 8,166,701 bytes.
- Summary: one succeeded, zero failed; elapsed time four seconds.
- A subsequent one-off SSH `ls -lh` check confirmed the file at the destination above, displayed as 7.8 MB.
- The verification SSH connection disconnected automatically afterward.

This verified file existence, not a remote checksum comparison. Local syntax and help-option checks passed. An end-to-end dry run with the final configuration has not been separately verified.
