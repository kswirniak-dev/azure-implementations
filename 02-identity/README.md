# 02 – Identity & RBAC

## Goal

Identity management in Entra ID and a least-privilege model: a custom RBAC role assigned to a **group** instead of individual users, with `AssignableScopes` limited to a single resource group. A lab VM is deployed as the target object for that role.

## What the script does

- Resource group `rg-identity` in `swedencentral`, tagged `environment=dev`, `project=azure-exercise`
- Two test users (`jan.kowalski`, `anna.nowak`) in the tenant's default domain, with password change enforced at first sign-in
- Group `SD-Operators` created; only `jan.kowalski` is added as a member — `anna.nowak` stays outside the group on purpose, as a control account for the negative test
- Custom role `Custom VM Operator (lab02)` — read, start, restart, power off and deallocate a VM, plus read on NICs and the resource group; no write or configuration actions
- Role assigned to the group at RG scope
- Lab VM `vm-02-01` (Ubuntu 22.04, `Standard_D2s_v3`, StandardSSD_LRS), created with `--nsg-rule NONE`; OS disk and NIC are removed together with the VM
- Auto-shutdown at 20:00
- NSG rule `allow-ssh-from-my-ip` — port 22 reachable only from the machine's current public IP

Every step is idempotent: existing users, group, role, assignment and VM are detected and skipped, and the NSG rule is updated rather than recreated. On a mobile connection just re-run the script after the public IP changes — it will refresh the rule.

## Prerequisites

- Azure CLI signed in to the dev tenant, plus `jq`
- User Administrator in Entra ID + Owner or User Access Administrator on the subscription
- `LAB_TMP_PASSWORD` exported — the script aborts immediately if it is missing
- `vm-operator-role.json` next to the script — it holds the role definition and is the single source of truth for the role name

## Implementation

```bash
export LAB_TMP_PASSWORD='<temporary password>'
./identity.sh
```

The script prints the subscription id, the resolved default domain and the role name at the start, and finishes with the SSH command, the whitelisted IP and a `run-command` fallback for working without SSH.

The role definition is kept in the repository as a template; the script copies it to a temporary file and injects the concrete `AssignableScopes` (which contains the subscription id) at runtime. An already existing role is left untouched — to apply changes made to the template, run `cleanup.sh` first.

## Verification

1. `az role assignment list -g rg-identity -o table` — `SD-Operators` with `Custom VM Operator (lab02)`
2. Sign in to the portal as `jan.kowalski` — the RG and VM are visible and the VM can be restarted, but changing its size fails with `AuthorizationFailed`
3. Sign in as `anna.nowak` — the RG is not visible at all, since the role reaches her only through group membership she does not have
4. Portal → Entra ID → Groups → SD-Operators → Members
5. `ssh azureuser@<public ip>` — succeeds only from the IP recorded in the NSG rule

## Project decisions

- CLI instead of Bicep — only for the Entra ID part: users and groups live in Microsoft Graph, not in ARM, and Bicep would need the Microsoft Graph extensibility provider. The role definition and the assignment are ordinary ARM resources (`Microsoft.Authorization/*`) and could be written in Bicep; they stay in the CLI so the whole lab is one script with one order of execution
- Role definition in a separate JSON file, not inline in the script — it is diffable, reusable in a Bicep or pipeline version, and the script reads the role name from it so the two cannot drift apart
- Role assigned to a group, not to users — standard in real environments, simpler audit and offboarding
- `AssignableScopes` limited to one RG — the role cannot leak to the whole subscription
- 30 s sleep after creating the role definition — RBAC propagation, otherwise the assignment intermittently fails
- `--nsg-rule NONE` plus an explicit rule instead of the default "SSH from anywhere" that `az vm create` would add; if the public IP cannot be determined the script aborts rather than writing a rule with an empty source
- Auto-shutdown — stops compute billing; the disk is still charged

## Extensions (described, not scripted)

- Conditional Access and SSPR — require a P1/P2 licence, configured manually on the dev tenant
- PIM for the Owner role — requires P2

## Cleanup

```bash
./cleanup.sh
```

Deletes `rg-identity` and `NetworkWatcherRG` (created automatically by Azure together with the first VNet in the region), then any remaining assignments of the custom role, the role definition itself, the group and both test users. The `az group wait --deleted` calls matter here: assignments scoped to the RG disappear with it, and the definition can only be removed once nothing references it. The tenant domain is resolved from Graph, so the script survives a change of tenant.
