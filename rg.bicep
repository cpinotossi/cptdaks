targetScope='subscription'

var parameters = json(loadTextContent('parameters.json'))

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: parameters.prefix
  location: parameters.location
}
