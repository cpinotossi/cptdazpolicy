targetScope='subscription'


// var location = resourceGroup().location
param location string = deployment().location
param myobjectid string
param myip string
param prefix string

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: prefix
  location: location
}

module sabModule 'bicep/sab.bicep' = {
  scope: resourceGroup(prefix)
  name: 'sabDeploy'
  params: {
    prefix: prefix
    location: location
    myip: myip
    myObjectId: myobjectid
  }
  dependsOn:[
        rg
  ]
}
