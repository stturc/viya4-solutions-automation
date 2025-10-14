[← Back to README](../README.md)

### Deploy SAS Solution (Automated way via GitHub Actions)

0. First, fork this repository—see [fork this repo](/doc/fork.md) for instructions. Once forked, go to your GitHub repository.

1. Ensure your environment variables are set via a GitHub environment. GitHub Environments allow you to define deployment targets and are named configurations used for deployments.

   1. Click `Settings` > `Environments` (left sidebar).
   2. Click `New environment`.
   3. Name your environment (for example `staging`, `production`).
   4. Configure `Secrets` by clicking `Add environment secret` and add at least the following secrets:


| Variable Name                | Description                                                                                                                        | Example Value                                 | Required |
|------------------------------|------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------|----------|
| `AZURE_SUBSCRIPTION_ID`      | Identifier of the Azure subscription you want to deploy into.                                                                      | `12345678-90ab-cdef-1234-567890abcdef`        | Yes      |
| `AZURE_CLIENT_ID`            | Client Identifier of the Azure application used to deploy (Azure Portal → Application's overview → Application (Client) ID). <br>**Note:** For GitHub Actions authentication, you may need to [add a federated credential](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust-github) to your Azure app registration for this Client ID. | `abcdef12-3456-7890-abcd-ef1234567890`        | Yes      |
| `AZURE_TENANT_ID`            | Azure Tenant Identifier (Azure Portal → Application's overview → Directory (Tenant) ID)                                            | `fedcba98-7654-3210-fedc-ba9876543210`        | Yes      |
| `AZURE_ADMIN_GROUP_NAME`     | Azure group name available in Microsoft Entra ID                                                                                   | `viya-admins`                                 | Yes      |
| `AZURE_ADMIN_GROUP_ROLE`     | Role name to be assigned to `AZURE_ADMIN_GROUP_NAME` in the managed resource group                                                 | `Owner`                                       | Yes      |
| `SSH_PUBLIC_KEY`             | SSH Public Key (OpenSSH format) to access the jumpbox client                                                                      | `ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ...`   | Yes      |
| `DNS_SUFFIX`                 | (Optional) Suffix of the target deployment FQDN. If provided, FQDN will be `<prefix>.${DNS_SUFFIX}`; else `<prefix>.<location>.cloudapp.azure.com`. | `mycompany.com`                               | No       |
| `TLS_CERT_B64`               | (Optional) TLS Certificate corresponding to `<prefix>.${DNS_SUFFIX}` (must be base64-encoded)                                     | `LS0tLS1CRUdJTiBD...`                         | Only if `DNS_SUFFIX` is provided       |
| `TLS_KEY_B64`                | (Optional) TLS Key corresponding to `<prefix>.${DNS_SUFFIX}` (must be base64-encoded)                                             | `LS0tLS1CRUdJTiBSU0EgUFJ...`                  | Only if `DNS_SUFFIX` is provided       |
| `TLS_TRUSTED_CA_CERTS_B64`   | (Optional) TLS Trusted CA certificate corresponding to `<prefix>.${DNS_SUFFIX}` (must be base64-encoded)                          | `LS0tLS1CRUdJTiBD...`                         | Only if `DNS_SUFFIX` is provided       |

2. On the default branch (`main`), edit `.github/workflows/deploy-managed-app.yaml`, set the `environment` input to the environment name you configured above and commit.
3. Go to `GitHub Actions`.
4. Select the `Deploy Managed Application` workflow.
5. Click `Run Workflow` and provide the required parameters:

| Parameter Name                  | Description                                                                                                                                                                            | Example Value                            | Required |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------|----------|
| `Branch`                        | The Git branch to use for the workflow run. Use `main` unless you are testing a feature branch.                                                                                        | `main`                                   | Yes      |
| `SAS solution to deploy`   | The specific SAS solution to deploy. This must match a solution present in the supported combinations table.                                 | `SAS Model Risk Management`              | Yes      |
| `AKS Cluster Sizing`            | The sizing preset for the Azure Kubernetes Service (AKS) cluster. Determines node sizes and counts for the deployment.                            | `ProdSmall`, `ProdMedium`, `ProdLarge`   | Yes      |
| `SAS URI for Viya Order`        | The URL to a ZIP file containing your SAS solution assets, license, and certificates (see [Note about SAS solution order](/doc/sas-solution-order.md) for more details). Must match the solution and cadence you are deploying.        | `https://<your-storage-account>/order.zip` | Yes      |
| `Viya Admin Password`           | The password for the admin user of the Viya deployment.                                                     | `S3cureP@ssw0rdW1thNumb3rsAndSymb0ls`   | Yes      |
| `SSH Public Key for the deployment`           | SSH Public Key (OpenSSH format) to access the jumpbox client                                                                      | `ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ...`   | Yes      |
| `Environment to deploy to`      | The target environment for deployment.                                                                     | The value you set as 'environment name'  | Yes      |
| `Additional Parameters for the deployment`            | A JSON object for advanced or optional deployment parameters. See [Notes on additional parameters](#notes-on-additional-parameters) for more details.                       | `{}`                                     | No       |

The following screenshot shows the GitHub Actions workflow UI for deploying the managed application. Specifically, it displays the form where users can manually trigger the "Deploy Managed Application" workflow in GitHub Actions. In this UI, users are prompted to enter required parameters such as:

* Branch
* SAS solution to deploy
* AKS Cluster Sizing
* SAS URI for Viya Order
* Viya Admin Password
* SSH Public Key for the deployment
* Environment to deploy to
* Additional Parameters for the deployment

This form allows users to provide all necessary inputs to start the automated deployment of the SAS solution to Azure using the GitHub Actions workflow.
![alt text](/doc/images/deploy-managed-app-github-ui.png "Title")


6. Monitor the workflow for progress and results. Artifacts and logs will be available for review. After execution, the following elements are available in the selected Azure subscription (`${GITHUB_RUN_ID}` corresponds to the GitHub workflow run identifier):
    * A resource group named `mapp-${GITHUB_RUN_ID}-rg` containing:
       * `mappdef-${GITHUB_RUN_ID}`: Service Catalog Managed Application Definition
       * `mapp-${GITHUB_RUN_ID}`: Managed Application
    * A resource group named `mapp-${GITHUB_RUN_ID}-mrg` (mrg = managed resource group), containing:
       * `mapp-${GITHUB_RUN_ID}-aks`: AKS Kubernetes service
       * `mapp-${GITHUB_RUN_ID}-jump-vm`: Jumpbox Virtual Machine
       * `mapp-${GITHUB_RUN_ID}-nfs-vm`: NFS Virtual Machine
       * `mapp${GITHUB_RUN_ID}<RandomNumber>`: Storage account for logs, deployment assets, and CA certificate
    * A resource group named `MC_mapp-${GITHUB_RUN_ID}-mrg-mapp-${GITHUB_RUN_ID}-aks_<Location>` (MC = managed by cluster), containing AKS cluster resources (nodes, disks, etc.)
    * A resource group named `sa-rg` containing:
       * `viyasolutions`: Azure Storage Account with blob containers (`sac-${GITHUB_RUN_ID}`) for the package needed to create the Service Catalog Managed Application Definition.

---

#### Notes on `Additional parameters`
`Additional parameters` is a JSON object for advanced or optional deployment parameters. It's required to tackle the limitation of Github actions to allow more than a limited number of inputs when triggering a worfklow through the Github UI.

**Note:** If you want to combine multiple parameters, simply include all the required variables in a single, larger JSON object according to your needs and make sure to transform it as a one-liner string.

For example, if you want to set the Azure location to `westus` and the number of pre-configured users to 3, you can merge the key-value pairs from below examples into one JSON to provide all desired parameters at once and generate the one-liner string that you can pass to the `additional_parameters` input variable.
```bash
cat <<EOF | jq -c .
{
  "location": "westus",
  "step_add_users": "1"
}
EOF
```

The table below indicates which additional parameters are required
| Label | Variable name | Required? | Default value | Link |
|-------------| -------------|----------|--|--|
| IP Allow List | ip_allow_list| **Yes** |   | [link](#ip-allow-list) |
| Admin User Name for IDS External Postgres Server | ext_pg_ids_admin_user | Yes (Depends on other selections) | | [link](#admin-user-name-and-password-for-external-postgres-server)|
| Admin Password for IDS External Postgres Server | ext_pg_ids_admin_password | Yes (Depends on other selections) | | [link](#admin-user-name-and-password-for-external-postgres-server)|
| Admin User Name for CDS External Postgres Server | ext_pg_cds_admin_user | Yes (Depends on other selections) | |[link](#admin-user-name-and-password-for-external-postgres-server)|
| Admin Pasword for CDS External Postgres Server | ext_pg_cds_admin_password | Yes (Depends on other selections) | |[link](#admin-user-name-and-password-for-external-postgres-server)|
| Number of predefined users to configure | step_add_users | No | 5 | [link](#number-of-pre-defined-users-to-configure)|
| Azure Region/Location | location | No | `eastus` | [link](#azure-regionlocation) |
| Azure Admin Group Name | azure_admin_group_name | No | see Environment Secrets | [link](#azure-regionlocation) |
| Azure Admin Group Role | azure_admin_group_role | No | see Environment Secrets | [link](#azure-managed-application-definition-authorizations) |
| DNS suffix | step_add_users | No | see Environment Secrets | [link](#dns-suffix) |
| Package version | package_version | No | `latest` | [link](#package-version) |
| Azure Storage Container Artifact Name | artifact_name | No | `package-deploy` | [link](#azure-storage-container-artifact-name) |
| Managed Application Resource Group Name | mapp_rg_name | No | `mapp-<github.run_id>-rg` | [link](#managed-application-resource-group-name) |
| Managed Application Definition Name | mapp_def_name | No | `mappdef-<github.run_id>` | [link](#managed-application-definition-name) |
| Update Existing Deployment Managed Resource Group Name | update_existing_deployment_mrg_name | No | | [link](#update-existing-deployment-managed-resource-group-name) |

---
##### IP allow list
To interact with your SAS solution AKS cluster or access the web interface, your client IP address must be allowed in both the AKS cluster's networking configuration and the ingress service controller. This is typically managed automatically via the `ip_allow_list` variable defined in `additional_parameters`input variable. 
If you need to update the allowed IPs after deployment, please follow the instructions described [here](#access-deployed-sas-solution).

```bash
cat <<EOF | jq -c .
{
  "ip_allow_list": "1.2.3.4/32"
}
EOF
```
where 1.2.3.4/32 represents the IP range in CIDR notation that you want to allow.

---
##### Admin User Name and Password for External Postgres Server
When deploying the `SAS Model Risk Management` solution with an AKS cluster sized as `ProdSmall`, `ProdMedium`, or `ProdLarge`, you must specify the usernames and passwords for the external Postgres admin users (IDS and CDS).
```bash
cat <<EOF | jq -c .
{
  "ext_pg_ids_admin_user": "admin_userName_for_IDS_postgres",
  "ext_pg_ids_admin_password": "admin_p@ssw0rd_for_IDS_postgres",
  "ext_pg_cds_admin_user": "admin_userName_for_CDS_postgres",
  "ext_pg_cds_admin_password": "admin_p@ssw0rd_for_CDS_postgres"
}
EOF
```
---
##### Number of Pre-defined Users to Configure
In the following configuration example, the automation will pre-configure *3* internal users.
If not specified, the automation will pre-configure 5 internal users.

**Note**: The possible values for `step_add_users` are "0", "1", "3", "5", "10".

| Username | Password |
|----------|----------|
| SAS_Demo_User1 | SAS_Demo_User1 |
| SAS_Demo_User2 | SAS_Demo_User2 |
| SAS_Demo_User13 | SAS_Demo_User3 |

All pre-configured users are part of the `SAS_Demo_Users` group.

In the case of `SAS Model Risk Management` deployment, those pre-configured users are part of `MRMUsers` group.

```bash
cat <<EOF | jq -c .
{
  "step_add_users": "3"
}
EOF
```
---
##### Azure region/location

To specify the Azure region for your deployment, use the [Azure region short names](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#available-regions), such as `eastus`, `westeurope`, or `centralus`.

The default region is `eastus`.

Here is an example of how to create the required **one-liner string** for the automation's `additional_parameters` variable:
```bash
cat <<EOF | jq -c .
{
  "location": "eastus"
}
EOF
```
---
##### Azure Managed Application Definition Authorizations

When creating the Azure Managed Application Definition, you need to set the authorization.

By default, authorization uses the values of `AZURE_ADMIN_GROUP_NAME` and `AZURE_ADMIN_GROUP_ROLE` defined in your environment secrets.

To override these values, use the following example:
```bash
cat <<EOF | jq -c .
{
  "azure_admin_group_name": "<your Group>",
  "azure_admin_group_role": "Owner"
}
EOF
```
---
##### DNS Suffix

To override the DNS suffix of the FQDN of the deployment, you can specify an entry in the `additional_parameters`input variable so the FQDN becomes `mapp-<ID>.<DNS_SUFFIX>`. For example, if the DNS suffix is set to `mycompany.com`, the FQDN will be `mapp-<ID>.mycompany.com`.

> **Important:** You must create a corresponding entry in your DNS manager to associate the FQDN with the external IP address of the deployment.

You can also specify TLS certificates (certificate, key, and trusted CA certificate) encoded in Base64. Here is an example with dummy values:

```bash
cat <<EOF | jq -c .
{
  "dns_suffix": "mycompany.com",
  "tls_cert_b64": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tClRoZSBjb250ZW50IG9mIHRoZSBjZXJ0aWZpY2F0ZQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=",
  "tls_key_b64": "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tClRoZSBjb250ZW50IG9mIHRoZSBrZXkKLS0tLS1FTkQgUFJJVkFURSBLRVktLS0tLQo=",
  "tls_trusted_ca_certs_b64": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCkRVTU1ZX0NBX0JBU0U2NF9FWEFNUExFClN1YmplY3Q6IENBIENlcnRpZmljYXRlCklzc3VlcjogQ0EgSXNzdWVyCgotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
}
EOF
```
- `tls_cert_b64`: Base64-encoded TLS certificate (dummy value shown)
- `tls_key_b64`: Base64-encoded private key (dummy value shown)
- `tls_trusted_ca_certs_b64`: Base64-encoded trusted CA certificate (dummy value shown)

If not specified in `additional_parameters`, `dns_suffix` will resolve to the value entered in the Environment secrets, as well as for `tls_cert_b64`, `tls_key_b64` and `tls_trusted_ca_certs_b64`.

If no dns_suffix is specified (neither in `additional_parameters`, nor in Environment secrets), the DNS Suffix will be `<location>.cloudapp.azure.com` and self-signed certificates will be used for the deployment.


---
##### Package version 
By default, the automation uses the `latest` SAS Solution package to deploy the environment. 
The available packages version strings are listed in Code → Releases.

> **Note** : using a package version different than `latest` might lead to unsupported cases.

```bash
cat <<EOF | jq -c .
{
  "package_version": "latest"
}
EOF
```


---
##### Azure Storage Container Artifact Name
By default, the automation uses the `package-deploy` name to upload the artifact to the storage container. You may override this by setting this variable.

---

##### Managed Application Resource Group Name
By default, the automation uses github.run_id to format a default name for the resource group that will hold all artifacts for the managed application. You may override this by setting this variable.

---

##### Managed Application Definition Name
By default, the automation uses github.run_id to format a default name for the managed application. You may override this by setting this variable.

---

##### Update Existing Deployment Managed Resource Group Name
By default, the automation will assume this is a new deployment request. You may update an existing deployment by passing in the managed resource group name to this variable.

---


[← Back to README](../README.md)