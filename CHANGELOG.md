# Changelog — GDC Plugin Manager

Format: fiecare intrare listează versiunea, platformele afectate, și — pentru
funcționalități noi — dacă are paritate completă Mac/Windows sau e "doar pe
o platformă, portare pe cealaltă e TODO".

## v1.2.18 (2026-08-25)
**Windows** — paritate cu Mac:
- Secțiune "Service & Reparații Echipament" (carduri, contact rapid, website/locație) — era doar pe Mac din v1.2.16.
- `SystemDependencyChecker` (DaVinci Resolve, Visual C++ Redistributable) — era doar pe Mac.
- Fix: `/Applications`-echivalent (instalare peste o copie root-owned) — n/a pe Windows, doar Mac avea nevoie.

## v1.2.17 (2026-08-25)
**Toate 4 componente** (Mac Swift, Windows C#, C++ resolve-encoder, Python production-manager) — **paritate completă**:
- Schemă de licențiere v2: payload extins de la 22 la 23 octeți (byte de platformă:
  `mac_only` / `windows_only` / `cross_platform`), 100% compatibil retroactiv cu codurile v1.
- Fix critic: release-ul Windows lipsea complet din `v1.2.16` (404 real la descărcare, nu problemă de site).

## v1.2.16 (2026-08-25)
**Doar Mac** — TODO paritate Windows (parțial acoperit în v1.2.18, vezi mai sus):
- Meniu nativ macOS (About, Check for Updates..., Preferences Cmd+,).
- Ghid PDF de utilizare (RO/EN/ES), deschis din meniul Help.
- Secțiune "Service & Reparații Echipament" (nouă, Client + Furnizor).
- `SystemDependencyChecker` (verificare DaVinci Resolve la lansare).
- Regulă de comunicare ultra-concisă adăugată în `CLAUDE.md`.

## v1.2.15 (2026-08-25)
**Mac + Windows** — Code Signing & Notarizare Apple completă (modul comun `codesigning/`, reutilizabil în orice repo GDC).

## v1.2.14 și anterior
Vezi istoricul `git log` — GDC-SEC-02 (Machine ID întărit), kill-switch diferențiat, retragere APK/TWA → PWA.

---

## Regulă de proces (vezi și CLAUDE.md)
Orice funcționalitate nouă adăugată **doar pe o platformă** trebuie:
1. Marcată explicit aici ca "doar pe X — TODO paritate pe Y".
2. Portată pe cealaltă platformă într-un ciclu de lucru ulterior, nu lăsată nedefinit.
