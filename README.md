# Ping Cloud Base Observability Patch Component

The patch described on this page is only applicable to the Beluga 1.18.0, 1.18.1 and 1.18.2 release. It includes changes for the following resources:

* OpenSearch LSM policy: Update retention period from 270 days to 180 days.

* Logstash CloudWatch pipeline: Send to S3.

* Logstash New Relic pipeline: Drop all events.

* CloudWatch agent: Deployed with 1 replica, collecting and shipping limited metrics.

Ref: https://pingidentity.atlassian.net/wiki/spaces/PDA/pages/884178997/Observability+Patch+for+Beluga+Release+Versions+1.18


NOTE: Releasing this patch on top of the earlier v1.18_Patch_Observability release to address an issue with the Elasticsearch/OpenSearch cluster facing shard limit problems. This patch updates the Index State Management (ISM) policy to delete shards after 60 days.
