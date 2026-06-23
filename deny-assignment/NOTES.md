# Azure Deny Assignment

This is a simple test in which we use Deny assignment to avoid the modification of an Azure Route Table UDR based on https://learn.microsoft.com/en-us/powershell/module/az.resources/new-azdenyassignment?view=azps-16.0.0

## Files

- [routetable.bicep](routetable.bicep) - deploys the protected route table with a force-tunneling UDR.
- [denyassignment.bicep](denyassignment.bicep) - deploys the deny assignment (`Microsoft.Authorization/denyAssignments@2024-07-01-preview`) that blocks write/delete on the route table and its routes.
- [deny-assignment-demo.ipynb](deny-assignment-demo.ipynb) - step-by-step walkthrough (bash + Azure CLI only) showing the UDR being modified **without** the deny assignment and **blocked with** it.

