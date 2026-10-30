#!/bin/bash
set -e
RG="rg-network"
az group create -n $RG -l swedencentral --tags environment=dev project=az104-portfolio
read -s -p "NVA Admin Password" PASS; echo
az deployment group create -g $RG --template-file main.bicep --parameters adminPassword="$PASS"

