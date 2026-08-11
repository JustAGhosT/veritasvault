// Networking Module
// This module creates the networking infrastructure for the VeritasVault platform

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

@description('Networking configuration')
param networkingConfig object = {
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

@description('Whether to deploy multi-region resources')
param multiRegion bool = false

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: '${baseName}-vnet-vv-${projectName}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkingConfig.addressSpace
      ]
    }
    subnets: [for subnet in networkingConfig.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        serviceEndpoints: contains(networkingConfig, 'serviceEndpoints') ? [for endpoint in networkingConfig.serviceEndpoints: {
          service: endpoint
        }] : []
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    }]
  }
}

// Network Security Group for default subnet
resource defaultNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${baseName}-nsg-vv-${projectName}-default'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Associate NSG with default subnet
resource nsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: '${vnet.name}/default'
  properties: {
    addressPrefix: networkingConfig.subnets[0].addressPrefix
    networkSecurityGroup: {
      id: defaultNsg.id
    }
    serviceEndpoints: contains(networkingConfig, 'serviceEndpoints') ? [for endpoint in networkingConfig.serviceEndpoints: {
      service: endpoint
    }] : []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// Front Door (if enabled)
resource frontDoor 'Microsoft.Network/frontDoors@2021-06-01' = if (networkingConfig.frontDoor.enabled) {
  name: '${baseName}-fd-vv-${projectName}'
  location: 'global'
  tags: tags
  properties: {
    friendlyName: '${baseName}-fd-vv-${projectName}'
    enabledState: 'Enabled'
    frontendEndpoints: [
      {
        name: 'defaultFrontendEndpoint'
        properties: {
          hostName: '${baseName}-fd-vv-${projectName}.azurefd.net'
          sessionAffinityEnabledState: 'Disabled'
          sessionAffinityTtlSeconds: 0
        }
      }
    ]
    loadBalancingSettings: [
      {
        name: 'defaultLoadBalancingSettings'
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 2
          additionalLatencyMilliseconds: 0
        }
      }
    ]
    healthProbeSettings: [
      {
        name: 'defaultHealthProbeSettings'
        properties: {
          path: '/'
          protocol: 'Https'
          intervalInSeconds: 30
          healthProbeMethod: 'HEAD'
          enabledState: 'Enabled'
        }
      }
    ]
    routingRules: [
      {
        name: 'defaultRoutingRule'
        properties: {
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontDoors/frontendEndpoints', '${baseName}-fd-vv-${projectName}', 'defaultFrontendEndpoint')
            }
          ]
          acceptedProtocols: [
            'Http'
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          enabledState: 'Enabled'
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            forwardingProtocol: 'HttpsOnly'
            backendPool: {
              id: resourceId('Microsoft.Network/frontDoors/backendPools', '${baseName}-fd-vv-${projectName}', 'defaultBackendPool')
            }
          }
        }
      }
    ]
    backendPools: [
      {
        name: 'defaultBackendPool'
        properties: {
          backends: [
            {
              address: '${baseName}-apim-vv-${projectName}.azure-api.net'
              httpPort: 80
              httpsPort: 443
              priority: 1
              weight: 50
              enabledState: 'Enabled'
            }
          ]
          loadBalancingSettings: {
            id: resourceId('Microsoft.Network/frontDoors/loadBalancingSettings', '${baseName}-fd-vv-${projectName}', 'defaultLoadBalancingSettings')
          }
          healthProbeSettings: {
            id: resourceId('Microsoft.Network/frontDoors/healthProbeSettings', '${baseName}-fd-vv-${projectName}', 'defaultHealthProbeSettings')
          }
        }
      }
    ]
  }
}

// Private DNS Zones (if private endpoints are enabled)
resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = if (networkingConfig.privateEndpoints.enabled) {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to VNet
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (networkingConfig.privateEndpoints.enabled) {
  parent: privateDnsZones
  name: '${baseName}-vnetlink'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// DDoS Protection Plan (if enabled)
resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2022-07-01' = if (networkingConfig.ddosProtection) {
  name: '${baseName}-ddos-vv-${projectName}'
  location: location
  tags: tags
}

// Update VNet with DDoS Protection (if enabled)
resource vnetWithDdos 'Microsoft.Network/virtualNetworks@2022-07-01' = if (networkingConfig.ddosProtection) {
  name: '${baseName}-vnet-vv-${projectName}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkingConfig.addressSpace
      ]
    }
    subnets: [for subnet in networkingConfig.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        serviceEndpoints: contains(networkingConfig, 'serviceEndpoints') ? [for endpoint in networkingConfig.serviceEndpoints: {
          service: endpoint
        }] : []
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    }]
    enableDdosProtection: true
    ddosProtectionPlan: {
      id: ddosProtectionPlan.id
    }
  }
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetIds object = {
  default: '${vnet.id}/subnets/default'
}
output frontDoorId string = networkingConfig.frontDoor.enabled ? frontDoor.id : ''
output frontDoorHostName string = networkingConfig.frontDoor.enabled ? '${frontDoor.name}.azurefd.net' : ''