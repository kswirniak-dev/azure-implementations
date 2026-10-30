// Lab 04 - VMSS + Load Balancer, availability zones, autoscale
param location string = resourceGroup().location
param adminUsername string = 'azureadmin'
@secure()
param adminPassword string

var tags = { environment: 'dev', project: 'az104-portfolio' }
var cloudInit = base64('''
#cloud-config
packages:
  - nginx
runcmd:
  - echo "<h1>Serwer $(hostname)</h1>" > /var/www/html/index.html
  - systemctl restart nginx
''')

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-lab04'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ '10.4.0.0/16' ] }
    subnets: [ {
      name: 'snet-vmss'
      properties: {
        addressPrefix: '10.4.1.0/24'
        networkSecurityGroup: { id: nsg.id }
      }
    } ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-lab04'
  location: location
  properties: {
    securityRules: [ {
      name: 'Allow-HTTP'
      properties: {
        priority: 100
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourceAddressPrefix: 'Internet'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '80'
      }
    } ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'pip-lb-lab04'
  location: location
  sku: { name: 'Standard' }
  zones: [ '1', '2', '3' ]
  properties: { publicIPAllocationMethod: 'Static' }
}

resource lb 'Microsoft.Network/loadBalancers@2024-01-01' = {
  name: 'lb-lab04'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    frontendIPConfigurations: [ {
      name: 'fe-public'
      properties: { publicIPAddress: { id: pip.id } }
    } ]
    backendAddressPools: [ { name: 'be-vmss' } ]
    probes: [ {
      name: 'probe-http'
      properties: { protocol: 'Http', port: 80, requestPath: '/', intervalInSeconds: 5, numberOfProbes: 2 }
    } ]
    loadBalancingRules: [ {
      name: 'rule-http'
      properties: {
        frontendIPConfiguration: { id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-lab04', 'fe-public') }
        backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-lab04', 'be-vmss') }
        probe: { id: resourceId('Microsoft.Network/loadBalancers/probes', 'lb-lab04', 'probe-http') }
        protocol: 'Tcp'
        frontendPort: 80
        backendPort: 80
      }
    } ]
  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-07-01' = {
  name: 'vmss-lab04'
  location: location
  tags: tags
  sku: { name: 'Standard_B1s', capacity: 2 }
  zones: [ '1', '2', '3' ]
  properties: {
    orchestrationMode: 'Uniform'
    upgradePolicy: { mode: 'Automatic' }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: 'web'
        adminUsername: adminUsername
        adminPassword: adminPassword
        customData: cloudInit
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
      networkProfile: {
        networkInterfaceConfigurations: [ {
          name: 'nic-vmss'
          properties: {
            primary: true
            ipConfigurations: [ {
              name: 'ipconfig1'
              properties: {
                subnet: { id: vnet.properties.subnets[0].id }
                loadBalancerBackendAddressPools: [ {
                  id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-lab04', 'be-vmss')
                } ]
              }
            } ]
          }
        } ]
      }
    }
  }
  dependsOn: [ lb ]
}

resource autoscale 'Microsoft.Insights/autoscaleSettings@2022-10-01' = {
  name: 'autoscale-vmss-lab04'
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceUri: vmss.id
    profiles: [ {
      name: 'cpu-based'
      capacity: { minimum: '2', maximum: '4', default: '2' }
      rules: [
        {
          metricTrigger: {
            metricName: 'Percentage CPU'
            metricResourceUri: vmss.id
            timeGrain: 'PT1M'
            statistic: 'Average'
            timeWindow: 'PT5M'
            timeAggregation: 'Average'
            operator: 'GreaterThan'
            threshold: 70
          }
          scaleAction: { direction: 'Increase', type: 'ChangeCount', value: '1', cooldown: 'PT5M' }
        }
        {
          metricTrigger: {
            metricName: 'Percentage CPU'
            metricResourceUri: vmss.id
            timeGrain: 'PT1M'
            statistic: 'Average'
            timeWindow: 'PT10M'
            timeAggregation: 'Average'
            operator: 'LessThan'
            threshold: 25
          }
          scaleAction: { direction: 'Decrease', type: 'ChangeCount', value: '1', cooldown: 'PT10M' }
        }
      ]
    } ]
  }
}

output publicIp string = pip.properties.ipAddress
