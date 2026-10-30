# Lab 05 – Storage i backup

## Cel
Zarządzanie cyklem życia danych (tiering hot→cool→archive), kontrolowany dostęp przez SAS ze stored access policy, udział Azure Files oraz backup VM z **testem restore** — element, który w portfolio odróżnia od tutoriali.

## Co wdraża
- Storage account (StorageV2, LRS, soft delete 7 dni, brak publicznego dostępu do blobów)
- Lifecycle policy: cool po 30 dniach, archive po 90, delete po 365 (prefix `documents/`)
- Azure Files share 5 GiB
- Recovery Services Vault + polityka backupu VM (codziennie 22:00 CET, retencja 14 dni)
- Skrypt: stored access policy `read-30d` i SAS wygenerowany z tej polityki

## Wdrożenie
```bash
./deploy.sh
```

## Weryfikacja i test restore
1. Wgraj blob do `documents/`, pobierz przez SAS z outputu → działa; usuń stored access policy → ten sam SAS przestaje działać (to jest cała wartość policy nad ad-hoc SAS)
2. Podepnij VM z lab-04 pod backup (odkomentuj linię w deploy.sh), uruchom backup on-demand: `az backup protection backup-now`
3. **Test restore**: przywróć dysk do nowej RG (`az backup restore restore-disks`), zamontuj i zweryfikuj dane — udokumentuj screenami. Backup bez przetestowanego restore to tylko nadzieja.
4. Zamontuj Azure Files w Windows/Linux (skrypt z portalu) i sprawdź zapis

## Decyzje projektowe
- SAS ze stored access policy zamiast ad-hoc — odwoływalność bez rotacji kluczy konta
- Soft delete włączony — ochrona przed przypadkowym `az storage blob delete`
- Polityka backupu V2 (Enhanced) — wspiera częstsze punkty przywracania i strefy
- LRS zamiast GRS — koszt; w README opisuję kiedy GRS/RA-GZRS ma sens (RPO/RTO)

## Sprzątanie
Vault z aktywnym backupem wymaga najpierw wyłączenia ochrony:
```bash
az backup protection disable --vault-name rsv-lab05 -g rg-lab05-storage \
  --container-name <container> --item-name <vm> --delete-backup-data true --yes
az group delete -n rg-lab05-storage --yes --no-wait
```
