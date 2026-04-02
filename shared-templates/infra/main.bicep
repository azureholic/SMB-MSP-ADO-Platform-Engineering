targetScope = 'resourceGroup'

@description('Azure region for the virtual network deployment.')
param location string = resourceGroup().location

@description('Name of the virtual network.')
param vnetName string = 'vnet-test'

@description('Address space for the virtual network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnets to create within the virtual network.')
param subnets array = [
  {
    name: 'snet-test'
    addressPrefix: '10.0.0.0/24'
  }
]

// --- Virtual Network ---
module vnet 'modules/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    subnets: subnets
  }
}

output vnetId string = vnet.outputs.vnetId
output vnetName string = vnet.outputs.vnetName
output subnetIds array = vnet.outputs.subnetIds
