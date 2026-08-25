#!/usr/bin/env bash
# codesigning/ci-import-certs.sh — DOAR pentru GitHub Actions (macOS
# runner). Un runner CI proaspat nu are login.keychain-db cu
# certificatele tale, ca pe Mac-ul local - acest script creeaza un
# keychain temporar, importa cele 2 certificate .p12 din GitHub Secrets,
# si il adauga la lista de cautare, ca sign-and-notarize.sh sa le
# gaseasca exact ca local.
#
# Variabile de mediu necesare (secrete GitHub Actions - vezi
# codesigning/README.md pentru cum se genereaza):
#   APPLE_CERT_APP_P12_BASE64        - .p12 (Developer ID Application), base64
#   APPLE_CERT_APP_P12_PASSWORD      - parola acelui .p12
#   APPLE_CERT_INSTALLER_P12_BASE64  - .p12 (Developer ID Installer), base64
#   APPLE_CERT_INSTALLER_P12_PASSWORD - parola acelui .p12
#
# Apelat o data, la inceputul job-ului CI, INAINTE de orice
# sign-and-notarize.sh:
#   ./codesigning/ci-import-certs.sh
set -euo pipefail

if [ -z "${APPLE_CERT_APP_P12_BASE64:-}" ]; then
    echo "==> [ci-import-certs] Variabilele APPLE_CERT_*_P12_BASE64 nu sunt setate - sar peste import (build local, nu CI)."
    exit 0
fi

KEYCHAIN_PATH="$RUNNER_TEMP/gdc-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"

echo "==> [ci-import-certs] Creez keychain temporar…"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "==> [ci-import-certs] Importez certificatul Application…"
echo "$APPLE_CERT_APP_P12_BASE64" | base64 --decode > "$RUNNER_TEMP/app.p12"
security import "$RUNNER_TEMP/app.p12" -k "$KEYCHAIN_PATH" -P "$APPLE_CERT_APP_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/productsign -T /usr/bin/pkgbuild -T /usr/bin/productbuild
rm -f "$RUNNER_TEMP/app.p12"

if [ -n "${APPLE_CERT_INSTALLER_P12_BASE64:-}" ]; then
    echo "==> [ci-import-certs] Importez certificatul Installer…"
    echo "$APPLE_CERT_INSTALLER_P12_BASE64" | base64 --decode > "$RUNNER_TEMP/installer.p12"
    security import "$RUNNER_TEMP/installer.p12" -k "$KEYCHAIN_PATH" -P "$APPLE_CERT_INSTALLER_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/productsign -T /usr/bin/pkgbuild -T /usr/bin/productbuild
    rm -f "$RUNNER_TEMP/installer.p12"
fi

# Fara asta, codesign/productsign/pkgbuild/productbuild cer parola
# keychain-ului interactiv la fiecare apel - imposibil intr-un job CI
# fara interactiune (job-ul ramane "in_progress" la nesfarsit, asteptand
# un prompt GUI care nu poate aparea pe un runner headless).
security set-key-partition-list -S apple-tool:,apple:,codesign:,productsign:,pkgbuild:,productbuild: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "==> [ci-import-certs] Adaug keychain-ul la lista de cautare…"
security list-keychains -d user -s "$KEYCHAIN_PATH" login.keychain-db

echo "==> [ci-import-certs] Gata."
