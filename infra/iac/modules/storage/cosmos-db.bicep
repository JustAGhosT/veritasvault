// Cosmos DB Module
// This module creates a Cosmos DB account, database, and containers for the VeritasVault platform

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

@description('Networking configuration')
param networkingConfig object = {
  privateEndpoints: {
    enabled: false
  }
  subnetId: ''
}

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// Cosmos DB Account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${baseName}-cosmos-vv-${projectName}'
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: environmentName == 'prod'
      }
    ]
    capabilities: cosmosDbConfig.serverless ? [
      {
        name: 'EnableServerless'
      }
    ] : []
    enableMultipleWriteLocations: cosmosDbConfig.multiRegionWrite
    enableAutomaticFailover: true
    publicNetworkAccess: networkingConfig.privateEndpoints.enabled ? 'Disabled' : 'Enabled'
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: environmentName == 'prod' ? 720 : 168 // 30 days for prod, 7 days for others
      }
    }
  }
}

// Cosmos DB Database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: 'veritasvault'
  properties: {
    resource: {
      id: 'veritasvault'
    }
  }
}

// Cosmos DB Containers
resource cosmosContainers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = [for container in cosmosDbConfig.containers: {
  parent: cosmosDatabase
  name: container.name
  properties: {
    resource: {
      id: container.name
      partitionKey: {
        paths: [
          container.partitionKeyPath
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/_etag/?'
          }
        ]
      }
      defaultTtl: container.ttlInSeconds
    }
  }
}]

// Private Endpoint for Cosmos DB (if enabled)
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = if (networkingConfig.privateEndpoints.enabled && !empty(networkingConfig.subnetId)) {
  name: '${baseName}-pe-vv-${projectName}-cosmos'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'cosmos-db-connection'
        properties: {
          privateLinkServiceId: cosmosAccount.id
          groupIds: [
            'Sql'
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
output cosmosDbId string = cosmosAccount.id
output cosmosDbName string = cosmosAccount.name
output cosmosDbEndpoint string = cosmosAccount.properties.documentEndpoint
output databaseName string = cosmosDatabase.name
output containerNames array = [for (container, i) in cosmosDbConfig.containers: cosmosContainers[i].name]