// Event Grid Subscriptions Module
// This module creates all the event grid subscriptions for the various function apps

@description('Name of the Event Grid Topic')
param eventGridTopicName string

@description('ID of the Dead Letter Storage Account')
param deadLetterStorageId string = ''

@description('Name of the Dead Letter Container')
param deadLetterContainerName string = 'deadletter'

@description('Function App IDs and details')
param functionAppIds object = {}

@description('Feature flags to control which subscriptions are deployed')
param featureFlags object = {
  deployRiskBotSubscription: true
  deployMetricsBotSubscription: true
  deployAlertFunctionSubscription: true
  deployArchivalFunctionSubscription: true
}

@description('Subscription configurations')
param subscriptionConfig object = {
  riskBot: {
    includedEventTypes: [
      'price.update',
      'asset.deposit',
      'asset.withdraw'
    ]
    maxDeliveryAttempts: 30
    eventTimeToLiveInMinutes: 1440
  }
  metricsBot: {
    includedEventTypes: [
      'price.update',
      'asset.deposit',
      'asset.withdraw',
      'governance.vote',
      'transaction.execute'
    ]
    maxDeliveryAttempts: 30
    eventTimeToLiveInMinutes: 1440
  }
  alert: {
    includedEventTypes: [
      'price.update',
      'asset.liquidation',
      'security.anomaly',
      'transaction.large'
    ]
    maxDeliveryAttempts: 30
    eventTimeToLiveInMinutes: 1440
  }
  archival: {
    includedEventTypes: []
    maxDeliveryAttempts: 30
    eventTimeToLiveInMinutes: 1440
  }
}

// Reference to the Event Grid Topic
resource eventGridTopic 'Microsoft.EventGrid/topics@2023-12-15-preview' existing = {
  name: eventGridTopicName
}

// Dead Letter Destination configuration
var deadLetterDestination = !empty(deadLetterStorageId) ? {
  endpointType: 'StorageBlob'
  properties: {
    resourceId: deadLetterStorageId
    blobContainerName: deadLetterContainerName
  }
} : null

// Event Grid Subscription for Risk Bot
resource riskBotSubscription 'Microsoft.EventGrid/eventSubscriptions@2023-12-15-preview' = if (featureFlags.deployRiskBotSubscription && contains(functionAppIds, 'riskBot') && !empty(functionAppIds.riskBot)) {
  name: 'risk-bot-subscription'
  scope: eventGridTopic
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppIds.riskBot.id}/functions/ProcessEvent'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: subscriptionConfig.riskBot.includedEventTypes
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    retryPolicy: {
      maxDeliveryAttempts: subscriptionConfig.riskBot.maxDeliveryAttempts
      eventTimeToLiveInMinutes: subscriptionConfig.riskBot.eventTimeToLiveInMinutes
    }
    deadLetterDestination: deadLetterDestination
  }
}

// Event Grid Subscription for Metrics Bot
resource metricsBotSubscription 'Microsoft.EventGrid/eventSubscriptions@2023-12-15-preview' = if (featureFlags.deployMetricsBotSubscription && contains(functionAppIds, 'metricsBot') && !empty(functionAppIds.metricsBot)) {
  name: 'metrics-bot-subscription'
  scope: eventGridTopic
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppIds.metricsBot.id}/functions/ProcessEvent'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: subscriptionConfig.metricsBot.includedEventTypes
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    retryPolicy: {
      maxDeliveryAttempts: subscriptionConfig.metricsBot.maxDeliveryAttempts
      eventTimeToLiveInMinutes: subscriptionConfig.metricsBot.eventTimeToLiveInMinutes
    }
    deadLetterDestination: deadLetterDestination
  }
}

// Event Grid Subscription for Alert Function
resource alertFunctionSubscription 'Microsoft.EventGrid/eventSubscriptions@2023-12-15-preview' = if (featureFlags.deployAlertFunctionSubscription && contains(functionAppIds, 'alert') && !empty(functionAppIds.alert)) {
  name: 'alert-function-subscription'
  scope: eventGridTopic
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppIds.alert.id}/functions/ProcessEvent'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: subscriptionConfig.alert.includedEventTypes
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    retryPolicy: {
      maxDeliveryAttempts: subscriptionConfig.alert.maxDeliveryAttempts
      eventTimeToLiveInMinutes: subscriptionConfig.alert.eventTimeToLiveInMinutes
    }
    deadLetterDestination: deadLetterDestination
  }
}

// Event Grid Subscription for Archival Function
resource archivalFunctionSubscription 'Microsoft.EventGrid/eventSubscriptions@2023-12-15-preview' = if (featureFlags.deployArchivalFunctionSubscription && contains(functionAppIds, 'archival') && !empty(functionAppIds.archival)) {
  name: 'archival-function-subscription'
  scope: eventGridTopic
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppIds.archival.id}/functions/ProcessEvent'
        maxEventsPerBatch: 10
        preferredBatchSizeInKilobytes: 256
      }
    }
    filter: {
      includedEventTypes: subscriptionConfig.archival.includedEventTypes
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    retryPolicy: {
      maxDeliveryAttempts: subscriptionConfig.archival.maxDeliveryAttempts
      eventTimeToLiveInMinutes: subscriptionConfig.archival.eventTimeToLiveInMinutes
    }
    deadLetterDestination: deadLetterDestination
  }
}

// Outputs
output subscriptionIds object = {
  riskBot: featureFlags.deployRiskBotSubscription && contains(functionAppIds, 'riskBot') && !empty(functionAppIds.riskBot) ? riskBotSubscription.id : ''
  metricsBot: featureFlags.deployMetricsBotSubscription && contains(functionAppIds, 'metricsBot') && !empty(functionAppIds.metricsBot) ? metricsBotSubscription.id : ''
  alert: featureFlags.deployAlertFunctionSubscription && contains(functionAppIds, 'alert') && !empty(functionAppIds.alert) ? alertFunctionSubscription.id : ''
  archival: featureFlags.deployArchivalFunctionSubscription && contains(functionAppIds, 'archival') && !empty(functionAppIds.archival) ? archivalFunctionSubscription.id : ''
}
