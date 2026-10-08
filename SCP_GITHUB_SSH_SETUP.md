# GitHub SSH setup guide transfer
## Copy the setup guide to a remote host

Run `scp-github-ssh-setup.sh` from the directory containing `GITHUB_SSH_SETUP.md`. The script copies the guide to the remote user's home directory using `scp`.

```bash
./scp-github-ssh-setup.sh LOGINUSER DESTSERVER
```

For example:

```bash
./scp-github-ssh-setup.sh jimy jyang02u.sv.splunk.com
```

The script exits with an error if `GITHUB_SSH_SETUP.md` is not found in the current directory. SSH may prompt for host-key confirmation or authentication.
