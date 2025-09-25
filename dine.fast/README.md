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


# Clean up, delete all resource groups starting with $prefix
foreach ($rg in $resourceGroups) {
    Write-Host "Deleting Resource Group: $rg"
    az group delete --name $rg --yes --no-wait
}    

# Delete the policy definition
az policy definition delete --name $prefix