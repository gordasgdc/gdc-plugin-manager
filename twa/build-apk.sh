#!/usr/bin/env bash
# =============================================================================
# GDC — build APK (TWA) din PWA-ul de pe gordas.dev
# -----------------------------------------------------------------------------
# Ce face, pe pasi:
#   1. verifica JDK 17 + Node
#   2. instaleaza bubblewrap (daca lipseste)
#   3. creeaza keystore-ul de semnare (o singura data, la prima rulare)
#   4. genereaza proiectul Android din twa/twa-manifest.json
#   5. construieste si semneaza APK-ul
#   6. tipareste amprenta SHA-256 si o scrie in docs/.well-known/assetlinks.json
#
# Rulare:  bash twa/build-apk.sh
# Prima rulare descarca Android SDK (~500 MB) si dureaza cateva minute.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"
REPO_ROOT="$(cd .. && pwd)"
KEYSTORE="android.keystore"
KEY_ALIAS="gdc"
ASSETLINKS="$REPO_ROOT/docs/.well-known/assetlinks.json"

echo "── [1/6] Verific JDK si Node ────────────────────────────────────────────"
# ATENTIE: pe macOS exista mereu un stub /usr/bin/java, chiar fara JDK instalat.
# De aceea NU verificam cu "command -v java", ci rulam efectiv "java -version".
if ! java -version >/dev/null 2>&1; then
  echo "EROARE: nu exista un JDK functional (stub-ul macOS nu se pune la socoteala)."
  echo "  brew install --cask temurin@17"
  echo "  export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"
  exit 1
fi
command -v node >/dev/null || { echo "EROARE: lipseste Node. Instaleaza: brew install node"; exit 1; }
java -version 2>&1 | head -1

echo "── [2/6] Verific bubblewrap ─────────────────────────────────────────────"
# Folderul de binare globale npm (ex: ~/.npm-global/bin) nu e mereu in PATH,
# asa ca il adaugam noi inainte de a cauta comanda.
export PATH="$(npm prefix -g)/bin:$PATH"
if ! command -v bubblewrap >/dev/null; then
  echo "Nu e instalat. Instalez global @bubblewrap/cli..."
  npm install -g @bubblewrap/cli
  export PATH="$(npm prefix -g)/bin:$PATH"
  hash -r
fi
command -v bubblewrap

echo "── [3/6] Keystore de semnare ────────────────────────────────────────────"
if [ -f "$KEYSTORE" ]; then
  echo "Exista deja $KEYSTORE — il refolosesc (OBLIGATORIU pentru update-uri)."
else
  echo "Creez $KEYSTORE. ATENTIE: fa-i backup imediat dupa. Fara el nu mai poti"
  echo "publica update-uri pentru utilizatorii care au deja aplicatia instalata."
  keytool -genkeypair \
    -v -keystore "$KEYSTORE" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA -keysize 2048 \
    -validity 10000 \
    -dname "CN=Cristinel Gordas, O=GDC, L=, S=, C=RO"
fi

echo "── [4/6] Generez proiectul Android ──────────────────────────────────────"
# ATENTIE la ordinea de mai jos: "bubblewrap init" isi scrie PROPRIUL
# twa-manifest.json peste al nostru. De aceea il punem deoparte inainte de init
# si il restauram dupa, apoi rulam "update", care regenereaza proiectul Android
# din configuratia noastra (culori, scurtaturi, startUrl).
if [ ! -d "app" ]; then
  # Daca o rulare anterioara a esuat dupa init, backup-ul nostru e deja pe disc
  # si twa-manifest.json poate fi cel scris de bubblewrap — deci restauram in
  # loc sa suprascriem backup-ul bun.
  if [ -f twa-manifest.gdc.json ]; then
    cp twa-manifest.gdc.json twa-manifest.json
  else
    cp twa-manifest.json twa-manifest.gdc.json
  fi
  # La intrebarile din init: keystore = ./android.keystore, alias = gdc.
  bubblewrap init --manifest="https://gordas.dev/manifest.webmanifest" --directory=.
  mv -f twa-manifest.gdc.json twa-manifest.json
fi
bubblewrap update --skipVersionUpgrade

# "bubblewrap update" cere versiunea interactiv si, cand nu primeste raspuns, o
# lasa GOALA in app/build.gradle (aplicatia ar aparea fara versiune in Setarile
# Android). O scriem noi, direct din twa-manifest.json, ca sa fie determinista.
VNAME="$(python3 -c "import json;print(json.load(open('twa-manifest.json'))['appVersionName'])")"
VCODE="$(python3 -c "import json;print(json.load(open('twa-manifest.json'))['appVersionCode'])")"
sed -i '' "s/versionName .*/versionName \"$VNAME\"/" app/build.gradle
sed -i '' "s/versionCode .*/versionCode $VCODE/" app/build.gradle
echo "Versiune fixata in app/build.gradle: $VNAME (code $VCODE)"

echo "── [5/6] Construiesc si semnez APK-ul ───────────────────────────────────"
bubblewrap build

echo "── [6/6] Amprenta SHA-256 pentru Digital Asset Links ────────────────────"
FINGERPRINT="$(keytool -list -v -keystore "$KEYSTORE" -alias "$KEY_ALIAS" \
  | grep -m1 'SHA256:' | sed 's/.*SHA256: *//' | tr -d ' \r')"
echo "SHA-256: $FINGERPRINT"

python3 - "$ASSETLINKS" "$FINGERPRINT" <<'PY'
import json, sys
path, fp = sys.argv[1], sys.argv[2]
data = json.load(open(path))
data[0]["target"]["sha256_cert_fingerprints"] = [fp]
json.dump(data, open(path, "w"), indent=2)
open(path, "a").write("\n")
print(f"Am scris amprenta in {path}")
PY

cat <<'EOF'

GATA. Mai ai de facut, manual:
  1. Publica docs/ (commit + push) — assetlinks.json trebuie sa fie live la
     https://gordas.dev/.well-known/assetlinks.json
  2. Verifica: curl -s https://gordas.dev/.well-known/assetlinks.json
  3. Urca APK-ul (app-release-signed.apk) in GitHub Releases si pune linkul pe site.
EOF
