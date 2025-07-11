[← Back to README](../README.md)

## SSO Configuration with Microsoft Entra ID

When you integrate SAS Viya SSO with Microsoft Entra ID, you can:

* Control in Microsoft Entra ID who has access to SAS Viya SSO.
* Enable your users to be automatically signed-in to SAS Viya SSO with their Microsoft Entra accounts.
* Manage your accounts in one central location.

### Prerequisites
The scenario outlined in this article assumes that you already have the following prerequisites:

* A Microsoft Entra user account with an active subscription. If you don't already have one, you can Create an account for free.
* One of the following roles:
  * Application Administrator
  * Cloud Application Administrator
  * Application Owner.
* SAS Viya SSO single sign-on (SSO) enabled subscription.

### Configuration

This section describes how to configure SSO provisioning from Microsoft Entra ID (formerly Azure AD) to your SAS solution deployed via this automation. For more details, see the [references](#references).

#### Overview of Steps

1. Prerequisites
2. Disable LDAP in SAS Viya
3. Register OAuth Client for SCIM
4. Allow Microsoft Entra ID IP Ranges
5. Configure SCIM Provisioning in Microsoft Entra ID
6. Configure Microsoft Entra SSO

---

#### 1. Prerequisites

- The SAS deployment FQDN must be registered in a DNS accessible from Azure.
- The deployment's HTTPS certificate must match the FQDN and be issued by a trusted certificate authority.
- SCIM cannot be configured if the DNS suffix is `cloudapp.azure.com`.

---

#### 2. Disable LDAP in SAS Viya

1. Go to `https://mapp-<ID>.<DNS_SUFFIX>/SASEnvironmentManager/`
2. Log in as `viya_admin` using the admin password.
   ![Login](/doc/images/configure-scim-010.png "Login to SAS Environment Manager")
3. Opt in to all assumable groups.
   ![Opt in groups](/doc/images/configure-scim-020.png "Opt in to groups")
4. In the left panel, expand **Configuration** and select **Identities service**.
   - In the **spring** configuration, ensure `profiles.active` is set to `identities-local`.
     ![Spring config](/doc/images/configure-scim-030.png "Spring configuration")
   - Edit **sas.identities.providers** and set `ldap.enabled` to `false`.
     ![Disable LDAP](/doc/images/configure-scim-040.png "Disable LDAP")
5. Restart the `sas-identities` pod:
   ```bash
   kubectl -n sas-viya delete pods -l app.kubernetes.io/name=sas-identities
   kubectl -n sas-viya get pods -l app.kubernetes.io/name=sas-identities
   ```
   Example output:
   ```
   NAME                              READY   STATUS    RESTARTS   AGE
   sas-identities-6d9b958c69-5mfkz   1/1     Running   0          52s
   ```

---

#### 3. Register OAuth Client for SCIM

Microsoft Entra ID requires an OAuth client and access token to provision users via SCIM.

**a. Obtain the `sasboot` password:**
1. In Azure Portal, go to the Storage Account in the `mapp-<ID>-mrg` resource group.
2. Click **Storage browser**, select **Blob containers**, and open `deploymentassets`.
3. Download `deployments.zip`.
   ![Download deployments.zip](/doc/images/configure-scim-050.png "Download deployments.zip")
4. Extract and open `deployments/mapp-<ID>-aks/sas-viya/site-config/sitedefault.yaml` to find `sas.logon.initial.password`.

**b. Register and obtain tokens:**
```bash
# Define variables - Replace with the real values:
# <SasBootPassword> is from the previous step
# <IngressUrl> is in the form https://mapp-<ID>.<DNS_SUFFIX>
USERNAME=sasboot
PASSWORD=<SasBootPassword>
INGRESS_URL=<IngressUrl>

# Obtain the token to register the new client
export BEARER_TOKEN=$(curl -sk -X POST "${INGRESS_URL}/SASLogon/oauth/token" \
  -u "sas.cli:" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&username=${USERNAME}&password=$PASSWORD" \
  | awk -F: '{print $2}'|awk -F\" '{print $2}')
echo "Registration access token is: $BEARER_TOKEN"

# Create the identity provider client 
# Note: The token validity is long to avoid routinely updating the identity provider configuration
CLIENT_ID=scim-client-id-$(date +%s)
CLIENT_SECRET=scim-client-secret

curl -sk -X POST "${INGRESS_URL}/SASLogon/oauth/clients" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -d "{
    \"client_id\": \"$CLIENT_ID\",
    \"client_secret\": \"$CLIENT_SECRET\",
    \"authorities\": [\"SCIM\"],
    \"authorized_grant_types\": [\"client_credentials\"],
    \"access_token_validity\": 63070000
  }"

# Obtain the SCIM client access token
ACCESS_TOKEN=$(curl -sk -X POST "${INGRESS_URL}/SASLogon/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  | awk -F: '{print $2}'|awk -F\" '{print $2}')
echo "SCIM client access token: $ACCESS_TOKEN"
```

Example output:
```
Registration access token is:  eyJqa3UiOiJodHRwczovL2xvY2FsaG9zdC9TQVNMb2dvbi90b2tl...
{"scope":["uaa.none"],"client_id":"scim-client-id-s", ... }
SCIM client access token is:  eyJqa3UiOiJodHRwczovL2xvY2FsaG9z....
```
Use the SCIM client access-token for SCIM provisioning.

---

#### 4. Allow Microsoft Entra ID IP Ranges

Microsoft Entra ID uses specific IP ranges to send SCIM requests. These must be allowed in your AKS ingress controller.

1. Download the latest [Azure IP Ranges and Service Tags](https://www.microsoft.com/en-us/download/details.aspx?id=56519).
2. Find the "AzureActiveDirectory" section and note the IP ranges listed under `addressPrefixes`.
   ![Ingress IP ranges](/doc/images/configure-scim-070.png "Ingress IP ranges")
3. Add these IP ranges to `loadBalancerSourceRanges` in the `ingress-nginx-controller` service in the `ingress-nginx` namespace of your AKS cluster.
   **Important:** Do not remove existing IP ranges (such as those from `IP_ALLOW_LIST`) or you may lose access.
   ![Existing IPs](/doc/images/configure-scim-080.png "Existing IPs")

---

#### 5. Configure SCIM Provisioning in Microsoft Entra ID

1. In Azure Portal, go to **Microsoft Entra ID** > **Enterprise Applications**.
2. Click **New Application**, search for "SAS Viya SSO", and select it.
   ![Search SAS Viya SSO](/doc/images/configure-scim-090.png "Search SAS Viya SSO")
   ![Select SAS Viya SSO](/doc/images/configure-scim-091.png "Select SAS Viya SSO")
3. Provide a name and click **Create**.
   - *Note: Creation may be restricted to IT administrators.*
4. Assign users and groups:
   1. On the application's **Overview** page, select **Assign users and groups**.
     ![Assign users and groups](/doc/images/configure-scim-092.png "Assign users and groups")
   2. Click **Add user/group**.
     ![Add user/group](/doc/images/configure-scim-093.png "Add user/group")
   - Select users/groups and click **Assign**.
5. Provision user accounts:
   1. On the application's **Overview** page, select **Provision User Accounts** > **Get started**.
     ![Provision User Accounts](/doc/images/configure-scim-094.png "Provision User Accounts")
   2. Click **Connect your application**.
     ![Connect your application](/doc/images/configure-scim-095.png "Connect your application")
   3. In **Admin Credentials**:
     - **Tenant URL**: `https://mapp-<ID>.<DNS_SUFFIX>/identities/scim/v2` (for example `https://mapp-1234.mycompany.com/identities/scim/v2`)
       **Important:** HTTPS and a valid public certificate are required.
     - **Secret Token**: Paste the SCIM client access token.
     - Click **Test Connection**.
       ![Test Connection](/doc/images/configure-scim-096.png "Test Connection")
     - On success, click **Create**.
   4. Click **Start provisioning** and confirm.
     ![Start provisioning](/doc/images/configure-scim-097.png "Start provisioning")

---

#### 6. Configure Microsoft Entra SSO

##### Configure SAML
1. On the **Overview** page of the application created above, select **Set up single sign on** > **Get started**.
  ![Start provisioning](/doc/images/configure-scim-100.png "Start provisioning")
2. On the **Select a single sign-on method** page, select **SAML**
  ![Start provisioning](/doc/images/configure-scim-101.png "Start provisioning")
3. On the **Set up single sign-on with SAML** page, select the pencil icon for **Basic SAML Configuration** to edit the settings.
  - Set **Identifier** to an unique SAML identifier (for example `cloudfoundry-saml-login`).
  - Set **Reply URL** to `https://mapp-<ID>.<DNS_Suffix>/SASLogon/saml/SSO/alias/<SAML Identifier>` (for example `https://mapp-1234.mycompany.com/SASLogon/saml/SSO/alias/cloudfoundry-saml-login`)
  - Set **Relay State** to `/SASLanding`
  - Set **Logout URL** to `https://mapp-<ID>.<DNS_Suffix>/SASLogon/saml/SingleLogout/alias/<SAML Identifier>` (for example `https://mapp-1234.mycompany.com/SASLogon/saml/SingleLogout/alias/cloudfoundry-saml-login`)

##### Configure `sas.logon.saml.sp`
Log on to SAS Environment Manager as `sasboot` user and navigate to the Configuration page.
  
  1. On the Configuration page, select **Definitions** from the drop-down list.
  2. Configure the `sas.logon.saml.sp` definition.
    1. In the **Definitions** list, select `sas.logon.saml.sp`.
    **Note**: If you change any of the sas.logon.saml.sp properties, the new metadata must be provided to the Relying Party in the federated service. Otherwise, the SAML connections might fail.
    2. In the top right corner of the window, click **New Configuration**.
    3. In the new `sas.logon.saml.sp` configuration window, specify values for the required fields, based on your environment. 
      The table available at [SAS Official Documentation: Configure SAML Provider Properties for Microsoft Entra ID](https://go.documentation.sas.com/doc/en/sasadmincdc/v_065/calauthmdl/n1iyx40th7exrqn1ej8t12gfhm88.htm#p0y96b71x0y7gvn111rpf4duvq58) provides full details on all fields.

      Here we can just proceed by updating the value of **entityID** and set it to the SAML identifier set above (for example `cloudfoundry-saml-login`) 
    4. Click **Save**.
    5. Restart the `sas-logon` pod.
      ```bash
      kubectl -n sas-viya delete pods -l app.kubernetes.io/name=sas-logon-app
      kubectl -n sas-viya get pods -l app.kubernetes.io/name=sas-logon-app
      ```
      Example output:
      ```
      NAME                             READY   STATUS    RESTARTS   AGE
      sas-logon-app-59c7f76444-4rvnq   1/1     Running   0          46s
      ```

##### Configure `sas.logon.saml.providers`
Log on to SAS Environment Manager as `sasboot` user and navigate to the Configuration page.
  
  1. On the Configuration page, select **Definitions** from the drop-down list.
  2. Configure the `sas.logon.saml.providers` definition.
    1. In the **Definitions** list, select `sas.logon.saml.providers`.
    2. In the top right corner of the window, click **New Configuration**.
    3. In the new `sas.logon.saml.providers` configuration window, enter values for the required fields, based on your environment.
      The table available at [SAS Official Documentation: Configure SAML Provider Properties for Microsoft Entra ID](https://go.documentation.sas.com/doc/en/sasadmincdc/v_065/calauthmdl/n1iyx40th7exrqn1ej8t12gfhm88.htm#p0y96b71x0y7gvn111rpf4duvq58) provides full details on all fields.
      Here we can proceed with setting the value of the following fields and leave the rest as the default: 
        - **name**: Specify a unique name for the provider (for example `azure`)
        - **idpMetadata**: To find the Federation Metadata for Azure, in the Azure portal, navigate to the Enterprise Application that you created above. Click **Single Sign-On** on the left pane. Copy the **App Federation Metadata Url** and use it to define the **idpMetadata**.
        - aaa

  3. Click **Save**.
  4. Restart the `sas-logon` pod.
      ```bash
      kubectl -n sas-viya delete pods -l app.kubernetes.io/name=sas-logon-app
      kubectl -n sas-viya get pods -l app.kubernetes.io/name=sas-logon-app
      ```
      Example output:
      ```
      NAME                             READY   STATUS    RESTARTS   AGE
      sas-logon-app-59c7f76444-vfd6f   1/1     Running   0          55s
      ```

##### Configure Cross-Origin and cookies Settings for SAML
Log on to SAS Environment Manager as `sasboot` user and navigate to the Configuration page.
  
  1. On the Configuration page, select **Definitions** from the drop-down list.
  2. In the **Definitions** list, select `sas.commons.web.security.cors`.
  3. In the top right corner of the window, click **New Configuration**.
  4. In the new `sas.commons.web.security.cors` configuration window:
    1. Select **SAS Logon Manager** from the list of services.
    2. Set **allowedOrigins** to `https://login.microsoftonline.com`
    3. Set **allowedMethods** to `HEAD,GET,POST`
  5. Click **Save**
  6. In the **Definitions** list, select `sas.commons.web.security.cookies`.
  7. In the top right corner of the window, click **New Configuration**.
  8. In the new `sas.commons.web.security.cookies` configuration window:
    1. Select **SAS Logon Manager** from the list of services.
    2. Set **sameSite** to `None`
  9. Click **Save**
  10. Restart the `sas-logon` pod.
      ```bash
      kubectl -n sas-viya delete pods -l app.kubernetes.io/name=sas-logon-app
      kubectl -n sas-viya get pods -l app.kubernetes.io/name=sas-logon-app
      ```

      Example output:

      ```
      NAME                             READY   STATUS    RESTARTS   AGE
      sas-logon-app-59c7f76444-2jt6m   1/1     Running   0          45s
      ```
      
##### SSO is configured 
![Start provisioning](/doc/images/configure-scim-102.png "Start provisioning")

---
### References

* [SAS Official Documentation: How to Configure SCIM](https://go.documentation.sas.com/doc/en/sasadmincdc/v_065/calids/n1rl3gjjjqmxmfn1hw9ebjjz5778.htm)
* [SAS Official Documentation: Configure Microsoft Entra ID for SAML](https://go.documentation.sas.com/doc/en/sasadmincdc/v_065/calauthmdl/n1iyx40th7exrqn1ej8t12gfhm88.htm?fromDefault=#n1mj93glryngkgn1e2mam2uy2dt8)
* [Microsoft Tutorial: Configure SAS Viya SSO for Single sign-on with Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/saas-apps/sas-viya-sso-tutorial#test-sso)

---
[← Back to README](../README.md)