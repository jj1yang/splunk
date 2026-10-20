# Splunk Universal Forwarder Setup

Adapted from `SPLUNK_SETUP.md`. The procedure below describes fresh installations; the final section separately records a previous host's completed installation and remaining limitations. Do not rerun extraction or credential initialization on a host with an existing installation.

Run on the active host unless another target is explicitly requested. Historical hostnames in the installation record are not prerequisites: do not require the active shell's hostname or IP address to match them. Check the target's actual OS, installation, process, and credential state before proceeding.

Follow the sections in order in Bash, replacing example values first. This guide covers a fresh, standalone Linux tarball installation, not an upgrade or a co-located Enterprise/UF deployment. Stop on errors; a failed subshell does not prevent you from manually running later sections.

Always accept the Splunk license noninteractively with `--accept-license`; never launch the license pager or ask for interactive license confirmation. This accepts the agreement rather than disabling license enforcement. Before the first successful start, do not run bare Splunk CLI checks such as `splunk version` or `splunk status`: they can trigger first-run license and credential initialization. Read `/opt/splunkforwarder/etc/splunk.version` to check the extracted version/build without invoking the CLI. Make `splunk start --accept-license` the first Splunk CLI invocation after extraction, and keep `--accept-license` on subsequent explicit start commands. Leave administrator credential prompts enabled.

Launch first start and authenticated CLI verification directly in an interactive terminal, without a separate approval, manual command handoff, or "done"/"continue" message. The user supplies the UF administrator name and password at the terminal prompts in both cases; password input must remain hidden. Wait for command completion and continue automatically on success. If interactive user input is unavailable, report that limitation rather than inventing credentials or claiming authentication succeeded. Never request passwords in chat or put them in command-line arguments, logs, or this document.

## Installation
- Platform used for this installation: Ubuntu 24.04.5 LTS, x86_64. Verify support separately for other hosts and UF releases.
- Product: Splunk Universal Forwarder. Select a UF release supported by the receiving Splunk deployment and confirm its version/build on the official download page; do not assume the Enterprise guide's version/build is available for UF.
- Install directory: `/opt/splunkforwarder`, owned by `splunkfwd:splunkfwd` with mode `750`.
- Verify the official UF Linux tarball's SHA-512 checksum before installation.
- Keep the downloaded installer tarball after installation by default. Remove it only when cleanup is explicitly requested.
- For a fresh installation, use the first-start procedure below. The UF has no Splunk Web interface; its administrator account is for local management and authenticated CLI operations.

## Pre-install checks
Confirm OS/architecture support using the [OS support table](https://help.splunk.com/en/splunk-enterprise/get-started/install-and-upgrade/10.2/plan-your-splunk-enterprise-installation/system-requirements-for-use-of-splunk-enterprise-on-premises) and [UF prerequisites](https://help.splunk.com/en/splunk-enterprise/forward-and-process-data/universal-forwarder-manual/10.2/deploy-the-universal-forwarder/universal-forwarder-deployment-prerequisites). Select the documentation version matching your intended UF release; the linked 10.2 requirements are not a guarantee for other releases. Check the [forwarder/indexer compatibility matrix](https://help.splunk.com/en/splunk-enterprise/release-notes-and-updates/compatibility-matrix/splunk-products-version-compatibility/compatibility-between-forwarders-and-splunk-enterprise-indexers), support lifecycle, and add-on requirements.

Check space for extracted software, the retained installer, logs, and configured queues. Confirm OpenSSL is available for password hashing:

```bash
uname -m
df -h /opt "$HOME"
command -v openssl
```

Before creating the UF service account, check whether the `splunkfwd` group and user already exist. Create only missing entries; inspect an existing account before changing its group or other settings.

```bash
getent group splunkfwd >/dev/null || sudo groupadd --system splunkfwd
if id splunkfwd >/dev/null 2>&1; then
  id splunkfwd
else
  sudo useradd --system --gid splunkfwd --home-dir /opt/splunkforwarder --shell /usr/sbin/nologin splunkfwd
fi
```

Check for running Splunk processes. If any are listed, stop here and investigate; do not stop an unrelated Enterprise instance. No matches produces exit status `1`, which is normal on a fresh host.

```bash
pgrep -af '[s]plunk'
```

## Locate and verify the installer
Check `~/Downloads` for a UF installer before downloading. Create the directory if necessary:

```bash
mkdir -p "$HOME/Downloads"
find "$HOME/Downloads" -maxdepth 1 -type f \( -name 'splunkforwarder-*.tgz' -o -name 'splunkforwarder-*.tar.gz' \) -print
```

If an archive exists, use it and do not download another copy. Select explicitly if multiple archives exist. If the version/build or architecture does not match the intended install, stop and resolve the mismatch. Download an official Linux x86_64 UF tarball only when the search finds no UF archive. Obtain it and the published checksum from the [UF download page](https://www.splunk.com/en_us/download/universal-forwarder.html).

Set `INSTALL_TARBALL` to the selected archive's absolute path before checking it. Replace the example filename:

```bash
INSTALL_TARBALL="$HOME/Downloads/splunkforwarder-VERSION-BUILD-linux-amd64.tgz"
sha512sum "$INSTALL_TARBALL"
```

Compare the complete SHA-512 result with the official published value; running `sha512sum` alone does not verify a match. Stop on a missing file or mismatch. Retain the installer until the final cleanup section.

## Extract the verified installer
Run only after checksum verification. This block aborts if the target exists, including a stopped installation or dangling symlink. Use the supported upgrade procedure for existing installations instead.

```bash
(
  set -euo pipefail
  : "${INSTALL_TARBALL:?Set INSTALL_TARBALL to the verified archive first}"
  test -f "$INSTALL_TARBALL"
  sudo -v
  if sudo test -e /opt/splunkforwarder || sudo test -L /opt/splunkforwarder; then
    printf 'Target already exists; use the supported upgrade procedure instead.\n' >&2
    exit 1
  fi
  sudo tar --no-same-owner -xzf "$INSTALL_TARBALL" -C /opt
  sudo chown -R splunkfwd:splunkfwd /opt/splunkforwarder
  sudo chmod 750 /opt/splunkforwarder
)
```

Do not continue if extraction or ownership setup fails.

## First start: accept the license and set admin credentials
Run only on a fresh installation before its first start. Use the interactive procedure by default; do not also run the optional seed-file alternative.

### Default: interactive first start
Launch this block directly in an interactive terminal. The user enters the desired UF administrator name and password, including confirmation, at Splunk's prompts. These are UF credentials, not OS service-account credentials. Do not pass `--no-prompt` or `--answer-yes`; credential prompts must remain available.

```bash
(
  set -euo pipefail
  sudo -v
  if sudo test -e /opt/splunkforwarder/etc/passwd ||
     sudo test -L /opt/splunkforwarder/etc/passwd ||
     sudo test -e /opt/splunkforwarder/etc/system/local/user-seed.conf ||
     sudo test -L /opt/splunkforwarder/etc/system/local/user-seed.conf; then
    printf 'Existing credentials or seed file found; inspect before proceeding.\n' >&2
    exit 1
  fi
  sudo -u splunkfwd /opt/splunkforwarder/bin/splunk start --accept-license
  sudo -u splunkfwd test -s /opt/splunkforwarder/etc/passwd
)
```

On success, continue with the remaining applicable setup sections without a separate confirmation. A nonempty credential file does not prove authentication; run authenticated CLI verification below after systemd setup.

### Optional: hashed seed-file alternative
Use only when explicitly requested instead of interactive first start. `ADMIN_USER` defaults to `admin`. Splunk ignores `user-seed.conf` if `$SPLUNK_HOME/etc/passwd` already exists; this example refuses to overwrite existing credentials or a seed file.

Use a salted SHA-512 crypt hash (`HASHED_PASSWORD`) instead of a plaintext `PASSWORD` configuration value. Ubuntu's `openssl passwd -6 -stdin` produces this format without putting the password in command-line arguments. Hashing avoids configuration escaping problems, including passwords ending in a backslash. For environments with additional cryptographic restrictions, use an approved hash-generation procedure.

The example checks the default minimum of eight printable ASCII characters and asks for confirmation. Choose a password that also meets organizational policy; hashing does not validate additional policy requirements. The seed file is mode `600`; an exit trap removes it on success or failure. Do not enable shell tracing, display the hash, or commit/retain the seed file. If cleanup fails or the process is killed abruptly, remove the seed file before proceeding.

```bash
ADMIN_USER="${ADMIN_USER:-admin}"
(
  set -euo pipefail
  export LC_ALL=C
  command -v openssl >/dev/null
  sudo -v
  if [[ ! "$ADMIN_USER" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    printf 'Use an admin name with letters, digits, dots, underscores, or hyphens.\n' >&2
    exit 1
  fi
  IFS= read -r -s -p "Universal Forwarder admin password: " ADMIN_PASSWORD
  printf '\n'
  if (( ${#ADMIN_PASSWORD} < 8 )) || [[ "$ADMIN_PASSWORD" == *[![:print:]]* ]]; then
    printf 'Use at least eight printable ASCII characters and satisfy your password policy.\n' >&2
    exit 1
  fi
  IFS= read -r -s -p "Confirm Universal Forwarder admin password: " ADMIN_PASSWORD_CONFIRM
  printf '\n'
  if [[ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]]; then
    printf 'Passwords do not match.\n' >&2
    exit 1
  fi
  ADMIN_PASSWORD_HASH=$(printf '%s\n' "$ADMIN_PASSWORD" | openssl passwd -6 -stdin)
  unset ADMIN_PASSWORD ADMIN_PASSWORD_CONFIRM
  [[ "$ADMIN_PASSWORD_HASH" == '$6$'* ]]

  SEED_FILE=/opt/splunkforwarder/etc/system/local/user-seed.conf
  if sudo test -e /opt/splunkforwarder/etc/passwd ||
     sudo test -e "$SEED_FILE" || sudo test -L "$SEED_FILE"; then
    printf 'Existing credentials or seed file found; inspect before proceeding.\n' >&2
    exit 1
  fi
  sudo install -d -o splunkfwd -g splunkfwd -m 700 /opt/splunkforwarder/etc/system/local
  trap 'sudo rm -f -- "$SEED_FILE"' EXIT
  sudo install -o splunkfwd -g splunkfwd -m 600 /dev/null "$SEED_FILE"
  printf '[user_info]\nUSERNAME = %s\nHASHED_PASSWORD = %s\n' "$ADMIN_USER" "$ADMIN_PASSWORD_HASH" |
    sudo -u splunkfwd tee "$SEED_FILE" >/dev/null
  unset ADMIN_PASSWORD_HASH

  sudo -u splunkfwd /opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt
  for attempt in {1..60}; do
    if sudo -u splunkfwd test -s /opt/splunkforwarder/etc/passwd; then
      break
    fi
    sleep 1
  done
  if ! sudo -u splunkfwd test -s /opt/splunkforwarder/etc/passwd; then
    sudo -u splunkfwd /opt/splunkforwarder/bin/splunk stop
    printf 'Administrator initialization failed; inspect startup logs before retrying.\n' >&2
    exit 1
  fi
)
```

`--accept-license` accepts the license without the interactive agreement prompt. `--no-prompt` suppresses interactive credential creation; seed credentials first and verify an authenticated CLI operation below. A nonempty `etc/passwd` is a basic creation check, not proof of successful authentication. Stop on any error. See [UF startup](https://help.splunk.com/en/splunk-cloud-platform/forward-and-process-data/universal-forwarder-manual/10.4/configure-the-universal-forwarder/start-or-stop-the-universal-forwarder) and [`user-seed.conf`](https://help.splunk.com/en/data-management/splunk-enterprise-admin-manual/10.4/configuration-file-reference/10.4.2-configuration-file-reference/user-seed.conf).

## Configure forwarding and inputs
For an install-only setup, skip this entire section and optional deployment-server enrollment. Continue with service setup and local verification. No receivers or application inputs are required simply to install and start UF.

When forwarding is required, the receivers must already have a Splunk-to-Splunk receiving input enabled, typically TCP `9997`, not a generic raw TCP input. Permit outbound connectivity from the UF. Choose exactly one output-configuration path below; do not apply the plaintext example to a TLS-required deployment.

### TLS-required deployments
Do not run `add forward-server` before configuring TLS: the UF is already running, and internal logs can be forwarded as soon as outputs become active.

1. Stop the initially started UF with `sudo -u splunkfwd /opt/splunkforwarder/bin/splunk stop`.
2. While stopped, install approved CA certificates and, if required by the receiver, a client certificate/private key with restrictive ownership and permissions.
3. Configure the receiver group and TLS settings together in `/opt/splunkforwarder/etc/system/local/outputs.conf` or an approved app. Configure trusted CA validation and receiver identity/hostname validation; encryption alone is insufficient. Follow the selected release's [forwarding TLS procedure](https://help.splunk.com/en/splunk-enterprise/administer/manage-users-and-security/9.4/secure-splunk-platform-communications-with-transport-layer-security-certificates/configure-splunk-indexing-and-forwarding-to-use-tls-certificates). Do not disable certificate checks to work around failures.
4. Review effective configuration with `sudo -u splunkfwd /opt/splunkforwarder/bin/splunk btool outputs list --debug` before starting. Protect the output because it can contain sensitive settings.
5. Start with `sudo -u splunkfwd /opt/splunkforwarder/bin/splunk start --accept-license`, inspect forwarding/TLS errors, and confirm the receiver reports encryption before adding application inputs.

For Splunk Cloud Platform, use the stack-specific UF Credentials package and Cloud onboarding instructions instead of the generic on-premises TLS procedure or plaintext example. If a deployment server manages outputs, prepare its approved TLS app before enrolling the UF.

### Plaintext lab-only forwarding
Use this example only when unencrypted forwarding is explicitly acceptable on an isolated lab network. Replace the destinations with actual receiver hostnames or IP addresses:

```bash
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk add forward-server indexer1.example.com:9997
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk add forward-server indexer2.example.com:9997
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk list forward-server
```

Enter the UF's local administrator credentials when prompted; do not put passwords in command-line arguments. Multiple receivers in one output group provide load balancing and failover, so not every receiver must appear active simultaneously. Check the effective group configuration with `btool`; multiple default groups clone data rather than load balance it.

### Application inputs

Forwarding destinations alone do not collect application logs. Configure inputs locally or through a deployment server. For a file-monitor input, replace the example path, index, and sourcetype with actual values; the target index must exist on the receiving deployment:

```bash
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk add monitor /path/to/application/logs -index your_index -sourcetype your_sourcetype
```

Before systemd capability grants, `splunkfwd` needs ordinary directory traversal and file-read access. Systemd can grant broader access as explained below; do not assume Unix file permissions alone restrict the running UF. Prefer narrow groups/ACLs when broad file-read capability is unnecessary, and ensure rotated logs retain required access. Do not make sensitive logs world-readable.

## Service
For a fresh, standalone UF installation, stop the initially started process and enable systemd boot start:

```bash
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk stop
sudo /opt/splunkforwarder/bin/splunk enable boot-start -user splunkfwd -group splunkfwd -systemd-managed 1
sudo /opt/splunkforwarder/bin/splunk display boot-start
sudo systemctl cat SplunkForwarder.service --no-pager
```

Confirm the actual unit name before using subsequent commands. Modern Linux UF boot-start setup can grant `AmbientCapabilities=CAP_DAC_READ_SEARCH`, allowing the process to bypass file-read and directory-traversal permission checks even though it runs as `splunkfwd`. This can also affect scripts/add-ons. This guide uses `splunkfwd`, the dedicated non-root account recommended by Splunk for modern Linux UF installations. A custom non-root account is also possible; its name alone does not determine its privileges.

**Choose the file-read privilege model before starting the service:**
- Retain the generated capability only if broad file-read access is explicitly approved.
- Otherwise run `sudo systemctl edit SplunkForwarder.service` and add this drop-in. Clearing `AmbientCapabilities` removes all ambient grants; assess any add-ons that need capabilities and grant only those explicitly approved.

```ini
[Service]
AmbientCapabilities=
```

After choosing the model, reload systemd, inspect effective settings, enable boot start explicitly, and start:

```bash
sudo systemctl daemon-reload
sudo systemctl show SplunkForwarder.service -p User -p Group -p AmbientCapabilities
sudo systemctl enable --now SplunkForwarder.service
sudo systemctl is-enabled SplunkForwarder.service
```

If the capability is removed, verify access to all intended inputs using ordinary permissions. Recheck the unit/drop-in after upgrades or boot-start regeneration. See [Linux least-privileged user management](https://help.splunk.com/en/data-management/onboard-data-to-splunk-enterprise/universal-forwarder-manual/10.6/working-with-the-universal-forwarder/manage-a-linux-least-privileged-user).

- Expected systemd unit: `SplunkForwarder.service`. Confirm the name reported by `enable boot-start`; existing installations may use a custom unit name.
- Boot start: verify it is enabled rather than assuming success.
- Runtime account: `splunkfwd`.
- Splunk Web: not available; there is no web endpoint to check on port `8000`.
- Local management: UF 9.1+ defaults to `mgmtMode=auto`, using Unix-domain sockets on Linux when available. A listening TCP `8089` port is not required for local CLI operation. If TCP management is enabled, it commonly uses `8089`; do not expose it publicly.
- Forwarding: outbound connections to configured receivers, typically TCP `9997`. A sending UF does not need its own receiving listener on `9997`.

Once systemd manages the UF, use `systemctl` for service lifecycle operations:

```bash
sudo systemctl restart SplunkForwarder.service
```

Check the selected release's [management-mode behavior](https://help.splunk.com/en/data-management/onboard-data-to-splunk-enterprise/universal-forwarder-manual/9.4/working-with-the-universal-forwarder/about-management-mode-for-the-universal-forwarder). Do not enable TCP management solely to satisfy a port-listening check.

## Optional deployment-server enrollment
Skip for locally managed UFs. Otherwise confirm deployment-server/client version compatibility and prepare the correct server-class assignment and approved apps first. Enrollment permits centrally managed configuration and potentially executable app content; use only a trusted server. Configure deployment-server TLS trust/identity validation according to policy before enrollment; forwarding TLS settings do not secure this communication.

Allow outbound connectivity to the deployment server's management endpoint, typically TCP `8089`. This is separate from any local UF management listener. Replace the example hostname:

```bash
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk set deploy-poll ds1.example.com:8089
sudo systemctl restart SplunkForwarder.service
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk btool deploymentclient list --debug
```

Authenticate interactively when prompted. Confirm the deployment server lists the client and expected apps arrive under `/opt/splunkforwarder/etc/apps`. Recheck inputs/outputs and receiver connectivity after deployment. Avoid conflicting local configuration: `etc/system/local` settings can override settings delivered in apps. See [CLI configuration and enrollment](https://help.splunk.com/en/splunk-enterprise/forward-and-process-data/forwarding-and-receiving-data/10.4/configure-forwarders/configure-the-universal-forwarder-using-configuration-files).

## Verification and logs
Check service, process, and receiver status directly in the same interactive setup session:

```bash
sudo systemctl status SplunkForwarder.service --no-pager
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk status
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk list forward-server
```

The `list forward-server` command is the authenticated CLI verification. Launch it directly without a separate approval or manual command handoff. The user supplies the UF administrator name and password at the CLI prompts when required; an existing valid cached session may avoid prompts. Keep password input hidden and do not use `-auth username:password`. Inspect the command's exit status and output, then continue automatically on success instead of asking the user to report the result. Stop and resolve authentication failures before marking verification complete. For install-only setup, both active and configured-but-inactive lists must show `None`.

Inspect effective forwarding and input configuration. `btool` shows configuration, not receiver connectivity. Its output may contain sensitive settings; redact it before sharing.

```bash
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk btool outputs list --debug
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk btool inputs list --debug
```

Review systemd startup logs and forwarding errors:

```bash
sudo journalctl -u SplunkForwarder.service --no-pager
sudo -u splunkfwd grep -Ei 'TcpOutputProc|ERROR|WARN' /opt/splunkforwarder/var/log/splunk/splunkd.log
```

On a search head, search a recent time range for forwarded internal events. Replace `your_uf_hostname` with the UF's configured event host:

```spl
index=_internal host="your_uf_hostname" sourcetype=splunkd
| stats count latest(_time) AS last_seen by host
| convert ctime(last_seen)
```

For an install-only setup, successful local verification means the service is enabled and active, `splunkd` runs as the intended service account, and authenticated local CLI operations work. Both forward-server lists should show `None`. An `outputs.conf` not-configured error is expected in this intentionally unconfigured state; this does not establish forwarding readiness.

For a forwarding deployment, additionally verify that a receiver is active and expected events reach the receiving deployment. Also search the configured application index to verify any added data inputs. These are verification criteria; the final section records which checks were completed on this host.

For TLS deployments, also confirm the receiver's connection metrics/logs show TLS and check for certificate-validation errors. An active receiver entry or successful TCP connection alone does not prove encryption or identity validation. For deployment-managed UFs, verify enrollment and expected app versions as well.

## Optional installer cleanup
Run only after all applicable verification above succeeds. The default is to retain the archive. Set `KEEP_INSTALL_TARBALL=false` only when cleanup is explicitly requested; confirm `INSTALL_TARBALL` still names the selected installer.

```bash
KEEP_INSTALL_TARBALL="${KEEP_INSTALL_TARBALL:-true}"
if [[ "$KEEP_INSTALL_TARBALL" == false ]]; then
  (
    set -euo pipefail
    : "${INSTALL_TARBALL:?Set INSTALL_TARBALL to the installer archive}"
    test -f "$INSTALL_TARBALL"
    rm -- "$INSTALL_TARBALL"
  )
fi
```

## Final installation record — 2026-10-19 UTC
This historical section records the completed work on a previous host; it does not identify or restrict the target for future runs, and it is not a claim that forwarding is configured or that startup logs are error-free.

### Installed software and service
- OS: Ubuntu 24.04.5 LTS, x86_64.
- UF: **10.6.1.1**, build **`b2ae2962645c`**.
- Installation: `/opt/splunkforwarder`, owned by `splunkfwd:splunkfwd`, mode `750`.
- Runtime account: `splunkfwd`, UID `999`, primary group `splunkfwd`, GID `987`; home `/opt/splunkforwarder`, shell `/usr/sbin/nologin`.
- The initially created `splunk` user/group were renamed to `splunkfwd` while preserving their numeric IDs. Installation ownership and numeric ACL identities were retained.
- Systemd unit: `/etc/systemd/system/SplunkForwarder.service`; verified enabled and active after the migration.
- Launch configuration: `/opt/splunkforwarder/etc/splunk-launch.conf` sets `SPLUNK_OS_USER=splunkfwd`.
- Hardening: `NoNewPrivileges=yes`; `/etc/systemd/system/SplunkForwarder.service.d/10-restrict-ambient-capabilities.conf` clears `AmbientCapabilities`. The running process was verified with zero ambient capabilities.
- Future application inputs require explicit file-read and directory-traversal permissions, suitable groups, or ACLs, including access after log rotation.

### Credentials, configuration, and retained files
- Administrator initialization completed; an authenticated `list forward-server` operation succeeded before the OS-account rename. This was not an authentication retest after migration.
- `/opt/splunkforwarder/etc/passwd` remains owned by the service account with mode `600`; the temporary `user-seed.conf` was removed. No administrator password or password hash is recorded here.
- No receivers, application inputs, or deployment-server enrollment were added. Existing packaged internal inputs remain; this is not a zero-input configuration.
- Both active and configured-but-inactive forward-server lists were `None` at the authenticated check. Migration preserved existing input/output/enrollment configuration.
- Installer retained at `/home/splunker/Downloads/splunkforwarder-10.6.1.1-b2ae2962645c-linux-amd64.tgz`; its SHA-512 matched the official checksum before installation.
- Pre-migration copies of the service unit, launch configuration, hardening drop-in, and guide are in `/var/backups/splunk-uf-account-20261019T232618Z`. These are targeted backups, not a full installation backup.
- The original `SPLUNK_SETUP.md` was left unchanged.

### Known unresolved startup issue
Startup logs report `Specified filename "lookup_handler.py" not found in search path.`

The `[script:lookup_handler]` stanza in `/opt/splunkforwarder/etc/system/default/restmap.conf` registers `/data/lookup_edit` and references the missing script. The same reference exists in the checksum-verified official UF archive, which does not contain the script. This strongly indicates a vendor packaging/configuration inconsistency rather than a local deletion.

No supported fix or documented handler-disable setting was verified. At the user's direction, vendor defaults were left unchanged; no substitute script, undocumented `disabled` setting, or log suppression was added. The error recurred after the account migration, while the service remained active. Changing the service-account name does not resolve it.

Request a corrected package or an approved endpoint-specific workaround through [Splunk Support](https://www.splunk.com/en_us/support-and-services.html), providing the UF version/build, stanza, error, and official-archive findings. No support case was submitted during this work.

### Completion boundary
Installation, systemd boot start, account migration, hardening checks, and guide Bash syntax validation are complete. Forwarding connectivity, TLS, application-log collection, and deployment-server enrollment remain unconfigured and unverified by design. The missing-handler issue remains open pending a vendor-supported resolution.
