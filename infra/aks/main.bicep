@description('Name of the AKS cluster')
param clusterName string

@description('Azure region — defaults to resource group location')
param location string = resourceGroup().location

@description('System node pool VM size')
param systemNodeVmSize string = 'Standard_D2s_v3'

@description('Number of system nodes')
param systemNodeCount int = 2

@description('User node pool VM size (memory-optimized for Redis Enterprise)')
param userNodeVmSize string = 'Standard_E4s_v3'

@description('Number of user nodes — minimum 3 for Redis Enterprise')
@minValue(3)
param userNodeCount int = 3

@description('SSH public key for the load test VM (contents of ~/.ssh/id_*.pub)')
param adminSshPublicKey string

@description('Admin username for the load test VM')
param adminUsername string = 'azureuser'

@description('VM size for the load test VM — handles 1000+ Locust users')
param loadtestVmSize string = 'Standard_D4_v5'

var vnetName = '${clusterName}-vnet'
var loadtestVmName = '${clusterName}-loadtest'

module vnet './modules/vnet.bicep' = {
  name: 'vnet'
  params: {
    location: location
    vnetName: vnetName
  }
}

module aks './modules/aks.bicep' = {
  name: 'aks'
  params: {
    clusterName: clusterName
    location: location
    systemNodeVmSize: systemNodeVmSize
    systemNodeCount: systemNodeCount
    userNodeVmSize: userNodeVmSize
    userNodeCount: userNodeCount
  }
}

module loadtestVm './modules/loadtest-vm.bicep' = {
  name: 'loadtest-vm'
  params: {
    location: location
    vmName: loadtestVmName
    subnetId: vnet.outputs.loadtestSubnetId
    adminUsername: adminUsername
    adminSshPublicKey: adminSshPublicKey
    vmSize: loadtestVmSize
  }
}

output clusterName string = aks.outputs.clusterName
output nodeResourceGroup string = aks.outputs.nodeResourceGroup
output loadtestVmName string = loadtestVm.outputs.vmName
output loadtestVmPublicIp string = loadtestVm.outputs.publicIp
