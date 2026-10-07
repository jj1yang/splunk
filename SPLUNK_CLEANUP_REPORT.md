# Splunk Cleanup Report

Audit date: 2026-10-07

## Actions performed

- Stopped and disabled the identified host services: `OpsSplunkForwarder.service`, `SplunkForwarder.service`, and `splunk-otel-collector.service`. `Splunkd.service` was not loaded under that name.
- Purged the `splunk-otel-collector` package and removed the remaining manually installed service unit/drop-in and Splunk-specific host configuration, APT source/key, and sysctl configuration.
- Removed the remaining OpenTelemetry collector cache file and Splunk-related log files.
- Verified `/opt/splunkforwarder` was not owned by a Debian package, then removed the manually extracted Universal Forwarder directory.
- Reloaded systemd after removing the unit files.

## Final host audit

- No matching Splunk or collector processes, systemd service units, or installed Debian packages were found.
- No Splunk/collector-named files remained under `/etc` or `/opt`.
- No matching cron entries or log files were found in the audited cron locations, `/var/log`, or `/opt`.

## Artifacts intentionally retained

- A stopped Docker container using `splunk/splunk:9.4.5` remains. Its volumes are mounted at `/opt/splunk/etc` and `/opt/splunk/var` inside the container and were retained to preserve configuration and data.
- Cached APT repository metadata for the Splunk OpenTelemetry Collector remains under `/var/lib/apt/lists`; the APT source and signing key were removed.
- PBIS identity-cache files with Splunk-related naming remain untouched because they may be used for domain authentication.

The existing `SPLUNK_SETUP.md` was left unchanged; it records setup-time service verification and is not a current service inventory.

This audit covers the host service/configuration cleanup and the paths listed above. It does not claim that all Splunk-related data has been erased from Docker storage or identity caches.
