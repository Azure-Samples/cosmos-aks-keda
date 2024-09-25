param aksCluster_issuerUrl string
param identity_name string
param service_account_namespace string 
param service_account_name string

resource azidentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: identity_name
}

resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  name: 'string'
  parent: azidentity
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: aksCluster_issuerUrl
    subject: 'system:serviceaccount:${service_account_namespace}:${service_account_name}'
  }
}
