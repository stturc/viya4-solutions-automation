[← Back to README](../README.md)

# Folder Structure

This repository is organized into several main directories, each serving a specific purpose in the deployment and documentation of SAS solutions on Azure.

---

## `template/`

Infrastructure-as-code and deployment logic for SAS solutions on Azure.

- **Main ARM Template:**  
  - `mainTemplate-mrm.jsonc`: Defines the resources for creating a managed application.
- **Artifacts:**  
  - `artifacts/`: Contains supporting files such as additional ARM templates, Kubernetes manifests, and configuration overlays for SAS solution.
  - Deployment Scripts (e.g., `viyaDeploy.sh`, `waitForPG.sh`): Shell scripts used during deployment.
- **UI Definition:**  
  - `createUiDefinition-mrm.jsonc`: Defines the user interface for creating a managed application.
- **Usage:**  
  - These templates and scripts are used both by the GitHub Actions workflows and for manual deployments via the Azure portal.

---

## `.github/workflows/`

Reusable GitHub Actions workflows for automating deployment and packaging.

- **Key Workflows:**
  - `deploy-managed-app.yaml`: Orchestrates the full deployment of a SAS solution, including parsing parameters, retrieving packages, uploading assets, and provisioning Azure resources.
  - `create-managed-app-definition.yaml`: Builds and publishes the Azure Managed Application definition.
  - `create-managed-app.yaml`: Instantiates a managed application in a target Azure subscription.
  - `create-package.yaml`: Packages SAS solution assets and supporting files for deployment.

---

## `doc/`

Documentation sources, guides, and usage instructions.

- This folder contains all documentation files referenced from the main [README](../README.md).
- Includes guides for deployment, configuration, access, SCIM integration, and more.

---

[← Back to README](../README.md)