#!/bin/bash
set -e
RG="rg-lab05-storage"
az group create -n $RG -l polandcentral --tags environment=dev project=az104-portfolio
az deployment group create -g $RG --template-file main.bicep --query properties.outputs

ST=$(az storage account list -g $RG --query "[0].name" -o tsv)

# Stored access policy + SAS na jej podstawie (odwolywalny)
az storage container policy create --container-name documents --name read-30d \
  --account-name $ST --permissions r \
  --expiry $(date -u -d "+30 days" +%Y-%m-%dT%H:%MZ) --auth-mode login 2>/dev/null || \
az storage container policy create --container-name documents --name read-30d \
  --account-name $ST --permissions r \
  --expiry $(date -u -v+30d +%Y-%m-%dT%H:%MZ)

echo "SAS z polityki:"
az storage container generate-sas --name documents --policy-name read-30d \
  --account-name $ST -o tsv

# Wlaczenie backupu istniejacej VM (podaj nazwe i RG swojej VM):
# az backup protection enable-for-vm --vault-name rsv-lab05 -g $RG \
#   --vm <vm-name> --policy-name policy-daily-vm
