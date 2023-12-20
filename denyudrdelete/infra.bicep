targetScope = 'resourceGroup'

@description('Object ID of the current user')
param currentUserObjectId string

@description('Location to deploy all resources')
param location string = resourceGroup().location

@description('Prefix used in the Naming for multiple Deployments in the same Subscription')
param prefix string

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++
// NETWORK
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++

resource vnet1 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: '${prefix}1'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
    ]
  }
  dependsOn: [
    vnet2
  ]
}

resource vnet2 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: '${prefix}2'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties:{
          addressPrefix: '10.1.0.0/24'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties:{
          addressPrefix: '10.1.1.0/24'
        }
      }
    ]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  parent: vnet1
  name: '${prefix}1'
  properties: {
    privateEndpointNetworkPolicies: 'Disabled'
    addressPrefix: '10.0.0.0/24'
    routeTable: {
      id: routeTable.id
    }
  }
}

// peering vnet and vnet2
resource vnetPeering1to2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-05-01' = {
  parent: vnet1
  name: '${prefix}1'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnet2.id
    }
  }
}

// peering vnet and vnet2
resource vnetPeering2to1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-05-01' = {
  parent: vnet2
  name: '${prefix}2'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnet1.id
    }
  }
}


resource routeTable 'Microsoft.Network/routeTables@2022-05-01' = {
  name: prefix
  location: location
  properties: {
    routes: [
      {
        name: 'forceTunneling'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.1.0.4'
        }
      }
    ]
  }
}


// ++++++++++++++++++++++++++++++++++++++++++++++++++++++
// COMPUTE
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++

module vm1 'vm.bicep' = {
  name: '${prefix}1'
  params: {
    location: location
    vmName: '${prefix}1'
    vnetName: '${prefix}1'
    subnetName: '${prefix}1'
    userObjectId: currentUserObjectId
    privateip: '10.0.0.4'
  }
  dependsOn:[
    vnet1
    subnet
  ]
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: prefix
  location: location
}

resource raMID2VMContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id,identity.id,'Virtual Machine Contributor')
  properties: {
    roleDefinitionId: builtInRoleNames['Virtual Machine Contributor']
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
   }
  scope: resourceGroup()
}

resource raMID2Reader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id,identity.id,'Reader')
  properties: {
    roleDefinitionId: builtInRoleNames['Reader']
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
   }
  scope: resourceGroup()
}

var builtInRoleNames = {
  Contributor: tenantResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  'Data Operator for Managed Disks': tenantResourceId('Microsoft.Authorization/roleDefinitions', '959f8984-c045-4866-89c7-12bf9737be2e')
  'Disk Backup Reader': tenantResourceId('Microsoft.Authorization/roleDefinitions', '3e5e47e6-65f7-47ef-90b5-e5dd4d455f24')
  'Disk Pool Operator': tenantResourceId('Microsoft.Authorization/roleDefinitions', '60fc6e62-5479-42d4-8bf4-67625fcc2840')
  'Disk Restore Operator': tenantResourceId('Microsoft.Authorization/roleDefinitions', 'b50d9833-a0cb-478e-945f-707fcc997c13')
  'Disk Snapshot Contributor': tenantResourceId('Microsoft.Authorization/roleDefinitions', '7efff54f-a5b4-42b5-a1c5-5411624893ce')
  Owner: tenantResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  Reader: tenantResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  'Role Based Access Control Administrator (Preview)': tenantResourceId('Microsoft.Authorization/roleDefinitions', 'f58310d9-a9f6-439a-9e8d-f62e7b41a168')
  'User Access Administrator': tenantResourceId('Microsoft.Authorization/roleDefinitions', '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9')
  'Virtual Machine Contributor': tenantResourceId('Microsoft.Authorization/roleDefinitions', '9980e02c-c2be-4d73-94e8-173b1dc7cf3c')
}

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++
// FIREWALL
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++

resource fwIpGroup 'Microsoft.Network/ipGroups@2023-06-01' = {
  name: prefix
  location: location
  properties: {
    ipAddresses: [
      '10.0.0.0/24'
    ]
  }
}

resource fwPublicIp 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: '${prefix}fw'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource fwPublicIpMgmt 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: '${prefix}fwmgmt'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}


resource fwPolicy 'Microsoft.Network/firewallPolicies@2023-06-01'= {
  name: prefix
  location: location
  properties: {
    sku: {
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
  }
}

resource networkRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-06-01' = {
  parent: fwPolicy
  name: prefix
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        name: prefix
        priority: 1250
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'internet'
            ipProtocols: [
              'UDP'
              'TCP'
            ]
            destinationAddresses: [
              '*'
            ]
            sourceIpGroups: [
              fwIpGroup.id
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-06-01' = {
  name: prefix
  location: location
  dependsOn: [
    fwIpGroup
    networkRuleCollectionGroup
  ]
  properties: {
    sku:{
      name: 'AZFW_VNet'
      tier:'Basic'
    }
    ipConfigurations: [
      {
        name: prefix
        properties:{
          publicIPAddress: {
            id: fwPublicIp.id
          }
          subnet: {
            id: '${vnet2.id}/subnets/azureFirewallSubnet'

          }
        }
      }
    ]
    managementIpConfiguration: {
      name: prefix
      properties:{
        publicIPAddress: {
          id: fwPublicIpMgmt.id
        }
        subnet: {
          id: '${vnet2.id}/subnets/azureFirewallManagementSubnet'
        }
      }
    }
    firewallPolicy: {
      id: fwPolicy.id
    }
  }  
}
