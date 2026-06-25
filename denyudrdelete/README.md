# Avoid UDR and route table deletion with Azure Policy

This folder protects a force-tunneling user defined route (`0.0.0.0/0` → virtual appliance) and its route table against deletion using two Azure Policy custom definitions with the `denyAction` effect.

The sibling folder [`../deny-assignment`](../deny-assignment) solves the same goal with an RBAC deny assignment and compares both approaches.

## Files

| File | Purpose |
| --- | --- |
| [main.bicep](main.bicep) | Subscription-scope entry point; creates the resource group and deploys `infra.bicep` |
| [infra.bicep](infra.bicep) | Two peered virtual networks, the route table with the force-tunneling route, an Azure Firewall, and a virtual machine |
| [vm.bicep](vm.bicep) | Virtual machine module |
| [policy.deny.udr.delete.json](policy.deny.udr.delete.json) | `DenyUDRDelete` — denies `delete` on `routeTables/routes` where `addressPrefix == 0.0.0.0/0` |
| [policy.deny.rt.delete.json](policy.deny.rt.delete.json) | `DenyRTDelete` — denies `delete` on the whole `routeTables` resource |

## Deploy the infrastructure

~~~bash
cd denyudrdelete
prefix=cptdazpolicy
location=germanywestcentral
currentUserObjectId=$(az ad signed-in-user show --query id -o tsv)
myip=$(curl ifconfig.io)
subId=$(az account show --query id -o tsv)
az deployment sub create -n $prefix -l $location --template-file main.bicep -p subscriptionId=$subId prefix=$prefix currentUserObjectId=$currentUserObjectId
~~~

## Verify the force-tunneling route

~~~bash
# effective routes of the VM NIC
az network nic show-effective-route-table -g $prefix -n ${prefix}1 -o table
# all routes of the route table
az network route-table route list -g $prefix --route-table-name $prefix -o table
# confirm traffic leaves through the firewall public IP
az network public-ip show -g $prefix -n ${prefix}fw -o tsv --query ipAddress
az vm run-command invoke -g $prefix -n ${prefix}1 --command-id RunShellScript --scripts 'curl https://ifconfig.io'
~~~

## Protect the route (DenyUDRDelete)

~~~bash
# create the policy
az policy definition create --name "DenyUDRDelete" --display-name "DenyUDRDelete" --description "Deny UDR Delete" --rules policy.deny.udr.delete.json --mode All
# assign the policy to the resource group
az policy assignment create --name "DenyUDRDelete" --display-name "Deny UDR Delete" --policy "DenyUDRDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
# the route delete is now blocked
az network route-table route delete -g $prefix --route-table-name $prefix -n forceTunneling   # RequestDisallowedByPolicy
~~~

## Protect the route table (DenyRTDelete)

~~~bash
# create the policy
az policy definition create --name "DenyRTDelete" --display-name "DenyRTDelete" --description "Deny Route Table Delete" --rules policy.deny.rt.delete.json --mode All
# assign the policy to the resource group
az policy assignment create --name "DenyRTDelete" --display-name "Deny RT Delete" --policy "DenyRTDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
# the route table delete is now blocked
az network route-table delete -g $prefix -n $prefix   # RequestDisallowedByPolicy
~~~

## Notes

- `denyAction` blocks `delete` only. It does not stop a caller from **modifying** the next hop of an existing route. Use an RBAC deny assignment (see [`../deny-assignment`](../deny-assignment)) to also block `write`.
- An `Owner` can unassign or delete the policy assignment unless it is separately protected.

## Cleanup

~~~bash
az policy assignment delete --name "DenyUDRDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
az policy assignment delete --name "DenyRTDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
az policy definition delete --name "DenyUDRDelete"
az policy definition delete --name "DenyRTDelete"
az group delete -n $prefix --yes --no-wait
~~~
