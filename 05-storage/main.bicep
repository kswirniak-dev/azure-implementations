// Lab 05 - Storage: lifecycle, SAS policy, Azure Files, Recovery Services Vault + backup VM
param location string = resourceGroup().location

var tags = { environment: 'dev', project: 'az104-portfolio' }

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stlab05${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: { enabled: true, days: 7 }
    containerDeleteRetentionPolicy: { enabled: true, days: 7 }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'documents'
}

// Lifecycle: hot -> cool po 30 dniach, -> archive po 90, delete po 365
resource lifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    policy: {
      rules: [ {
        name: 'tier-and-expire'
        enabled: true
        type: 'Lifecycle'
        definition: {
          filters: { blobTypes: [ 'blockBlob' ], prefixMatch: [ 'documents/' ] }
          actions: {
            baseBlob: {
              tierToCool: { daysAfterModificationGreaterThan: 30 }
              tierToArchive: { daysAfterModificationGreaterThan: 90 }
              delete: { daysAfterModificationGreaterThan: 365 }
            }
          }
        }
      } ]
    }
  }
}

// Azure Files
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: 'shared-docs'
  properties: { shareQuota: 5 }
}

// Recovery Services Vault
resource rsv 'Microsoft.RecoveryServices/vaults@2024-04-01' = {
  name: 'rsv-lab05'
  location: location
  tags: tags
  sku: { name: 'RS0', tier: 'Standard' }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// Polityka backupu VM: codziennie 22:00, retencja 14 dni
resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2024-04-01' = {
  parent: rsv
  name: 'policy-daily-vm'
  properties: {
    backupManagementType: 'AzureIaasVM'
    policyType: 'V2'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicyV2'
      scheduleRunFrequency: 'Daily'
      dailySchedule: { scheduleRunTimes: [ '2026-01-01T22:00:00Z' ] }
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [ '2026-01-01T22:00:00Z' ]
        retentionDuration: { count: 14, durationType: 'Days' }
      }
    }
    timeZone: 'Central European Standard Time'
  }
}

output storageAccountName string = storage.name
output vaultName string = rsv.name
