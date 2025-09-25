targetScope = 'subscription'

param prefix string = 'cptdazpolicy'
param location string = 'northeurope'

// 0m
resource rg0minute 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}0m'
  location: location
}

module policyAssignment0minute 'policyAssignment.bicep' = {
  name: '${prefix}-policyAssignment-0minute'
  scope: resourceGroup('${prefix}0m')
  params: {
    prefix: '${prefix}0m'
    policyDefinitionId: dinePolicy.id
  }
    dependsOn: [
    rg0minute
  ]
}

// 10m
resource rg10minute 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}10m'
  location: location
}

module policyAssignment10minute 'policyAssignment.bicep' = {
  name: '${prefix}-policyAssignment-10minute'
  scope: resourceGroup('${prefix}10m')
  params: {
    prefix: '${prefix}10m'
    policyDefinitionId: dinePolicy.id
  }
  dependsOn: [
    rg10minute
  ]
}

// AfterProvisioning
resource rgAfterProvisioning 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}ap'
  location: location
}

module policyAssignmentAfterProvisioning 'policyAssignment.bicep' = {
  name: '${prefix}-policyAssignment-ap'
  scope: resourceGroup('${prefix}ap')
  params: {
    prefix: '${prefix}ap'
    policyDefinitionId: dinePolicy.id
  }
    dependsOn: [
    rgAfterProvisioning
  ]
}

// AfterProvisioningSuccess
resource rgAfterProvisioningSuccess 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}aps'
  location: location
}

module policyAssignmentAfterProvisioningSuccess 'policyAssignment.bicep' = {
  name: '${prefix}-policyAssignment-aps'
  scope: resourceGroup('${prefix}aps')
  params: {
    prefix: '${prefix}aps'
    policyDefinitionId: dinePolicy.id
  }
    dependsOn: [
    rgAfterProvisioningSuccess
  ]
}

// DINE Policy Definition for Storage Account Private Endpoints
resource dinePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: prefix
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Deploy DNS Zone Group for Storage Private Endpoints if not exists'
    description: 'This policy will create DNS zone group entries for blob storage private endpoints if they do not exist'
    metadata: {
      category: 'Storage'
    }
    parameters: {
      privateDnsZoneId: {
        type: 'String'
        metadata: {
          displayName: 'Private DNS Zone ID'
          description: 'The resource ID of the private DNS zone for blob storage'
          strongType: 'Microsoft.Network/privateDnsZones'
        }
      }
      evaluationDelay: {
        type: 'String'
        defaultValue: 'PT0M'
        metadata: {
          displayName: 'Evaluation Delay'
          description: 'The delay before policy evaluation. Use ISO 8601 duration format (PT0M, PT1M, etc.) or special keywords (AfterProvisioning, AfterProvisioningSuccess, AfterProvisioningFailure)'
        }
        allowedValues: [
          'PT0M'
          'PT1M'
          'PT5M'
          'PT10M'
          'AfterProvisioning'
          'AfterProvisioningSuccess'
          'AfterProvisioningFailure'
        ]
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            equals: 'Microsoft.Network/privateEndpoints'
            field: 'type'
          }
          {
            count: {
              field: 'Microsoft.Network/privateEndpoints/privateLinkServiceConnections[*]'
              where: {
                allOf: [
                  {
                    field: 'Microsoft.Network/privateEndpoints/privateLinkServiceConnections[*].privateLinkServiceId'
                    contains: 'Microsoft.Storage/storageAccounts'
                  }
                  {
                    field: 'Microsoft.Network/privateEndpoints/privateLinkServiceConnections[*].groupIds[*]'
                    equals: 'blob'
                  }
                ]
              }
            }
            greaterOrEquals: 1
          }
        ]
      }
      then: {
        effect: 'deployIfNotExists'
        details: {
          type: 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups'
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor
            '/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
          ]
          evaluationDelay: '[parameters(\'evaluationDelay\')]'
          deployment: {
            properties: {
              mode: 'incremental'
              parameters: {
                privateDnsZoneId: {
                  value: '[parameters(\'privateDnsZoneId\')]'
                }
                privateEndpointName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
              }
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  privateDnsZoneId: {
                    type: 'string'
                  }
                  privateEndpointName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    apiVersion: '2022-07-01'
                    location: '[parameters(\'location\')]'
                    name: '[concat(parameters(\'privateEndpointName\'), \'/deployedByPolicy\')]'
                    properties: {
                      privateDnsZoneConfigs: [
                        {
                          name: 'blob-private-dns-zone'
                          properties: {
                            privateDnsZoneId: '[parameters(\'privateDnsZoneId\')]'
                          }
                        }
                      ]
                    }
                    type: 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups'
                  }
                ]
              }
            }
          }
        }
      }
    }
  }
}

