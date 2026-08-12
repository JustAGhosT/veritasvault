@description('Base name for all resources')
param baseName string = 'veritasvault'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Tags for all resources')
param tags object = {
  environment: 'production'
  project: 'veritasvault'
}

@description('ML Engine API URL')
param mlEngineApiUrl string

var apiGatewayName = '${baseName}-apigw'

resource apiManagement 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apiGatewayName
  location: location
  tags: tags
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@veritasvault.ai'
    publisherName: 'VeritasVault'
  }
}

resource mlApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: apiManagement
  name: 'ml-engine-api'
  properties: {
    displayName: 'ML Engine API'
    path: 'ml'
    protocols: [
      'https'
    ]
  }
}

resource mlBackend 'Microsoft.ApiManagement/service/backends@2022-08-01' = {
  parent: apiManagement
  name: 'ml-engine-backend'
  properties: {
    url: mlEngineApiUrl
    protocol: 'http'
  }
}

resource riskPredictionOperation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: mlApi
  name: 'risk-prediction'
  properties: {
    displayName: 'Risk Prediction'
    method: 'POST'
    urlTemplate: '/predict'
    request: {
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

resource riskPredictionPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = {
  parent: riskPredictionOperation
  name: 'policy'
  properties: {
    value: '''
    <policies>
      <inbound>
        <base />
        <rate-limit calls="5" renewal-period="10" />
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
          <openid-config url="https://${baseName}.b2clogin.com/${baseName}.onmicrosoft.com/v2.0/.well-known/openid-configuration?p=B2C_1_risk_api" />
          <required-claims>
            <claim name="roles" match="any">
              <value>RiskApiUser</value>
            </claim>
          </required-claims>
        </validate-jwt>
        <set-backend-service backend-id="${mlBackend.name}" />
      </inbound>
      <backend>
        <base />
      </backend>
      <outbound>
        <base />
        <set-header name="X-Powered-By" exists-action="delete" />
        <set-header name="X-AspNet-Version" exists-action="delete" />
        <cors allow-credentials="false">
          <allowed-origins>
            <origin>https://dashboard.veritasvault.ai</origin>
          </allowed-origins>
          <allowed-methods>
            <method>POST</method>
            <method>OPTIONS</method>
          </allowed-methods>
          <allowed-headers>
            <header>Content-Type</header>
            <header>Authorization</header>
          </allowed-headers>
        </cors>
      </outbound>
      <on-error>
        <base />
        <set-header name="X-Error-Source" exists-action="override">
          <value>API Gateway</value>
        </set-header>
        <set-header name="X-Error-Code" exists-action="override">
          <value>@(context.LastError.Code)</value>
        </set-header>
        <return-response>
          <set-status code="500" reason="Internal Server Error" />
          <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
          </set-header>
          <set-body>{"error": "An error occurred processing your request. Please try again later."}</set-body>
        </return-response>
      </on-error>
    </policies>
    '''
    format: 'xml'
  }
}

output apiGatewayUrl string = 'https://${apiManagement.properties.gatewayUrl}/ml'
