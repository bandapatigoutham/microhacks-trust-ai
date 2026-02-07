@description('Azure region for resources')
param location string

@description('Resource tags')
param tags object = {}

@description('AI Services account name')
param accountName string

@description('AI Foundry project name')
param projectName string

@description('AI Search service name')
param searchName string

@description('Storage account name')
param storageName string

@description('Log Analytics workspace name')
param logAnalyticsName string

@description('Application Insights name')
param appInsightsName string

@description('Chat completion model')
param chatModel string

@description('Chat model version')
param chatModelVersion string

@description('Chat model capacity (tokens per minute in thousands)')
param chatModelCapacity int

@description('Embedding model')
param embeddingModel string

@description('Embedding model capacity (tokens per minute in thousands)')
param embeddingModelCapacity int

@description('Eval model')
param evalModel string

@description('Eval model version')
param evalModelVersion string

@description('Eval model capacity (tokens per minute in thousands)')
param evalModelCapacity int

@description('Principal ID of the user running deployment (for role assignments)')
param deployingUserPrincipalId string

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    DisableLocalAuth: false
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

// AI Services Account (Foundry)
resource aiServices 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
    allowProjectManagement: true
  }
}

// Chat Model Deployment
resource chatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiServices
  name: chatModel
  sku: {
    name: 'GlobalStandard'
    capacity: chatModelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: chatModel
      version: chatModelVersion
    }
  }
}

resource evalDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiServices
  name: evalModel
  sku: {
    name: 'GlobalStandard'
    capacity: evalModelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: evalModel
      version: evalModelVersion
    }
  }
  dependsOn: [chatDeployment]
}

// Embedding Model Deployment
resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiServices
  name: embeddingModel
  sku: {
    name: 'Standard'
    capacity: embeddingModelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: embeddingModel
    }
  }
  dependsOn: [evalDeployment]
}

// AI Search Service
resource aiSearch 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: searchName
  location: location
  tags: tags
  sku: { name: 'basic' }
  identity: { type: 'SystemAssigned' }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
    semanticSearch: 'free'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

// AI Foundry Project
resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: aiServices
  name: projectName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: projectName
  }
  dependsOn: [embeddingDeployment]
}

// Connect AI Search to Project
resource searchConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: aiProject
  name: 'search-connection'
  properties: {
    category: 'CognitiveSearch'
    target: 'https://${aiSearch.name}.search.windows.net'
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiSearch.id
    }
  }
}

// Connect Application Insights to Project
resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: aiProject
  name: appInsightsName
  properties: {
    category: 'AppInsights'
    target: appInsights.id
    authType: 'ApiKey'
    isSharedToAll: true
    isDefault: true
    credentials: {
      key: appInsights.properties.InstrumentationKey
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsights.id
    }
  }
}

// Role Definitions
resource searchIndexDataContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7' // Search Index Data Contributor
}

resource searchIndexDataReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '1407120a-92aa-4202-b7e9-c0e197c71c8f' // Search Index Data Reader
}

resource searchServiceContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0' // Search Service Contributor
}

// Grant AI Project identity access to AI Search
resource projectSearchIndexContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiSearch
  name: guid(aiSearch.id, aiProject.id, searchIndexDataContributor.id)
  properties: {
    principalId: aiProject.identity.principalId
    roleDefinitionId: searchIndexDataContributor.id
    principalType: 'ServicePrincipal'
  }
}

resource projectSearchIndexReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiSearch
  name: guid(aiSearch.id, aiProject.id, searchIndexDataReader.id)
  properties: {
    principalId: aiProject.identity.principalId
    roleDefinitionId: searchIndexDataReader.id
    principalType: 'ServicePrincipal'
  }
}

resource projectSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiSearch
  name: guid(aiSearch.id, aiProject.id, searchServiceContributor.id)
  properties: {
    principalId: aiProject.identity.principalId
    roleDefinitionId: searchServiceContributor.id
    principalType: 'ServicePrincipal'
  }
}

// Grant AI Search identity access to AI Services (for skillset to call embeddings)
resource searchAIServicesAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiServices
  name: guid(aiServices.id, aiSearch.id, cognitiveServicesUser.id)
  properties: {
    principalId: aiSearch.identity.principalId
    roleDefinitionId: cognitiveServicesUser.id
    principalType: 'ServicePrincipal'
  }
}

// Storage Role Definitions
resource storageBlobDataContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
}

resource storageBlobDataReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
}

// Grant AI Project identity access to Storage
resource projectStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, aiProject.id, storageBlobDataContributor.id)
  properties: {
    principalId: aiProject.identity.principalId
    roleDefinitionId: storageBlobDataContributor.id
    principalType: 'ServicePrincipal'
  }
}

resource projectStorageBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, aiProject.id, storageBlobDataReader.id)
  properties: {
    principalId: aiProject.identity.principalId
    roleDefinitionId: storageBlobDataReader.id
    principalType: 'ServicePrincipal'
  }
}

// Grant AI Search identity access to Storage (for indexers)
resource searchStorageBlobDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, aiSearch.id, storageBlobDataReader.id)
  properties: {
    principalId: aiSearch.identity.principalId
    roleDefinitionId: storageBlobDataReader.id
    principalType: 'ServicePrincipal'
  }
}

// Default container for AI Foundry
resource defaultContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'default'
  properties: {
    publicAccess: 'None'
  }
}

// Connect Storage to Project
resource storageConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: aiProject
  name: 'storage-connection'
  properties: {
    category: 'AzureBlob'
    target: storageAccount.properties.primaryEndpoints.blob
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ResourceId: storageAccount.id
      AccountName: storageAccount.name
      ContainerName: 'default'
    }
  }
  dependsOn: [defaultContainer]
}

// Role Definitions for deploying user
resource cognitiveServicesUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services User
}

resource azureAIUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '53ca6127-db72-4b80-b1b0-d745d6d5456d' // Azure AI User
}

// Grant deploying user access to AI Services
resource userAIServicesAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiServices
  name: guid(aiServices.id, deployingUserPrincipalId, cognitiveServicesUser.id)
  properties: {
    principalId: deployingUserPrincipalId
    roleDefinitionId: cognitiveServicesUser.id
    principalType: 'User'
  }
}

// Grant deploying user Azure AI User role on AI Services
resource userAzureAIAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiServices
  name: guid(aiServices.id, deployingUserPrincipalId, azureAIUser.id)
  properties: {
    principalId: deployingUserPrincipalId
    roleDefinitionId: azureAIUser.id
    principalType: 'User'
  }
}

// Grant deploying user access to AI Search
resource userSearchIndexContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiSearch
  name: guid(aiSearch.id, deployingUserPrincipalId, searchIndexDataContributor.id)
  properties: {
    principalId: deployingUserPrincipalId
    roleDefinitionId: searchIndexDataContributor.id
    principalType: 'User'
  }
}

resource userSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiSearch
  name: guid(aiSearch.id, deployingUserPrincipalId, searchServiceContributor.id)
  properties: {
    principalId: deployingUserPrincipalId
    roleDefinitionId: searchServiceContributor.id
    principalType: 'User'
  }
}

// Grant deploying user access to Storage
resource userStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, deployingUserPrincipalId, storageBlobDataContributor.id)
  properties: {
    principalId: deployingUserPrincipalId
    roleDefinitionId: storageBlobDataContributor.id
    principalType: 'User'
  }
}

output accountName string = aiServices.name
output projectName string = aiProject.name
output projectEndpoint string = aiProject.properties.endpoints['AI Foundry API']
output aiEndpoint string = aiServices.properties.endpoint
output openAIEndpoint string = aiServices.properties.endpoints['OpenAI Language Model Instance API']
output searchName string = aiSearch.name
output searchEndpoint string = 'https://${aiSearch.name}.search.windows.net'
output storageName string = storageAccount.name
output storageBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output appInsightsName string = appInsights.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsCustomerId string = logAnalytics.properties.customerId
output logAnalyticsSharedKey string = logAnalytics.listKeys().primarySharedKey
output evalModel string = evalModel
