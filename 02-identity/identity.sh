#!/usr/bin/env bash
# 02 - Entra ID + RBAC + lab VM (CLI, identity objects live in Graph, not in ARM)
set -euo pipefail
export MSYS_NO_PATHCONV=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RG="rg-identity"
LOCATION="swedencentral"
TAGS=(environment=dev project=azure-exercise)

GROUP_NAME="SD-Operators"
GROUP_NICK="sd-operators"
USERS=(jan.kowalski anna.nowak)
# anna.nowak is deliberately left out of the group - control account for the negative test
GROUP_MEMBERS=(jan.kowalski)

ROLE_TEMPLATE="$SCRIPT_DIR/vm-operator-role.json"
ROLE_TEMPLATE_WIN="$(cygpath -m "$ROLE_TEMPLATE")"

VM_NAME="vm-02-01"
VM_SIZE="Standard_D2s_v3"
VM_IMAGE="Ubuntu2204"
ADMIN_USER="azureuser"
SHUTDOWN_TIME="2000"

# ---------- preflight ----------
command -v jq >/dev/null 2>&1 || {
  echo "!! jq is required (winget install jqlang.jq / apt install jq)" >&2; exit 1; }
[ -f "$ROLE_TEMPLATE_WIN" ] || {
  echo "!! role template not found: $ROLE_TEMPLATE_WIN" >&2; exit 1; }

TMP_PASSWORD="${LAB_TMP_PASSWORD:?ustaw najpierw: export LAB_TMP_PASSWORD=}"
ROLE_NAME=$(jq -er '.Name' "$ROLE_TEMPLATE_WIN")

SUB_ID=$(az account show --query id -o tsv)
DOMAIN=$(az rest --method get --url "https://graph.microsoft.com/v1.0/domains" \
  --query "value[?isDefault].id" -o tsv)
SCOPE="/subscriptions/$SUB_ID/resourceGroups/$RG"

echo ">> subscription: $SUB_ID"
echo ">> domain:       $DOMAIN"
echo ">> role:         $ROLE_NAME"

# ---------- 0. Resource group ----------
az group create -n "$RG" -l "$LOCATION" --tags "${TAGS[@]}" --output none

# ---------- 1. Test users ----------
for U in "${USERS[@]}"; do
  UPN="$U@$DOMAIN"
  if [ -z "$(az ad user list --filter "userPrincipalName eq '$UPN'" --query "[0].id" -o tsv)" ]; then
    az ad user create \
      --display-name "$U" \
      --user-principal-name "$UPN" \
      --password "$TMP_PASSWORD" \
      --force-change-password-next-sign-in true \
      --output none
    echo ">> user created: $UPN"
  else
    echo ">> user already exists: $UPN"
  fi
done

# ---------- 2. Group and membership ----------
GROUP_ID=$(az ad group list --display-name "$GROUP_NAME" --query "[0].id" -o tsv)
if [ -z "$GROUP_ID" ]; then
  GROUP_ID=$(az ad group create --display-name "$GROUP_NAME" --mail-nickname "$GROUP_NICK" \
    --query id -o tsv)
  echo ">> group created: $GROUP_NAME ($GROUP_ID)"
fi

for M in "${GROUP_MEMBERS[@]}"; do
  MEMBER_ID=$(az ad user show --id "$M@$DOMAIN" --query id -o tsv)
  if [ "$(az ad group member check --group "$GROUP_ID" --member-id "$MEMBER_ID" \
      --query value -o tsv)" != "true" ]; then
    az ad group member add --group "$GROUP_ID" --member-id "$MEMBER_ID" --output none
    echo ">> member added: $M"
  fi
done

# ---------- 3. Custom RBAC role ----------
# the definition lives in vm-operator-role.json; only AssignableScopes is filled in at runtime
if [ -z "$(az role definition list --name "$ROLE_NAME" --query "[0].id" -o tsv)" ]; then
  ROLE_FILE="$(mktemp)"
  ROLE_FILE_WIN="$(cygpath -m "$ROLE_FILE")"
  trap 'rm -f "$ROLE_FILE"' EXIT

  jq --arg scope "$SCOPE" '.AssignableScopes = [$scope]' \
     "$ROLE_TEMPLATE_WIN" > "$ROLE_FILE"

  az role definition create --role-definition "$ROLE_FILE_WIN" --output none
  echo ">> role created, awaiting propagation..."
  sleep 30
else
  echo ">> role already exists: $ROLE_NAME"
fi

# ---------- 4. Role assignment to group on RG scope (least privilege) ----------
EXISTING=$(az role assignment list --assignee "$GROUP_ID" --scope "$SCOPE" \
  --query "[?roleDefinitionName=='$ROLE_NAME'].id" -o tsv)
if [ -z "$EXISTING" ]; then
  az role assignment create \
    --assignee-object-id "$GROUP_ID" \
    --assignee-principal-type Group \
    --role "$ROLE_NAME" \
    --scope "$SCOPE" \
    --output none
  echo ">> role assigned to group $GROUP_NAME"
fi

# ---------- 5. Lab VM (target of the role above) ----------
if [ -z "$(az vm list -g "$RG" --query "[?name=='$VM_NAME'].id" -o tsv)" ]; then
  az vm create \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --name "$VM_NAME" \
    --image "$VM_IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USER" \
    --generate-ssh-keys \
    --public-ip-sku Standard \
    --nsg-rule NONE \
    --os-disk-delete-option Delete \
    --nic-delete-option Delete \
    --tags "${TAGS[@]}" \
    --output none \
    --storage-sku StandardSSD_LRS

  echo ">> VM created: $VM_NAME"
fi

# auto-shutdown: compute przestaje byc naliczany (dysk dalej tak)
az vm auto-shutdown -g "$RG" -n "$VM_NAME" --time "$SHUTDOWN_TIME" --output none

# ---------- 6. SSH tylko z biezacego IP (mobilny internet: uruchom ponownie po zmianie IP) ----------
MY_IP=$(curl -fsS https://ifconfig.me || true)
if ! [[ "$MY_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "!! cannot determine public IP - refusing to touch the SSH rule" >&2
  exit 1
fi

NSG_NAME="${VM_NAME}NSG"
RULE_NAME="allow-ssh-from-my-ip"

if [ -z "$(az network nsg rule list -g "$RG" --nsg-name "$NSG_NAME" \
    --query "[?name=='$RULE_NAME'].name" -o tsv)" ]; then
  az network nsg rule create \
    --resource-group "$RG" --nsg-name "$NSG_NAME" --name "$RULE_NAME" \
    --priority 100 --protocol Tcp --destination-port-ranges 22 \
    --source-address-prefixes "$MY_IP" --access Allow --output none
else
  az network nsg rule update \
    --resource-group "$RG" --nsg-name "$NSG_NAME" --name "$RULE_NAME" \
    --source-address-prefixes "$MY_IP" --output none
fi

PUBLIC_IP=$(az vm show -d -g "$RG" -n "$VM_NAME" --query publicIps -o tsv)

cat << EOF

Ready.
  SSH:            ssh ${ADMIN_USER}@${PUBLIC_IP}    (allowed IP: $MY_IP)
  without SSH:    az vm run-command invoke -g $RG -n $VM_NAME --command-id RunShellScript --scripts "uptime"
  Verification:   az role assignment list -g $RG -o table
EOF
