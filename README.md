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

Host-key checking remains enabled. Verify and accept each server's SSH host key before running unattended transfers.

See [the directory-transfer guide](SCP_DIRECTORY.md) for installation, validation, and transfer behavior.

## Tests

```bash
python3 -m unittest discover -s tests -p 'test_scp_directory.py' -v
```