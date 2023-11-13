targetScope = 'resourceGroup'

param event_grid_system_topic_name string
param logic_app_resource_id string
param tags object = {}

resource logic_app 'Microsoft.Logic/workflows@2019-05-01' existing = {
  scope: resourceGroup(split(logic_app_resource_id, '/')[2], split(logic_app_resource_id, '/')[4])
  name: last(split(logic_app_resource_id, '/'))
}

resource event_grid_system_topic 'Microsoft.EventGrid/systemTopics@2023-06-01-preview' = {
  name: event_grid_system_topic_name
  location: 'global'
  tags: tags
  properties: {
    source: subscription().id
    topicType: 'Microsoft.PolicyInsights.PolicyStates'
  }
}

resource event_grid_subscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-06-01-preview' = {
  parent: event_grid_system_topic
  name: last(split(logic_app_resource_id, '/'))
  properties: {
    destination: {
      properties: {
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
        endpointUrl: listCallbackURL('${logic_app.id}/triggers/manual', '2017-07-01').value
      }
      endpointType: 'WebHook'
    }
    filter: {
      includedEventTypes: [
        'Microsoft.PolicyInsights.PolicyStateChanged'
        'Microsoft.PolicyInsights.PolicyStateCreated'
        'Microsoft.PolicyInsights.PolicyStateDeleted'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}
