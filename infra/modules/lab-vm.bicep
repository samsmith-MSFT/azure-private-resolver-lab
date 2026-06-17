// =============================================================================
// modules/lab-vm.bicep — Ubuntu lab VM for Demo 3 (DNS Security Policy)
//
// Lives in the lab VNet. No public IP — access via serial console only.
// Used to run dig/nslookup against the DNS Security Policy linked to its VNet.
// =============================================================================

@description('Azure region.')
param location string

@description('Resource name prefix.')
param prefix string

@description('Tags applied to every resource.')
param tags object

@description('Subnet resource ID for the lab VM.')
param labSubnetId string

@description('Admin username.')
param adminUsername string

@description('Admin password.')
@secure()
param adminPassword string

module vmLab 'br/public:avm/res/compute/virtual-machine:0.22.2' = {
  name: 'vm-ubuntu-lab'
  params: {
    name: 'vm-${prefix}-ubuntu-lab'
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
        name: 'nic-${prefix}-ubuntu-lab'
        nicSuffix: ''
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: labSubnetId
          }
        ]
      }
    ]
  }
}

output vmId string = vmLab.outputs.resourceId
output vmName string = vmLab.outputs.name
