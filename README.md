# Multi-server rsync script
`rsync-multi.zsh` copies a local file or directory to one or more SSH servers sequentially. Directory transfers include all files and subdirectories. All servers use the same username and password.

## Requirements
- Run locally with zsh.
- Install `sshpass`, `ssh`, and `rsync` locally.
- Install `rsync` on each remote server.
- Ensure the remote destination exists and is writable by the SSH account.
- Connect to each server using `ssh your_username@server` first. Verify the host-key fingerprint through a trusted source before accepting it. The script rejects unknown or changed host keys.

## Configuration
Edit the variables near the top of `rsync-multi.zsh`:
- `servers`: Comma-separated hostnames or IP addresses; currently `jyang03u.sv.splunk.com`. Do not include spaces or empty entries.
- `username`: SSH username shared by all servers; currently `jimy`.
- `source_dir`: Existing absolute local file or directory, other than `/`. Despite its name, this variable now accepts a single file. Currently `/Users/jimyang2/Downloads/SP108HowtoSpinupLabstoPracticeandReproduceCustomerIssues (2).pdf`. Keep the value quoted so spaces and parentheses remain part of the path.
- `destination`: Currently `"~"`, meaning the remote SSH user's home directory. The script sends this as `./`, not the locally expanded home directory. Existing absolute directories such as `/backup` are also supported; absolute paths may contain only letters, digits, underscores, dots, slashes, and hyphens.
- `transfer_timeout`: Positive number of seconds without rsync transfer I/O before a transfer fails; defaults to `120`.

Review these machine-specific settings before running elsewhere. The script prompts for the shared password with input hidden; do not put passwords in the script or README.

### Current configured transfer
- SSH account: `jimy@jyang03u.sv.splunk.com`.
- Source: the single PDF listed above, not the entire local home directory.
- Destination: `/home/jimy/SP108HowtoSpinupLabstoPracticeandReproduceCustomerIssues (2).pdf` on the tested server.
- File-source validation and remote-home destination handling are included in the repository script.

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
- A single source file is copied under its original name into the remote destination.
- For directory sources, the directory itself is copied. For example, source `/data/photos` and destination `/backup` produce `/backup/photos`.
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
- **Authentication failure:** Check the shared username/password and the server's SSH authentication policy. `sshpass` exit code `5` indicates rejected password authentication.
- **Remote errors:** Confirm that remote rsync is installed and available on the non-interactive SSH command's `PATH`, and that the destination exists and is writable. A remote `rsync: command not found` error requires installing rsync or correcting its path.
- **Failed transfer:** Review the error above the summary, correct the issue, then rerun. Existing unchanged files are normally skipped.

## Validation status
On October 16, 2026, the configured PDF transfer completed successfully after remote rsync was installed and correct authentication was supplied:
- Transferred size: 8,166,701 bytes.
- Summary: one succeeded, zero failed; elapsed time four seconds.
- A subsequent one-off SSH `ls -lh` check confirmed the file at the destination above, displayed as 7.8 MB.
- The verification SSH connection disconnected automatically afterward.

This verified file existence, not a remote checksum comparison. Local syntax and help-option checks passed. An end-to-end dry run with the final configuration has not been separately verified.
