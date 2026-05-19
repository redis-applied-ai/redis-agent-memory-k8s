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

output clusterName string = aks.outputs.clusterName
output nodeResourceGroup string = aks.outputs.nodeResourceGroup
