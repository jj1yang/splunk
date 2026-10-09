# Directory transfer
## Copy a directory to one or more remote hosts

Run `scp-directory.sh` from the directory containing the directory you want to transfer. The script recursively copies that directory, including its subdirectories and files, to each remote user's home directory using `scp`. All servers use the same username and password.

Install the required `sshpass` dependency on Ubuntu:

```bash
sudo apt-get install sshpass
```

```bash
./scp-directory.sh LOGINUSER DESTSERVER[,DESTSERVER...] DIRECTORY
```

Quote directory names containing spaces:

```bash
./scp-directory.sh jimy jyang02u 'Configurations - Base'
```

For multiple servers, separate hostnames or IPv4 addresses with commas, without spaces or empty entries:

```bash
./scp-directory.sh jimy jyang02u,jyang04u.sv.splunk.com,192.0.2.10 'Configurations - Base'
```

The script prompts once for the SSH password with input hidden, then reuses it for every server. The password is passed to `sshpass` through a file descriptor, not command-line arguments, environment variables, or a password file. Do not run the script with verbose shell tracing (`bash -v`).

Host-key verification is required (`StrictHostKeyChecking=yes`). Before running the script, connect to each server using `ssh LOGINUSER DESTSERVER`, verify its host-key fingerprint through a trusted source, and accept the verified key. Unknown or changed host keys cause the transfer to fail; the script does not automatically trust them.

The directory itself is created under each remote user's home directory, preserving its contents and nested structure. Servers are processed sequentially. The script stops at the first failed transfer and returns its nonzero exit status; copies to earlier servers are not rolled back. It also exits with an error for a missing source directory, invalid username/server list, missing `sshpass`, or an empty/unreadable password.

Relative source paths are explicitly marked as local, so directory names containing `:` are not interpreted as remote hosts. Absolute source paths are preserved.

## Tests

Run the isolated regression tests without making SSH connections:

```bash
python3 -m unittest discover -s tests -p 'test_scp_directory.py' -v
```
