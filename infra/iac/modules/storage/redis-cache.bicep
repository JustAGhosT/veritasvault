// Redis Cache Module
// This module creates a Redis Cache for real-time data access in the VeritasVault platform

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

@description('Networking configuration')
param networkingConfig object = {
  privateEndpoints: {
    enabled: false
  }
  subnetId: ''
}

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// Redis Cache
resource redisCache 'Microsoft.Cache/redis@2023-04-01' = {
  name: '${baseName}-redis-vv-${projectName}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: redisCacheConfig.skuName
      family: contains(redisCacheConfig, 'family') ? redisCacheConfig.family : (redisCacheConfig.skuName == 'Basic' || redisCacheConfig.skuName == 'Standard' ? 'C' : 'P')
      capacity: redisCacheConfig.capacity
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: networkingConfig.privateEndpoints.enabled ? 'Disabled' : 'Enabled'
    redisConfiguration: {
      'maxmemory-policy': contains(redisCacheConfig, 'maxMemoryPolicy') ? redisCacheConfig.maxMemoryPolicy : 'volatile-lru'
    }
    redisVersion: contains(redisCacheConfig, 'redisVersion') ? redisCacheConfig.redisVersion : '6'
  }
}

// Private Endpoint for Redis Cache (if enabled)
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = if (networkingConfig.privateEndpoints.enabled && !empty(networkingConfig.subnetId)) {
  name: '${baseName}-pe-vv-${projectName}-redis'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'redis-cache-connection'
        properties: {
          privateLinkServiceId: redisCache.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
    subnet: {
      id: networkingConfig.subnetId
    }
  }
}

// Diagnostic Settings for Redis Cache
resource redisDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${redisCache.name}-diagnostics'
  scope: redisCache
  properties: {
    logs: [
      {
        category: 'ConnectedClientList'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: contains(redisCacheConfig, 'logAnalyticsWorkspaceId') ? redisCacheConfig.logAnalyticsWorkspaceId : null
  }
}

// Outputs
output redisCacheId string = redisCache.id
output redisCacheName string = redisCache.name
output redisCacheHostName string = redisCache.properties.hostName
output redisCacheConnectionString string = '${redisCache.name}.redis.cache.windows.net:6380,password=${listKeys(redisCache.id, redisCache.apiVersion).primaryKey},ssl=True,abortConnect=False'