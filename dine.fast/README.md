# Azure Blob Storage with Private Endpoint and DINE Policy

~~~powershell
az account set -s "onprem"
$subId = az account show --query id -o tsv
# Create resource group
$prefix = "cptdazpolicy"
# Deploy main infrastructure
az deployment sub create -l $location -f deploy1.bicep -p prefix=$prefix
az deployment sub create -l $location -f deploy2.bicep -p prefix=$prefix

# verify policy assignment for all resource groups which start with $prefix
# List all resource groups starting with $prefix
$resourceGroups = az group list --query "[?starts_with(name, '$prefix')].name" -o tsv
# For each resource group, list policy assignments starting with $prefix
foreach ($rg in $resourceGroups) {
    Write-Host "Resource Group: $rg"
    az policy assignment list --resource-group $rg --query "[?starts_with(name, '$prefix')].[name]" -o table
}



# Retrieve activity logs related to policy interactions in the last 6 hours and write to file with time range in name
az monitor activity-log list --offset 1h --max-events 1000 | Out-File -FilePath "activity.log.json"
powershell -ExecutionPolicy Bypass -File .\analyse.ps1
~~~

## Policy and Resource Event Logs

### ResourceGroup: `cptdazpolicy0m` (Events: 12)

| EventTimestamp               | EventSource | Status    | PolicyAssignmentName | OperationName                                               | OperationNameLocalized                | UpdatedResources |
|------------------------------|-------------|-----------|----------------------|-------------------------------------------------------------|---------------------------------------|-----------------|
| 2025-09-25T10:27:42.8841714Z | Resource    | Started   |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:42.8841714Z | Policy      | Started   |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:43.8061047Z | Policy      | Started   |                      | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    |                 |
| 2025-09-25T10:27:43.9154834Z | Resource    | Accepted  |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:54.5734351Z | Resource    | Running   |                      | Microsoft.Network/privateEndpoints/read                     | Get an private endpoint resource.     |                 |
| 2025-09-25T10:28:08.9325792Z | Resource    | Running   |                      | Microsoft.Network/privateEndpoints/read                     | Get an private endpoint resource.     |                 |
| 2025-09-25T10:28:10.666948Z  | Resource    | Succeeded |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:28:23.5020881Z | Policy      | Accepted  | cptdazpolicy0m        | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    |                 |
| 2025-09-25T10:28:24.1703891Z | Resource    | Started   |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:28:24.5922952Z | Resource    | Accepted  |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:28:27.1484708Z | Resource    | Succeeded |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:32:24.4524221Z | Policy      | Succeeded | cptdazpolicy0m        | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    | /subscriptions/<SUB-ID>/resourceGroups/cptdazpolicy0m/prov... |

**EventSource Summary:** Policy: 4 &nbsp;&nbsp; Resource: 8

---

### ResourceGroup: `cptdazpolicy10m` (Events: 11)

| EventTimestamp               | EventSource | Status    | PolicyAssignmentName | OperationName                                               | OperationNameLocalized                | UpdatedResources |
|------------------------------|-------------|-----------|----------------------|-------------------------------------------------------------|---------------------------------------|-----------------|
| 2025-09-25T10:27:42.4957315Z | Resource    | Started   |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:42.4957315Z | Policy      | Started   |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:43.2769912Z | Policy      | Started   |                      | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    |                 |
| 2025-09-25T10:27:43.3551226Z | Resource    | Accepted  |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:55.4327176Z | Resource    | Running   |                      | Microsoft.Network/privateEndpoints/read                     | Get an private endpoint resource.     |                 |
| 2025-09-25T10:28:09.3203406Z | Resource    | Succeeded |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:28:34.5584764Z | Policy      | Accepted  | cptdazpolicy10m       | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    |                 |
| 2025-09-25T10:28:34.8259661Z | Resource    | Started   |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:28:35.7165862Z | Resource    | Accepted  |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:28:36.8527557Z | Resource    | Succeeded |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:32:34.9778281Z | Policy      | Succeeded | cptdazpolicy10m       | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    | /subscriptions/<SUB-ID>/resourceGroups/cptdazpolicy10m/pro... |

**EventSource Summary:** Policy: 4 &nbsp;&nbsp; Resource: 7

---

### ResourceGroup: `cptdazpolicyap` (Events: 12)

| EventTimestamp               | EventSource | Status    | PolicyAssignmentName | OperationName                                               | OperationNameLocalized                | UpdatedResources |
|------------------------------|-------------|-----------|----------------------|-------------------------------------------------------------|---------------------------------------|-----------------|
| 2025-09-25T10:27:46.8479606Z | Resource    | Started   |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:46.8479606Z | Policy      | Started   |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:47.6448487Z | Policy      | Started   |                      | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    |                 |
| 2025-09-25T10:27:47.7386014Z | Resource    | Accepted  |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:58.2922785Z | Resource    | Running   |                      | Microsoft.Network/privateEndpoints/read                     | Get an private endpoint resource.     |                 |
| 2025-09-25T10:28:11.7444194Z | Resource    | Running   |                      | Microsoft.Network/privateEndpoints/read                     | Get an private endpoint resource.     |                 |
| 2025-09-25T10:28:14.1989714Z | Resource    | Succeeded |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:28:14.2969818Z | Policy      | Accepted  | cptdazpolicyap        | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    |                 |
| 2025-09-25T10:28:14.6127025Z | Resource    | Started   |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:28:15.1439551Z | Resource    | Accepted  |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:28:16.5743227Z | Resource    | Succeeded |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:32:14.934817Z  | Policy      | Succeeded | cptdazpolicyap        | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    | /subscriptions/<SUB-ID>/resourceGroups/cptdazpolicyap/pro... |

**EventSource Summary:** Policy: 4 &nbsp;&nbsp; Resource: 8

---

### ResourceGroup: `cptdazpolicyaps` (Events: 11)

| EventTimestamp               | EventSource | Status    | PolicyAssignmentName | OperationName                                               | OperationNameLocalized                | UpdatedResources |
|------------------------------|-------------|-----------|----------------------|-------------------------------------------------------------|---------------------------------------|-----------------|
| 2025-09-25T10:27:42.4649151Z | Resource    | Started   |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:42.4649151Z | Policy      | Started   |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:43.2149333Z | Policy      | Started   |                      | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    |                 |
| 2025-09-25T10:27:43.2774324Z | Resource    | Accepted  |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:27:56.4805465Z | Resource    | Running   |                      | Microsoft.Network/privateEndpoints/read                     | Get an private endpoint resource.     |                 |
| 2025-09-25T10:28:23.8263543Z | Policy      | Accepted  | cptdazpolicyaps       | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    |                 |
| 2025-09-25T10:28:24.4394845Z | Resource    | Started   |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:28:24.9237898Z | Resource    | Accepted  |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:28:27.7479434Z | Resource    | Succeeded |                      | Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write| Put Private DNS Zone Group            |                 |
| 2025-09-25T10:29:44.3174079Z | Resource    | Succeeded |                      | Microsoft.Network/privateEndpoints/write                    | Create or update an private endpoint. |                 |
| 2025-09-25T10:32:24.0184079Z | Policy      | Succeeded | cptdazpolicyaps       | Microsoft.Authorization/policies/deployIfNotExists/action   | 'deployIfNotExists' Policy action.    | /subscriptions/<SUB-ID>/resourceGroups/cptdazpolicyaps/pro... |

**EventSource Summary:** Policy: 4 &nbsp;&nbsp; Resource: 7



## Clean up, delete all resource groups starting with $prefix
~~~powershell
foreach ($rg in $resourceGroups) {
    Write-Host "Deleting Resource Group: $rg"
    az group delete --name $rg --yes --no-wait
}    

# Delete the policy definition
az policy definition delete --name $prefix