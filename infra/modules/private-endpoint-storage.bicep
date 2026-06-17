// =============================================================================
// modules/private-endpoint-storage.bicep — Storage + PE + privatelink zone
//
// Storage account with public network access disabled. Reachable only via the
// private endpoint in snet-pe (hub). The privatelink zone is linked to the hub
// VNet so the resolver inbound endpoint can answer queries against it.
// =============================================================================

@description('Azure region.')
param location string

@description('Resource name prefix.')
param prefix string

@description('Tags applied to every resource.')
param tags object

@description('Hub VNet resource ID (privatelink zone is linked here).')
param hubVnetId string

@description('Subnet resource ID for the storage private endpoint.')
param privateEndpointSubnetId string

var storageAccountName = take('st${replace(prefix, '-', '')}${uniqueString(resourceGroup().id)}', 24)

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.1' = {
  name: 'pdns-blob'
  params: {
    name: 'privatelink.blob.core.windows.net'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: hubVnetId
        registrationEnabled: false
      }
    ]
  }
}

module storage 'br/public:avm/res/storage/storage-account:0.32.1' = {
  name: 'storage'
  params: {
    name: storageAccountName
    location: location
    tags: tags
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    privateEndpoints: [
      {
        service: 'blob'
        subnetResourceId: privateEndpointSubnetId
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
  }
}

output storageAccountId string = storage.outputs.resourceId
output storageAccountName string = storage.outputs.name
output privateDnsZoneId string = privateDnsZone.outputs.resourceId
