# Ubuntu 22.04 (Jammy) → 24.04 (Noble) upgrade runbook

Use this on CIS-hardened (and similar) Jammy servers. The release upgrade is not the hard part; three blockers usually fail first: `/tmp` `noexec`, split `/usr` (`usrmerge`), and a pending reboot (`libc6`).

Do the steps in order. Do not run `do-release-upgrade` until steps 1–4 are clean.

## 0. Snapshot / access

- Confirm console or out-of-band access (SSH will drop on reboot).
- Note hostname, IP, and that you can get back in after reboot.
- Optional: copy `/etc/apt/sources.list` and `/etc/fstab` somewhere off-box.

```bash
lsb_release -ds
uname -r
uptime
```

## 1. Fix `/tmp` `noexec`

CIS often mounts `/tmp` as tmpfs with `noexec`. Upgrade scripts need to execute from `/tmp`.

Check:

```bash
findmnt -T /tmp -o TARGET,SOURCE,FSTYPE,OPTIONS
grep -E '/tmp' /etc/fstab
```

If options include `noexec`:

```bash
sudo cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d%H%M%S)
sudo sed -i 's|^\(tmpfs[[:space:]]\+/tmp[[:space:]]\+tmpfs[[:space:]]\+defaults,\)noexec,|\1|' /etc/fstab
sudo mount -o remount,exec /tmp
findmnt -T /tmp -o OPTIONS
```

`fstab` `/tmp` line should look like:

```
tmpfs   /tmp    tmpfs   defaults,nosuid,nodev 0   0
```

Leave `/dev/shm` `noexec` unless you have a reason to change it.

## 2. Finish Jammy updates first

Stay on Jammy repos. Do not point APT at Noble yet.

```bash
grep -E '^deb ' /etc/apt/sources.list
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
```

If `apt` is already talking to `noble`, stop. Restore Jammy sources (see [Rollback if sources were rewritten](#rollback-if-sources-were-rewritten)), then update again.

## 3. Merged `/usr` (`usrmerge`)

Noble `base-files` refuses to unpack on a split `/usr`:

```
The base-files package cannot be installed because this system has a split /usr.
Please install the usrmerge package to convert this system to merged-/usr.
```

The check fails if **any** of these is a **real directory** (not a symlink):

`/bin` `/sbin` `/lib` `/lib32` `/lib64` `/libo32`

A common CIS/legacy trap: `/bin` `/lib` `/lib64` `/sbin` are already merged, but **`/lib32` is still a directory** (e.g. pbis-open 32-bit NSS libs).

Check:

```bash
for d in bin sbin lib lib32 lib64 libo32; do
  echo -n "/$d: "
  if [ -e "/$d" ] || [ -L "/$d" ]; then
    ls -ld "/$d"
    if [ -d "/$d" ] && [ ! -h "/$d" ]; then
      echo "  *** REAL DIRECTORY — usrmerge required ***"
    fi
  else
    echo "does not exist"
  fi
done
```

Convert:

```bash
sudo apt-get install -y usrmerge
sudo /usr/lib/usrmerge/convert-usrmerge
```

Success looks like:

```
The system has been successfully converted.
```

Re-check until every existing path above is a symlink into `/usr`.

## 4. Reboot if required (before the release upgrade)

`do-release-upgrade` will refuse if `/var/run/reboot-required` exists (often `libc6` after Jammy updates).

```bash
cat /var/run/reboot-required 2>/dev/null
cat /var/run/reboot-required.pkgs 2>/dev/null
```

If present:

```bash
sudo reboot
```

After reconnect:

```bash
test -f /var/run/reboot-required && echo STILL_REQUIRED || echo ok
lsb_release -ds   # still 22.04
```

## 5. Release upgrade to 24.04

Confirm `Prompt=lts` in `/etc/update-manager/release-upgrades`.

```bash
sudo do-release-upgrade
```

- Answer **yes** to start.
- Continue past third-party / SSH / removal warnings unless there is a hard error.
- For conffile prompts:
  - **Keep local** for CIS/security files: `sshd_config`, `sshd_config.d`, pam, `login.defs`, sysctl, audit, `fstab`, sudoers.
  - **Maintainer version** for generic package defaults.

`do-release-upgrade` often uses `screen`. Stay attached.

When it asks to reboot at the end, reboot (or reboot immediately after it finishes):

```bash
sudo reboot
```

## 6. Verify Noble

After the post-upgrade reboot:

```bash
lsb_release -ds          # Ubuntu 24.04.x LTS
uname -r                 # 6.8.x, not 5.15.x
cat /etc/os-release
sudo apt-get update
sudo apt-get check
sudo dpkg --audit
test -f /var/run/reboot-required && cat /var/run/reboot-required.pkgs
```

Expect:

- `VERSION_CODENAME=noble`
- kernel `6.8.0-*-generic` (or current Noble generic/HWE)
- `apt-get check` and `dpkg --audit` clean

If still on `5.15`, reboot again. Noble userspace with a Jammy kernel is incomplete.

## Rollback if sources were rewritten

If `do-release-upgrade` dies after switching APT to Noble, but `lsb_release` is still 22.04 and `base-files` never unpacked:

1. Confirm nothing actually upgraded:

```bash
lsb_release -ds
apt-cache policy base-files apt python3
```

Installed versions should still be Jammy (`12ubuntu*`, `apt 2.4.x`, `python3 3.10.x`). Candidate may already be Noble — that only means sources are wrong.

2. Restore Jammy `sources.list`. `/etc/apt/sources.list.distUpgrade` may already be Noble; do not blindly restore it.

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.noble-failed.$(date +%Y%m%d%H%M%S)
sudo tee /etc/apt/sources.list >/dev/null <<'EOF'
deb http://us.archive.ubuntu.com/ubuntu jammy main restricted
deb http://us.archive.ubuntu.com/ubuntu jammy-updates main restricted
deb http://us.archive.ubuntu.com/ubuntu jammy universe
deb http://us.archive.ubuntu.com/ubuntu jammy-updates universe
deb http://us.archive.ubuntu.com/ubuntu jammy multiverse
deb http://us.archive.ubuntu.com/ubuntu jammy-updates multiverse
deb http://us.archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted
deb http://security.ubuntu.com/ubuntu jammy-security universe
deb http://security.ubuntu.com/ubuntu jammy-security multiverse
EOF
sudo apt-get update
```

3. Fix the actual blocker (`/tmp` `noexec` and/or `usrmerge`), then start again from step 2.

If Noble packages **did** unpack, do not try to roll back with `sources.list`. Restore from backup/snapshot instead.

## Order (checklist)

1. Remount `/tmp` without `noexec`; fix `fstab`.
2. `apt-get update && apt-get upgrade` on **Jammy**.
3. `convert-usrmerge` until `/bin` `/sbin` `/lib` `/lib32` `/lib64` are symlinks (skip missing dirs).
4. Reboot if `/var/run/reboot-required` exists.
5. `do-release-upgrade`.
6. Reboot onto the 6.8 kernel and verify 24.04.

## Notes from the first host

- Jammy standard support ends **May 2027**; Pro/ESM through May 2032.
- Third-party lists (e.g. Splunk OTel) may be disabled or converted to DEB822; re-enable after verify if needed.
- `usrmerge` can already be installed while `/lib32` is still unmerged — always inspect the directories, do not trust the package alone.
