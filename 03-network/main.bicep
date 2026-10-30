// Lab 03 - Hub-and-spoke: peering, NSG, UDR, Private Endpoint do Storage
param location string = resourceGroup().location
param adminUsername string = 'azureadmin'
@secure()
param adminPassword string

var tags = { environment: 'dev', project: 'az104-portfolio' }

// ===== HUB =====
resource hubVnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-hub'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      { name: 'snet-nva', properties: { addressPrefix: '10.0.1.0/24' } }
      { name: 'snet-mgmt', properties: { addressPrefix: '10.0.2.0/24' } }
    ]
  }
}

// NVA: small VM with IP forwarding instead of Azure Firewall (koszt!)
resource nvaNic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: 'nic-nva'
  location: location
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: hubVnet.properties.subnets[0].id }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.4'
        }
      }
    ]
  }
}

resource nvaVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-nva'
  location: location
  tags: tags
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2s_v3' }
    osProfile: {
      computerName: 'vm-nva'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: { disablePasswordAuthentication: false }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' } }
    }
    networkProfile: { networkInterfaces: [{ id: nvaNic.id }] }
  }
}

// ===== SPOKES =====
resource spoke1Vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-spoke1'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.1.0.0/16'] }
    subnets: [
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: '10.1.1.0/24'
          networkSecurityGroup: { id: nsgWorkload.id }
          routeTable: { id: rtSpokes.id }
        }
      }
    ]
  }
}
resource pipSpoke1 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'pip-spoke1'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource spoke1Nic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: 'nic-spoke1'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: spoke1Vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipSpoke1.id
          }
        }
      }
    ]
  }
}

resource spoke1Vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-spoke1'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'vm-spoke1'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: spoke1Nic.id
        }
      ]
    }
  }
}

resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-spoke2'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.2.0.0/16'] }
    subnets: [
      {
        name: 'snet-data'
        properties: {
          addressPrefix: '10.2.1.0/24'
          routeTable: { id: rtSpokes.id }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource pipSpoke2 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'pip-spoke2'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource spoke2Nic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: 'nic-spoke2'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: spoke2Vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipSpoke2.id
          }
        }
      }
    ]
  }
}

resource spoke2Vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-spoke2'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'vm-spoke2'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: spoke2Nic.id
        }
      ]
    }
  }
}

// ===== PEERING (bidirectional hub<->spoke1, hub<->spoke2) =====
resource peerHubSpoke1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  parent: hubVnet
  name: 'peer-hub-to-spoke1'
  properties: {
    remoteVirtualNetwork: { id: spoke1Vnet.id }
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
  }
}
resource peerSpoke1Hub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  parent: spoke1Vnet
  name: 'peer-spoke1-to-hub'
  properties: {
    remoteVirtualNetwork: { id: hubVnet.id }
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
  }
}
resource peerHubSpoke2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  parent: hubVnet
  name: 'peer-hub-to-spoke2'
  properties: {
    remoteVirtualNetwork: { id: spoke2Vnet.id }
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
  }
}
resource peerSpoke2Hub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  parent: spoke2Vnet
  name: 'peer-spoke2-to-hub'
  properties: {
    remoteVirtualNetwork: { id: hubVnet.id }
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
  }
}

// ===== NSG =====
resource nsgWorkload 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-workload'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-Mgmt'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.0.2.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-SSH-Internet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Deny-Spoke-To-Spoke-Direct'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '10.2.0.0/16'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ===== UDR: traffic spoke->spoke via NVA in hub =====
resource rtSpokes 'Microsoft.Network/routeTables@2024-01-01' = {
  name: 'rt-spokes-via-hub'
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: 'to-spoke1-via-nva'
        properties: {
          addressPrefix: '10.1.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.1.4'
        }
      }
      {
        name: 'to-spoke2-via-nva'
        properties: {
          addressPrefix: '10.2.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.1.4'
        }
      }
    ]
  }
}

// ===== STORAGE + PRIVATE ENDPOINT in spoke2 =====
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stlab03${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pe-storage-blob'
  location: location
  tags: tags
  properties: {
    subnet: { id: spoke2Vnet.properties.subnets[0].id }
    privateLinkServiceConnections: [
      {
        name: 'plsc-blob'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
}

resource dnsLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'link-hub'
  location: 'global'
  properties: {
    virtualNetwork: { id: hubVnet.id }
    registrationEnabled: false
  }
}

resource dnsLinkSpoke1 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'link-spoke1'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spoke1Vnet.id
    }
    registrationEnabled: false
  }
}
resource dnsLinkSpoke2 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'link-spoke2'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spoke2Vnet.id
    }
    registrationEnabled: false
  }
}

resource peDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-config'
        properties: { privateDnsZoneId: privateDnsZone.id }
      }
    ]
  }
}

output storageAccountName string = storage.name
