using 'main.bicep'

// Lab defaults. Override at deploy time:
//   az deployment sub create -l eastus2 \
//     --template-file infra/main.bicep --parameters infra/main.bicepparam \
//     --parameters adminPassword='<your-strong-password>' \
//     --parameters allowedPublicIp='203.0.113.50'

param location = 'eastus2'
param prefix = 'dnslab'
param resourceGroupName = 'rg-dnslab'
param adminUsername = 'azureuser'

// REQUIRED at deploy time. Never hard-code here.
param adminPassword = readEnvironmentVariable('ADMIN_PASSWORD', '')

// On-prem domain for Demo 2.
param onpremDnsDomain = 'contoso.com'
param onpremDnsRecordName = 'dns'

// Demo 3 block list. Trailing dot is required.
param blockedDomains = [
  'malicious.contoso.com.'
  'exploit.adatum.com.'
]

// Set to your public IP (e.g. '203.0.113.50') to enable direct RDP to the Windows DNS server.
// Leave empty to use serial console only.
param allowedPublicIp = ''

param tags = {
  workload: 'dns-resolver-lab'
  env: 'lab'
}
