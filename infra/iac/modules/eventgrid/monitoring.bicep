// Monitoring Module
// This module creates monitoring resources for the Event Grid architecture

@description('Environment name (dev, test, prod)')
param environmentName string

@description('Location code for resource naming')
param locationCode string

@description('Project name for resource naming')
param projectName string

@description('Location for resources')
param location string

@description('Tags for all resources')
param tags object

@description('Monitoring configuration')
param monitoringConfig object = {
  logRetentionDays: 30
  enableDiagnostics: true
}

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${baseName}-logs-vv-${projectName}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: monitoringConfig.logRetentionDays
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${baseName}-insights-vv-${projectName}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey