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
- Lot 2: listele proprii ale editorilor ascunse în spațiul de lucru (`embedded`), ștergerea intrării selectate păstrată cu aceeași
  confirmare; la Produse rămân „Șterge acest produs” și ștergerea multiplă. Foaia „Publică în producție/staging”
  (`Workspace/PublishConfirmation.swift`, `PublishGate` prin environment) peste `publish()` existent — în PRODUCȚIE cere bifa explicită.
- Lot 3: Prețuri & Oferte (tabel produse: sumă de bază, ofertă activă, următoarea + editorul existent în inspector), Token-uri & Chei
  (tabel secrete, detalii/reînnoire în inspector, valorile niciodată afișate), Stocare pe repo-uri (grafic + tabel, detalii/duplicate
  în inspector), Backup (componente în tabel cu bifă, parolă + export/restaurare în inspector). V1 COMPLET pe toate cele 5 domenii.
- Rămas opțional: captura foii de publicare în PRODUCȚIE (alerta STAGING→PRODUCȚIE are prioritate pe Mac-ul de dezvoltare).

## Modul „Bannere promoționale” — IMPLEMENTAT pe ramură (2026-09-26), nepublicat
- Moduri: Doar text · Imagine + text · Doar imagine. Texte RO (obligatoriu) / EN / ES. Imagini separate Light/Dark (Dark opțional).
- PNG și SVG; SVG se rasterizează la publicare în PNG @2x (ImageIO nu randează `<text>` din SVG — vezi preseturile sezoniere),
  sursa SVG se păstrează. Recomandat 1200×200, < 400 KB.
- Campanii programate (listă, ca `promoSchedule` din pricing.json): Black Friday, Crăciun etc.; una activă la un moment dat.
- Previzualizare în editor: lat/îngust (1440/760) și Light/Dark, cu randarea reală a bannerului din client.
- Compatibilitate `launch-banner.json`: câmpurile vechi (`enabled`, `topText`, `mainText`, `imagePath`, `textOnTop`, `scheduling`)
  rămân și sunt scrise mereu din campania activă ca rezervă (clienții ≤ 1.40 văd textul RO); câmpuri noi opționale
  (`mode`, `campaigns[]`, `imageDark`, texte localizate). „Doar imagine” = invizibil pe clienții vechi (isDisplayable cere text).
- Conținutul actual din producție („PREȚURI SPECIALE…”) NU se modifică în acest lot; încalcă Regula 3 — decizia rămâne la Cristi.

### Implementare (lot 2)
- Core: `PromoBanner.swift` (model, `PromoBannerSpec`, `activeCampaign`, suprapuneri, `withLegacyFallback`, `PromoBannerView` comun
  client + previzualizare Furnizor). `campaigns` decodat tolerant — o listă stricată nu ascunde bannerul clasic.
- Rapoarte: Doar imagine 6:1 (1200×200), opțional lată 12:1 (2400×200) de la 900 pt, afișare `fit` (integral vizibilă),
  înălțime plafonată la 160 pt; Imagine + text 3:1 (600×200), `fill` cu decupare centrală într-un panou de 72 pt; Doar text 56 pt.
- Furnizor: `BannerImageProcessor` — PNG (transparență reală detectată)/JPEG (fotografii, calitate ≥ 0.72)/SVG, tip verificat din conținut, raport ±2%, minim @1x, peste @2x micșorat, PNG fără metadate ≤ 400 KB
  (dacă @2x depășește, se încearcă @1x); SVG respins la script/foreignObject/entități/DOCTYPE/href extern/url() extern, apoi
  rasterizat local cu NSImage (verificat în teste). `PromoBanner/PromoBannerEditorView.swift`: listă campanii, mod, RO/EN/ES,
  sloturi Light/Dark/lată, program, link, blocarea publicării la suprapuneri sau conținut incomplet, previzualizare 470/760/1150 pt
  × Light/Dark, publicare prin foaia de confirmare. „Banner clasic” = editorul vechi (păstrează acum și campaniile).
- Client: `LaunchBannerChecker` alege campania activă, descarcă imaginile asincron cu cache pe disc (nume SHA-256 stabil) și
  memorie (decodare o singură dată); fără campanii → bannerul clasic neschimbat.
- Verificat: 14 teste noi; capturi pe fereastra reală a clientului (DEBUG `-PromoBannerFixture text|imageText|image`) la 760×500
  și 1440×900, Light/Dark, RO + ES; editorul Furnizor cu `-PromoBannerFixture YES`.
