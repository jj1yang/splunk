# Lab server IP variables

`set-lab-ips.sh` exports the current lab addresses for the search head, monitoring console, two indexers, and one universal forwarder. Source it. Running it as a normal command cannot change the parent shell, and the script exits with an error if you do that.

```bash
source ./set-lab-ips.sh
```

Public addresses are for SSH and SCP from outside the lab. Private addresses are the in-lab `10.0.1.0/24` addresses used between Splunk nodes. `LAB_SERVERS` is the public addresses joined with commas, in the order `SH1`, `MC1`, `IDX1`, `IDX2`, `UF1`, so it can be passed to the comma-delimited server scripts in this directory.

| Variable | Role | Address |
|---|---|---|
| `SH1` | Search head, public | `18.222.205.188` |
| `MC1` | Monitoring console, public | `3.16.143.153` |
| `IDX1` | Indexer 1, public | `18.220.190.150` |
| `IDX2` | Indexer 2, public | `18.219.231.192` |
| `UF1` | Universal forwarder 1, public | `18.216.108.44` |
| `SH1_PRIV` | Search head, private | `10.0.1.1` |
| `MC1_PRIV` | Monitoring console, private | `10.0.1.7` |
| `IDX1_PRIV` | Indexer 1, private | `10.0.1.2` |
| `IDX2_PRIV` | Indexer 2, private | `10.0.1.3` |
| `UF1_PRIV` | Universal forwarder 1, private | `10.0.1.5` |
| `LAB_SERVERS` | Public list | `$SH1,$MC1,$IDX1,$IDX2,$UF1` |

After sourcing, confirm the values:

```bash
printf '%s\n' "$SH1" "$MC1" "$IDX1" "$IDX2" "$UF1" "$LAB_SERVERS"
```

Example with a comma-delimited transfer script:

```bash
source ./set-lab-ips.sh
./scp-directory.sh archStudent "$LAB_SERVERS" 'core_consultant_lab1'
```

These addresses belong to one lab session. When the lab is rebuilt, update the assignments in `set-lab-ips.sh` and this table together. The script does not store usernames or passwords.

## Live lab mapping: `set-lab-ips_live.sh`

Use `set-lab-ips_live.sh` instead of editing hardcoded IP assignments for each new lab. It follows the same variable naming and host order as `set-lab-ips.sh`, but reads IPs and credentials from a Markdown table every time it is sourced. It supports Bash and zsh and requires `python3`.

### Update process

#### Agent prompt

Attach the latest server-mapping Markdown file (for example, `/Users/jimyang2/Downloads/new_lab_server.md`) and submit this prompt:

> /agent Create the set-lab-ips_live.sh script using the provided IP mapping in the attached .md file, model after set-lab-ips.sh, extract password "admin user" and "login user"

For the current table, “admin user” corresponds to `Splunk User Name`, “login user” corresponds to `SSH Username`, and both use the shared `Password` column. Load credentials from the Markdown file at source time rather than embedding or displaying passwords.

#### Refresh and load the mapping

1. Save the latest lab server table as `$HOME/Downloads/new_lab_server.md`, or choose another local file using `LAB_SERVER_FILE`.
2. Ensure the first pipe-delimited Markdown table has these columns (header matching is case-insensitive):
   - `Role`
   - `Public IP`
   - `Private IP`
   - `Splunk User Name`
   - `Password`
   - `SSH Username`
   Additional columns such as `Server URL` and `Status` are ignored. Keep credential values out of this repository.
3. Include exactly one row for each required role: `sh1`, `mc1`, `idx1`, `idx2`, and `uf1`. Role matching is case-insensitive. All five rows must share the same nonempty admin username, SSH username, and password. IP values must be valid IPv4 addresses.
4. Source the script in the shell where you will use the variables:

   ```bash
   unset LAB_SERVER_FILE
   source ./set-lab-ips_live.sh
   ```

   Clearing `LAB_SERVER_FILE` removes an earlier override and selects the default Downloads file. To use a different file:

   ```bash
   export LAB_SERVER_FILE="$HOME/Documents/Server_list/current_lab.md"
   source ./set-lab-ips_live.sh
   ```

5. Review the printed IP summary. Verify that public addresses are externally routable and private addresses belong to the lab network; the script validates IPv4 syntax but does not correct reversed column labels.
6. After a lab rebuild, replace the table with the new mapping and source the script again. There is no need to edit IP assignments in the script.

Executing the script directly cannot update the parent shell and is rejected. If loading fails, it returns a nonzero status without replacing the previously exported IPs or credentials; do not use stale values. When chaining an operation, use `source ./set-lab-ips_live.sh && ...` so it runs only after a successful load.

### Exported variables

| Variables | Source |
|---|---|
| `SH1`, `MC1`, `IDX1`, `IDX2`, `UF1` | `Public IP` for the corresponding role |
| `SH1_PRIV`, `MC1_PRIV`, `IDX1_PRIV`, `IDX2_PRIV`, `UF1_PRIV` | `Private IP` for the corresponding role |
| `LAB_SERVERS` | Comma-separated public IPs in `SH1,MC1,IDX1,IDX2,UF1` order |
| `ADMIN_USER` | `Splunk User Name` |
| `LOGIN_USER` | `SSH Username` |
| `ADMIN_PASSWORD`, `LOGIN_PASSWORD`, `SSHPASS` | The shared `Password` column |
| `LAB_SERVER_FILE` | Selected Markdown file path |

The table supplies a single shared password, not separate admin and SSH passwords. Passwords are exported into the shell environment, but are not embedded in the script or printed in its summary. Do not use `set -x`, dump the environment, or commit the credential-bearing Markdown file. `sshpass -e` reads `SSHPASS` without placing the password in command arguments.

### Using the loaded mapping

For an interactive SSH connection from your Mac:

```bash
ssh "${LOGIN_USER}@${SH1}"
```

For password-based SSH using `sshpass`:

```bash
sshpass -e ssh "${LOGIN_USER}@${SH1}"
```

Verify an unfamiliar server's host-key fingerprint before accepting it. These commands retain normal SSH host-key checks.

To copy a directory to all five public addresses:

```bash
source ./set-lab-ips_live.sh &&
  ./scp-directory.sh "$LOGIN_USER" "$LAB_SERVERS" 'core_consultant_lab1'
```

The directory transfer script uses the exported `SSHPASS` without prompting. This command performs an actual transfer. Use `_PRIV` addresses for Splunk communication between lab servers, not public addresses or public DNS.

When finished, remove credential variables from the current shell:

```bash
unset ADMIN_PASSWORD LOGIN_PASSWORD SSHPASS
```

### Verified lab session — 2026-10-30 UTC

| Role | Public IP | Private IP | SSH result |
|---|---|---|---|
| `sh1` | `18.219.64.244` | `10.0.69.149` | PASS |
| `mc1` | `3.135.63.168` | `10.0.106.68` | PASS |
| `idx1` | `18.216.250.72` | `10.0.96.54` | PASS |
| `idx2` | `18.224.172.245` | `10.0.82.228` | PASS |
| `uf1` | `3.143.221.237` | `10.0.126.82` | PASS |

Validation passed in Bash and zsh for all ten IP exports, admin/login credential exports, server-list ordering, the source-only guard, and missing-file handling.

Actual SSH authentication succeeded on all five public IPs as `sccStudent`. Each server returned its expected role hostname and username using `hostname; whoami`. The tests used short timeouts and temporary host-key files; no remote files or services were changed. These results verify SSH only, not Splunk admin authentication, Splunk services, or file transfers. Addresses and credentials are specific to this lab session and must be refreshed after a rebuild.
