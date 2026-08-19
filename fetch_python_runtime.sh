#!/usr/bin/env bash
# Descarca Python-ul portabil (cpython-build-standalone, arm64, MIT licensed)
# folosit de PowerGradeImporter pentru importul automat in Gallery — bundle-uit
# in app la build (vezi build_app.sh), ca clientul sa nu mai depinda de un
# python3 instalat separat. NU e commit-uit in git (66MB, resursa binara
# redistribuibila, nu cod sursa) — ruleaza scriptul asta o data pe orice
# masina noua de dezvoltare, inainte de build_app.sh / build_installer.sh.
set -euo pipefail
cd "$(dirname "$0")"

PYTHON_BUILD_TAG="20260814"
PYTHON_VERSION="3.12.14"
ASSET="cpython-${PYTHON_VERSION}+${PYTHON_BUILD_TAG}-aarch64-apple-darwin-install_only_stripped.tar.gz"
URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_BUILD_TAG}/${ASSET}"

if [ -x "PythonRuntime/bin/python3" ]; then
    echo "PythonRuntime deja prezent — sterge folderul daca vrei sa il reinstalezi."
    exit 0
fi

echo "==> Descarc $URL"
TMP=$(mktemp -d)
curl -sL -o "$TMP/python.tar.gz" "$URL"
mkdir -p "$TMP/extracted"
tar xzf "$TMP/python.tar.gz" -C "$TMP/extracted"
rm -rf PythonRuntime
mv "$TMP/extracted/python" PythonRuntime
rm -rf "$TMP"
echo "==> Gata: PythonRuntime/ ($(du -sh PythonRuntime | cut -f1))"
