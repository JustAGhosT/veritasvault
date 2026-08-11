// Private DNS Zones Module
// This module creates private DNS zones for Azure services and links them to a virtual network

@description('Resource ID of the virtual network to link with private DNS zones')
param vnetId string

@description('Array of private DNS zone names to create')
param privateDnsZones array = [
  'privatelink.database.windows.net'
  'privatelink.documents.azure.com'
  'privatelink.blob.core.windows.net'
  'privatelink.vaultcore.azure.net'
]

@description('Tags for all resources')
param tags object

// Create private DNS zones
resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zoneName in privateDnsZones: {
  name: zoneName
  location: 'global'
  tags: tags
}]

// Link private DNS zones to the virtual network
resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zoneName, i) in privateDnsZones: {
  name: '${zoneName}/${split(vnetId, '/')[8]}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
  dependsOn: [
    dnsZones[i]
  ]
}]

// Create a dictionary of DNS zone IDs for easy reference
var dnsZoneIdDict = reduce(privateDnsZones, {}, (result, zoneName, i) => union(result, {
  '${replace(replace(zoneName, 'privatelink.', ''), '.', '_')}': dnsZones[i].id
}))

// Outputs
output privateDnsZoneIds object = dnsZoneIdDict