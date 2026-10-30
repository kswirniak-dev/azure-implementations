# Lab 04 – Compute z wysoką dostępnością

## Cel
Skalowalny, strefowo odporny frontend HTTP: VM Scale Set rozłożony na 3 availability zones za Standard Load Balancerem, z autoskalowaniem na metryce CPU i konfiguracją przez cloud-init.

## Co wdraża
- VNet + NSG (HTTP z internetu)
- Standard LB (zone-redundant public IP, health probe HTTP, reguła 80→80)
- VMSS 2× B1s, Ubuntu 24.04, zones 1-3, cloud-init instalujący nginx ze stroną pokazującą hostname
- Autoscale: 2-4 instancje, scale-out przy CPU > 70% (5 min), scale-in przy < 25% (10 min)

## Wdrożenie
```bash
./deploy.sh
```

## Weryfikacja
1. Otwórz `http://<publicIp>` kilkukrotnie — hostname w odpowiedzi zmienia się między instancjami (round-robin LB)
2. Test autoskalowania: `stress-ng --cpu 2` na instancji przez SSH → po ~5 min capacity rośnie do 3 (`az vmss list-instances`)
3. `az vmss show -n vmss-lab04 -g rg-lab04-compute --query zones` → rozkład strefowy

## Decyzje projektowe
- Uniform orchestration — prostszy dla labu; Flexible to naturalne rozszerzenie (mieszanie SKU)
- Standard LB zamiast Application Gateway — warstwa 4 wystarcza dla HTTP demo, App GW kosztuje ~10× więcej; WAF/L7 opisany jako wariant
- Cloud-init w `customData` zamiast VM extension — konfiguracja wypieka się przy starcie instancji, działa też przy scale-out
- Asymetryczne progi autoscale (70/25) i cooldowny — ochrona przed flappingiem

## Sprzątanie
```bash
az group delete -n rg-lab04-compute --yes --no-wait
```
