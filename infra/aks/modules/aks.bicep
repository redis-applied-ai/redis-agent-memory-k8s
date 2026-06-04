@description('Name of the AKS cluster')
param clusterName string

@description('Azure region')
param location string

@description('System node pool VM size')
param systemNodeVmSize string

@description('Number of system nodes')
param systemNodeCount int

@description('User node pool VM size (memory-optimized for Redis Enterprise)')
param userNodeVmSize string

@description('Number of user nodes for Redis Enterprise (minimum 3)')
@minValue(3)
param userNodeCount int

resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // kubernetesVersion omitted — AKS uses the current default stable version for the region.
    // Pin a version by setting AKS_KUBERNETES_VERSION in .env and adding the parameter back.
    dnsPrefix: clusterName
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'system'
        count: systemNodeCount
        vmSize: systemNodeVmSize
        osType: 'Linux'
        osDiskSizeGB: 128
        mode: 'System'
        type: 'VirtualMachineScaleSets'
      }
      {
        // Dedicated pool for Redis Enterprise pods; sized for memory-heavy workloads
        name: 'redis'
        count: userNodeCount
        vmSize: userNodeVmSize
        osType: 'Linux'
        osDiskSizeGB: 128
        mode: 'User'
        type: 'VirtualMachineScaleSets'
      }
    ]
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
    }
  }
}

output clusterName string = aks.name
output nodeResourceGroup string = aks.properties.nodeResourceGroup
