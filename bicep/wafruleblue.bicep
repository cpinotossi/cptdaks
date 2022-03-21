param location string
param prefix string

resource fwp1 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-03-01' = {
  name: '${prefix}blue'
  location:location
  properties: {
    policySettings: {
      state:'Enabled'
      mode:'Prevention'
      requestBodyCheck: false
      maxRequestBodySizeInKb: 128
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
      ]
    }
    customRules:[
      {
        name:'customrule1'
        priority:5
        ruleType:'MatchRule'
        action:'Block'
        matchConditions:[
          {
            matchVariables:[
              {
                variableName:'QueryString'
              }
            ]
            operator:'Contains'
            transforms:[
              'Lowercase'
            ]
            matchValues:[
              'blue'
            ]
          }
        ]
      }
    ]
  }
}
