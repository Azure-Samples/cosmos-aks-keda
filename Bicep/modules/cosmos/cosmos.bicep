@description('Location for all resources.')
param location string = resourceGroup().location

@description('Cosmos DB account name, max length 44 characters')
param accountName string// = toLower('rgName-${uniqueString(resourceGroup().id)}-cosmossql')

@description('Friendly name for the SQL Role Definition')
param roleDefinitionName string = 'My All Acess Role'

@description('Resource Id of the Subnet to enable service endpoints in Cosmos')

param throughput int

param subNetId string

@description('Data actions permitted by the Role Definition')
param dataActions array = [
    'Microsoft.DocumentDB/databaseAccounts/readMetadata'
    'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
    'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
]

@description('Object ID of the AAD identity. Must be a GUID.')
param principalId string

var locations = [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
]
var roleDefinitionId = guid('sql-role-definition-', principalId, databaseAccount.id)
var roleAssignmentId = guid(roleDefinitionId, principalId, databaseAccount.id)

resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: accountName
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: locations
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: false      // set to false if you want to use master keys in addition to RBAC
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false   
    isVirtualNetworkFilterEnabled: false     // set to false if you want to use public endpoint for Cosmos
    //uncoment  virtualNetworkRules if you want to use public endpoint for Cosmos
    /*
    virtualNetworkRules: [
          {
              id: subNetId
              ignoreMissingVNetServiceEndpoint: false
          }
      ]*/
      
  }
}
output cosmosEndpoint string = databaseAccount.name

resource sqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2022-05-15' = {
  name: '${databaseAccount.name}/${roleDefinitionId}'
  properties: {
    roleName: roleDefinitionName
    type: 'CustomRole'
    assignableScopes: [
      databaseAccount.id
    ]
    permissions: [
      {
        dataActions: dataActions
      }
    ]
  }
}

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
  name: '${databaseAccount.name}/${roleAssignmentId}'
  properties: {
    roleDefinitionId: sqlRoleDefinition.id
    principalId: principalId
    scope: databaseAccount.id
  }
}


resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-10-15' = {
  name: '${databaseAccount.name}/StoreDatabase'
  properties: {
    resource: {
      id: 'StoreDatabase'
    }
  }
}

resource OrderContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
  name: '${database.name}/${'OrderContainer'}'
  properties: {
    resource: {
      id: 'OrderContainer'
      partitionKey: {
        paths: [
          '/Article'
        ]
      }         
    }
    options: {
      autoscaleSettings: {
        maxThroughput: throughput
      }
    }   
  }
}

  resource OrderProcessorLeasescontainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
    name: '${database.name}/${'OrderProcessorLeases'}'
    properties: {
      resource: {
        id: 'OrderProcessorLeases'
        partitionKey: {
          paths: [
            '/id'
          ]
        }      
                 
      }
      options: {
        throughput: 400
      }
    }
  }

