# Directory transfer
## Copy a directory to a remote host

Run `scp-directory.sh` from the directory containing the directory you want to transfer. The script recursively copies that directory, including its subdirectories and files, to the remote user's home directory using `scp`.

```bash
./scp-directory.sh LOGINUSER DESTSERVER DIRECTORY
```

Quote directory names containing spaces:

```bash
./scp-directory.sh jimy jyang02u 'Configurations - Base'
```

The directory itself is created under the remote user's home directory, preserving its contents and nested structure. The script exits with an error if the specified directory is not found in the current directory. SSH may prompt for host-key confirmation or authentication.

Relative source paths are explicitly marked as local, so directory names containing `:` are not interpreted as remote hosts. Absolute source paths are preserved.

## Tests

Run the isolated regression tests without making SSH connections:

```bash
python3 -m unittest discover -s tests -p 'test_scp_directory.py' -v
```
