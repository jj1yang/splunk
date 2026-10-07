# splunk
## Copy a Splunk tarball to a remote host

Run `scp-splunk-tarball.sh` from the directory containing exactly one Splunk Enterprise or Universal Forwarder `.tgz` archive. The script copies that archive to the home directory of the remote account using `scp`.

```bash
./scp-splunk-tarball.sh LOGINUSER DESTSERVER
```

For example:

```bash
./scp-splunk-tarball.sh jimy jyang02u
```

The script exits with an error if no matching archive or more than one matching archive is found. SSH may prompt for host-key confirmation or authentication.
