# Splunk utilities

## Directory transfers

`scp-directory.sh` recursively copies a local directory to the home directory of one or more remote servers. All servers use the same username and password. Install `sshpass` before using the script.

```bash
./scp-directory.sh sccStudent server1,server2 'core_consultant_lab1'
```

### Password authentication

- If `SSHPASS` is unset, the script prompts once with input hidden and reuses the password for every server.
- If `SSHPASS` is set, the script uses that password without prompting. An empty value is rejected rather than falling back to a prompt.
- For unattended jobs, inject `SSHPASS` from your secret manager or automation platform's secret environment. Do not hard-code passwords in scripts, command arguments, or version-controlled files.

To enter a password once for use through the environment without putting its value in shell history:

```bash
read -rsp 'SSH password: ' SSHPASS; printf '\n'
export SSHPASS
./scp-directory.sh sccStudent server1,server2 'core_consultant_lab1'
unset SSHPASS
```

The script removes `SSHPASS` from its own environment before starting transfers and passes the password to `sshpass` through a file descriptor, not command-line arguments. The calling shell retains its exported variable until you unset it. Environment variables are not a secret vault; avoid shell tracing when loading or using credentials.

The script uses `StrictHostKeyChecking=no` and `UserKnownHostsFile=/dev/null`, so no initial SSH connection or manual host-key acceptance is needed, and `~/.ssh/known_hosts` is not created or updated. This disables persistent server-identity verification and reduces protection against server impersonation; use only with trusted hosts and networks.

See [the directory-transfer guide](SCP_DIRECTORY.md) for installation, validation, and transfer behavior.

## Tests

```bash
python3 -m unittest discover -s tests -p 'test_scp_directory.py' -v
```

## Warp tab configurations

Reusable Warp layouts live in `~/.warp/tab_configs/`, not in this repository. Open one from the `+` menu by its display name. `Cmd-T` uses `home_agent.toml`.

| File | Menu name | What it opens |
|---|---|---|
| `home_agent.toml` | Home agent | Agent pane in the home directory. This is the default new tab. |
| `empty_terminal.toml` | Empty terminal | One terminal pane with no startup command. |
| `documents_agent.toml` | Documents agent | Focused agent pane in `~/Documents`. |
| `documents_split_terminal.toml` | Documents split terminal | Two side-by-side terminals in `~/Documents`. The left pane is focused. |
| `split_agent.toml` | Split agent | Two side-by-side agent panes. The left pane is focused. |
| `ccm_ssh.toml` | CCM SSH | Prompts for a CCM IP, then runs `ssh -i .ssh/praclab.pem splunker@<ip>` from the home directory. |
| `jyang03u_ssh.toml` | jyang03u SSH | Runs `ssh jimy@jyang03u.sv.splunk.com` from the home directory. |

The SSH configs connect when opened, so use them only for the intended hosts. The key path in `ccm_ssh.toml` is relative to the home directory. Warp has no command-line action for opening these TOML files; select them from the `+` menu.
