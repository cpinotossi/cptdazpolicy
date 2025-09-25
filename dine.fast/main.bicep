targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name prefix for resources')
param prefix string = 'cptdazpolicy'

@description('Admin username for the VM')
param adminUsername string = 'chpinoto'

@description('Admin username for the VM')
@secure()
param password string = 'demo!pass123'


// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: prefix
  location: location
  properties: {
    securityRules: [
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: prefix
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: prefix
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: prefix
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Private DNS Zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  // scope: resourceGroup('${prefix}0m')
}

// Private DNS Zone Virtual Network Link
resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: prefix
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private Endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = {
  name: prefix
  location: location
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${prefix}'
    }
    privateLinkServiceConnections: [
      {
        name: prefix
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group
// resource privateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = {
//   parent: privateEndpoint
//   name: 'default'
//   properties: {
//     privateDnsZoneConfigs: [
//       {
//         name: 'config1'
//         properties: {
//           privateDnsZoneId: privateDnsZone.id
//         }
//       }
//     ]
//   }
// }

// Network Interface for VM
// resource nic 'Microsoft.Network/networkInterfaces@2023-06-01' = {
//   name: prefix
//   location: location
//   properties: {
//     ipConfigurations: [
//       {
//         name: 'ipconfig1'
//         properties: {
//           privateIPAllocationMethod: 'Dynamic'
//           subnet: {
//             id: '${vnet.id}/subnets/${prefix}'
//           }
//         }
//       }
//     ]
//   }
// }

// // Virtual Machine (cheapest Linux VM)
// resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
//   name: prefix
//   location: location
//   properties: {
//     hardwareProfile: {
//       vmSize: 'Standard_B1ls' // Cheapest Linux VM size
//     }
//     osProfile: {
//       computerName: prefix
//       adminUsername: adminUsername
//       adminPassword: password
//       linuxConfiguration: {
//         disablePasswordAuthentication: false
//       }
//     }
//     storageProfile: {
//       imageReference: {
//         publisher: 'Canonical'
//         offer: '0001-com-ubuntu-server-jammy'
//         sku: '22_04-lts-gen2'
//         version: 'latest'
//       }
//       osDisk: {
//         createOption: 'FromImage'
//         managedDisk: {
//           storageAccountType: 'Standard_LRS'
//         }
//       }
//     }
//     networkProfile: {
//       networkInterfaces: [
//         {
//           id: nic.id
//         }
//       ]
//     }
//   }
// }

