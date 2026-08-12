// Cosmos DB Module
// This module creates a Cosmos DB account, database, and containers

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
  containers: [
    {
      name: 'blockchain-events'
      partitionKeyPath: '/eventType'
      ttlInSeconds: 2592000 // 30 days
    }
  ]
}

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'
var uniqueSuffix = uniqueString(resourceGroup().id)

// Cosmos DB Account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${baseName}-cosmos-vv-${projectName}-${uniqueSuffix}'
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
        isZoneRedundant: false
      }
    ]
    capabilities: cosmosDbConfig.serverless ? [
      {
        name: 'EnableServerless'
      }
    ] : []
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

// Outputs
output cosmosDbId string = cosmosAccount.id
output cosmosDbName string = cosmosAccount.name
output cosmosDbEndpoint string = cosmosAccount.properties.documentEndpoint
output databaseName string = cosmosDatabase.name
