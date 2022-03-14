targetScope='resourceGroup'

param prefix string
param location string


resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: prefix
  location: location
}

resource sab 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: prefix
}

resource diaagw 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: prefix
  properties: {
    storageAccountId: sab.id
    workspaceId: law.id
    logs: [
      // {
      //   categoryGroup: 'StorageRead'
      //   enabled: true
      // }
      // {
      //   categoryGroup: 'StorageWrite'
      //   enabled: true
      // }
      // {
      //   categoryGroup: 'StorageDelete'
      //   enabled: true
      // }
    ]
    metrics:[
      {
        category:'Transaction'
        enabled: true
      }
    ]
  }
  scope: sab
}



