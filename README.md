# Multi-server rsync script
`rsync-multi.zsh` copies a local directory, including its files and subdirectories, to multiple SSH servers sequentially. All servers use the same username and password.

## Requirements
- Run locally with zsh.
- Install `sshpass`, `ssh`, and `rsync` locally.
- Install `rsync` on each remote server.
- Ensure the remote destination exists and is writable by the SSH account.
- Connect to each server using `ssh your_username@server` first. Verify the host-key fingerprint through a trusted source before accepting it. The script rejects unknown or changed host keys.

## Configuration
Edit the variables near the top of `rsync-multi.zsh`:
- `servers`: Comma-separated hostnames or IP addresses, such as `server1,server2,server3`. Do not include spaces or empty entries.
- `username`: SSH username shared by all servers.
- `source_dir`: Existing absolute local directory, other than `/`, such as `/Users/jimyang2/Documents/photos`.
- `destination`: Existing absolute directory on every remote server, such as `/backup`. Only letters, digits, underscores, dots, slashes, and hyphens are supported in this path.
- `transfer_timeout`: Positive number of seconds without rsync transfer I/O before a transfer fails; defaults to `120`.

Replace all placeholder values before running. The script prompts for the shared password with input hidden; do not put passwords in the script or README.

## Usage
The script is executable. From the directory containing it, display help:

```zsh
./rsync-multi.zsh --help
```

Preview planned changes before transferring:

```zsh
./rsync-multi.zsh --dry-run
```

Perform transfers:

```zsh
./rsync-multi.zsh
```

Alternatively, invoke it with `zsh ./rsync-multi.zsh`.

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
- **Source validation failure:** Replace the placeholder `source_dir` with an existing absolute directory other than `/`.
- **Host-key verification failure:** Independently verify the server fingerprint and resolve its known-host entry before retrying; do not disable verification.
- **Authentication failure:** Check the shared username/password and the server's SSH authentication policy.
- **Remote errors:** Confirm that remote rsync is installed and the destination exists and is writable.
- **Failed transfer:** Review the error above the summary, correct the issue, then rerun. Existing unchanged files are normally skipped.

## Validation status
Local syntax and help-option checks passed. A dry-run invocation reached source validation and exited with status `1` because the source was still a placeholder. End-to-end server connectivity and transfer previews require real configuration and have not been verified.
