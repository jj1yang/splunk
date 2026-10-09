# Splunk Enterprise Setup

## Installation
- Host platform: Ubuntu 22.04 LTS, x86_64.
- Product: Splunk Enterprise 10.6.0.5, build `86587d4e3b27`.
- Install directory: `/opt/splunk`, owned by `splunk:splunk` with mode `750`.
- The official Linux tarball's SHA-512 checksum was verified before installation.
- Keep the downloaded installer tarball after installation by default. Remove it only when cleanup is explicitly requested.
- The existing installation's first-run license setup and Splunk Web administrator credentials were completed interactively; credentials are not recorded here. For a fresh installation, use the first-start procedure below.

## First start: accept the license and set admin credentials
Run this only on a fresh installation, after extracting Splunk to `/opt/splunk` and before its first start. Set `ADMIN_USER` to the desired Splunk Web administrator name (it defaults to `admin`); the password is requested without echo. Splunk ignores `user-seed.conf` if `$SPLUNK_HOME/etc/passwd` already exists.

The seed file is created with mode `600` and removed after a successful first start. The password is passed through a pipe rather than a command-line argument. Do not commit or otherwise retain a copy of the seed file.

```bash
ADMIN_USER="${ADMIN_USER:-admin}"
(
  set -euo pipefail
  read -r -s -p "Splunk admin password: " ADMIN_PASSWORD
  printf '\n'
  if [[ -z "$ADMIN_PASSWORD" ]]; then
    printf 'A non-empty admin password is required.\n' >&2
    exit 1
  fi

  SEED_FILE=/opt/splunk/etc/system/local/user-seed.conf
  sudo install -d -o splunk -g splunk -m 700 /opt/splunk/etc/system/local
  sudo install -o splunk -g splunk -m 600 /dev/null "$SEED_FILE"
  printf '[user_info]\nUSERNAME = %s\nPASSWORD = %s\n' "$ADMIN_USER" "$ADMIN_PASSWORD" |
    sudo -u splunk tee "$SEED_FILE" >/dev/null
  unset ADMIN_PASSWORD

  sudo -u splunk /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt
  sudo rm -- "$SEED_FILE"
)
```

`--accept-license` accepts the license without the interactive agreement prompt. The admin account must be seeded before using `--no-prompt`; otherwise, Splunk can start without an administrator account. See Splunk's documentation for [first startup](https://help.splunk.com/en/splunk-enterprise/get-started/install-and-upgrade/10.4/start-using-splunk-enterprise/start-splunk-enterprise-for-the-first-time) and [`user-seed.conf`](https://help.splunk.com/en/data-management/splunk-enterprise-admin-manual/10.4/configuration-file-reference/10.4.2-configuration-file-reference/user-seed.conf).

## Pre-install checks
Before creating the Splunk account, check whether the `splunk` group and user already exist. Create only missing entries; inspect an existing account before changing its group or other settings.

```bash
getent group splunk >/dev/null || sudo groupadd --system splunk
if id splunk >/dev/null 2>&1; then
  id splunk
else
  sudo useradd --system --gid splunk --home-dir /opt/splunk --shell /usr/sbin/nologin splunk
fi
```

Check for running Splunk processes before installing or replacing files. Investigate and stop any listed process cleanly before continuing.

```bash
pgrep -af '[s]plunk'
```

## Installer tarball reuse and cleanup
Check the user's `~/Downloads` directory for a Splunk Enterprise installer tarball before downloading. If one is found, use that file and do not download another copy from the internet. Confirm that its version/build matches the intended install and verify its checksum against the official download:

```bash
find "$HOME/Downloads" -maxdepth 1 -type f \\( -name 'splunk-*.tgz' -o -name 'splunk-*.tar.gz' \\) -print
sha512sum "$INSTALL_TARBALL"
```

Set `INSTALL_TARBALL` to the existing archive path when one is found. If the version/build does not match, stop and resolve the mismatch rather than downloading another copy. Download the official tarball into `~/Downloads` only when the search finds no tarball. Keep the archive after installation by default; opt into cleanup only after a successful install by setting `KEEP_INSTALL_TARBALL=false`:

```bash
KEEP_INSTALL_TARBALL="${KEEP_INSTALL_TARBALL:-true}"
# Run only after successful installation; the default is to retain the tarball.
if [[ "$KEEP_INSTALL_TARBALL" == false ]]; then
  rm -- "$INSTALL_TARBALL"
fi
```

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
