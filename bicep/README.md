# Azure Storage governance policies

This folder collects Bicep templates and Azure Policy definitions used to experiment with storage account governance: TLS/SSL enforcement, disallowing anonymous public access, IP firewall rules, and denying deletion of a storage account.

The subscription-scope entry point [`../deploy.bicep`](../deploy.bicep) creates a resource group and deploys [sab.bicep](sab.bicep).

## Files

| File | Purpose |
| --- | --- |
| [sab.bicep](sab.bicep) | Storage account with an IP firewall rule (`defaultAction: Deny`), a blob service, and a container |
| [policyStorageAddIP.bicep](policyStorageAddIP.bicep) | Built-in `Allowed locations` policy definition example |
| [storagesslpolicy.json](storagesslpolicy.json) | Deploy a minimum TLS version and enforce SSL/HTTPS on storage accounts |
| [storagessl1policy.json](storagessl1policy.json) | Enforce TLS 1.1 on storage accounts |
| [storagessl2policy.json](storagessl2policy.json) | Enforce TLS 1.2 on storage accounts |
| [sapublicyes.json](sapublicyes.json) | Configure storage account public access to be disallowed |
| [denyactionpolicy.json](denyactionpolicy.json) | `denyAction` policy that denies deletion of a storage account |

## Related templates at the repository root

| File | Purpose |
| --- | --- |
| [../deploy.bicep](../deploy.bicep) | Subscription-scope deployment that creates the resource group and deploys `sab.bicep` |
| [../policy.conflict.bicep](../policy.conflict.bicep) | Assigns the built-in TLS 1.1 and TLS 1.2 policies together to study conflicting effects |
| [../test.bicep](../test.bicep) | Standalone `Azure Storage enforce TLS1_2` policy definition object |

## Deploy

~~~bash
prefix=cptdazpolicy
location=germanywestcentral
myobjectid=$(az ad signed-in-user show --query id -o tsv)
myip=$(curl ifconfig.io)
az deployment sub create -n $prefix -l $location --template-file deploy.bicep \
  -p prefix=$prefix myobjectid=$myobjectid myip=$myip
~~~
