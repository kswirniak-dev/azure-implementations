# Lab 03 – hub-and-spoke network

## Goal

Topology hub-and-spoke with movement spoke→spoke enforced by central network appliance, segmentation NSG and private access to Storage via Private Endpoint.

## Architecture

```
            vnet-hub 10.0.0.0/16
           /  (NVA 10.0.1.4)  \
   peering/                    \peering
vnet-spoke1 10.1.0.0/16   vnet-spoke2 10.2.0.0/16
 (workload + NSG)          (data + Private Endpoint → Storage)
```

- bidirectional peering hub↔spoke with `allowForwardedTraffic`
- UDR on subnets of spokes: next hop `VirtualAppliance` (10.0.1.4)
- NVA: VM B1s with `enableIPForwarding` — substitute for Azure Firewall
- Storage with `publicNetworkAccess: Disabled`, access only via Private Endpoint + private DNS zone

## Implementation

```bash
./deploy.sh
```

## Verification

1. `az network vnet peering list -g rg-network --vnet-name vnet-hub -o table` → status `Connected`
2. With VM in spoke1: `nslookup <storage>.blob.core.windows.net` → private adress 10.2.1.x
3. Effective routes for NIC in spoke: `az network nic show-effective-route-table -g rg-network -n nic-spoke1 -o table` → routes through 10.0.1.4
4. Public access to BLOB `curl -v https://stlab033bahndx2loqis.blob.core.windows.net/?comp=list` → `403` / connection refused

## Project decisions

- NVA (VM with IP forwarding) instead of Azure Firewall — Firewall Standard us ~1,25 EUR/h, non-proportional for the goal of the example; architecture of routing is identical though
- Private DNS zone linked to hub — pattern of central DNS (in real environment spokes use DNS in the hub)
- NSG deny for direct traffic spoke→spoke — segmentation double enforced (routing + filtration)

## Cleanup

```bash
./clenup.sh
```
