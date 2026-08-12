// NSG Association Module
// This module associates a Network Security Group with an existing subnet

@description('Name of the virtual network containing the subnet')
param vnetName string

@description('Name of the subnet to associate with the NSG')
param subnetName string

@description('Resource ID of the Network Security Group')
param nsgId string

// Get the existing virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName
}

// Get the existing subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: subnetName
  parent: vnet
}

// Update the subnet to associate it with the NSG
resource subnetWithNsg 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: subnetName
  parent: vnet
  properties: {
    addressPrefix: subnet.properties.addressPrefix
    networkSecurityGroup: {
      id: nsgId
    }
    serviceEndpoints: subnet.properties.serviceEndpoints
    delegations: subnet.properties.delegations
    privateEndpointNetworkPolicies: subnet.properties.privateEndpointNetworkPolicies
    privateLinkServiceNetworkPolicies: subnet.properties.privateLinkServiceNetworkPolicies
  }
}

// Outputs
output subnetId string = subnetWithNsg.id