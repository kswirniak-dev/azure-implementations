// 01 - Governance: Resource Groups, tags, Azure Policy, lock
targetScope = 'subscription'

param location string = 'polandcentral'
param environment string = 'dev'

var tags = {
  environment: environment
  project: 'az104-portfolio'
  owner: 'karol'
}

resource rgWorkload 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-lab01-workload-${environment}'
  location: location
  tags: tags
}

resource rgShared 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-lab01-shared-${environment}'
  location: location
  tags: tags
}
resource requireTagPolicy 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'require-env-tag'
  properties: {
    policyDefinitionId: tenantResourceId(
      'Microsoft.Authorization/policyDefinitions',
      '871b6d14-10aa-478d-b590-94f262ecfa99'
    )
    parameters: {
      tagName: { value: 'environment' }
    }
  }
}

resource allowedLocations 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'allowed-locations'
  properties: {
    displayName: 'Allowed regions: Poland Central, West Europe'
    policyDefinitionId: tenantResourceId(
      'Microsoft.Authorization/policyDefinitions',
      'e56962a6-4747-49cd-b67b-bf8b01975c4c'
    )
    parameters: {
      listOfAllowedLocations: { value: ['polandcentral', 'westeurope'] }
    }
  }
}

module lockModule 'lock.bicep' = {
  name: 'deploy-lock'
  scope: rgShared
}

output workloadRgName string = rgWorkload.name
output sharedRgName string = rgShared.name
