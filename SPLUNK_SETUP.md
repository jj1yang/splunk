# Splunk Enterprise Setup

## Installation
- Host platform: Ubuntu 22.04 LTS, x86_64.
- Product: Splunk Enterprise 10.6.0.5, build `86587d4e3b27`.
- Install directory: `/opt/splunk`, owned by `splunk:splunk` with mode `750`.
- The official `.deb` package's SHA-512 checksum was verified before installation. The downloaded installer was removed after installation.
- First-run license setup and Splunk Web administrator credentials were completed interactively; credentials are not recorded here.

## Service
- systemd unit: `Splunkd.service`.
- Boot start: enabled.
- Runtime account: `splunk`.
- Splunk Web: `http://mc1:8000/` (HTTP redirects to the login page).
- Management interface: port `8089`.

## Verification and logs
Check service and Splunk process status:

```bash
sudo systemctl status Splunkd.service
sudo -u splunk /opt/splunk/bin/splunk status
```

Review systemd startup logs:

```bash
sudo journalctl -u Splunkd.service --no-pager
```

Check the local web endpoint:

```bash
curl -I http://127.0.0.1:8000/
```

At setup verification, the service was enabled and active, `splunkd` was running, and ports `8000` and `8089` were listening.
