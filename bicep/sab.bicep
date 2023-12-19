targetScope='resourceGroup'

param prefix string
param location string
param myObjectId string
param myip string


resource sa 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: prefix
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      resourceAccessRules: []
      bypass: 'AzureServices'
      ipRules: [
        {
          value: myip
          action: 'Allow'
        }
      ]
      defaultAction: 'Deny'
    }
    accessTier: 'Hot'
  }
}

resource sab 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: sa
  name: 'default'
}

resource sac 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  parent: sab
  name: prefix
  properties: {
    publicAccess: 'Blob'
  }
}

var roleStorageBlobDataContributorName = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //Storage Blob Data Contributor

resource rablobcontributor 'Microsoft.Authorization/roleAssignments@2018-01-01-preview' = {
  name: guid(resourceGroup().id,'rablobcontributort')
  properties: {
    principalId: myObjectId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/RoleDefinitions',roleStorageBlobDataContributorName)
  }
}
