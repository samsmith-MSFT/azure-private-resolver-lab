// =============================================================================
// modules/on-prem-sim.bicep — Windows DNS server + Ubuntu on-prem client
//
// Windows Server 2022 with the DNS Server role. Custom Script Extension runs
// `Configure-WindowsDns.ps1` to install the role, create a conditional
// forwarder, and create the on-prem primary zone with one A record.
//
// Optional public IP + RDP rule when allowedPublicIp is set; otherwise the
// VM is reachable only via Azure serial console.
//
// The Ubuntu on-prem client uses the Windows DNS server as its nameserver via
// resolv.conf, populated from the VNet's custom DNS settings (configured by
// referencing the WindowsDNS NIC IP at module-output time — see comment at
// the bottom of this module).
// =============================================================================

@description('Azure region.')
param location string

@description('Resource name prefix.')
param prefix string

@description('Tags applied to every resource.')
param tags object

@description('Subnet resource ID for the on-prem VMs (snet-onprem).')
param onpremSubnetId string

@description('Admin username for both VMs.')
param adminUsername string

@description('Admin password for both VMs.')
@secure()
param adminPassword string

@description('On-prem DNS domain hosted on the Windows DNS server.')
param onpremDnsDomain string

@description('A record name created in the on-prem zone.')
param onpremDnsRecordName string

@description('Inbound endpoint static IP (used by the conditional forwarder).')
param inboundEndpointIp string

@description('If set to a public IPv4, opens RDP/3389 from that IP only. Empty disables direct RDP.')
param allowedPublicIp string

var enableRdp = !empty(allowedPublicIp)
var configureDnsScript = loadTextContent('../scripts/Configure-WindowsDns.ps1')

// -----------------------------------------------------------------------------
// Optional public IP + NSG rule for direct RDP to the Windows DNS server.
// -----------------------------------------------------------------------------
module rdpPublicIp 'br/public:avm/res/network/public-ip-address:0.12.0' = if (enableRdp) {
  name: 'pip-windns'
  params: {
    name: 'pip-${prefix}-windns'
    location: location
    tags: tags
    skuName: 'Standard'
    publicIPAllocationMethod: 'Static'
  }
}

module nsgRdp 'br/public:avm/res/network/network-security-group:0.5.3' = if (enableRdp) {
  name: 'nsg-windns-rdp'
  params: {
    name: 'nsg-${prefix}-windns-rdp'
    location: location
    tags: tags
    securityRules: [
      {
        name: 'AllowRdpFromAdmin'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedPublicIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Windows DNS server VM (10.1.1.4 — first non-reserved address in /24)
// -----------------------------------------------------------------------------
module vmDnsServer 'br/public:avm/res/compute/virtual-machine:0.22.2' = {
  name: 'vm-dns-server'
  params: {
    name: 'vm-${prefix}-dns'
    location: location
    tags: tags
    vmSize: 'Standard_D2s_v5'
    osType: 'Windows'
    adminUsername: adminUsername
    adminPassword: adminPassword
    zone: 0
    encryptionAtHost: false
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    osDisk: {
      caching: 'ReadWrite'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    nicConfigurations: [
      {
        name: 'nic-${prefix}-dns'
        nicSuffix: ''
        networkSecurityGroupResourceId: enableRdp ? nsgRdp.outputs.resourceId : null
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: onpremSubnetId
            privateIPAllocationMethod: 'Static'
            privateIPAddress: '10.1.1.4'
            pipConfiguration: enableRdp ? {
              publicIPAddressResourceId: rdpPublicIp.outputs.resourceId
            } : null
          }
        ]
      }
    ]
    extensionCustomScriptConfig: {
      enabled: true
      fileData: []
    }
    extensionCustomScriptProtectedSetting: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "${replace(replace(configureDnsScript, '\r\n', '; '), '"', '\\"')}" -InboundEndpointIp ${inboundEndpointIp} -OnpremDnsDomain ${onpremDnsDomain} -OnpremDnsRecordName ${onpremDnsRecordName} -OnpremDnsRecordIp 10.1.1.4'
    }
  }
}

// -----------------------------------------------------------------------------
// Ubuntu on-prem client (uses Windows DNS as nameserver)
// -----------------------------------------------------------------------------
module vmOnpremClient 'br/public:avm/res/compute/virtual-machine:0.22.2' = {
  name: 'vm-onprem-client'
  params: {
    name: 'vm-${prefix}-onprem-client'
    location: location
    tags: tags
    vmSize: 'Standard_B2s'
    osType: 'Linux'
    adminUsername: adminUsername
    adminPassword: adminPassword
    disablePasswordAuthentication: false
    zone: 0
    encryptionAtHost: false
    imageReference: {
      publisher: 'Canonical'
      offer: 'ubuntu-24_04-lts'
      sku: 'server'
      version: 'latest'
    }
    osDisk: {
      caching: 'ReadWrite'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    nicConfigurations: [
      {
        name: 'nic-${prefix}-onprem-client'
        nicSuffix: ''
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: onpremSubnetId
          }
        ]
        dnsServers: [
          '10.1.1.4'
        ]
      }
    ]
  }
}

@description('Public IP attached to the Windows DNS server (empty if RDP is disabled).')
output windowsDnsServerPublicIp string = enableRdp ? rdpPublicIp.outputs.ipAddress : ''
