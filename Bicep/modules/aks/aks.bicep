param basename string

param identity object
param location string = resourceGroup().location


//param logworkspaceid string  // Uncomment this to configure log analytics workspace

param subnetId string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-05-02-preview' = {
  name: '${basename}aks'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: identity   
  }
  properties: {
    kubernetesVersion: '1.26.3'
    nodeResourceGroup: '${basename}-aksInfraRG'
    dnsPrefix: '${basename}aks'
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    agentPoolProfiles: [
      {
        name: 'default'
        count: 2
        vmSize: 'Standard_D4s_v3'
        mode: 'System'
        maxCount: 5
        minCount: 2
        osType: 'Linux'
        osSKU: 'Ubuntu'
        enableAutoScaling:true
        maxPods: 50
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetId  // Uncomment this to configure VNET
        enableNodePublicIP:false
      }
    ]

    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: 'azure'
      outboundType: 'loadBalancer'
      dnsServiceIP: '10.0.0.10'
      serviceCidr: '10.0.0.0/16'
 
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    enableRBAC: true
    enablePodSecurityPolicy: false
    addonProfiles:{
      /*
	  // Uncomment this to configure log analytics workspace
	  omsagent: {
        config: {
          logAnalyticsWorkspaceResourceID: logworkspaceid
        }
        enabled: true
      }*/
      azureKeyvaultSecretsProvider: {
        enabled: true
      }
      azurepolicy: {
        enabled: false
      }
    }
    
  }
}

output aksName string = aksCluster.name
output issuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL
output principalId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
