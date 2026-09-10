#!/bin/bash
set -e
az deployment sub create \
  --name lab01-governance \
  --location polandcentral \
  --template-file main.bicep

echo "Test policy (expected error RequestDisallowedByPolicy):"
az storage account create -n testnotag$RANDOM -g rg-lab01-workload-dev -l polandcentral --sku Standard_LRS || true
