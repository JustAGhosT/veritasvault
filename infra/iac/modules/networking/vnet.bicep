// Virtual Network Module
// This module creates a virtual network with subnets

@description('Resource name prefix')
param prefix string

@description('Location for resources')
param location string

@description('Tags for all resources')
param tags object

@description('Address space for the virtual network')
param addressSpace string = '10.0.0.0/16'

@description('Subnet configurations')
param subnets array = [
  {
    name: 'default'
    addressPrefix: '10.0.0.0/24'
    serviceEndpoints: []
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
  }
]

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: '${prefix}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        serviceEndpoints: [for endpoint in subnet.serviceEndpoints: {
          service: endpoint
        }]
        delegations: [for delegation in subnet.delegations: {
          name: delegation.name
          properties: {
            serviceName: delegation.properties.serviceName
          }
        }]
        privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
      }
    }]
  }
}

// Create a dictionary of subnet IDs for easy reference
var subnetIdDict = reduce(subnets, {}, (result, subnet) => union(result, {
  '${subnet.name}': '${vnet.id}/subnets/${subnet.name}'
}))

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetIds object = subnetIdDict