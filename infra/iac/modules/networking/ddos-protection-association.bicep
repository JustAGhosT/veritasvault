// DDoS Protection Association Module
// This module associates a DDoS protection plan with an existing virtual network

@description('Name of the virtual network to associate with DDoS protection')
param vnetName string

@description('Resource ID of the DDoS protection plan')
param ddosProtectionPlanId string

// Get the existing virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName
}

// Update the virtual network to enable DDoS protection
resource vnetWithDdos 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: vnet.location
  tags: vnet.tags
  properties: {
    addressSpace: vnet.properties.addressSpace
    subnets: vnet.properties.subnets
    enableDdosProtection: true
    ddosProtectionPlan: {
      id: ddosProtectionPlanId
    }
  }
}

// Outputs
output vnetId string = vnetWithDdos.id