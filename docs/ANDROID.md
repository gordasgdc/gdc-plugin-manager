# Aplicatia GDC pentru Android (PWA + TWA)

Aplicatia Android **nu** are cod separat: e chiar site-ul `gordas.dev`,
transformat in PWA si impachetat intr-un APK prin TWA (Trusted Web Activity).

Consecinta practica: **orice produs, curs sau eveniment adaugat in
`catalog.json` apare in aplicatie imediat, fara APK nou si fara reinstalare.**
APK-ul se reconstruieste doar cand schimbi numele aplicatiei, iconita sau
permisiunile.

Scope-ul e radacina domeniului (`https://gordas.dev/`), deci si paginile de
produs (`/datamover/`, `/cursorpro-gdc/`, `/CGConvertor/` ...) se deschid in
aplicatie, fara bara de browser.

## Fisiere si rolul lor

| Fisier | Rol |
|---|---|
| `docs/manifest.webmanifest` | nume, iconite, culori, scurtaturi |
| `docs/sw.js` | service worker: offline + cache + notificari |
| `docs/offline.html` | pagina afisata cand nu e retea |
| `docs/icons/` | iconite 192/512 + varianta *maskable* pentru Android |
| `docs/.well-known/assetlinks.json` | dovada ca APK-ul si domeniul iti apartin |
| `docs/.nojekyll` | fara el, GitHub Pages ignora folderul `.well-known` |
| `twa/twa-manifest.json` | configuratia APK-ului (bubblewrap) |
| `twa/build-apk.sh` | scriptul care construieste si semneaza APK-ul |

> La fiecare modificare de pagina, **incrementeaza `CACHE_VERSION` din `docs/sw.js`**.
> Altfel utilizatorii raman cu versiunea veche din cache.
> `catalog.json` face exceptie: e network-first, deci se improspateaza singur.

## Build APK

```bash
bash twa/build-apk.sh
```

Cerinte: JDK 17 si Node. Restul (Android SDK) se descarca automat la prima
rulare. Rezultatul: `twa/app-release-signed.apk`.

## Semnare (keystore) — partea ireversibila

`twa/android.keystore`, alias **`datamover`** (creat initial pentru primul APK,
refolosit aici — o cheie de semnare nu depinde de numele aplicatiei).

- **Fa-i backup** (password manager + un al doilea loc, offline).
- Salveaza parola keystore-ului, parola cheii si alias-ul.
- `twa/.gitignore` il tine in afara repo-ului — nu-l adauga niciodata fortat.
- **Daca il pierzi**, utilizatorii care au aplicatia instalata nu mai pot face
  update: Android refuza un APK semnat cu alta cheie.

## Digital Asset Links (fara bara de browser)

Fisierul se verifica pe **radacina originii**, si e deja la locul potrivit:

```
https://gordas.dev/.well-known/assetlinks.json
```

Amprenta SHA-256 din el trebuie sa fie exact cea a keystore-ului
(`build-apk.sh` o completeaza automat la pasul 6). Manual:

```bash
keytool -list -v -keystore twa/android.keystore -alias datamover | grep SHA256
```

Verificare dupa publicare:

```bash
curl -s https://gordas.dev/.well-known/assetlinks.json
```

## Instalare pe telefon (Android 13, 14, 15+)

APK-ul nu vine din Play Store, deci sistemul cere o permisiune explicita:

1. Descarca APK-ul de pe site (Chrome → "Descarca oricum").
2. Deschide fisierul din notificare sau din **Fisiere → Descarcari**.
3. Android afiseaza "Din motive de securitate nu poti instala..." →
   **Setari** → activeaza **Permite din aceasta sursa** pentru Chrome/Fisiere.
4. Inapoi → **Instaleaza**. Play Protect poate avertiza ca aplicatia e
   necunoscuta → **Instaleaza oricum**.
5. Pe Android 13+, permisiunea de notificari se cere separat, la prima pornire.

Alternativa fara APK: Chrome → meniul ⋮ → **Adauga la ecranul principal**.
Instaleaza acelasi PWA, fara pasii de securitate de mai sus.

## Notificari (produs nou, LUT/DCTL, curs, workshop)

`docs/sw.js` are deja handler-ele `push` si `notificationclick`. Mai lipsesc
doua lucruri, de facut cand ai ce anunta:

1. **Backend**: Firebase Cloud Messaging (gratuit) sau server web-push cu VAPID.
2. **Abonare in pagina**: `Notification.requestPermission()`, apoi
   `registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey })`
   si trimiterea subscriptiei catre backend.

Payload-ul asteptat de service worker:

```json
{ "title": "Produs nou", "body": "GDC Film Look v2 e disponibil", "url": "/#catalog", "tag": "produs-nou" }
```

## Checklist la fiecare release

- [ ] `CACHE_VERSION` incrementat in `docs/sw.js`
- [ ] site publicat si testat in Chrome mobil (DevTools → Application, fara erori)
- [ ] APK reconstruit **doar** daca s-au schimbat nume/iconite/scurtaturi
- [ ] `appVersionName` + `appVersionCode` crescute in `twa/twa-manifest.json`
- [ ] keystore-ul in backup, nu in git
