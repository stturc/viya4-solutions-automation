[← Back to README](../README.md)

### Deploy SAS Solution (Manual way)

Assumptions:

* You are deploying the `SAS-solution` solution (for example `SAS Model Risk Management`).
* You are deploying into an Azure subscription named `TargetAzureSubscription`.
* You are deploying in the `TargetRegion` Azure region (for example `eastus`).

#### 0. Download Repository Release

1. Go to [Code → Releases](https://github.com/sassoftware/viya4-solutions-automation/releases).
2. Download the latest package for the `SAS-solution` solution (for example if `SAS-solution` is `SAS Model Risk Management`, use `package-MRM-<version>.zip`).

#### 1. Create or Use a Resource Group

(Skip creation if you already have a resource group.)

1. Go to the [Azure Portal](https://portal.azure.com).
2. In the left menu, select **Resource groups**.
3. Click **+ Create**.
4. Select your `TargetAzureSubscription` subscription.
5. Enter a **Resource group name** (for example `sa-rg`).
6. Select your `TargetRegion` region.
6. (Optional) Add tags if required.
7. Click **Review + create** and then **Create**.

#### 2. Create or Use a Storage Account

(Skip creation if you already have a storage account.)

1. In the left menu, select **Storage accounts**.
2. Click **+ Create**.
3. Select your `TargetAzureSubscription` subscription and **Resource group**.
4. Enter a **Storage account name** (must be globally unique, 3-24 lower case letters/numbers).
5. Select the `TargetRegion` region (same as your resource group).
6. Select `Azure Blob Storage`as **Primary Service**.
6. Select `Standard` for **Performance**.
7. Select `Locally-redundant storage (LRS)` for **Redundancy**.
8. Use default values in other tabs.
9. (Optional) Add tags if required.
10. Click **Review + create** and then **Create**.

#### 3. Create a Storage Container

1. Navigate to your storage account (either the one you just created or an existing one) by clicking its name in the Storage accounts list.
2. In the left menu, under **Data storage**, click **Containers**.
3. Click **+ Container**.
4. Enter a **Name** (for example `sac-<unique-id>`).
5. Set **Public access level** to `Private (no anonymous access)`.
6. Click **Create**.

#### 4. Upload Your Artifact

1. Click the container you just created.
2. Click **Upload**.
3. Click **Browse for files** and select the repository release downloaded above (such as `package-MRM-<version>.zip`).
4. Click **Upload**.

#### 5. Generate a SAS URI for the Uploaded Blob

1. In the storage container, find your uploaded file in the list.
2. Click the **...** (More) next to the file and select **Generate SAS**.
3. Set the **Permissions** to `Read` (at minimum).
4. Set the **Expiry time** (for example 3 hours from now; ensure it exceeds the deployment duration).
5. Click **Generate SAS token and URL**.
6. Copy the **Blob SAS URL** for use in your deployment.

#### 6. Create or Use a Resource Group for the Managed Application

**Note**: This resource group should be different from the one you created earlier for the storage account (for example, if you used `sa-rg` for the storage account, choose a different name here such as `mapp-rg`).

1. Go to the [Azure Portal](https://portal.azure.com).
2. In the left menu, select **Resource groups**.
3. Click **+ Create**.
4. Select your `TargetAzureSubscription` subscription.
5. Enter a **Resource group name** (for example `mapp-rg`).
6. Select your `TargetRegion` region.
6. (Optional) Add tags if required.
7. Click **Review + create** and then **Create**.

#### 7. Create the Managed Application Definition

1. In the [Azure Portal](https://portal.azure.com), go to **Create a resource**.
2. Search for **Service Catalog Managed Application Definition** and select it.
3. Click **Create**.
4. In the **Basics** tab:
    1. Select your `TargetAzureSubscription` subscription.
    2. Select the **Resource group** you created for the managed application definition (for example `mapp-rg`).
    3. Enter a **Name** for the managed application definition (for example `mappdef`).
    4. Select the `TargetRegion` region (should match your other resources).
    5. Set a Name, Display name and description for your Managed Application Definition.
5. In the **Package** tab:
    1. For **Package file URI**, paste the **Blob SAS URL** you generated earlier for your package ZIP file.
    2. Choose `Complete` **Deployment Mode**
6. Use the default values in **Management settings** tab
7. In the **Authorization** section:
    1. Select `None` for **Lock Level**
    2. Click **Add Members**.
    3. For **Role**, select the role to assign (for example `Owner`).
    4. For **Principals**, enter the **Object ID** of the Azure AD user, group that should have access (for example your admin group).
8. Click **Review + create**.
9. Review your settings and click **Create**.

#### 8. Create the Managed Application

1. In the `mapp-rg` resource group, click on the `mappdef` Service Catalog Managed Application Definition.
2. Click on the **Deploy from Definition** button.
3. **Basics** tab:
   1. Select your `TargetAzureSubscription` subscription.
   2. Select the **Resource group** for the managed application (for example `mapp-rg`).
   3. Select the `TargetRegion` region (should match your other resources).
   4. Enter a **Deployment Name** (for example `my-viya-app`).
   5. Enter an **Application Name**.
   6. Click **Next**.
4. **Software Order ID** tab:
   1. Select "Supply ZIP file URL (SAS Token)" in the **Choose input method** dropdown.
   2. For **Viya Order SAS URI (SAS Token)**, enter the URL to a ZIP file containing your SAS solution assets, license, and certificates. See [Note about SAS solution order](/doc/sas-solution-order.md) for more details.
   3. Click **Next**.
5. **Sizing** tab:
   1. Choose the desired sizing for your deployment.
   2. Click **Next**.
6. **Accounts** tab:
   1. Enter the application administrator password and confirm it.
   2. Enter the SSH public key (OpenSSH format).
   3. Click **Next**.
7. **Review + Create** tab:
   1. If all parameters are correct, proceed with creation.
   2. If not, fix your entries and try again.


---
[← Back to README](../README.md)