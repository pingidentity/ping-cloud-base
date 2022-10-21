# Delegated Admin Notes

This document covers some important notes regarding how to deploy Delegated Admin in P1AS.

## Delegated Admin out-of-the-box configuration

In the out-of-the-box configuration, Delegated Admin rights are provided to the admin user `uid=admin,${USER_BASE_DN}`. 
Delegated Admin rights may only be granted to a single LDAP user or to a single LDAP group but not both. So an LDAP 
group is required to grant Delegated Admin rights to more than one user. Even for a single admin user, the recommended 
approach is to create an LDAP group, add the admin user to that group and grant Delegated Admin rights to the group 
as a whole. The out-of-the-box configuration is set up with a user only for convenience so that it works with data 
loaded using the example MakeLDIF templates. 

## How to create an LDAP group and add users to the group

An LDAP group may be created using the following LDIF:

```shell
dn: cn=administrators,${GROUP_BASE_DN}
objectClass: groupOfUniqueNames
cn: administrators
uniquemember: uid=admin,${GROUP_BASE_DN}
```

where `GROUP_BASE_DN` is the base DN of the LDAP group under `USER_BASE_DN` for the customer environment. It could 
simply be the same as `USER_BASE_DN` in test environments.

## How to grant delegated admin rights to the group

After creating the LDAP group, grant the group Delegated Admin rights by adding the following `dsconfig` command to 
the bottom of `profiles/pingdirectory/pd.profile/misc-files/delegated-admin/01-add-delegated-admin.dsconfig.subst` in 
the cluster-state repo. Note that this will be effective only on the next rollout of the PingDirectory servers.

```shell
dsconfig set-delegated-admin-rights-prop \
    --rights-name administrator-user-${DA_DEFAULT_GRANT_TYPE_CLIENT_ID} \
    --remove admin-user-dn:uid=admin,${USER_BASE_DN} \
    --set admin-group-dn:cn=administrators,${GROUP_BASE_DN}
```

## Changing the USER_BASE_DN

Changing the `USER_BASE_DN` requires completely rolling out every PingDirectory server in the replication topology, 
followed by rolling out all PingFederate servers (admin and engines). Use the `LAST_UPDATE_REASON` environment 
variable to roll out PingDirectory and PingFederate servers sequentially.

## Delegated Admin certificate issue

In lower environments where the PingDirectory certificate is from the Let's Encrypt staging server, the Delegated Admin 
UI will deny access due to the certificate being invalid. To work around it, download the certificate and import it 
as a trusted certificate into the system trust store (e.g. OSX keychain).

## Fixing Delegated Admin warnings on PingDirectory

### Determining if there are problems with the Delegated Admin configuration or data 

- In the server's status output (run the `status` tool from the CLI), alerts and alarms will be displayed when there are
  problems with Delegated Admin configuration or data.
- On the Delegated Admin UI, the user will be presented with a yellow banner with the following warning message:
`Please contact your administrator. The current Delegated Admin configuration is invalid.`

### Fixing Delegated Admin configuration warnings

The Delegated Admin configuration is set up after the server has started through a post-start hook script. If the 
configuration contains references to LDAP data that does not yet exist (e.g. references to the 
`uid=admin,${USER_BASE_DN}` LDAP user or the `cn=administrators,${GROUP_BASE_DN}` LDAP group), then the Delegated Admin 
configuration will be considered invalid, but it is just a warning, not an error. 

To fix the issue, the PD servers must be re-rolled after creating the missing LDAP data references. Run the `status` 
tool to confirm that all invalid configuration is fixed. You may need more than one restart to get it right for the 
customer's user data.

### Fixing Delegated Admin data warnings

This is *only* a problem for existing customers. The `USER_BASE_DN` entry contains an ACI that's too permissive. Run 
the `ldapmodify` command and type in the following LDIF interactively to fix it:

```shell
dn: ${USER_BASE_DN}
changetype: modify
delete: aci
aci: (targetattr!="userPassword")(version 3.0; acl "Allow anonymous read access for anyone"; allow (read,search,compare) userdn="ldap:///anyone";)
-
add: aci
aci: (targetattr!="userPassword")(version 3.0; acl "Allow read access for all"; allow (read,search,compare) userdn="ldap:///all";)

<Hit enter key twice to apply the modifications>
```

Replace `USER_BASE_DN` above with the `USER_BASE_DN` for the customer environment.

## Port Forward into Delegated Admin

**Note: If you have access to the private network from VPN then you do not need to port-forward.**

1. You must have installed [Versent/saml2aws](https://github.com/Versent/saml2aws).

   Skip if you already have installed, but if you do experience timeouts after logging into DA. You must upgrade Versent/saml2aws.

2. Get the ingress private hosts for pingdirectory-http-ingress and pingdelegator-ingress. From your cluster by running the following:
   ```shell
   $ kubectl get ingress -n ping-cloud

   <Remember host URLs as you will need in the next step>
   ```

3. Add  the pingdirectory-http-ingress and pingdelegator-ingress hosts from step 2 in your `/etc/hosts` file
  
   ```
   127.0.0.1  pingdelegator.<cde>-<customer>.<region (e.g. us1)>.ping-<environment>.cloud
   127.0.0.1  pingdirectory.<cde>-<customer>.<region (e.g. us1)>.ping-<environment>.cloud

   <Comment out all other 127.0.0.1 lines except for localhost>
   ```

4. Start a port-forwarding session
   
5. Within your cluster state repo navigate to the file `/k8s-configs/base/env_vars`
   
   a) Search for variable PD_DELEGATOR_PUBLIC_PORT and set to `localPortNumber`
   
   b) Add new variable PD_HTTP_PUBLIC_PORT and set to `localPortNumber`

   e.g.
   ```
   PD_DELEGATOR_PUBLIC_PORT=8080
   PD_HTTP_PUBLIC_PORT=8080
   ```

6. Modify PingFederate CORS Settings to allow private port for PingDelegator app.
   
   a) Login into the PingFederate Admin Console. 
   
   b) Navigate to System > OAuth Settings > Authorization Server Setting.
   
   c) Scroll to the section Cross-Origin Resource Sharing Settings > Allowed Origin
   
   d) Add the wildcard character `*` to your pingdelegator URL 
      
      e.g. `https://pingdelegator.test-whale.us1.ping-preview.cloud:*`

   e) Click Update > Save

   f) Replicate changes to cluster

7. Modify 'dadmin' client Redirection URI to `localPortNumber`.

   a) Login into the PingFederate Admin Console.

   b) Navigate to Applications > OAuth Clients > Client `dadmin`.

   c) Edit all the Redirection URIs that has the port number 443 to your `localPortNumber`.

      e.g. `https://pingdelegator.test-whale.us1.ping-preview.cloud:443` to `https://pingdelegator.test-whale.us1.ping-preview.cloud:8080`

   d) Click Update > Save

8. Respin DA pods by updating last `LAST_UPDATE_REASON` variable.
   
   a) Navigate to file, `k8s-configs/<region>/pingdelegator/env_vars`, and update `LAST_UPDATE_REASON`.
   
   b) Save file > commit > push changes into cluster state repo.

   c) Wait for argocd to respin DA pods within your cluster.

   d) Login into DA from the browser to confirm the changes that were made are successful. The URL should include the `localPortNumber`.

      e.g. `https://pingdelegator.test-whale.us1.ping-preview.cloud:8080`

## Existing customers

### Quick test of Delegated Admin after upgrading a customer to >= 1.9.0

- Add the following admin user using the `ldapmodify` tool, if it is not already present.
  ```shell
  dn: uid=admin,${USER_BASE_DN}
  objectClass: top
  objectClass: person
  objectClass: organizationalPerson
  objectClass: inetOrgPerson
  uid: admin
  givenName: Admin
  sn: User
  cn: Admin User
  userPassword: 2FederateM0re
  ```
- Login to the Delegated Admin app at https://pingdelegator.${DNS_ZONE} as `admin/2FederateM0re`.
- You will see the following warning banner on the UI:
    `Please contact your administrator. The current Delegated Admin configuration is invalid.`
- Follow the steps in the previous sections to fix the warning.

### Integrating existing customers with Delegated Admin

- Apply the ACI change from the above section to the base user entry to prevent warnings about invalid configuration in
  the Delegated Admin application.
- Add the `dsconfig` command mentioned earlier into the PingDirectory profile in the correct location. Note that since 
  Delegated Admin configuration is set up post server startup, it is not located in the normal `dsconfig` directory 
  that `manage-profile` uses. Also, the file has a `.subst` extension so variable substitutions work as expected.