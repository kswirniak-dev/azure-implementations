#!/bin/bash
set -e
RG="rg-lab03-network"
az group create -n $RG -l polandcentral --tags environment=dev project=az104-portfolio
read -s -p "Haslo admina NVA: " PASS; echo
az deployment group create -g $RG --template-file main.bicep --parameters adminPassword="$PASS"
