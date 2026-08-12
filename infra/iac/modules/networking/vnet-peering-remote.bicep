// Remote VNet Peering Module
// This module creates a peering connection from a remote VNet to a local VNet

@description('Name of the local virtual network')
param localVnetName string

@description('Name of the remote virtual network')
param remoteVnetName string

@description('Resource ID of the remote virtual network')
param remoteVnetId string

// Remote to Local peering
resource remoteTolocalPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${localVnetName}/peering-to-${remoteVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
  }
}

// Outputs
output peeringId string = remoteTolocalPeering.id