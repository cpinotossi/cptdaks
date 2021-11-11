targetScope='resourceGroup'

var parameters = json(loadTextContent('parameters.json'))

resource vnet 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: parameters.prefix
  location: parameters.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/8'
      ]
    }
    subnets: [
      {
        name: 'aks-sn'
        properties: {
          addressPrefix: '10.1.0.0/16'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      /*{
        name: 'agw-sn'
        properties: {
          addressPrefix: '10.2.0.0/16'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }*/
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.3.0.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.3.1.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'wl-sn'
        properties: {
          addressPrefix: '10.3.2.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

// Create the vm
var vmName = '${parameters.prefix}-lin-vm'

resource nic 'Microsoft.Network/networkInterfaces@2020-08-01' = {
  name: '${vmName}-nic'
  location: parameters.location
  properties: {
    ipConfigurations: [
      {
        name: '${parameters.prefix}-ipconfig1'
        properties: {
          privateIPAddress: '10.3.2.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${vnet.id}/subnets/wl-sn'
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: false
    enableIPForwarding: false
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2019-07-01' = {
  name: vmName
  location: parameters.location
  zones: [
    '1'
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-disc'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: 'chpinoto'
      adminPassword: 'demo!pass123'
      //customData: base64('sudo apt-get install apache2-utils')
      customData: loadFileAsBase64('vm.ab.yaml')
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource pubip 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: parameters.prefix
  location: parameters.location
  sku: {
    name:'Standard'
  }
  properties: {
    publicIPAllocationMethod:'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2020-04-01' = {
  name: parameters.prefix
  location: parameters.location
  properties: {
    ipConfigurations: [
      {
        name: '${parameters.prefix}-ipconfig'
        properties: {
          publicIPAddress: {
            id: pubip.id
          }
          subnet: {
            id: '${vnet.id}/subnets/AzureBastionSubnet'
          }
        }
      }
    ]
  }
}
