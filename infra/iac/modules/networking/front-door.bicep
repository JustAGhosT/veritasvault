// Front Door Module
// This module creates an Azure Front Door instance with optional WAF and CDN capabilities

@description('Resource name prefix')
param prefix string

@description('Location for resources')
param location string = 'global'

@description('Tags for all resources')
param tags object

@description('Whether to enable Web Application Firewall')
param wafEnabled bool = true

@description('Whether to enable CDN capabilities')
param cdnEnabled bool = true

@description('Array of endpoints to configure')
param endpoints array = [
  {
    name: 'default'
    hostName: 'default.example.com'
    originHostName: 'default-origin.azurewebsites.net'
  }
]

// Front Door Profile
resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: '${prefix}-frontdoor'
  location: location
  tags: tags
  sku: {
    name: wafEnabled ? 'Premium_AzureFrontDoor' : 'Standard_AzureFrontDoor'
  }
}

// Front Door Endpoints
resource frontDoorEndpoints 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = [for endpoint in endpoints: {
  name: endpoint.name
  parent: frontDoorProfile
  location: location
  properties: {
    enabledState: 'Enabled'
  }
}]

// Front Door Origins
resource frontDoorOriginGroups 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = [for (endpoint, i) in endpoints: {
  name: '${endpoint.name}-origin-group'
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}]

resource frontDoorOrigins 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = [for (endpoint, i) in endpoints: {
  name: '${endpoint.name}-origin'
  parent: frontDoorOriginGroups[i]
  properties: {
    hostName: endpoint.originHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: endpoint.originHostName
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}]

// Front Door Routes
resource frontDoorRoutes 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = [for (endpoint, i) in endpoints: {
  name: '${endpoint.name}-route'
  parent: frontDoorEndpoints[i]
  properties: {
    originGroup: {
      id: frontDoorOriginGroups[i].id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
  dependsOn: [
    frontDoorOrigins[i]
  ]
}]

// Web Application Firewall Policy (if enabled)
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = if (wafEnabled) {
  name: '${prefix}-waf-policy'
  location: location
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'DefaultRuleSet'
          ruleSetVersion: '1.0'
        }
        {
          ruleSetType: 'BotProtection'
          ruleSetVersion: '1.0'
        }
      ]
    }
  }
}

// WAF Security Policy (if enabled)
resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2021-06-01' = if (wafEnabled) {
  name: 'security-policy'
  parent: frontDoorProfile
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            for endpoint in endpoints: {
              id: resourceId('Microsoft.Cdn/profiles/afdEndpoints', frontDoorProfile.name, endpoint.name)
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
  dependsOn: [
    frontDoorEndpoints
  ]
}

// Outputs
output frontDoorId string = frontDoorProfile.id
output frontDoorHostName string = frontDoorProfile.properties.frontDoorId
output endpointHostNames array = [for (endpoint, i) in endpoints: {
  name: endpoint.name
  hostName: frontDoorEndpoints[i].properties.hostName
}]