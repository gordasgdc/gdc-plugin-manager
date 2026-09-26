# Plan consolidat — adaptarea funcțională Windows (client 1.37.2 → paritate cu Mac 1.40.0)

Stare: PROPUNERE, neimplementată. Bază: `WINDOWS_ADAPTATION_INVENTORY.md`. Principiu: paritate de COMPORTAMENT și de date,
nu de interfață — WPF rămâne nativ Windows (WPF-UI), fără a copia layout-ul Mac. Furnizorul nu există pe Windows.

## Ordinea (după risc pentru clienți)

### 1. Compatibilitatea catalogului (blocant pentru tot restul)
- Obiectiv: orice câmp nou din `catalog.json` / `launch-banner.json` publicat de Furnizor 1.53 e decodat sau ignorat fără eroare.
- Verificare: fixture-uri comune Mac/Windows (catalogul real + `launch-banner.json` cu `campaigns`, câmpuri necunoscute, liste stricate)
  rulate în `GDCPluginManager.Core.Tests`; decodarea tolerantă (ca în Swift: `campaigns` invalid → ignorat, bannerul clasic rămâne).
- Risc: `CatalogJsonOptions` are convertori stricți (`PluginItemJsonConverter` etc.) — de confirmat comportamentul pe câmpuri noi.

### 2. Bannere promoționale
- `LaunchBannerModel.cs`: câmpurile `campaigns` (mod, texte RO/EN/ES, imagini Light/Dark/lată, program, link) + `ActiveCampaign`,
  aceleași reguli ca `PromoBanner.swift` (câștigă începutul cel mai recent; incomplet = ignorat; fără campanii → clasic).
- `LaunchBannerChecker.cs`: descărcare asincronă, cache pe disc cu nume SHA-256 stabil, `BitmapImage` înghețat (`Freeze`) o singură dată.
- Randare: 6:1 `Uniform` (integral), 12:1 de la 900 px logici, 3:1 `UniformToFill` în panoul stâng; text separat, tema Light/Dark.
- Teste: aceleași cazuri ca `PromoBannerTests` (portate 1:1).

### 3. Licențiere (fără schimbări de format)
- `LicenseCore.cs`/`MachineID.cs`/`RevocationCheck.cs` există; se verifică doar paritatea cu Mac pe vectori de test comuni
  (serial valid/alt Mac/expirat/revocat, fail-open la revocare offline — Regula 12). Nicio cheie nouă, niciun secret atins.

### 4. Instalare / descărcare
- `DownloadAuthorizer.cs` + `InstallManager.cs`: paritate cu Mac 1.39.4 (authorize-download; fără PAT). Portare `ProductActionState`
  în Core C# (8 stări; PAUSED amânat) + teste; UI-ul citește starea, nu o calculează.
- Stări de ecran: loading/empty/error + banner offline (catalog din cache) — echivalentul `isShowingCachedCatalog`.

### 5. Actualizare
- `UpdateChecker.cs`/`SelfUpdater.cs`/`UpdatePackageVerifier.cs`: fără schimbări funcționale; se verifică doar că `update.json`
  (format compatibil, Regula 35) rămâne decodabil și că versiunea Windows e anunțată separat de cea Mac.

### 6. Interfață (după 1–5, opțional la același release)
- Tokeni în `Theme*.xaml` (valori identice), stiluri de buton, `StatusBadge`, card comun; spargerea `MainWindow.xaml` (2614 linii)
  în controale — premisa oricărei redesenări. Tema: Regula 37 (fără culori literale).

## Validare și livrare
- Build + teste pe CI (`WINDOWS_CI.md`), apoi VM ARM64 din `WINDOWS_LAB.md` (snapshot curat): catalog, banner (3 moduri, cu și fără
  campanii), activare licență, instalare/ștergere produs, actualizare 1.37.2 → nouă. Versiune nouă Windows (MINOR), CHANGELOG,
  installer semnat (Regula 34), `update.json` sincronizat. Nimic publicat fără aprobare.
- Estimare: 1–5 = un lot funcțional (fără UI nou); 6 = lot separat.
