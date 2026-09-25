# Constatări de catalog (2026-09-25)

Detectate de `scripts/validate_catalog.py --history`. Nicio modificare de catalog aplicată.

## gdc-style-m02-film-demo — republicat după ștergere

| | |
|---|---|
| Sursa de adevăr | `docs/catalog.json` (publicat) + repo-ul privat de fișiere; ambele consistente (fișiere + SHA-256 OK) |
| Generator | Furnizor, `DemoPublisher` (mod fără fereastră `--publish-demo-inbox`), alimentat de căsuța comună `StyleLabInbox` |
| Cine îl reintroduce | aplicația GDC STYLE Lab: exportul „Demo” din Film Pipeline (`DemoPublish.send`, `autoPublish = true`) scrie trimiterea `gdc-style-m02-film-demo` și pornește Furnizorul, care îl adaugă/actualizează în catalog |
| Cronologie | șters în lotul de 7 produse (c0e6122, 2026-09-23 16:58); republicat v1.46.0 (aafa68f, 21:09) după un export Demo din STYLE Lab 1.46.0 |
| Intenționat? | exportul e o acțiune a operatorului; nu există însă nicio marcă a ștergerii, deci ORICE export Demo ulterior readuce produsul |
| Deprecated? | nu: `gdc-style-m02-film` e modulul Film Pipeline activ în STYLE Lab |
| Decizie | 2026-09-25 14:02: proprietarul a șters din Furnizor m02 și universal-idt-demo (0fb2f15). Deschis: dacă ștergerea trebuie să BLOCHEZE republicarea automată (istoricul arată și cicluri voite „șterge → republică”) |
| Dacă se retrage | schimbarea se face la sursă, nu în catalog: (a) STYLE Lab nu mai oferă exportul Demo pentru m02, sau (b) Furnizor ține o listă de ID-uri retrase pe care `DemoPublisher` o respectă (refuz + mesaj). Doar apoi ștergerea din catalog |

Același tipar: `gdc-style-gdc-pro-universal-idt-demo` (șters 53b0d97, republicat 0c1d493).

## Filigrane sezoniere — imagini lipsă (404)

| Asset | Referință | Locație așteptată | Locație reală | Impact | Intenționat? | Remediere |
|---|---|---|---|---|---|---|
| black-friday-seeklogo, black-friday-sale-seeklogo, blackfriday, craciun, summer, lansare | `catalog.json` → `seasonalBackgrounds[].imagePath` | `docs/covers/seasonal/<id>.png/.jpg` (→ `gordas.dev/covers/seasonal/…`) | inexistente (folderul lipsește; 404 live) | niciunul vizibil: toate 6 au `isEnabled: false`, clientul nu le afișează | probabil: fișierele au fost scoase la curățarea filigranelor, intrările au rămas | la activarea unui filigran, Furnizor trebuie să reîncarce imaginea; opțional: curățarea intrărilor moarte din Furnizor. Validatorul le raportează ca avertisment (eroare dacă intrarea e activă) |
