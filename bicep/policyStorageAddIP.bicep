targetScope = 'subscription'

resource allowedLocations 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'Allowed locations'
  properties: {
    policyType: 'BuiltIn'
    displayName: 'Allowed locations'
    description: 'This policy enables you to restrict the locations ...'
    metadata: {
      version: '1.0.0'
      category: 'General'
    }
    mode: 'Indexed'
    parameters: {
      listOfAllowedLocations: {
        type: 'Array'
        metadata: {
        description: 'The list of locations that can be specified when deploying resources.'
        strongType: 'location'
        displayName: 'Allowed locations'
      }
    }
  }
  policyRule: {
    if: {
      allOf: [
        {
          field: 'location'
          notIn: '[parameters(\'listOfAllowedLocations\')]'
        }
        {
          field: 'location'
          notEquals: 'global'
        }
        {
          field: 'type'
          notEquals: 'Microsoft.AzureActiveDirectory/b2cDirectories'
        }
      ]
    }
    then: {
      effect: 'Deny'
    }
  }
}
}
