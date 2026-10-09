````markdown
# Configure the Monitoring Console in distributed mode

The following steps show you how to configure the monitoring console in distributed mode manually.

Optionally, you can enable the monitoring console to configure distributed mode automatically. See [Enable automatic distributed mode configuration](#enable-automatic-distributed-mode-configuration).

> **NOTE:** Changes to Splunk configurations, such as turning off lookups or alert actions, or making edits to the `populate_lookup` and other lookup configurations, can result in unexpected behavior, such as saved searches not working as you would expect. Before you configure the monitoring console for distributed mode, review your Splunk configuration settings, and specifically check the configuration file precedence to confirm that your configuration does not interfere with monitoring console operations. For more information about configuration file precedence, see *Configuration file reference* in the *Admin Manual*.

To configure the monitoring console in distributed mode:

1. Log into the instance on which you want to configure the monitoring console. By default, the instance is in standalone mode, unconfigured.
2. In Splunk Web, select **Monitoring Console > Settings > General Setup**.
3. Click **Distributed mode**.
4. Confirm the following:
   - The columns labeled **instance** and **machine** are populated correctly and show unique values within each column.
   - The server roles are correct. For example, a search head that is also a license manager must have both server roles listed. If not, click **Edit > Edit Server Roles** and select the correct server roles for the instance.
   - If you are using indexer clustering, make sure the cluster manager instance is set to the cluster manager server role. If not, click **Edit > Edit Server Roles** and select the correct server role.
   - If you are hosting the monitoring console on an instance other than the cluster manager, you must add the cluster manager instance as a search peer and configure the monitoring console instance as a search head in that cluster. See *Enable a search head* in *Managing Indexers and Clusters of Indexers*.
5. *(Optional)* Set custom groups. Custom groups are tags that map directly to distributed search groups. You might find groups useful, for example, if you have multisite indexer clustering in which each group can consist of the indexers in one location, or if you have an indexer cluster plus standalone peers. Custom groups are allowed to overlap. For example, one indexer can belong to multiple groups. See *Create distributed search groups* in the *Distributed Search* manual.
6. Click **Apply Changes**.

If you add another node to your deployment later, click **Settings > General Setup** and check that these items are accurate.

## Enable automatic distributed mode configuration

You can optionally enable automatic distributed mode configuration for the monitoring console. When enabled, the monitoring console automatically identifies existing search peers and configures itself in distributed mode. You must have search peers already added to the monitoring console before you can use automatic distributed mode configuration. For more information, see *Add Splunk Enterprise instances to the monitoring console*.

To enable automatic distributed mode configuration:

1. Edit the `splunk_monitoring_console_assets.conf` file in `etc/apps/splunk_monitoring_console/local`.
2. Under the `[settings]` stanza, set `mc_auto_config` to `enabled`, as shown:

   ```ini
   [settings]
   mc_auto_config = enabled
   ```

3. If you want to implement automatic distributed mode configuration immediately, restart Splunk. Otherwise, changes are implemented automatically every hour with no restart required.

## Reset server roles after restart

After you configure the monitoring console in distributed mode, a restart of the instance hosting the monitoring console can cause any changes to server role settings on the instances you are monitoring to be lost.

To properly reset server roles after restart of the distributed monitoring console:

1. Click **Settings > General Setup > Reset All Settings > Refresh**. This restores the monitoring console to its original default configuration.
2. Click **Distributed**.
3. For the remote instances whose server roles you want to change, click **Edit**.
4. Select or remove the specific server roles. Click **Save**.
5. Click **Apply Changes**.

## Next step

To configure the monitoring console for forwarders, see *Configure forwarder monitoring for the Monitoring Console*.

---

*Copyright 2025 Splunk.*
````

**Notes on conversion:**
- Removed PDF page numbers and repeated headers/footers.
- Replaced ligature characters (e.g., "ﬁ") with standard text.
- Corrected the source's "set `mc_auto_config` to enable" to `enabled` to match the code sample.
