// Monitoring Module
// This module creates monitoring resources for the VeritasVault platform

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
  deploySentinel: false
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
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
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
    DisableIpMasking: false
    SamplingPercentage: 100
  }
}

// Dashboard for monitoring
resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: '${baseName}-dashboard-vv-${projectName}'
  location: location
  tags: tags
  properties: {
    lenses: {
      '0': {
        order: 0
        parts: {
          '0': {
            position: {
              x: 0
              y: 0
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              inputs: [
                {
                  name: 'resourceTypeMode'
                  isOptional: true
                  value: 'workspace'
                }
                {
                  name: 'ComponentId'
                  isOptional: true
                  value: {
                    SubscriptionId: subscription().subscriptionId
                    ResourceGroup: resourceGroup().name
                    Name: logAnalyticsWorkspace.name
                  }
                }
              ]
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              settings: {
                content: {
                  Query: 'AppEvents | summarize count() by AppRoleInstance | render piechart'
                  PartTitle: 'Application Events'
                }
              }
            }
          }
        }
      }
    }
    metadata: {
      model: {}
    }
  }
}

// Azure Sentinel (conditional)
resource sentinel 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = if (monitoringConfig.deploySentinel) {
  name: 'SecurityInsights(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: 'SecurityInsights(${logAnalyticsWorkspace.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/SecurityInsights'
    promotionCode: ''
  }
}

// Action Group for alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2022-06-01' = {
  name: '${baseName}-actiongroup-vv-${projectName}'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'vvAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'emailAction'
        emailAddress: 'alerts@veritasvault.ai'
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: []
    webhookReceivers: []
    itsmReceivers: []
    azureAppPushReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceivers: [
      {
        name: 'Monitoring Contributor'
        roleId: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Alert for high CPU usage
resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${baseName}-cpualert-vv-${projectName}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when CPU usage is high'
    severity: 2
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'High CPU'
          metricName: 'CpuPercentage'
          dimensions: []
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output actionGroupId string = actionGroup.id