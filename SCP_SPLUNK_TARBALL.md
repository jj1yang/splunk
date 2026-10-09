# splunk
## Copy a Splunk tarball to remote hosts

Run `scp-splunk-tarball.sh` from the directory containing exactly one Splunk Enterprise or Universal Forwarder `.tgz` archive. The script creates `~/Downloads` on each remote host if needed, then copies the archive there using `scp`. All hosts use the same login username and password.

```bash
./scp-splunk-tarball.sh LOGINUSER DESTSERVER[,DESTSERVER...]
```

For example:

```bash
./scp-splunk-tarball.sh jimy jyang02u
./scp-splunk-tarball.sh jimy jyang02u,jyang03u,jyang04u
```

Use hostnames or IPv4 addresses separated by commas without spaces. A single host is still supported.
After each successful copy, the script prints `File transfer finished:` with the archive and destination. When all copies succeed, it prints `All file transfers finished successfully (N host(s)).`, where `N` is the number of destination hosts. Completion messages are only printed after successful transfers; a failure prevents the final success message.

### Requirements and authentication
- Install `sshpass` (for example, `sudo apt install sshpass` on Ubuntu). On macOS, install a macOS-compatible `sshpass` package from a trusted package source.
- The script asks for the SSH password once with input hidden, then reuses it for every host. The password is passed to `sshpass` through a file descriptor, not in command-line arguments or a file on disk. Do not put a password in the invocation.
- Existing SSH keys can still authenticate successfully instead of the supplied password.
- Host-key verification is required. Before running the script, connect with `ssh LOGINUSER@DESTSERVER` for each new host and verify its host-key fingerprint through a trusted source. Unknown or changed host keys cause the script to fail rather than automatically accepting them.

Transfers run sequentially and stop on the first directory-creation or transfer failure. Previously completed copies remain in place. The local archive is retained. The script also exits with an error for missing or multiple matching archives, invalid server lists, a missing `sshpass` dependency, or an empty password.
