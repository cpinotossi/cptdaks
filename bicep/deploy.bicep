targetScope='resourceGroup'

// var parameters = json(loadTextContent('../parameters.json'))
param location string = resourceGroup().location
param myobjectid string
param myip string
param prefix string

module vnetModule 'vnet.bicep' = {
  name: 'vnetDeploy'
  params: {
    prefix: prefix
    location: location
  }
}

// module vmModule 'vm.bicep' = {
//   name: 'vmDeploy'
//   params: {
//     prefix: parameters.prefix
//     location: location
//     username: parameters.username
//     password: parameters.password
//     myObjectId: myobjectid
//     postfix: 'lin'
//     privateip: '10.0.0.4'
//   }
//   dependsOn:[
//     vnetModule
//   ]
// }

// module sabModule 'sab.bicep' = {
//   name: 'sabDeploy'
//   params: {
//     prefix: parameters.prefix
//     location: location
//     myip: myip
//     myObjectId: myobjectid
//   }
//   dependsOn:[
//     vnetModule
//   ]
// }

module acrModule 'acr.bicep' = {
  name: 'acrDeploy'
  params: {
    prefix: prefix
    location: location
  }
}

// module aksModule 'aks.bicep' = {
//   name: 'aksDeploy'
//   params: {
//     prefix: prefix
//     location: location
//     aksServicePrincipalAppId: parameters.aksServicePrincipalAppId
//     aksServicePrincipalClientSecret: parameters.aksServicePrincipalClientSecret
//     aksServicePrincipalObjectId: parameters.aksServicePrincipalObjectId
//   }
//   dependsOn:[
//     vnetModule
//     acrModule
//   ]
// }

module agwModule 'agw.bicep' = {
  name: 'agwDeploy'
  params: {
    prefix: prefix
    location: location
  }
  dependsOn:[
    vnetModule
    acrModule
  ]
}

module wafRuleRedModule 'wafrulered.bicep' = {
  name: 'wafRuleRedDeploy'
  params: {
    prefix: prefix
    location: location
  }
  dependsOn:[
    vnetModule
    acrModule
  ]
}

module wafRuleGreenModule 'wafrulegreen.bicep' = {
  name: 'wafRuleGreenDeploy'
  params: {
    prefix: prefix
    location: location
  }
  dependsOn:[
    vnetModule
    acrModule
  ]
}

// module lawModule 'law.bicep' = {
//   name: 'lawDeploy'
//   params:{
//     prefix: parameters.prefix
//     location: location
//   }
//   dependsOn:[
//     sabModule
//   ]
// }
