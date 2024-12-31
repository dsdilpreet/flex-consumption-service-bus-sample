@description('Name of the Service Bus namespace')
param serviceBusNamespaceName string

@description('Location for all resources.')
param location string = resourceGroup().location

var serviceBusTopicName = 'sbt-topic'
var subscriptionNameForFlexConsumption = 'sbs-flexconsumption'
var subscriptionNameForConsumption = 'sbs-consumption'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {}
}

resource serviceBusTopic 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' = {
  parent: serviceBusNamespace
  name: serviceBusTopicName
}

resource subscriptionForFlexConsumption 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2024-01-01' = {
  parent: serviceBusTopic
  name: subscriptionNameForFlexConsumption
}

resource subscriptionForConsumption 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2024-01-01' = {
  parent: serviceBusTopic
  name: subscriptionNameForConsumption
}
