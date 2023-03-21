PingFederateDSJNDIName

grep -r audit *

LDAP-FA8D375DFAC589A222E13AA059319ABF9823B552


IKs="pf-jwt-token-translator-1.1.1.2.jar \
  opentoken-adapter-2.7.jar \
  pf-pcv-pone-52.137.jar \
  pf-pingid-idp-adapter-2.11.1.jar \
  pf-pingid-quickconnection-1.1.1.jar \
  pf-pingone-datastore-2.2.2.jar \
  pf-pingone-mfa-adapter-1.3.2.jar \
  pf-pingone-pcv-2.2.2.jar \
  pf-pingone-quickconnection-2.2.2.jar \
  pf-pingone-risk-management-adapter-1.1.jar \
  pf-referenceid-adapter-2.0.3.jar \
  PingIDRadiusPCV-2.9.1.jar \
  x509-certificate-adapter-1.3.1.jar"

for ik in ${IKs}
do
  echo ${ik}
  find /opt/out/instance -name *${ik}*
done


PDO-4823