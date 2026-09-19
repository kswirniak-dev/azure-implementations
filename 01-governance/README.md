# 01 – Governance

## Goal

Foundaiton of subscription management: resource groups with naming convention and tags, Azure Policy enforcing standards and lock securing shared rules.

## What is achieved

- 2 resource gropus (`workload`, `shared`) with tags `environment`, `project`, `owner`
- Policy: rquired tag `environment` na on reources (deny)
- Policy: allowed regions limited to Poland Central and West Europe
- Lock `CanNotDelete` on RG shared

## Implementation

```bash
./deploy.sh
```

## Verification

1. `az policy assignment list -o table` — both policies visible
2. Attempt to create RG without tag 'environment' → error `RequestDisallowedByPolicy`
3. `az group delete -n rg-lab01-shared-dev` → blocked by lock

## Project decisions

- Policy on subscription level (`targetScope = 'subscription'`) — simulation of real governance instead of single RG
- Built-in policy instead of custom definition — quicker implementation
- Lock in separate module, for locks are implementend in scope of RG, whereas main template works in subscription scope

## Cleanup

```bash
az lock delete -n lock-no-delete -g rg-lab01-shared-dev
az group delete -n rg-lab01-workload-dev --yes --no-wait
az group delete -n rg-lab01-shared-dev --yes --no-wait
az policy assignment delete -n require-env-tag
az policy assignment delete -n allowed-locations
```
