// Blob Storage Module
// This module creates a Storage Account with blob containers for the VeritasVault platform

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

@description('Blob Storage configuration')
param blobStorageConfig object = {
  sku: 'Standard_LRS'
  kind: 'StorageV2'
  accessTier: 'Hot'
  containers: [
    {
      name: 'documents'
      publicAccess: 'None'
    }
  ]
}

@description('Networking configuration')
param networkingConfig object = {
  privateEndpoints: {
    enabled: false
  }
  subnetId: ''
}

// Resource naming convention
var baseName = replace('${environmentName}${locationCode}', '-', '')
var uniqueSuffix = uniqueString(resourceGroup().id)

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${baseName}sa${projectName}${uniqueSuffix}'
  location: location
  tags: tags
  kind: blobStorageConfig.kind
  sku: {
    name: blobStorageConfig.sku
  }
  properties: {
    accessTier: blobStorageConfig.accessTier
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: networkingConfig.privateEndpoints.enabled ? 'Deny' : 'Allow'
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: environmentName == 'prod'
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: environmentName == 'prod'
      days: 7
    }
  }
}

// Blob Containers
resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for container in blobStorageConfig.containers: {
  parent: blobService
  name: container.name
  properties: {
    publicAccess: container.publicAccess
  }
}]

// Private Endpoint for Blob Storage (if enabled)
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = if (networkingConfig.privateEndpoints.enabled && !empty(networkingConfig.subnetId)) {
  name: '${baseName}-pe-vv-${projectName}-blob'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'blob-storage-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: networkingConfig.subnetId
    }
  }
}

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output storageAccountBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output containerNames array = [for (container, i) in blobStorageConfig.containers: blobContainers[i].name]