// =============================================================================
// modules/private-resolver.bicep — DNS Private Resolver + endpoints + ruleset
//
// Creates the resolver bound to the hub VNet, an inbound endpoint with a
// PINNED static IP (10.0.1.4 — first usable address in the /28), an outbound
// endpoint, a forwarding ruleset, a single forwarding rule for the on-prem
// domain pointing at the on-prem Windows DNS server (10.1.1.4), and VNet
// links so the rule applies to both hub and lab VNets.
// =============================================================================

@description('Azure region.')
param location string

@description('Resource name prefix.')
param prefix string

@description('Tags applied to every resource.')
param tags object

@description('Hub VNet resource ID. The resolver is attached to this VNet.')
param hubVnetId string

@description('Subnet resource ID for the inbound endpoint (delegated /28).')
param inboundSubnetId string

@description('Subnet resource ID for the outbound endpoint (delegated /28).')
param outboundSubnetId string

@description('On-prem domain for the forwarding rule (e.g. contoso.com).')
param onpremDnsDomain string

@description('IP address of the on-prem Windows DNS server. The forwarding rule routes matching queries here.')
param windowsDnsServerIp string

@description('VNet resource IDs to link the forwarding ruleset to. Without a link the rule has no effect on that VNet.')
param linkedVnetIdsForRuleset array

module dnsResolver 'br/public:avm/res/network/dns-resolver:0.5.7' = {
  name: 'dns-resolver'
  params: {
    name: 'res-${prefix}-resolver'
    location: location
    tags: tags
    virtualNetworkResourceId: hubVnetId
    inboundEndpoints: [
      {
        name: 'inbound-ep'
        subnetResourceId: inboundSubnetId
        privateIpAllocationMethod: 'Static'
        privateIpAddress: '10.0.1.4'
      }
    ]
    outboundEndpoints: [
      {
        name: 'outbound-ep'
        subnetResourceId: outboundSubnetId
      }
    ]
  }
}

module forwardingRuleset 'br/public:avm/res/network/dns-forwarding-ruleset:0.5.4' = {
  name: 'fwdr-ruleset'
  params: {
    name: 'fwdr-${prefix}'
    location: location
    tags: tags
    dnsResolverOutboundEndpointResourceIds: [
      dnsResolver.outputs.outboundEndpointsObject[0].resourceId
    ]
    forwardingRules: [
      {
        name: 'onprem-zone'
        domainName: '${onpremDnsDomain}.'
        forwardingRuleState: 'Enabled'
        targetDnsServers: [
          {
            ipAddress: windowsDnsServerIp
            port: 53
          }
        ]
      }
    ]
    vNetLinks: [for vnetId in linkedVnetIdsForRuleset: {
      vNetResourceId: vnetId
    }]
  }
}

output dnsResolverId string = dnsResolver.outputs.resourceId
output forwardingRulesetId string = forwardingRuleset.outputs.resourceId
output inboundEndpointIp string = '10.0.1.4'
