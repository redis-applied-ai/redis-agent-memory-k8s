// Reference only — aks-provision.sh passes parameters inline from .env vars.
// This file documents the available parameters and their defaults.
// To use directly: az bicep build-params infra/aks/main.bicepparam
using './main.bicep'

param clusterName = 'ram-aks'
param systemNodeVmSize = 'Standard_D2s_v3'
param systemNodeCount = 2
param userNodeVmSize = 'Standard_E4s_v3'
param userNodeCount = 3
