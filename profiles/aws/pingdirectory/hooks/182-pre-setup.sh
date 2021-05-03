#!/usr/bin/env sh

# No-op to prevent errors due to "publishNotReadyAddresses" not being set to "true" on the pingdirectory service.
# This field is not required in P1AS because we enable replication in offline mode and don't use any of the
# topology-related tools such as dsreplication and remove-defunct-server.
exit 0