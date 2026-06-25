# Azure governance demos: deny assignments and Azure Policy

A collection of small, self-contained demos that show how to protect Azure resources from unwanted changes or deletion. Each subproject lives in its own folder with a dedicated README.

## Subprojects

| Subproject | What it shows |
| --- | --- |
| [deny-assignment](deny-assignment/README.md) | Protect a route table (UDR) with an RBAC **deny assignment** that overrides `Owner`. Includes a guided [Jupyter notebook](deny-assignment/deny-assignment-demo.ipynb) and a management-group guardrail scenario. |
| [denyudrdelete](denyudrdelete/README.md) | Protect a force-tunneling route and its route table from **deletion** with Azure Policy `denyAction`. |
| [denytagdelete](denytagdelete/README.md) | Attempt to protect a resource **tag** with Azure Policy `denyAction` (Terraform-based) — and why it does not work. |
| [bicep](bicep/README.md) | Storage account governance policies: TLS/SSL enforcement, disallow public access, IP firewall, and deny deletion. |
| [dine.fast](dine.fast/README.md) | Blob Storage with a private endpoint and a **DeployIfNotExists** policy for the private DNS zone group. |

## Common prerequisites

- Azure CLI, signed in: `az login`
- Bicep CLI (bundled with recent Azure CLI)
- Terraform (only for [denytagdelete](denytagdelete/README.md))
- A subscription where you can create resource groups, policies, and role or deny assignments

Most demos share these variables:

~~~bash
prefix=cptdazpolicy
location=germanywestcentral
subId=$(az account show --query id -o tsv)
~~~


