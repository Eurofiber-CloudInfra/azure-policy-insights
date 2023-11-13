targetScope = 'resourceGroup'

param location string = resourceGroup().location
param law_connection_name string = 'azureloganalyticsdatacollector'
param logic_app_name string 
param law_resource_id string
param tags object = {}

resource law 'Microsoft.OperationalInsights/workspaces@2020-10-01' existing = if(empty(law_resource_id)) {
  scope: resourceGroup(split(law_resource_id, '/')[2], split(law_resource_id, '/')[4])
  name: last(split(law_resource_id, '/'))
}

resource law_connection 'Microsoft.Web/connections@2016-06-01' = {
  name: law_connection_name
  location:location
  tags: tags
  properties: {
    displayName: law_connection_name
    statuses: []
    parameterValues: {
      username: law.properties.customerId
      password: law.listKeys().primarySharedKey
    }
    api: {
      name: 'azureloganalyticsdatacollector'  
      displayName: 'Azure Log Analytics Data Collector'
      description: 'Azure Log Analytics Data Collector will send data to any Azure Log Analytics workspace.'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1652/1.0.1652.3394/azureloganalyticsdatacollector/icon.png'
      brandColor: '#0072C6'
      id: subscriptionResourceId(subscription().subscriptionId, 'Microsoft.Web/locations/managedApis', location, 'azureloganalyticsdatacollector' )
      type: 'Microsoft.Web/locations/managedApis'
    }
  }
}

resource logic_app 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logic_app_name
  location: location
  tags: tags
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {}
          }
        }
      }
      actions: {
        Send_Data: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            body: '@{triggerBody()}'
            headers: {
              'Log-Type': 'PolicyInsights'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'${law_connection_name}\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/api/logs'
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          '${law_connection_name}': {
            connectionId: law_connection.id
            connectionName: law_connection_name
            id: subscriptionResourceId(subscription().subscriptionId, 'Microsoft.Web/locations/managedApis', location, 'azureloganalyticsdatacollector' )
          }
        }
      }
    }
  }
}

output logic_app_resource_id string = logic_app.id
