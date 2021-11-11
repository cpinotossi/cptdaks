targetScope='resourceGroup'

var parameters = json(loadTextContent('parameters.json'))

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' existing = {
  name: parameters.prefix
}

resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: parameters.prefix
  location: parameters.location
}

resource aks 'Microsoft.ContainerService/managedClusters@2021-08-01' = {
  name: parameters.prefix
  location: parameters.location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableRBAC: true
    dnsPrefix: parameters.prefix
    addonProfiles:{ 
      omsagent:{
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: law.id
        }
      }
    }
    agentPoolProfiles: [
      {
        name: '${parameters.prefix}sys'
        mode:'System'
        osType:'Linux'
        count: 1
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        vmSize: 'standard_d2s_v3'
        vnetSubnetID: '${vnet.id}/subnets/aks-sn'
      }
      {
        name: '${parameters.prefix}ng1'
        mode:'User'
        osType:'Linux'
        count: 1
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        vmSize: 'standard_d2s_v3'
        vnetSubnetID: '${vnet.id}/subnets/aks-sn'
      }
    ]
  }
}

var roleAcrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var roleNetworkContributor = '4d97b98b-1d4f-4787-a291-c67834d212e7'

resource raAP 'Microsoft.Authorization/roleAssignments@2015-07-01' = {
  name: guid(resourceGroup().id, 'acrpull2aks')
  properties: {
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/rolesDefinition', roleAcrPull)
  }
}

resource raNC 'Microsoft.Authorization/roleAssignments@2015-07-01' = {
  name: guid(resourceGroup().id, 'networkcontributor2aks')
  properties: {
    principalId: aks.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/rolesDefinition', roleNetworkContributor)
  }
}
