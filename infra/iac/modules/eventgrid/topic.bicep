// Event Grid Topic Module
// This module creates an Event Grid Topic

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

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// Event Grid Topic
resource eventGridTopic 'Microsoft.EventGrid/topics@2023-12-15-preview' = {
  name: '${baseName}-topic-vv-${projectName}'
  location: location
  tags: tags
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
    dataResidencyBoundary: 'WithinGeopair'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Outputs
output topicName string = eventGridTopic.name
output topicId string = eventGridTopic.id
output topicEndpoint string = eventGridTopic.properties.endpoint