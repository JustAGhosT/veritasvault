// Development Environment Configuration
// This file serves as the main entry point for the development environment

// Parameters
param location string = 'westeu'
param environmentName string = 'dev'
param resourceTags object = {
  Environment: environmentName
  ManagedBy: 'IaC'
  Project: 'YourProjectName'
}

// Import modules
module apiGateway '../../modules/apigateway.bicep' = {
  name: 'apiGatewayDeploy'
  params: {
    location: location
    environmentName: environmentName
    tags: resourceTags
  }
}

// Add more modules as needed for your dev environment
