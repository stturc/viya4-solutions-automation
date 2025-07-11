[← Back to README](../README.md)

### Access deployed SAS Solution

To interact with your SAS solution AKS cluster or access the web interface, your client IP address must be allowed in both the AKS cluster's networking configuration and the ingress service controller. This is typically managed automatically via the `ip_allow_list` variable during deployment. If you need to update the allowed IPs after deployment, follow these Azure Portal steps:

#### Allowing Your IP Address in the AKS Cluster (Azure Portal)

1. Navigate to the AKS Cluster:
   1. Go to the [Azure Portal](https://portal.azure.com).
   2. In the left sidebar, select **Resource groups** and open the resource group containing your AKS cluster (for example `mapp-<ID>-mrg`).
   3. Click on your AKS cluster resource (for example `mapp-<ID>-aks`).

2. Update Authorized IP Ranges:
   1. In the AKS cluster menu, scroll down to **Settings** and select **Networking**.
   2. Find the **API server authorized IP ranges** section.
   3. Click the **Manage** button.
   4. Add your public IP address or desired IP range in CIDR notation.
   5. Click **Save**.
   6. Wait a few minutes for the changes to take effect.
   7. This will give access to the public IP addresses in the IP range for the AKS API server.

**Note:** If you set the `ip_allow_list` variable correctly during deployment, these steps are handled automatically. Manual changes are only needed if you want to update the allow list after deployment.

---

#### Allowing Your IP Address in the Ingress Service Controller

1. Navigate to the Ingress Controller Resource:
   (This requires to have your IP address authorized for the API server - see above).
   1. In the same AKS Cluster Resource, locate the `ingress-nginx-controller` ingress controller (Kubernetes Resources -> Services and ingresses -> Services -> `ingress-nginx` namespace -> `ingress-nginx-controller` service)
   2. Click on the `ingress-nginx-controller` service.

2. Update Ingress IP Restrictions:
   1. Go to **YAML** associated with the service. 
   2. Add the public IP  range (CIDR notation) in the `loadBalancerSourceRanges` YAML section.
   3. Click on **Review+Save**
   4. Check the **Confirm Manifest Changes** checkbox and click on **Save**
   5. This will give access to the the public IP addresses in the IP range to the `ingress-nginx-controller` service (i.e. via the browser)

**Note:** If you set the `ip_allow_list` variable correctly during deployment, these steps are handled automatically. Manual changes are only needed if you want to update the allow list after deployment.

---

#### Allowing Your IP Address in the jumpbox
1. Navigate to the Jumpbox Network Security Group
2. Go to the `mapp-<ID>-mrg` resource group and click on the jumpbox `mapp-<ID>-jump-vm`.
3. Go to **Networking**->**Network Settings**  and **Create port rule**->**Inbound port rule** and edit the fields to match the IP addresses (or range) you want to have access to the jumpbox resource.
4. Once done, click **Add** and wait few minutes for the changes to take effect

**Note:** If you set the `ip_allow_list` variable correctly during deployment, these steps are handled automatically. Manual changes are only needed if you want to update the allow list after deployment.

---

#### Access the AKS Cluster via the API Server

Once your IP is allowed:

1. **Obtain AKS Credentials:**
   1. In the AKS cluster overview page, click **Connect** at the top.
   2. Follow the instructions to run the provided `az aks get-credentials` command in your terminal.

2. **Verify Access:**
   Use `kubectl get nodes` to confirm you can access the cluster.

---
#### Access the SAS Solution Deployment in Your Browser

1. Find the FQDN:
   The DNS name or FQDN will be, depending on whether you supplied or not a `DNS_SUFFIX`, either `mapp-<ID>.$DNS_SUFFIX`, f.e. `mapp-123.customer.com` or `mapp-<ID>.$LOCATION.cloudapp.azure.com`, f.e. `mapp-123.eastus.cloudapp.azure.com`).

2. Open the URL:
   1. Enter the FQDN in your browser using `https://`.
   2. Example: `https://mapp-123.customer.com`

3. Log In:
   * Use the admin credentials you set during deployment:
       *  admin user name: viya_admin
       *  admin password: see `Viya Admin Password` in table above
   * If you used the automated way to deploy, a number of pre-defined users `SAS_Demo_User<ID>` should be already provided and those can be used as well to access the environment.

---
#### Access the SAS Solution Deployment via the jumpbox
1. Find the IP address of the jumpbox:
   The IP address of the jumpbox will be available in the Azure portal, under the `mapp-<ID>-jump-vm` resource's properties (**Public IP Address** in **Overview** section)
2. Access via SSH
   The jumpbox allows incoming traffic on port 22 (SSH) from IP addresses allowed in the Network Security Group (see above for more details).
   ```bash
   ssh -i <SSH_Private_Key_Path> jumpuser@<Jumpbox_Public_IP_Address>
   # For example 
   # ssh -i ~/.ssh/id_rsa.pem jumpuser@1.2.3.4
   ```
3. Access NFS Server via the Jumpbox
   The NFS server can be accessed from the jumpbox at the mount point `/viya-share`.
   

---
[← Back to README](../README.md)