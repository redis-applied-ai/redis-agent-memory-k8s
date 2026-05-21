@description('Azure region')
param location string

@description('VNet name')
param vnetName string

@description('VNet address space — must not overlap with AKS auto-VNet (10.224.0.0/12)')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Load test VM subnet CIDR')
param loadtestSubnetPrefix string = '10.0.2.0/28'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'loadtest-subnet'
        properties: {
          addressPrefix: loadtestSubnetPrefix
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output loadtestSubnetId string = vnet.properties.subnets[0].id
