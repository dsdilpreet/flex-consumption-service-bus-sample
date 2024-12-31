targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string
@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
param location string
param resourceGroupName string
param flexConsumptionFunctionAppPlanName string
param consumptionFunctionAppPlanName string
param flexConsumptionFunctionAppName string
param consumptionFunctionAppName string
param flexConsumptionStorageAccountName string
param consumptionStorageAccountName string
param appInsightsLocation string
param logAnalyticsName string
param applicationInsightsName string
param serviceBusNamespaceName string
@allowed(['dotnet-isolated','python','java', 'node', 'powerShell'])
param functionAppRuntime string = 'dotnet-isolated'
@allowed(['3.10','3.11', '7.4', '8.0', '10', '11', '17', '20'])
param functionAppRuntimeVersion string = '8.0'
@minValue(40)
@maxValue(1000)
param maximumInstanceCount int = 100
@allowed([2048,4096])
param instanceMemoryMB int = 2048

var abbrs = loadJsonContent('./abbreviations.json')
// Generate a unique token to be used in naming resources.
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
// Generate a unique function app name if one is not provided.
var flexConsumptionAppName = !empty(flexConsumptionFunctionAppName) ? flexConsumptionFunctionAppName : '${abbrs.webSitesFunctions}${resourceToken}'
// Generate a unique container name that will be used for deployments.
var flexConsumptionDeploymentStorageContainerName = 'app-package-${take(flexConsumptionAppName, 32)}-${take(resourceToken, 7)}'

// tags that should be applied to all resources.
var tags = {
  // Tag all resources with the environment name.
  'azd-env-name': environmentName
}

var monitoringLocation = !empty(appInsightsLocation) ? appInsightsLocation : location

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  location: location
  tags: tags
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
}

// module serviceBus 'core/servicebus/servicebus.bicep' = {
//   name: 'serviceBus'
//   scope: rg
//   params: {
//     location: location
//     serviceBusNamespaceName: serviceBusNamespaceName
//   }
// }

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: monitoringLocation
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
  }
}

// Backing storage for Azure Functions
module storageForFlexConsumptionFunction 'core/storage/storage-account.bicep' = {
  name: 'storageForFlexConsumptionFunction'
  scope: rg
  params: {
    location: location
    tags: tags
    name: flexConsumptionStorageAccountName
    containers: [{name: flexConsumptionDeploymentStorageContainerName}]
  }
}

module storageForConsumptionFunction 'core/storage/storage-account.bicep' = {
  name: 'storageForConsumptionFunction'
  scope: rg
  params: {
    location: location
    tags: tags
    name: consumptionStorageAccountName
  }
}

// Azure Functions Flex Consumption
module flexConsumptionFunction 'core/host/flexconsumptionfunction.bicep' = {
  name: 'flexConsumptionFunction'
  scope: rg 
  params: {
    location: location
    tags: tags
    planName: !empty(flexConsumptionFunctionAppPlanName) ? flexConsumptionFunctionAppPlanName : '${abbrs.webServerFarms}${resourceToken}'
    appName: flexConsumptionAppName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    storageAccountName: storageForFlexConsumptionFunction.outputs.name
    deploymentStorageContainerName: flexConsumptionDeploymentStorageContainerName
    serviceBusNamespaceName: serviceBusNamespaceName // serviceBus.name
    functionAppRuntime: functionAppRuntime
    functionAppRuntimeVersion: functionAppRuntimeVersion
    maximumInstanceCount: maximumInstanceCount
    instanceMemoryMB: instanceMemoryMB    
  }
}

// Azure Functions Consumption
module consumptionFunction 'core/host/consumptionfunction.bicep' = {
  name: 'consumptionFunction'
  scope: rg 
  params: {
    location: location
    planName: !empty(consumptionFunctionAppPlanName) ? consumptionFunctionAppPlanName : '${abbrs.webServerFarms}${resourceToken}'
    functionAppName: consumptionFunctionAppName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    storageAccountName: storageForConsumptionFunction.outputs.name 
    serviceBusNamespaceName: serviceBusNamespaceName 
  }
}
