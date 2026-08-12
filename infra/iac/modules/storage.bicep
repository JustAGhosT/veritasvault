// Storage Module
// This module orchestrates the deployment of all storage resources for the VeritasVault platform

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

@description('Feature flags to control which storage resources are deployed')
param featureFlags object = {
  deployCosmosDb: true
  deployBlobStorage: true
  deployRedisCache: false
  deployTableStorage: false
  deployPrivateEndpoints: false
}

@description('Cosmos DB configuration')
param cosmosDbConfig object = {
  serverless: true
  multiRegionWrite: false
  containers: [
    {
      name: 'blockchain-events'
      partitionKeyPath: '/eventType'
      ttlInSeconds: 2592000 // 30 days
    }
  ]
}

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

@description('Redis Cache configuration')
param redisCacheConfig object = {
  skuName: 'Basic'
  capacity: 1
}

@description('Networking configuration')
param networkingConfig object = {
  privateEndpoints: {
    enabled: false
  }
  subnetId: ''
}

// Deploy Cosmos DB resources
module cosmosDb 'storage/cosmos-db.bicep' = if (featureFlags.deployCosmosDb) {
  name: 'cosmosDbDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    cosmosDbConfig: cosmosDbConfig
    networkingConfig: networkingConfig
  }
}

// Deploy Blob Storage resources
module blobStorage 'storage/blob-storage.bicep' = if (featureFlags.deployBlobStorage) {
  name: 'blobStorageDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    blobStorageConfig: blobStorageConfig
    networkingConfig: networkingConfig
  }
}

// Deploy Redis Cache resources
module redisCache 'storage/redis-cache.bicep' = if (featureFlags.deployRedisCache) {
  name: 'redisCacheDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    redisCacheConfig: redisCacheConfig
    networkingConfig: networkingConfig
  }
}

// Outputs
output cosmosDbEndpoint string = featureFlags.deployCosmosDb ? cosmosDb.outputs.cosmosDbEndpoint : ''
output cosmosDbId string = featureFlags.deployCosmosDb ? cosmosDb.outputs.cosmosDbId : ''
output cosmosDbName string = featureFlags.deployCosmosDb ? cosmosDb.outputs.cosmosDbName : ''
output blobStorageId string = featureFlags.deployBlobStorage ? blobStorage.outputs.storageAccountId : ''
output blobStorageName string = featureFlags.deployBlobStorage ? blobStorage.outputs.storageAccountName : ''
output blobStorageEndpoint string = featureFlags.deployBlobStorage ? blobStorage.outputs.storageAccountBlobEndpoint : ''
output redisCacheId string = featureFlags.deployRedisCache ? redisCache.outputs.redisCacheId : ''
output redisCacheName string = featureFlags.deployRedisCache ? redisCache.outputs.redisCacheName : ''
output redisCacheHostName string = featureFlags.deployRedisCache ? redisCache.outputs.redisCacheHostName : ''