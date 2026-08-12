// Network Security Groups Module
// This module creates NSGs for each subnet with custom security rules

@description('Resource name prefix')
param prefix string

@description('Location for resources')
param location string

@description('Tags for all resources')
param tags object

@description('Subnet configurations with security rules')
param subnets array = [
  {
    name: 'default'
    rules: []
  }
]

// Create NSG for each subnet
resource networkSecurityGroups 'Microsoft.Network/networkSecurityGroups@2022-07-01' = [for subnet in subnets: {
  name: '${prefix}-${subnet.name}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: subnet.rules
  }
}]

// Associate each NSG with its subnet
module nsgAssociations 'nsg-association.bicep' = [for (subnet, i) in subnets: {
  name: 'nsgAssociation-${subnet.name}'
  params: {
    vnetName: '${prefix}-vnet'
    subnetName: subnet.name
    nsgId: networkSecurityGroups[i].id
  }
}]

// Outputs
output nsgIds array = [for (subnet, i) in subnets: {
  subnetName: subnet.name
  nsgId: networkSecurityGroups[i].id
  nsgName: networkSecurityGroups[i].name
}]