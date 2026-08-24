# Machine ID — arhitectură & regulă strictă (GDC-SEC-02)

> Document canonic. Copie identică în `gdc-production-manager`,
> `gdc-plugin-manager` (Mac), `gdc-plugin-manager-win`. Dacă modifici
> formula, actualizează TOATE cele 4 copii + fișierele de cod sursă.

## De ce există acest document

Audit de securitate intern, 2026-08-24: `MachineGuid` din Windows Registry
(`HKLM\SOFTWARE\Microsoft\Cryptography`) — folosit până acum ca sursă a
ID-ului de mașină pe Windows — se rescrie cu un singur comand, din orice
cont administrator:

```
reg add "HKLM\SOFTWARE\Microsoft\Cryptography" /v MachineGuid /t REG_SZ /d {guid-tinta} /f
```

Efect: o licență legată de mașina A putea fi „mutată" pe mașina B (fizică
sau VM proaspătă) fără efort. Pe o VM cu snapshot, licența devenea
efectiv nelimitată.

## Formula curentă

**macOS** (neschimbat — nu e afectat de acest atac, nu există un
echivalent trivial de „reg add" pentru `IOPlatformUUID`):

```
raw = IOPlatformUUID
hash = SHA-512(raw), primii 6 octeți, Base32 (fără padding)
```

**Windows** (STRICTĂ, obligatorie identică în Python / C# / C++ / orice
implementare viitoare):

```
raw = trim(Win32_ComputerSystemProduct.UUID) + "|" + trim(Win32_DiskDrive[0].SerialNumber)
hash = SHA-512(raw), primii 6 octeți, Base32 (fără padding)
```

- `Win32_ComputerSystemProduct.UUID` — UUID-ul plăcii de bază, expus de
  BIOS prin WMI, stabil între reinstalări OS.
- `Win32_DiskDrive[0].SerialNumber` — serialul discului fizic (primul
  găsit), la fel prin WMI.
- Separator `"|"` literal între cele două valori, **după** trim
  (spații/tab/CR/LF la capete — serialurile ATA vin adesea cu padding).
- Dacă board UUID e indisponibil → `"windows-machine-id-unavailable"`
  (nu se combină parțial). Dacă disk serial e indisponibil dar board UUID
  există → se continuă cu partea de disc goală (`"<uuid>|"`), nu se
  întrerupe complet, ca aplicația să rămână utilizabilă chiar și fără
  drept de citire pe discuri (VM restricționată etc.).

## Regula strictă pentru orice cod nou

Orice modul care calculează machine ID pe Windows — indiferent de limbaj —
**trebuie** să reproducă exact acest string brut înainte de hash, inclusiv
trim-ul și separatorul. O deviație (altă ordine, alt separator, fără trim)
produce un ID diferit pentru aceeași mașină și rupe validarea tuturor
licențelor Windows deja emise.

## Implementări

| Componentă | Fișier |
|---|---|
| C++ (`gdc-resolve-encoder`) | `src/license_check.cpp` — `raw_machine_id()`, `wmi_query_first()` |
| Python (`gdc-production-manager`) | `backend/machine_id.py` — `_raw_machine_id()` |
| C# (`gdc-plugin-manager-win`) | `src/GDCPluginManager.Core/Services/MachineID.cs` — `RawPlatformUuid()` |
| Swift (`gdc-plugin-manager`, macOS) | `Sources/GDCPluginManager/MachineID.swift` — `rawPlatformUUID()` (neschimbat, doar IOPlatformUUID) |

## Migrare — licențe Windows deja emise

Formula veche (Registry `MachineGuid`) producea un ID diferit de formula
nouă. **Decizie 2026-08-24: fără validare duală** — toate serialurile
Windows deja active (Production Manager + resolve-encoder) trebuie
re-emise manual către clienți, pe formula nouă. Vezi `furnizor_sales.csv`
pentru lista clienților Windows de contactat.

## Comportament la eșec de validare (kill-switch)

Vezi secțiunea „Fallback la detectare fraudă" din CLAUDE.md / notele de
arhitectură ale fiecărui produs — tratamentul diferă după tipul erorii de
validare (semnătură invalidă vs. mașină diferită vs. eroare temporară de
rețea/WMI), nu e un singur comportament uniform.
