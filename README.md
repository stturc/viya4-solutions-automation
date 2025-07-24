# SAS Solutions

This repository provides all the resources, templates, and automation necessary to create and deploy a SAS solution environment on an AKS cluster using an **Azure Service Catalog Managed Application Definition (SCMAD)**. The **SCMAD** enables users to provision a SAS solution deployment in a dedicated Azure subscription.

Currently, this repository supports the following combinations:

|SAS solution              |Cadence           |AKS Kubernetes Version|
|--------------------------|------------------|--------|
|SAS Model Risk Management | stable - 2025.03 | 1.30.6 |
|SAS Model Risk Management | stable - 2025.04 | 1.30.6 |
|SAS Model Risk Management | stable - 2025.05 | 1.30.6 |
|SAS Model Risk Management | stable - 2025.06 | 1.30.6 |

## Documentation Index

- [Prerequisites](/doc/prerequisites.md)
- [Folder Structure](/doc/folder-structure.md)
- [Deploy SAS Solution](/doc/deploy.md)
  - [Manual Deployment](/doc/deploy-manual.md)
  - [Automated Deployment via GitHub Actions](/doc/deploy-automated.md)
  - [SAS Solution Order Notes](/doc/sas-solution-order.md)
  - [SAS Viya CLI Notes](/doc/sas-viya-cli.md)
  - [Access Environment](/doc/access.md)
  - [Environment Sizing](/doc/environment-sizing.md)
  - [SSO Configuration with Microsoft Entra ID](/doc/sso-entra-id.md)
- [Delete Deployment](/doc/delete.md)

> For details, follow the links above or browse the `/doc` folder.

---

## Contributing

Maintainers are not currently accepting software patches to this project. The project does welcome contributions to documentation. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for additional details. For instructions on reporting potential security issues, see [`SECURITY.md`](SECURITY.md).

---

## License

This project is licensed under the [Apache 2.0 License](LICENSE).

---
## Additional Resources

- [Create and publish an Azure Managed Application definition](https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/publish-service-catalog-app?tabs=azure-portal)
- [Deploy a service catalog managed application](https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/deploy-service-catalog-quickstart?tabs=azure-portal)
- [ARM Templates](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/overview)