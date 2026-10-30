#!/bin/bash
set -e
RG="rg-lab04-compute"
az group create -n $RG -l polandcentral --tags environment=dev project=az104-portfolio
read -s -p "Haslo admina VMSS: " PASS; echo
az deployment group create -g $RG --template-file main.bicep --parameters adminPassword="$PASS" --query properties.outputs
