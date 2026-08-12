// Storage Account Module
// This module creates a storage account for Function Apps

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

@description('Storage account configuration')
param storageConfig object = {
  sku: 'Standard_LRS'
  kind: 'StorageV2'
}

// Resource naming convention
var baseName = replace('${environmentName}${locationCode}', '-', '')
var uniqueSuffix = uniqueString(resourceGroup().id)

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${baseName}sa${projectName}${uniqueSuffix}'
  location: location
  tags: tags
  kind: storageConfig.kind
  sku: {
    name: storageConfig.sku
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output storageAccountKey string = storageAccount.listKeys().keys[0].value