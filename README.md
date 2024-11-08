# Ping Cloud Base Observability Patch Component

The patch described on this page is only applicable to the Beluga 1.18.0, 1.18.1 and 1.18.2 release. It includes changes for the following resources:

* OpenSearch LSM policy: Update retention period from 270 days to 60 days.
  - We observed a shard limit issue with the 180-day retention period. As a team, BeOps, Engineering, and Product (Brit) decided to reduce this period to 60 days.

* Logstash CloudWatch pipeline: Send to S3.

* Logstash New Relic pipeline: Drop all events.

* CloudWatch agent: Deployed with 1 replica, collecting and shipping limited metrics.

Ref: https://pingidentity.atlassian.net/wiki/spaces/PDA/pages/884178997/Observability+Patch+for+Beluga+Release+Versions+1.18


