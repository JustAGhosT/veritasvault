// Production Environment Infrastructure
// This is the main entry point for deploying the production environment
// Minimal deployment by default, can be extended using feature toggles

// Core parameters
@description('Environment name')
param environmentName string = 'prod'

@description('Location for all resources')
param location string = 'westeurope'

@description('Location code for resource naming')
param locationCode string = 'weu'

@description('Project name for resource naming')
param projectName string = 'chain'

@description('Tags for all resources')
param tags object = {
  environment: environmentName
  project: 'VeritasVault'
  owner: 'Phoenix VC'
  managedBy: 'IaC'
}

// Feature toggles to control which components are deployed
@description('Feature toggles to control which components are deployed')
param featureToggles object = {
  // Core infrastructure - minimal deployment
  core: {
    deployResourceGroups: true
    deployNetworking: true
    deployKeyVault: true
  }
  // Event processing infrastructure
  eventProcessing: {
    deployEventGrid: true
    deployDeadLetterStorage: true
    deployCosmosDB: false
    deployRedisCache: false
    deployAppServicePlan: false
    deployFunctionApps: false
  }
  // API infrastructure
  api: {
    deployApiGateway: true
    deployAppService: false
    deployContainerApps: false
  }
  // Monitoring and security
  monitoring: {
    deployMonitoring: false
    deployDiagnostics: false
    deploySecurityCenter: false
    deploySentinel: false
  }
  // Advanced features
  advanced: {
    deployMultiRegion: false
    deployAdvancedAnalytics: false
    deployBlockchainIndexers: false
    deployConfidentialComputing: false
  }
}

// Resource Group Module - Create the basic resource groups
module resourceGroups 'modules/resource-groups.bicep' = if (featureToggles.core.deployResourceGroups) {
  name: 'resourceGroupsDeployment'
  scope: subscription()
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    multiRegion: featureToggles.advanced.deployMultiRegion
  }
}

// Networking Module - Deploy minimal networking infrastructure
module networking 'modules/networking.bicep' = if (featureToggles.core.deployNetworking) {
  name: 'networkingDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    networkingConfig: {
      addressSpace: '10.0.0.0/16'
      subnets: [
        {
          name: 'default'
          addressPrefix: '10.0.0.0/24'
        }
      ]
      serviceEndpoints: []
      privateEndpoints: {
        enabled: false
      }
      frontDoor: {
        enabled: false
      }
      ddosProtection: false
    }
    multiRegion: featureToggles.advanced.deployMultiRegion
  }
  dependsOn: [
    resourceGroups
  ]
}

// Key Vault - Deploy basic key vault for secrets
module keyVault 'modules/key-vault.bicep' = if (featureToggles.core.deployKeyVault) {
  name: 'keyVaultDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    keyVaultConfig: {
      skuName: 'standard'
      enablePurgeProtection: true
      enableRbacAuthorization: true
    }
  }
  dependsOn: [
    resourceGroups
    networking
  ]
}

// Event Grid Infrastructure - Deploy minimal event processing
module eventGridInfra 'modules/eventgrid.bicep' = if (featureToggles.eventProcessing.deployEventGrid) {
  name: 'eventGridDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    featureFlags: {
      deployEventGrid: featureToggles.eventProcessing.deployEventGrid
      deployDeadLetterStorage: featureToggles.eventProcessing.deployDeadLetterStorage
      deployCosmosDB: featureToggles.eventProcessing.deployCosmosDB
      deployRedisCache: featureToggles.eventProcessing.deployRedisCache
      deployAppServicePlan: featureToggles.eventProcessing.deployAppServicePlan
      deployMonitoring: featureToggles.monitoring.deployMonitoring
      deployKeyVault: false // We're using the main Key Vault
      deployFunctionApps: featureToggles.eventProcessing.deployFunctionApps
    }
  }
  dependsOn: [
    resourceGroups
  ]
}

// API Gateway - Deploy minimal API infrastructure
module apiGateway 'modules/apigateway.bicep' = if (featureToggles.api.deployApiGateway) {
  name: 'apiGatewayDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    mlEngineApiUrl: 'https://ml-engine-${environmentName}.veritasvault.ai'
  }
  dependsOn: [
    resourceGroups
    networking
  ]
}

// Monitoring - Conditionally deploy monitoring infrastructure
module monitoring 'modules/monitoring.bicep' = if (featureToggles.monitoring.deployMonitoring) {
  name: 'monitoringDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    monitoringConfig: {
      logRetentionDays: 30
      enableDiagnostics: featureToggles.monitoring.deployDiagnostics
      deploySentinel: featureToggles.monitoring.deploySentinel
    }
  }
  dependsOn: [
    resourceGroups
  ]
}

// Outputs - Essential outputs for the minimal deployment
output resourceGroupNames object = featureToggles.core.deployResourceGroups ? {
  core: resourceGroups.outputs.coreResourceGroupName
} : {}

output keyVaultUri string = featureToggles.core.deployKeyVault ? keyVault.outputs.keyVaultUri : ''

output eventGridTopicEndpoint string = featureToggles.eventProcessing.deployEventGrid ? eventGridInfra.outputs.eventGridTopicEndpoint : ''

output apiGatewayUrl string = featureToggles.api.deployApiGateway ? apiGateway.outputs.apiGatewayUrl : ''

// Additional outputs - Only included when advanced features are enabled
output deployedFeatures object = {
  core: featureToggles.core
  eventProcessing: featureToggles.eventProcessing
  api: featureToggles.api
  monitoring: featureToggles.monitoring
  advanced: featureToggles.advanced
}