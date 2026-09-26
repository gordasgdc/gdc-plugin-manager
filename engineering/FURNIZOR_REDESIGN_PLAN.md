# Furnizor — plan de redesign premium (Faza 5)

Stare: V1 APROBAT 2026-09-26; lotul 1 implementat pe ramura `furnizor-faza5` (vezi „Progres”). Prototip: canvas „GDC Furnizor — redesign premium”.
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

## Progres (2026-09-26, ramura `furnizor-faza5`, neîmpinsă, neinstalată)
- FĂCUT: 5 domenii în bara laterală (Prețuri & Oferte separat, cu Banner Lansare); `Workspace/CatalogWorkspace.swift` — pentru
  toate cele 13 tipuri: `Table` nativ (sortat alfabetic, căutare în bara de unelte, stare Publicat/Programat) + editorul EXISTENT
  în `.inspector` redimensionabil (420–820). Legătura: `workspaceSelection` în fiecare editor (rând → `load`/`fillFromExisting`,
  „+ Nou” → `clearForm`); editorii anunță reîncărcarea prin `.furnizorCatalogChanged`. Publicarea/Git/licențierea neatinse.
- Clienți: `ClientDetailView` în inspector lângă tabel (nu mai e foaie); fereastră minimă 1040×600.
- Verificare: build + teste; capturi DEBUG `scripts/furnizor-snapshots.sh` (Dark/Light, 1280×800 și 1040×600, rând preselectat).
  Rularea de previzualizare pornește blocată la scriere (confirmarea PRODUCȚIE după STAGING rămâne neconfirmată).
- RĂMAS: editorii își păstrează încă propria listă internă (dublură cu tabelul) — de scos tip cu tip; `InspectorPanel`/`ActionBar`
  comune; foaia „Publică în producție” din prototip peste fluxul existent; Prețuri/Întreținere pe tiparul listă + inspector.

## Modul „Bannere promoționale” (propus; prototip pe canvas, NEimplementat)
- Moduri: Doar text · Imagine + text · Doar imagine. Texte RO (obligatoriu) / EN / ES. Imagini separate Light/Dark (Dark opțional).
- PNG și SVG; SVG se rasterizează la publicare în PNG @2x (ImageIO nu randează `<text>` din SVG — vezi preseturile sezoniere),
  sursa SVG se păstrează. Recomandat 1200×200, < 400 KB.
- Campanii programate (listă, ca `promoSchedule` din pricing.json): Black Friday, Crăciun etc.; una activă la un moment dat.
- Previzualizare în editor: lat/îngust (1440/760) și Light/Dark, cu randarea reală a bannerului din client.
- Compatibilitate `launch-banner.json`: câmpurile vechi (`enabled`, `topText`, `mainText`, `imagePath`, `textOnTop`, `scheduling`)
  rămân și sunt scrise mereu din campania activă ca rezervă (clienții ≤ 1.40 văd textul RO); câmpuri noi opționale
  (`mode`, `campaigns[]`, `imageDark`, texte localizate). „Doar imagine” = invizibil pe clienții vechi (isDisplayable cere text).
- Conținutul actual din producție („PREȚURI SPECIALE…”) NU se modifică în acest lot; încalcă Regula 3 — decizia rămâne la Cristi.
