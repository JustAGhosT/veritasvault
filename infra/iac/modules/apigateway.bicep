// API Gateway Module
// This module creates an API Management instance for the VeritasVault platform

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

@description('ML Engine API URL')
param mlEngineApiUrl string = 'https://ml-engine-${environmentName}.veritasvault.ai'

@description('API Gateway SKU')
param apiGatewaySku string = environmentName == 'prod' ? 'Standard' : 'Developer'

@description('API Gateway capacity')
param apiGatewayCapacity int = environmentName == 'prod' ? 2 : 1

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// API Management Service
resource apiManagement 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: '${baseName}-apim-vv-${projectName}'
  location: location
  tags: tags
  sku: {
    name: apiGatewaySku
    capacity: apiGatewayCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: 'admin@veritasvault.ai'
    publisherName: 'VeritasVault'
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: '${baseName}-apim-vv-${projectName}.azure-api.net'
        negotiateClientCertificate: false
        defaultSslBinding: true
      }
    ]
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
    }
  }
}

// ML Engine API
resource mlEngineApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: '${apiManagement.name}/ml-engine'
  properties: {
    displayName: 'ML Engine API'
    apiRevision: '1'
    subscriptionRequired: true
    serviceUrl: mlEngineApiUrl
    path: 'ml-engine'
    protocols: [
      'https'
    ]
    format: 'openapi'
    value: loadTextContent('apigateway/ml-engine-api.json')
  }
}

// Rate limit policy for ML Engine API
resource mlEngineRateLimit 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = {
  name: '${mlEngineApi.name}/policy'
  properties: {
    value: loadTextContent('apigateway/ml-engine-policy.xml')
    format: 'xml'
  }
}

// Product for internal APIs
resource internalProduct 'Microsoft.ApiManagement/service/products@2022-08-01' = {
  name: '${apiManagement.name}/internal'
  properties: {
    displayName: 'Internal APIs'
    description: 'APIs for internal VeritasVault services'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

// Add ML Engine API to internal product
resource mlEngineProductApi 'Microsoft.ApiManagement/service/products/apis@2022-08-01' = {
  name: '${internalProduct.name}/ml-engine'
  dependsOn: [
    mlEngineApi
  ]
}

// Diagnostic settings for API Management
resource apiManagementDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2022-08-01' = {
  name: '${apiManagement.name}/applicationinsights'
  properties: {
    loggerId: appInsightsLogger.id
    alwaysLog: 'allErrors'
    logClientIp: true
    httpCorrelationProtocol: 'W3C'
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
    verbosity: 'verbose'
    metrics: true
  }
}

// Application Insights logger for API Management
resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2022-08-01' = {
  name: '${apiManagement.name}/appinsights'
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger'
    credentials: {
      instrumentationKey: '{{appInsightsKey}}'
    }
    isBuffered: true
  }
}

// Outputs
output apiGatewayId string = apiManagement.id
output apiGatewayName string = apiManagement.name
output apiGatewayUrl string = 'https://${apiManagement.properties.hostnameConfigurations[0].hostName}'
output mlEngineApiId string = mlEngineApi.id