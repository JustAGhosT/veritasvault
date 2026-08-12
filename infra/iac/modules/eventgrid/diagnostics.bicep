// Diagnostics Module
// This module creates diagnostic settings for Event Grid Topic

@description('Name of the Event Grid Topic')
param eventGridTopicName string

@description('ID of the Log Analytics Workspace')
param workspaceId string

// Reference to the Event Grid Topic
resource eventGridTopic 'Microsoft.EventGrid/topics@2023-12-15-preview' existing = {
  name: eventGridTopicName
}

// Diagnostic Settings for Event Grid Topic
resource eventGridDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'eventGridDiagnostics'
  scope: eventGridTopic
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'DeliveryFailures'
        enabled: true
      }
      {
        category: 'PublishFailures'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs
output diagnosticsId string = eventGridDiagnostics.id