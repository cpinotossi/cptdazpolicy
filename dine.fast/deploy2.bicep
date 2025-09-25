targetScope = 'subscription'

param prefix string = 'cptdazpolicy'
param location string = 'northeurope'

// 0m
module main0minute 'main.bicep' = {
  name: '${prefix}-main-0minute'
  scope: resourceGroup('${prefix}0m')
  params: {
    prefix: '${prefix}0m'
    location: location
  }
}

// 10m
module main10minute 'main.bicep' = {
  name: '${prefix}-main-10minute'
  scope: resourceGroup('${prefix}10m')
  params: {
    prefix: '${prefix}10m'
    location: location
  }
}

// AfterProvisioning
module mainAfterProvisioning 'main.bicep' = {
  name: '${prefix}-main-ap'
  scope: resourceGroup('${prefix}ap')
  params: {
    prefix: '${prefix}ap'
    location: location
  }
}

// AfterProvisioningSuccess
module mainAfterProvisioningSuccess 'main.bicep' = {
  name: '${prefix}-main-aps'
  scope: resourceGroup('${prefix}aps')
  params: {
    prefix: '${prefix}aps'
    location: location
  }
}

