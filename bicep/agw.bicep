param location string
param prefix string

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: prefix
}

resource aks 'Microsoft.ContainerService/containerServices@2017-07-01' existing = {
  name: prefix
}

resource pubip 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: '${prefix}agw'
  location: location
  sku: {
    name:'Standard'
  }
  properties: {
    publicIPAllocationMethod:'Static'
  }
}

resource agw 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: prefix
  location: location
  tags: {
    'ingress-for-aks-cluster-id': aks.id
    'managed-by-k8s-ingress': '1.5.1/0a4f032f/2022-02-22-18:27T+0000'
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/agw'
          }
        }
      }
    ]
    sslCertificates: []
    trustedRootCertificates: []
    trustedClientCertificates: []
    sslProfiles: []
    frontendIPConfigurations: [
      {
        name: 'frontendIPConfigurationPublic'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pubip.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'frontendportHttp'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendaddresspoolApp1'
        properties: {
          backendAddresses: [
            {
              ipAddress: '10.1.0.38'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'bachendHtppSettingApp1'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 30
          probe: {
            id:'${resourceId('Microsoft.Network/applicationGateways', prefix)}/probes/probeApp1'
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'fl-e1903c8aa3446b7b3207aec6d6ecba8a'
        properties: {
          frontendIPConfiguration: {
            id:'${resourceId('Microsoft.Network/applicationGateways', prefix)}/frontendIPConfigurations/frontendIPConfigurationPublic'
          }
          frontendPort: {
            id:'${resourceId('Microsoft.Network/applicationGateways', prefix)}/frontendPorts/frontendportHttp'
          }
          protocol: 'Http'
          hostNames: []
          requireServerNameIndication: false
        }
      }
    ]
    urlPathMaps: []
    requestRoutingRules: [
      {
        name: 'rr-e1903c8aa3446b7b3207aec6d6ecba8a'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id:'${resourceId('Microsoft.Network/applicationGateways', prefix)}/httpListeners/fl-e1903c8aa3446b7b3207aec6d6ecba8a'
          }
          backendAddressPool: {
            id:'${resourceId('Microsoft.Network/applicationGateways', prefix)}/backendAddressPools/backendaddresspoolApp1'
          }
          backendHttpSettings: {
            id:'${resourceId('Microsoft.Network/applicationGateways', prefix)}/backendHttpSettingsCollection/bachendHtppSettingApp1'
          }
        }
      }
    ]
    probes: [
      {
        name: 'probeApp1'
        properties: {
          protocol: 'Http'
          host: 'localhost'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
          match: {}
        }
      }
    ]
    rewriteRuleSets: []
    redirectConfigurations: []
    privateLinkConfigurations: []
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
  }
}


