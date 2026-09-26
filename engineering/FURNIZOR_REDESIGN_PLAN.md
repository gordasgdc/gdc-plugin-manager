# Furnizor — plan de redesign premium (Faza 5)

Stare: PROPUNERE, neimplementată. Prototip: canvas „GDC Furnizor — redesign premium”.
Bază: DESIGN_SYSTEM.md („Furnizor — aceeași identitate, altă UX”) + UI_ARCHITECTURE.md (straturi, componente din F3/F4).

## Principii
- Aceiași tokeni ca clientul; suprafețe OPACE (tabele, formulare, inspector); fără artwork mare, fără material pe tabele.
- Dens, bazat pe tabele: `Table` nativ + inspector lateral; `metadata`/`numeric` pentru date.
- Amber doar pe acțiunea principală a ecranului; distructivul mereu cu confirmare și `Palette.destructive`.
- Mediul (PRODUCȚIE/STAGING) vizibil permanent sus — păstrat din 1.52.5.

## Navigație (decizie de aprobat)
- **V1 (recomandat):** bara laterală pe 5 domenii — Catalog · Clienți & Licențe · Prețuri & Oferte · Interfața clientului · Întreținere;
  în Catalog, sub-listă „Tip de conținut” (13 tipuri) → un singur ecran listă + inspector în loc de 13 formulare separate.
- **V2:** domeniile ca segmente în bara de sus, bara laterală doar pentru tipul de conținut. Mai mult spațiu orizontal, dar
  mai puțin nativ pe macOS și cu un nivel de navigație ascuns la Clienți/Întreținere.

## Ecrane și fluxuri
1. **Catalog**: tabel (Nume, Tip, Versiune, Platformă, Susținere, Stare: Publicat/Staging/Programat/Ciornă) + inspector
   (câmpuri, fișier + SHA-256, platforme, validare live — inclusiv Regula 3) + bară de acțiuni (Șterge… · Salvează ciorna · Publică…).
2. **Publică în producție**: foaie cu pașii existenți (validare → staging verificat → tranzacție multi-repo), confirmare explicită.
   Aceleași mecanisme (PublishTransaction, jurnal, Reia/Curăță) — doar prezentarea se schimbă.
3. **Clienți & Licențe (CRM, Regula 15)**: tabel filtrabil pe produs, copiere pe câmp, export selecție, licențiere în masă;
   inspector cu licențele clientului, activitate, Revocă… / Editează durata / Licență nouă….
4. Prețuri & Oferte, Interfața clientului, Întreținere (Token-uri & Chei, Backup, Stocare): același tipar listă + inspector.

## Ordinea implementării (după aprobare; fiecare pas = commit, comportament identic)
1. Shell: `FurnizorSection` → domenii + sub-secțiuni; bara de mediu ca frate în VStack (Regula 24).
2. Componente comune Furnizor: `InspectorPanel`, `ActionBar`, `ConfirmDestructive`, `ValidationList` (pe tokeni).
3. Clienți (cel mai folosit, `SalesHistoryView` 644 linii) → tabel + inspector.
4. Catalog: un editor generic peste cele 13 formulare existente, câte un tip pe rând (Produse primul).
5. Publicare: foaia de confirmare peste fluxul existent.
6. Restul domeniilor; audit teme + capturi RO × Light/Dark (Furnizorul e doar RO).

## Riscuri
- Cele 13 formulare au câmpuri diferite: unificarea se face pe inspector comun cu secțiuni specifice, nu pe un formular unic.
- Nicio schimbare în PublishTransaction/GitOps/SecretRegistry — doar UI; testele existente (33 Furnizor) rămân poarta.
