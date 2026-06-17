// =============================================================================
// modules/networking.bicep — three VNets + peering + NSGs
//
// Hub VNet (10.0.0.0/16):
//   - snet-resolver-in   10.0.1.0/28   delegated to Microsoft.Network/dnsResolvers
//   - snet-resolver-out  10.0.2.0/28   delegated to Microsoft.Network/dnsResolvers
//   - snet-pe            10.0.3.0/24   private endpoints
//
// On-prem VNet (10.1.0.0/16):
//   - snet-onprem        10.1.1.0/24   Windows DNS server (.4) + Ubuntu client
//
// Lab VNet (10.2.0.0/16):
//   - snet-lab           10.2.1.0/24   Ubuntu lab VM for Demo 3
//
// Hub <-> on-prem peering simulates ExpressRoute/VPN connectivity for the lab.
// Lab VNet is intentionally NOT peered (it tests its own DNS Security Policy).
// =============================================================================

@description('Azure region.')
param location string

@description('Resource name prefix.')
param prefix string

@description('Tags applied to every resource.')
param tags object

// -----------------------------------------------------------------------------
// NSGs
// -----------------------------------------------------------------------------
module nsgHub 'br/public:avm/res/network/network-security-group:0.5.3' = {
  name: 'nsg-hub'
  params: {
    name: 'nsg-${prefix}-hub'
    location: location
    tags: tags
  }
}

module nsgOnprem 'br/public:avm/res/network/network-security-group:0.5.3' = {
  name: 'nsg-onprem'
  params: {
    name: 'nsg-${prefix}-onprem'
    location: location
    tags: tags
    securityRules: [
      {
        name: 'AllowDnsFromHub'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '10.0.0.0/16'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.1.0.0/16'
          destinationPortRange: '53'
        }
      }
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

module nsgLab 'br/public:avm/res/network/network-security-group:0.5.3' = {
  name: 'nsg-lab'
  params: {
    name: 'nsg-${prefix}-lab'
    location: location
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// VNets
// -----------------------------------------------------------------------------
module hubVnet 'br/public:avm/res/network/virtual-network:0.9.0' = {
  name: 'vnet-hub'
  params: {
    name: 'vnet-${prefix}-hub'
    location: location
    tags: tags
    addressPrefixes: [ '10.0.0.0/16' ]
    subnets: [
      {
        name: 'snet-resolver-in'
        addressPrefix: '10.0.1.0/28'
        delegation: 'Microsoft.Network/dnsResolvers'
      }
      {
        name: 'snet-resolver-out'
        addressPrefix: '10.0.2.0/28'
        delegation: 'Microsoft.Network/dnsResolvers'
      }
      {
        name: 'snet-pe'
        addressPrefix: '10.0.3.0/24'
        networkSecurityGroupResourceId: nsgHub.outputs.resourceId
        privateEndpointNetworkPolicies: 'Disabled'
      }
    ]
  }
}

module onpremVnet 'br/public:avm/res/network/virtual-network:0.9.0' = {
  name: 'vnet-onprem'
  params: {
    name: 'vnet-${prefix}-onprem'
    location: location
    tags: tags
    addressPrefixes: [ '10.1.0.0/16' ]
    subnets: [
      {
        name: 'snet-onprem'
        addressPrefix: '10.1.1.0/24'
        networkSecurityGroupResourceId: nsgOnprem.outputs.resourceId
      }
    ]
    peerings: [
      {
        remoteVirtualNetworkResourceId: hubVnet.outputs.resourceId
        remotePeeringEnabled: true
        remotePeeringName: 'peer-hub-to-onprem'
        allowForwardedTraffic: true
        allowVirtualNetworkAccess: true
      }
    ]
  }
}

module labVnet 'br/public:avm/res/network/virtual-network:0.9.0' = {
  name: 'vnet-lab'
  params: {
    name: 'vnet-${prefix}-lab'
    location: location
    tags: tags
    addressPrefixes: [ '10.2.0.0/16' ]
    subnets: [
      {
        name: 'snet-lab'
        addressPrefix: '10.2.1.0/24'
        networkSecurityGroupResourceId: nsgLab.outputs.resourceId
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Outputs — IDs consumed by downstream modules
// -----------------------------------------------------------------------------
output hubVnetId string = hubVnet.outputs.resourceId
output onpremVnetId string = onpremVnet.outputs.resourceId
output labVnetId string = labVnet.outputs.resourceId

output inboundSubnetId string = hubVnet.outputs.subnetResourceIds[0]
output outboundSubnetId string = hubVnet.outputs.subnetResourceIds[1]
output peSubnetId string = hubVnet.outputs.subnetResourceIds[2]
output onpremSubnetId string = onpremVnet.outputs.subnetResourceIds[0]
output labSubnetId string = labVnet.outputs.subnetResourceIds[0]
