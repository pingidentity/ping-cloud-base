# Ping Cloud Base Observability Patch Component

The patch described on this page is only applicable to the Beluga 1.19.0 release. It includes changes for the following resources:

* OpenSearch ISM policy: Update retention period from 270 days to 60 days.
  We observed a shard limit issue with the 180-day retention period. As a team, BeOps, Engineering, and Product (Brit) decided to reduce this period to 60 days.

* Logstash CloudWatch pipeline: Drop all events.

* Logstash New Relic pipeline: Drop all events.

* Logstash Customer pipeline: include time field

* CloudWatch agent: Deployed with 1 replica, collecting and shipping limited metrics.

Ref: https://pingidentity.atlassian.net/wiki/spaces/PDA/pages/883687448/Observability+Patch+for+Beluga+Release+Versions+1.19.0


