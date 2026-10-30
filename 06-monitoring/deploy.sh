#!/bin/bash
set -e
RG="rg-lab06-monitoring"
read -p "E-mail do alertow: " MAIL
az group create -n $RG -l polandcentral --tags environment=dev project=az104-portfolio

# Opcjonalnie: resource ID zasobu do alertu CPU (np. VMSS z lab-04)
VMSS_ID=$(az vmss show -n vmss-lab04 -g rg-lab04-compute --query id -o tsv 2>/dev/null || echo "")

az deployment group create -g $RG --template-file main.bicep \
  --parameters alertEmail="$MAIL" monitoredResourceId="$VMSS_ID"

# Diagnostic settings: przyklad podpiecia storage z lab-05 do workspace
LAW_ID=$(az monitor log-analytics workspace show -n law-lab06 -g $RG --query id -o tsv)
ST_ID=$(az storage account list -g rg-lab05-storage --query "[0].id" -o tsv 2>/dev/null || echo "")
if [ -n "$ST_ID" ]; then
  az monitor diagnostic-settings create --name diag-to-law \
    --resource "$ST_ID/blobServices/default" --workspace "$LAW_ID" \
    --logs '[{"categoryGroup":"allLogs","enabled":true}]' \
    --metrics '[{"category":"Transaction","enabled":true}]'
fi
