#!/usr/bin/env bash
# 02 - cleanup: RG, custom role + assignments, group, test users
set -euo pipefail
export MSYS_NO_PATHCONV=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RG="rg-identity"
GROUP_NAME="SD-Operators"
USERS=(jan.kowalski anna.nowak)
ROLE_TEMPLATE="$SCRIPT_DIR/vm-operator-role.json"
ROLE_TEMPLATE_WIN="$(cygpath -m "$ROLE_TEMPLATE")"

command -v jq >/dev/null 2>&1 || {
  echo "!! jq is required (winget install jqlang.jq / apt install jq)" >&2; exit 1; }
[ -f "$ROLE_TEMPLATE_WIN" ] || {
  echo "!! role template not found: $ROLE_TEMPLATE_WIN" >&2; exit 1; }

ROLE_NAME=$(jq -er '.Name' "$ROLE_TEMPLATE_WIN")
DOMAIN=$(az rest --method get --url "https://graph.microsoft.com/v1.0/domains" \
  --query "value[?isDefault].id" -o tsv)

echo ">> domain: $DOMAIN"
echo ">> role:   $ROLE_NAME"

# ---------- 1. Resource groups ----------
# NetworkWatcherRG is created by Azure together with the first VNet in the region
for G in "$RG" NetworkWatcherRG; do
  if [ "$(az group exists -n "$G")" = "true" ]; then
    az group delete -n "$G" --yes
    az group wait --name "$G" --deleted
    echo ">> RG deleted: $G"
  else
    echo ">> RG not found, skipping: $G"
  fi
done

# ---------- 2. Leftover assignments of the custom role ----------
# assignments scoped to the RG go away with it; this catches anything else
az role assignment list --all --query "[?roleDefinitionName=='$ROLE_NAME'].id" -o tsv \
| while read -r ID; do
    echo ">> deleting assignment: $ID"
    az role assignment delete --ids "$ID"
  done

# ---------- 3. Role definition ----------
if [ -n "$(az role definition list --name "$ROLE_NAME" --query "[0].id" -o tsv)" ]; then
  az role definition delete --name "$ROLE_NAME"
  echo ">> role definition deleted: $ROLE_NAME"
fi

# ---------- 4. Group ----------
GROUP_ID=$(az ad group list --display-name "$GROUP_NAME" --query "[0].id" -o tsv)
if [ -n "$GROUP_ID" ]; then
  az ad group delete --group "$GROUP_ID"
  echo ">> group deleted: $GROUP_NAME"
fi

# ---------- 5. Test users ----------
for U in "${USERS[@]}"; do
  UPN="$U@$DOMAIN"
  if [ -n "$(az ad user list --filter "userPrincipalName eq '$UPN'" --query "[0].id" -o tsv)" ]; then
    az ad user delete --id "$UPN"
    echo ">> user deleted: $UPN"
  else
    echo ">> user not found, skipping: $UPN"
  fi
done

echo ">> cleanup done"
