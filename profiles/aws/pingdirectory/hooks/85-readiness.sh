#!/usr/bin/env sh

# Verify that server is responsive on its LDAP secure port
echo "readiness: verifying root DSE access"
/opt/liveness.sh || exit 1

exit 0