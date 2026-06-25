# Protect Azure resource tags with Azure Policy

This folder explores whether an Azure Policy `denyAction` effect can stop a tag on a virtual network from being modified or removed. The infrastructure is provisioned with Terraform, and the policy is created and assigned with the Azure CLI.

## Result

**It does not work.** Azure Policy `denyAction` cannot protect tag modification or deletion. The policy assignment is accepted, but tag updates and removals still succeed. See [Conclusion](#conclusion).

## Files

| File | Purpose |
| --- | --- |
| [main.tf](main.tf) | Terraform that deploys a resource group and a virtual network with a `Network-Type` tag |
| [terraform.tfvars.json](terraform.tfvars.json) | Terraform variable values (subscription id, prefix, location) |
| [policy.deny.tag.delete.json](policy.deny.tag.delete.json) | `DenyTagDelete` policy rule (`denyAction` on virtual networks that carry the `Network-Type` tag) |

## Deploy the infrastructure

~~~powershell
$prefix="cptdazpolicy"
$location="germanywestcentral"
$currentUserObjectId=az ad signed-in-user show --query id -o tsv
$subId = (Get-Content -Raw -Path "terraform.tfvars.json" | ConvertFrom-Json).subscription_id
az account set --subscription $subId
cd denytagdelete
terraform init
terraform apply --auto-approve
az network vnet show -g $prefix -n $prefix --query tags
~~~

## Create the policy

~~~bash
# list all custom policies under current subscription
az policy definition list --subscription $subId --query "[?policyType=='Custom'].displayName" -o table
# create the policy that should protect the tag
az policy definition create --name "DenyTagDelete" --display-name "DenyTagDelete" --description "Deny Tag Delete" --rules policy.deny.tag.delete.json --mode Indexed
# show the policy
az policy definition show --name "DenyTagDelete"
~~~

## Assign the policy

~~~bash
az policy assignment create --name "DenyTagDelete" --display-name "Deny Tag Delete" --policy "DenyTagDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
az policy assignment show --name "DenyTagDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
~~~

## Try to change or remove the tag

~~~bash
# modify the tag value
az network vnet update -g $prefix -n $prefix --set tags.Network-Type="Hub"   # not denied, policy does not apply
az network vnet update -g $prefix -n $prefix --set tags.Network-Type="Spoke"
# remove the tag
az network vnet update -g $prefix -n $prefix --remove tags.Network-Type
~~~

## Conclusion

It is not possible to protect tag modification or deletion with the Azure Policy `denyAction` effect. To block changes to a resource, use an RBAC deny assignment instead — see [`../deny-assignment`](../deny-assignment).
