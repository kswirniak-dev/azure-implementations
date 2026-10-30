# Lab 06 – Monitoring i alerty

## Cel
Centralny monitoring: Log Analytics workspace zbierający diagnostykę z zasobów pozostałych labów, zapytania KQL i alerty (metryczny + activity log) z powiadomieniem mailowym.

## Co wdraża
- Log Analytics workspace (PerGB2018, retencja 30 dni)
- Action group z odbiorcą e-mail (common alert schema)
- Alert metryczny: CPU > 80% przez 5 min na VMSS z lab-04 (jeśli istnieje)
- Activity log alert: usunięcie dowolnej resource groupy w subskrypcji
- Skrypt podpina diagnostic settings storage'a z lab-05 do workspace
- `queries.kql` — 4 zapytania: heartbeat, CPU timechart, nieudane logowania SSH, operacje administracyjne

## Wdrożenie
```bash
./deploy.sh
```

## Weryfikacja
1. Usuń testową RG → w ciągu kilku minut mail z alertu `alert-rg-delete`
2. `stress-ng` na VMSS → alert CPU (severity 2) + wpis w Alerts w portalu
3. Logs → wklej zapytania z `queries.kql`; timechart CPU renderuje się po podpięciu Azure Monitor Agent (DCR opisany niżej)
4. Storage z lab-05: wygeneruj ruch na blobie → `StorageBlobLogs` w workspace

## Decyzje projektowe
- Jeden workspace dla wszystkich labów — wzorzec centralnego logowania; per-RG workspace'y utrudniają korelację
- Common alert schema w action group — jednolity format payloadu, gotowy pod webhook/Logic App
- Activity log alert na delete RG — praktyczny "wire trip" na przypadkowe usunięcia, zero kosztu
- Perf/Syslog wymagają Azure Monitor Agent + Data Collection Rule — celowo osobny krok (portal lub `az monitor data-collection rule create`), bo DCR to materiał, o który pytają na AZ-104

## Sprzątanie
```bash
az group delete -n rg-lab06-monitoring --yes --no-wait
```
