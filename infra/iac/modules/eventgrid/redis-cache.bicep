// Redis Cache Module
// This module creates a Redis Cache instance for the Event Grid architecture

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

@description('Redis Cache configuration')
param redisCacheConfig object = {
  skuName: 'Basic'
  capacity: 1
}

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// Redis Cache for Risk Bot
resource redisCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${baseName}-redis-vv-${projectName}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: redisCacheConfig.skuName
      family: 'C'
      capacity: redisCacheConfig.capacity
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'maxmemory-policy': 'volatile-lru'
    }
  }
}

// Outputs
output redisId string = redisCache.id
output redisName string = redisCache.name
output redisHostName string = redisCache.properties.hostName