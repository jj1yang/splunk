To configure **Distributed Search** on a **Splunk Search Head (SH)**, the process depends entirely on whether your backend Indexers are standalone (non-clustered) or part of an Indexer Cluster. \[1, 2\]

Before starting, ensure that **TCP Port 8089** (Splunk Management Port) is open and accessible between the Search Head and all Indexers. \[3, 4\]

## ---

**Option 1: Connecting to Standalone Indexers (Non-Clustered)**

Every full Splunk Enterprise instance is functionally a search head by default. You simply need to link the standalone indexers to it as **Search Peers**. \[1, 4, 5\]

## **Method A: Via Splunk Web UI**

> 1. Log in to your **Search Head**. \[5\]  
> 2. Navigate to **Settings** \> **Distributed Environment** \> **Distributed Search**. \[6\]  
> 3. Click on **Search Peers**, then select **New Search Peer**. \[3, 7\]  
> 4. Fill out the remote indexer information:  
   * **Peer URI:** Enter the indexer IP or hostname with port 8089 (e.g., https\://192.168.1.50:8089).  
   * **Authentication:** Provide the Splunk administrative username and password for that specific indexer. \[3, 7, 8\]  
> 5. Click **Save**. Repeat this for all other indexers. \[5, 6\]

## **Method B: Via Command Line (CLI)**

Run the following command directly on your Search Head: \[6\]

`splunk add search-server https://<Indexer_IP_or_Hostname>:8089 -auth <SH_admin_user>:<SH_admin_password> -remoteUsername <Indexer_admin_user> -remotePassword <Indexer_admin_password>`

*Splunk automatically exchanges public security keys behind the scenes when configured via UI or CLI.* \[3, 9\]

## ---

**Option 2: Connecting to an Indexer Cluster (Peer Replication)**

If your indexers are managed by an Indexer Cluster, **do not manually add the search peers**. Instead, configure the Search Head to connect to the cluster's **Manager Node** (Cluster Master), which will automatically distribute the peer lists and public keys to the SH. \[1, 9\]

## **Method A: Via Splunk Web UI**

> 1. Log in to your **Search Head**.  
> 2. Navigate to **Settings** \> **Distributed Environment** \> **Indexer Clustering**. \[8\]  
> 3. Select **Enable Clustering**. \[8\]  
> 4. Choose **Search Head Node** and click **Next**. \[8\]  
> 5. Fill out the cluster properties:  
   * **Manager URI:** Enter the Manager Node's management URI (e.g., https\://10.0.1.20:8089).  
   * **Security Key:** Enter the exact cluster-wide password/passkey configured on your Manager Node. \[8\]  
> 6. Click **Enable search head node** and **restart Splunk** when prompted. \[8\]

## **Method B: Via Command Line (CLI)**

Run this command from your Search Head and restart the instance: \[2\]

`splunk edit cluster-config -mode searchhead -manager_uri https://<Manager_Node_IP>:8089 -secret <cluster_security_key>`  
`splunk restart`

## ---

**Verification**

Once configured, run a wide-scoping query like index=\_internal or \* on your Search Head.  
Expand the **splunk\_server** sidebar field in your search results. You should see all of your designated indexers actively responding to the search query. \[3, 5\]

To ensure this setup handles your bundle replication smoothly, let me know:

> * Are your indexers **clustered** or **standalone**?  
> * Is this a **single Search Head**, or are you setting up a **Search Head Cluster (SHC)** using a Deployer?

\[1\] [https\://help.splunk.com](https://help.splunk.com/en/splunk-enterprise/administer/distributed-search/9.4/deploy-search-head-clustering/connect-the-search-heads-in-clusters-to-search-peers)  
\[2\] [https\://help.splunk.com](https://help.splunk.com/en/data-management/manage-splunk-enterprise-indexers/9.4/configure-the-search-head)  
\[3\] [https\://www\.youtube.com](https://www.youtube.com/watch?v=R86phfbo9KQ&t=177)  
\[4\] [https\://www\.youtube.com](https://www.youtube.com/watch?v=tOgjsWl4Nac&t=412)  
\[5\] [https\://help.splunk.com](https://help.splunk.com/en/splunk-enterprise/administer/distributed-search/9.4/deploy-distributed-search)  
\[6\] [https\://docs.splunk.com](https://docs.splunk.com/Documentation/Splunk/8.2.12/DistSearch/Configuredistributedsearch)  
\[7\] [https\://www\.youtube.com](https://www.youtube.com/watch?v=yj9G_jedV4Q&t=89)  
\[8\] [https\://help.splunk.com](https://help.splunk.com/en/data-management/manage-splunk-enterprise-indexers/9.2/deploy-the-indexer-cluster/enable-the-search-head)  
\[9\] [https\://help.splunk.com](https://help.splunk.com/en/data-management/manage-splunk-enterprise-indexers/9.0/configure-the-search-head/search-head-configuration-overview)