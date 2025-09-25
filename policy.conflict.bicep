param location string = 'germanywestcentral'
param prefix string

param deployTLS1 bool = true
param deployTLS2 bool = true

// Needed Roles can be found here: https://www.azadvertizer.net/azpolicyinitiativesadvertizer/53448c70-089b-4f52-8f38-89196d7f2de1.html
var policyTLS2Id = '/subscriptions/7d78637d-e12e-4374-82de-06e12f808df6/providers/Microsoft.Authorization/policyDefinitions/b3396a60-4edd-422d-8c55-5436916f40d4'
var policyTLS1Id = '/subscriptions/7d78637d-e12e-4374-82de-06e12f808df6/providers/Microsoft.Authorization/policyDefinitions/b3396a60-4edd-422d-8c55-5436916f40e4'

var policyAssignmentTLS1Name = guid(policyTLS1Id, resourceGroup().name)
var policyAssignmentTLS2Name = guid(policyTLS2Id, resourceGroup().name)

resource policyAssignmentTLS1 'Microsoft.Authorization/policyAssignments@2023-04-01' = if (deployTLS1){
  name: policyAssignmentTLS1Name
  scope: resourceGroup()
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: policyTLS1Id
    displayName: '${prefix}tls1'
    description: 'force tls 1'
  }
}

resource policyAssignmentTLS2 'Microsoft.Authorization/policyAssignments@2023-04-01' = if (deployTLS2){
  name: policyAssignmentTLS2Name
  scope: resourceGroup()
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: policyTLS2Id
    displayName: '${prefix}tls2'
    description: 'force tls 2'
  }
}

// Define role IDs
var roleStorageAccountContributorName = '17d1049b-9a84-46fb-8f53-869881c3d3ab' //Storage Account Contributor

resource rablobcontributortls1 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployTLS1){
  name: guid(policyAssignmentTLS1Name, resourceGroup().id,'rablobcontributort')
  scope: resourceGroup()
  properties: {
    principalId: policyAssignmentTLS1.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/RoleDefinitions',roleStorageAccountContributorName)
    principalType: 'ServicePrincipal'
  }
}

resource rablobcontributortls2 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployTLS2){
  name: guid(policyAssignmentTLS2Name, resourceGroup().id,'rablobcontributort')
  scope: resourceGroup()
  properties: {
    principalId: policyAssignmentTLS2.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/RoleDefinitions',roleStorageAccountContributorName)
    principalType: 'ServicePrincipal'
  }
}

