// Lab 06 - Log Analytics, diagnostic settings, alerty, action group
param location string = resourceGroup().location
param alertEmail string

var tags = { environment: 'dev', project: 'az104-portfolio' }

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-lab06'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-lab06-mail'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'lab06'
    enabled: true
    emailReceivers: [ {
      name: 'admin'
      emailAddress: alertEmail
      useCommonAlertSchema: true
    } ]
  }
}

// Alert metryczny: CPU VMSS z lab-04 (parametr - resource ID monitorowanego zasobu)
param monitoredResourceId string = ''

resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(monitoredResourceId)) {
  name: 'alert-high-cpu'
  location: 'global'
  tags: tags
  properties: {
    severity: 2
    enabled: true
    scopes: [ monitoredResourceId ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [ {
        name: 'HighCPU'
        metricName: 'Percentage CPU'
        operator: 'GreaterThan'
        threshold: 80
        timeAggregation: 'Average'
        criterionType: 'StaticThresholdCriterion'
      } ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// Alert aktywnosci: usuniecie resource groupy w subskrypcji
resource activityAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-rg-delete'
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    scopes: [ subscription().id ]
    condition: {
      allOf: [
        { field: 'category', equals: 'Administrative' }
        { field: 'operationName', equals: 'Microsoft.Resources/subscriptions/resourceGroups/delete' }
      ]
    }
    actions: {
      actionGroups: [ { actionGroupId: actionGroup.id } ]
    }
  }
}

output workspaceId string = law.id
