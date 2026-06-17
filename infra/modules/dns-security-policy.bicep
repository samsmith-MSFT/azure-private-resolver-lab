// =============================================================================
// modules/dns-security-policy.bicep — DNS Security Policy + diagnostics
//
// No AVM coverage as of writing — declared as raw resources at API
// 2025-05-01.
//
// Resources:
//   1. Microsoft.Network/dnsResolverDomainLists — list of FQDNs to block.
//   2. Microsoft.Network/dnsResolverPolicies — the policy itself.
//   3. Microsoft.Network/dnsResolverPolicies/dnsSecurityRules — block rule.
//   4. Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks — link the
//      policy to the lab VNet so its queries are evaluated.
//   5. Microsoft.Insights/diagnosticSettings (resource-scoped) — query logs
//      to Log Analytics.
//
// blockResponseCode options at API 2025-05-01:
//   - SERVFAIL — most visible in dig output (default for this lab)
//   - NXDOMAIN — synthetic response: clients see blockpolicy.azuredns.invalid
//   - REFUSED  — clean refusal
// =============================================================================

@description('Azure region.')
param location string

@description('Resource name prefix.')
param prefix string

@description('Tags applied to every resource.')
param tags object

@description('FQDNs to block. Each MUST end with a trailing dot, e.g. "malware.example.com."')
param blockedDomains array

@description('Resource ID of the lab VNet to attach the resolver policy to.')
param labVnetId string

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

resource dnsResolverDomainList 'Microsoft.Network/dnsResolverDomainLists@2025-05-01' = {
  name: '${prefix}-blocked-domains'
  location: location
  tags: tags
  properties: {
    domains: blockedDomains
  }
}

resource dnsResolverPolicy 'Microsoft.Network/dnsResolverPolicies@2025-05-01' = {
  name: '${prefix}-resolver-policy'
  location: location
  tags: tags
  properties: {}
}

resource dnsSecurityRule 'Microsoft.Network/dnsResolverPolicies/dnsSecurityRules@2025-05-01' = {
  parent: dnsResolverPolicy
  name: '${prefix}-block-rule'
  location: location
  properties: {
    priority: 100
    state: 'Enabled'
    action: {
      actionType: 'Block'
      blockResponseCode: 'SERVFAIL'
    }
    dnsResolverDomainLists: [
      {
        id: dnsResolverDomainList.id
      }
    ]
  }
}

resource dnsResolverPolicyVnetLink 'Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2025-05-01' = {
  parent: dnsResolverPolicy
  name: '${prefix}-lab-vnet-link'
  location: location
  properties: {
    virtualNetwork: {
      id: labVnetId
    }
  }
}

resource dnsResolverPolicyDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${prefix}-resolver-policy-diag'
  scope: dnsResolverPolicy
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: []
  }
}

@description('DNS Resolver Policy resource ID.')
output dnsResolverPolicyId string = dnsResolverPolicy.id

@description('Domain list resource ID.')
output dnsResolverDomainListId string = dnsResolverDomainList.id

@description('Block rule resource ID.')
output dnsSecurityRuleId string = dnsSecurityRule.id
