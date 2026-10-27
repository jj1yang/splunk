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
