targetScope = 'resourceGroup'

@description('Policy Definition ID')
param policyDefinitionId string

@description('Evaluation delay for policy in ISO 8601 duration format')
param evaluationDelay string = 'PT0M'

param prefix string

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'Global'
}

// Policy Assignment at Resource Group scope
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: prefix
  properties: {
    displayName: 'Assign Storage Private Endpoint DNS Policy'
    description: 'This assignment ensures storage private endpoints have DNS zone groups configured'
    policyDefinitionId: policyDefinitionId
    parameters: {
      privateDnsZoneId: {
        value: privateDnsZone.id
      }
      evaluationDelay: {
        value: evaluationDelay
      }
    }
    enforcementMode: 'Default'
  }
  identity: {
    type: 'SystemAssigned'
  }
  location: resourceGroup().location
}

// Role Assignment for the managed identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, policyAssignment.id, 'Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: policyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Network Contributor role for private endpoint operations
resource networkRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, policyAssignment.id, 'NetworkContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7') // Network Contributor
    principalId: policyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
