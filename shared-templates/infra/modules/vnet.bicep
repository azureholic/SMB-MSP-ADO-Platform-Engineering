targetScope = 'resourceGroup'

@description('Azure region for the virtual network deployment.')
param location string

@description('Name of the virtual network.')
param vnetName string

@description('Address space for the virtual network.')
param vnetAddressPrefix string

@description('Subnets to create within the virtual network.')
param subnets array

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetIds array = [for (subnet, i) in subnets: vnet.properties.subnets[i].id]
