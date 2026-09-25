# CI Windows — ce validează (gordasgdc/gdc-plugin-manager-win, `.github/workflows/build-windows.yml`)

Verificat 2026-09-25 pe workflow + logul ultimului run. Workflow-ul NU a fost modificat.

| Stare | Validat în CI? | Cum |
|---|---|---|
| BUILD | DA | `dotnet publish` win-x64 self-contained (Release) |
| TESTS | PARȚIAL (main) / DA (ramura `s1-authorize-download`) | pe ramură: `tests/GDCPluginManager.Core.Tests` — 10 teste fără NuGet, rulate cu `dotnet run` înainte de publish. Pe main încă doar smoke test-ul: un binar separat apelează `Core.dll` publicat (după obfuscare) și compară `ProductHash` cu o valoare calculată independent. **Nu există proiecte de test** (`*.Tests.csproj`: 0; soluția are doar Client + Core) → `dotnet test` nu are ce rula |
| SIGNING | DA, dacă există secretele | `codesigning/sign-windows.ps1`: `signtool` + timestamp, apoi `Get-AuthenticodeSignature` (semnătură atașată; lanțul de încredere NU, normal pentru self-signed). Fără secrete → build nesemnat, fără eroare (Regula 34) |
| PACKAGE | DA | Inno Setup compilează installer-ul; artefact încărcat |
| RELEASE | DA (doar push pe main) | upload pe release + bump `update.json` |
| INSTALLATION | NU | **REQUIRES PHYSICAL WINDOWS VALIDATION** (wizard Inno, Program Files, scurtături, dezinstalare) |
| RUNTIME | NU | **REQUIRES PHYSICAL WINDOWS VALIDATION** (pornire WPF, catalog, instalare produs, self-updater) |
| VISUAL | NU | **REQUIRES PHYSICAL WINDOWS VALIDATION** (teme, texte, redimensionare) |

## Ce se poate muta în CI fără hardware (propus, Faza 7)
1. Proiect `GDCPluginManager.Core.Tests` (xUnit): licență, decodarea `catalog.json` real, `update.json` — aceleași contracte ca testele Mac.
2. `dotnet test` înainte de publish.
3. Instalare silențioasă în runner: `GDCPluginManagerSetup.exe /VERYSILENT /SUPPRESSMSGBOXES`, verificarea fișierelor în Program Files, apoi dezinstalare silențioasă → INSTALLATION parțial validat (fără UI).
4. Pornire headless a exe-ului cu timeout (proces viu N secunde, fără crash în `DiagnosticLog`) → RUNTIME smoke, nu validare vizuală.

## Actualizare 2026-09-25
- Proiect de test adăugat pe ramura `s1-authorize-download` (nu pe `main`: un push pe `main` publică automat un release).
  Fără xUnit: restaurarea NuGet e blocată în mediul local de dezvoltare; executabilul cu aserțiuni proprii rulează identic local și în CI.
- Pas nou: fișierele publicate fără credentiale (ASCII + UTF-16). Pasul care recrea `PrivateCatalogAuth.cs` din secret a fost eliminat.
