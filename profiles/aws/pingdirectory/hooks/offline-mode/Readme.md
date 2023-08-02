The `dsreplication enable-with-static-topology` is a tool that configures PingDirectory replication before the server starts up.

The script takes in a file called `topologyFilePath`. Below is an example of how the structure of this file should look like.
The Python script `manage_offline_mode` creates the topology JSON file that will be needed for `enable-with-static-topology` subcommand.

### Limitations

PingDirectory can be deployed to every single AWS region with a:
  - Replica Limit: Up to 50 pods per EKS cluster
  - Base DN / Backend Limit: Up to 11 base DNs can be added

  To extend these limits see variables PD_POD_LIMIT_INDEX and PD_BASE_DN_LIMIT_INDEX.
  Also, there is an integration test (TODO PDO-5557) that can help you simulate higher replicase or base_dns if needed.
```
$ dsreplication enable-with-static-topology --help

topologyFilePath {topologyFilePath}
  A JSON file that describes server instances in the topology and how
  replication is to be enabled on them. This JSON file has the same
  syntax as the JSON file specified by the same option for the 'enable'
  subcommand. To generate an example topology JSON file, the
  "manage-topology export --complexityLevel advanced" may be used on any
  server. Note that server IDs must be even, and domain IDs must be odd.
  An example JSON file:
```
```json
{
  "serverInstances": [
    {
      "instanceName": "pingdirectory-0-us-west-2",
      "clusterName": "cluster_pingdirectory-0-us-west-2",
      "location": "us-west-2",
      "serverRoot": "/opt/out/instance",
      "hostname": "pingdirectory-0.us-west-2.example.com",
      "ldapPort": 1389,
      "ldapsPort": 1636,
      "httpsPort": 1443,
      "replicationPort": 8989,
      "replicationServerID": 1000,
      "startTLSEnabled": "true",
      "preferredSecurity": "SSL",
      "product": "DIRECTORY",
      "productVersion": {
        "version": "9.2.0.0"
      },
      "replicationDomainServerInfos": [
        "1001 o=platformconfig",
        "1003 o=appintegrations",
        "1005 dc=example,dc=com"
      ],
      "listenerCert": "ADS_CRT_FILE with \n character on every line"
    },
    {
      "instanceName": "pingdirectory-1-us-west-2",
      "clusterName": "cluster_pingdirectory-1-us-west-2",
      "location": "us-west-2",
      "serverRoot": "/opt/out/instance",
      "hostname": "pingdirectory-1.us-west-2.example.com",
      "ldapPort": 1389,
      "ldapsPort": 1636,
      "httpsPort": 1443,
      "replicationPort": 8989,
      "replicationServerID": 1100,
      "startTLSEnabled": "true",
      "preferredSecurity": "SSL",
      "product": "DIRECTORY",
      "productVersion": {
        "version": "9.2.0.0"
      },
      "replicationDomainServerInfos": [
        "1101 o=platformconfig",
        "1103 o=appintegrations",
        "1105 dc=example,dc=com"
      ],
      "listenerCert": "ADS_CRT_FILE with \n character on every line"
    },
    {
      "instanceName": "pingdirectory-0-eu-west-2",
      "clusterName": "cluster_pingdirectory-0-eu-west-2",
      "location": "eu-west-2",
      "serverRoot": "/opt/out/instance",
      "hostname": "pingdirectory-0.eu-west-2.example.com",
      "ldapPort": 1389,
      "ldapsPort": 1636,
      "httpsPort": 1443,
      "replicationPort": 8989,
      "replicationServerID": 2000,
      "startTLSEnabled": "true",
      "preferredSecurity": "SSL",
      "product": "DIRECTORY",
      "productVersion": {
        "version": "9.2.0.0"
      },
      "replicationDomainServerInfos": [
        "2001 o=platformconfig",
        "2003 o=appintegrations",
        "2005 dc=example,dc=com"
      ],
      "listenerCert": "ADS_CRT_FILE with \n character on every line"
    },
    {
      "instanceName": "pingdirectory-1-eu-west-2",
      "clusterName": "cluster_pingdirectory-1-eu-west-2",
      "location": "eu-west-2",
      "serverRoot": "/opt/out/instance",
      "hostname": "pingdirectory-1.eu-west-2.example.com",
      "ldapPort": 1389,
      "ldapsPort": 1636,
      "httpsPort": 1443,
      "replicationPort": 8989,
      "replicationServerID": 2100,
      "startTLSEnabled": "true",
      "preferredSecurity": "SSL",
      "product": "DIRECTORY",
      "productVersion": {
        "version": "9.2.0.0"
      },
      "replicationDomainServerInfos": [
        "2101 o=platformconfig",
        "2103 o=appintegrations",
        "2105 dc=example,dc=com"
      ],
      "listenerCert": "ADS_CRT_FILE with \n character on every line"
    }
  ]
}
```

See Lucid Chart for more details.
https://lucid.app/lucidchart/6b9043d7-9717-4dff-b1ec-3dd4d649c33b/edit?viewport_loc=-283%2C869%2C3960%2C1765%2C0_0&invitationId=inv_9c20db11-0e83-4e4b-8b5f-184607a26ad4
