targetScope='resourceGroup'

param prefix string
param location string

resource acr 'Microsoft.ContainerRegistry/registries@2019-05-01' = {
  name: prefix
  location: location
  sku: {
    name: 'Standard'
  }
}

