targetScope = 'subscription'

// =============================================================================
// main.bicep — Azure DNS Private Resolver Lab
//
// Three demos:
//   1. Inbound endpoint + on-prem DNS forwarding (on-prem → Azure private DNS)
//   2. Outbound endpoint + DNS forwarding ruleset (Azure → on-prem zones)
//   3. DNS Security Policy with a domain-block rule + Log Analytics diagnostics
//
// Deploys at subscription scope: creates the resource group, then provisions
// every lab resource inside it. Composable via Azure Verified Modules where
// available; raw `resource` blocks for DNS Security Policy (no AVM coverage
// at the time of writing).
// =============================================================================

@description('Azure region for all resources.')
param location string = 'eastus2'

@description('Short lowercase prefix used in resource names.')
@minLength(3)
@maxLength(10)
param prefix string = 'dnslab'

@description('Resource group name.')
param resourceGroupName string = 'rg-${prefix}'

@description('Admin username for all VMs.')
param adminUsername string = 'azureuser'

@description('Admin password used for all VMs (Windows DNS server, on-prem Ubuntu client, lab Ubuntu VM). Required.')
@secure()
@minLength(12)
param adminPassword string

@description('On-prem DNS zone hosted on the simulated Windows DNS server. Used by Demo 2.')
param onpremDnsDomain string = 'contoso.com'

@description('A record name created in the on-prem zone (resolves to 10.1.1.4).')
param onpremDnsRecordName string = 'dns'

@description('FQDNs blocked by the DNS Security Policy. MUST end with a trailing dot.')
param blockedDomains array = [
  'malicious.contoso.com.'
  'exploit.adatum.com.'
]

@description('If set to a public IPv4 address, opens RDP/3389 from that single IP to the Windows DNS server. Empty string disables direct RDP (use serial console).')
param allowedPublicIp string = ''

@description('Tags applied to every resource.')
param tags object = {
  workload: 'dns-resolver-lab'
  env: 'lab'
}

// -----------------------------------------------------------------------------
// Resource group
// -----------------------------------------------------------------------------
module rg 'br/public:avm/res/resources/resource-group:0.4.3' = {
  name: 'rg-${prefix}'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// Networking — three VNets + peering + NSGs
// -----------------------------------------------------------------------------
module networking 'modules/networking.bicep' = {
  name: 'networking'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    prefix: prefix
    tags: tags
  }
  dependsOn: [
    rg
  ]
}

// -----------------------------------------------------------------------------
// DNS Private Resolver — resolver, inbound EP, outbound EP, ruleset + rule
// -----------------------------------------------------------------------------
module privateResolver 'modules/private-resolver.bicep' = {
  name: 'private-resolver'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    prefix: prefix
    tags: tags
    hubVnetId: networking.outputs.hubVnetId
    inboundSubnetId: networking.outputs.inboundSubnetId
    outboundSubnetId: networking.outputs.outboundSubnetId
    onpremDnsDomain: onpremDnsDomain
    windowsDnsServerIp: '10.1.1.4'
    linkedVnetIdsForRuleset: [
      networking.outputs.hubVnetId
      networking.outputs.labVnetId
    ]
  }
}

// -----------------------------------------------------------------------------
// Storage account + private endpoint + private DNS zone (Demo 1 target)
// -----------------------------------------------------------------------------
module privateEndpointStorage 'modules/private-endpoint-storage.bicep' = {
  name: 'pe-storage'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    prefix: prefix
    tags: tags
    hubVnetId: networking.outputs.hubVnetId
    privateEndpointSubnetId: networking.outputs.peSubnetId
  }
}

// -----------------------------------------------------------------------------
// On-prem simulation — Windows DNS server (with conditional forwarder + zone)
// + Ubuntu on-prem client
// -----------------------------------------------------------------------------
module onPremSim 'modules/on-prem-sim.bicep' = {
  name: 'on-prem-sim'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    prefix: prefix
    tags: tags
    onpremSubnetId: networking.outputs.onpremSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    onpremDnsDomain: onpremDnsDomain
    onpremDnsRecordName: onpremDnsRecordName
    inboundEndpointIp: '10.0.1.4'
    allowedPublicIp: allowedPublicIp
  }
  dependsOn: [
    privateResolver
  ]
}

// -----------------------------------------------------------------------------
// Lab VM (Demo 3 client)
// -----------------------------------------------------------------------------
module labVm 'modules/lab-vm.bicep' = {
  name: 'lab-vm'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    prefix: prefix
    tags: tags
    labSubnetId: networking.outputs.labSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// -----------------------------------------------------------------------------
// Log Analytics workspace (Demo 3 diagnostics destination)
// -----------------------------------------------------------------------------
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.15.1' = {
  name: 'log-analytics'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'law-${prefix}'
    location: location
    tags: tags
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

// -----------------------------------------------------------------------------
// DNS Security Policy — domain list, policy, block rule, VNet link, diagnostics
// (No AVM coverage; raw resources at API 2025-05-01.)
// -----------------------------------------------------------------------------
module dnsSecurityPolicy 'modules/dns-security-policy.bicep' = {
  name: 'dns-security-policy'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    prefix: prefix
    tags: tags
    blockedDomains: blockedDomains
    labVnetId: networking.outputs.labVnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.resourceId
  }
}

// -----------------------------------------------------------------------------
// Outputs — discoverable post-deploy
// -----------------------------------------------------------------------------
@description('Resource group containing every lab resource.')
output resourceGroupName string = resourceGroupName

@description('Inbound endpoint static IP. Conditional forwarders point here.')
output inboundEndpointIp string = '10.0.1.4'

@description('Forwarding ruleset resource ID.')
output forwardingRulesetId string = privateResolver.outputs.forwardingRulesetId

@description('Storage account name (target for Demo 1 private-endpoint resolution).')
output storageAccountName string = privateEndpointStorage.outputs.storageAccountName

@description('Storage account blob host (use for nslookup on the on-prem client in Demo 1).')
output storageAccountBlobHost string = '${privateEndpointStorage.outputs.storageAccountName}.blob.core.windows.net'

@description('Windows DNS server private IP.')
output windowsDnsServerPrivateIp string = '10.1.1.4'

@description('Windows DNS server public IP (empty if allowedPublicIp was empty).')
output windowsDnsServerPublicIp string = onPremSim.outputs.windowsDnsServerPublicIp

@description('Log Analytics workspace resource ID.')
output logAnalyticsWorkspaceId string = logAnalytics.outputs.resourceId

@description('DNS resolver policy resource ID.')
output dnsResolverPolicyId string = dnsSecurityPolicy.outputs.dnsResolverPolicyId

@description('Admin username for all VMs (password was supplied as a secure parameter).')
output adminUsername string = adminUsername
