// VNet Peering Module
// This module creates peering connections between two virtual networks

@description('Name of the primary virtual network')
param primaryVnetName string

@description('Name of the secondary virtual network')
param secondaryVnetName string

@description('Resource ID of the secondary virtual network')
param secondaryVnetId string

@description('Name of the resource group containing the secondary virtual network')
param secondaryResourceGroupName string

// Primary to Secondary peering
resource primaryToSecondaryPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${primaryVnetName}/peering-to-${secondaryVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: secondaryVnetId
    }
  }
}

// Secondary to Primary peering
module secondaryToPrimaryPeering 'vnet-peering-remote.bicep' = {
  name: 'secondaryToPrimaryPeering'
  scope: resourceGroup(secondaryResourceGroupName)
  params: {
    localVnetName: secondaryVnetName
    remoteVnetName: primaryVnetName
    remoteVnetId: resourceId('Microsoft.Network/virtualNetworks', primaryVnetName)
  }
}

// Outputs
output peeringId string = primaryToSecondaryPeering.id