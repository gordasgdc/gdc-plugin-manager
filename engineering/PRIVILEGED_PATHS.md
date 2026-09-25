# Căi privilegiate și execuție de procese — inventar (2026-09-25)

Căutare sistematică în `Sources/GDCPluginManager` + `Sources/GDCPluginManagerCore` (client Mac) după: `osascript`,
`sudo`, `administrator`, `AuthorizationCreate`, `SMJobBless`/`SMAppService`, `installer`, `Process()`, scripturi temporare.
Furnizor (unealtă locală a vânzătorului, nedistribuită) nu e în acest inventar.

| # | Cale | Privilegiu | Date externe în comandă | Protecție | Test |
|---|---|---|---|---|---|
| P1 | `SelfUpdater` → `installer` | root (osascript + parolă) | versiune și URL din `update.json`, pachet descărcat | versiune validată; semnătură Developer ID Installer + Team ID + SHA-256 în contextul utilizatorului ȘI pe copia root (folder 700); script ca argv, fără fișier de script | AUTO: `UpdatePackageVerifierTests` (10); MANUAL: promptul real de parolă |
| P2 | `InstallManager.runElevated` (OFX în `/Library/OFX/Plugins`) | root (osascript + parolă) | căi din catalog (nume de fișiere) | căi prin `shellQuote`; script ca argv (`osascriptArguments`), fără concatenare în AppleScript; fișierele au trecut deja de SHA-256 | AUTO: argv/quoting acoperit în P1; MANUAL: instalare OFX reală |
| P3 | `PowerGradeImporter.runPython` | utilizator | nume album și căi `.drx` din catalog | literale Python generate prin JSON (ghilimele, `\`, rânduri noi, Unicode) | verificat local: 7 cazuri adversariale round-trip; fără test automat în suită (tipul e în ținta executabilă) |
| P4 | `SelfUpdater.unzip` (`/usr/bin/unzip`) | utilizator | arhiva descărcată | argumente ca listă (fără shell); `unzip` elimină `../`; pachetul extras trece apoi prin P1 | acoperit indirect |
| P5 | `UpdatePackageVerifier.verify` (`pkgutil`) | utilizator | calea pachetului | argumente ca listă | AUTO |

Nu există: `sudo`, `SMJobBless`, `SMAppService`, helper privilegiat, `AuthorizationCreate`.

Regula: orice cale nouă care rulează un proces cu date din rețea/catalog trece argumentele ca listă (niciodată prin
shell/AppleScript concatenat) și, dacă e privilegiată, verifică exact fișierul pe care îl folosește ca root.
Windows: instalarea cu UAC (`WriteFile` → elevare) — de inventariat la fel în faza Windows.
