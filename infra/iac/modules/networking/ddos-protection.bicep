// DDoS Protection Module
// This module creates a DDoS Protection Plan and associates it with virtual networks

@description('Resource name prefix')
param prefix string

@description('Location for resources')
param location string

@description('Tags for all resources')
param tags object

@description('Array of virtual network IDs to associate with the DDoS protection plan')
param vnetIds array = []

// DDoS Protection Plan
resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2022-07-01' = {
  name: '${prefix}-ddos-protection-plan'
  location: location
  tags: tags
}

// Associate VNets with DDoS Protection Plan
// Note: This is done through the VNet resource, but we're using a module to update existing VNets
module ddosProtectionAssociation 'ddos-protection-association.bicep' = [for (vnetId, i) in vnetIds: {
  name: 'ddosProtectionAssociation-${i}'
  scope: resourceGroup(split(vnetId, '/')[4])
  params: {
    vnetName: split(vnetId, '/')[8]
    ddosProtectionPlanId: ddosProtectionPlan.id
  }
}]

// Outputs
output ddosProtectionPlanId string = ddosProtectionPlan.id
output ddosProtectionPlanName string = ddosProtectionPlan.name