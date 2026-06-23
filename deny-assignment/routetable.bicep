targetScope = 'resourceGroup'

@description('Location for the route table. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Name of the route table that hosts the protected user defined route (UDR).')
param routeTableName string

@description('Next hop IP address (virtual appliance / firewall) for the force tunneling route.')
param nextHopIpAddress string = '10.0.0.4'

// Route table with a force-tunneling UDR (0.0.0.0/0 -> virtual appliance).
// This is the resource we later protect with an Azure deny assignment.
resource routeTable 'Microsoft.Network/routeTables@2023-11-01' = {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'forceTunneling'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nextHopIpAddress
        }
      }
    ]
  }
}

output routeTableName string = routeTable.name
output routeTableId string = routeTable.id
