// Dead Letter Storage Module
// This module creates a storage account and container for Event Grid dead letters

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
var uniqueSuffix = uniqueString(resourceGroup().id)

// Dead Letter Storage Account
resource deadLetterStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(baseName, '-', '')}dlvv${projectName}${uniqueSuffix}'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// Dead Letter Container
resource deadLetterContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${deadLetterStorage.name}/default/deadletter'
  properties: {
    publicAccess: 'None'
  }
}

// Outputs
output storageId string = deadLetterStorage.id
output storageName string = deadLetterStorage.name
output containerName string = 'deadletter'