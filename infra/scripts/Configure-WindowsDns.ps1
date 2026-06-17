# Configure-WindowsDns.ps1
# Custom Script Extension payload for the Windows DNS server VM.
# Installs the DNS Server role, sets up a conditional forwarder for
# privatelink.blob.core.windows.net pointing at the resolver inbound endpoint,
# and creates a primary zone with a single A record for the on-prem domain.
#
# Parameters are passed via the CSE settings.protectedSettings.commandToExecute.

param(
    [Parameter(Mandatory = $true)] [string] $InboundEndpointIp,
    [Parameter(Mandatory = $true)] [string] $OnpremDnsDomain,
    [Parameter(Mandatory = $true)] [string] $OnpremDnsRecordName,
    [Parameter(Mandatory = $true)] [string] $OnpremDnsRecordIp
)

$ErrorActionPreference = 'Stop'

Write-Output "Installing DNS Server role..."
Install-WindowsFeature -Name DNS -IncludeManagementTools | Out-Null

Write-Output "Adding conditional forwarder for privatelink.blob.core.windows.net -> $InboundEndpointIp"
if (Get-DnsServerZone -Name 'privatelink.blob.core.windows.net' -ErrorAction SilentlyContinue) {
    Remove-DnsServerZone -Name 'privatelink.blob.core.windows.net' -Force
}
Add-DnsServerConditionalForwarderZone `
    -Name 'privatelink.blob.core.windows.net' `
    -MasterServers $InboundEndpointIp `
    -ReplicationScope 'None'

Write-Output "Creating primary zone for $OnpremDnsDomain"
if (Get-DnsServerZone -Name $OnpremDnsDomain -ErrorAction SilentlyContinue) {
    Remove-DnsServerZone -Name $OnpremDnsDomain -Force
}
Add-DnsServerPrimaryZone -Name $OnpremDnsDomain -ZoneFile "$OnpremDnsDomain.dns" -DynamicUpdate None

Write-Output "Adding A record $OnpremDnsRecordName.$OnpremDnsDomain -> $OnpremDnsRecordIp"
Add-DnsServerResourceRecordA `
    -ZoneName $OnpremDnsDomain `
    -Name $OnpremDnsRecordName `
    -IPv4Address $OnpremDnsRecordIp `
    -TimeToLive 00:01:00

Write-Output "DNS server configuration complete."
