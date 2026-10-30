# Lab 03 – Sieć hub-and-spoke

## Cel
Topologia hub-and-spoke z wymuszeniem ruchu spoke→spoke przez centralne urządzenie sieciowe, segmentacją NSG i prywatnym dostępem do Storage przez Private Endpoint.

## Architektura
```
            vnet-hub 10.0.0.0/16
           /  (NVA 10.0.1.4)  \
   peering/                    \peering
vnet-spoke1 10.1.0.0/16   vnet-spoke2 10.2.0.0/16
 (workload + NSG)          (data + Private Endpoint → Storage)
```
- Peering dwukierunkowy hub↔spoke z `allowForwardedTraffic`
- UDR na subnetach spoke'ów: next hop `VirtualAppliance` (10.0.1.4)
- NVA: VM B1s z `enableIPForwarding` — zamiennik Azure Firewall dla labu
- Storage z `publicNetworkAccess: Disabled`, dostęp wyłącznie przez Private Endpoint + prywatna strefa DNS

## Wdrożenie
```bash
./deploy.sh
```

## Weryfikacja
1. `az network vnet peering list -g rg-lab03-network --vnet-name vnet-hub -o table` → status `Connected`
2. Z VM w spoke1: `nslookup <storage>.blob.core.windows.net` → adres prywatny 10.2.1.x
3. Effective routes na NIC w spoke: `az network nic show-effective-route-table` → trasy przez 10.0.1.4
4. Publiczny dostęp do blob → `403` / connection refused

## Decyzje projektowe
- NVA (VM z IP forwarding) zamiast Azure Firewall — Firewall Standard to ~1,25 USD/h, nieproporcjonalny koszt do celu labu; architektura routingu identyczna
- Prywatna strefa DNS linkowana do hub — wzorzec centralnego DNS (w realnym środowisku spoke'i korzystają z DNS w hubie)
- NSG deny na ruch bezpośredni spoke→spoke — segmentacja wymuszona podwójnie (routing + filtracja)

## Sprzątanie
```bash
az group delete -n rg-lab03-network --yes --no-wait
```
