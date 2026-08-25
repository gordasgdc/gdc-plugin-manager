#!/usr/bin/env bash
# codesigning/sign-and-notarize.sh — modul comun GDC pentru semnare +
# notarizare pe Mac. Copiaza folderul "codesigning/" NESCHIMBAT in orice
# alt repo GDC (gdc-production-manager, cursorpro-gdc, gdc-resolve-encoder
# etc.) - vezi codesigning/README.md pentru cablarea intr-un build script
# existent.
#
# Functioneaza identic local (developer machine) SAU in GitHub Actions -
# alege automat sursa credentialelor dupa ce variabile de mediu gaseste
# (vezi README.md pentru lista completa si de unde vin).
#
# NU face nimic (iese cu succes, fara sa semneze) daca APPLE_SIGN_IDENTITY_APP
# nu e setata - asta pastreaza fluxul actual (nesemnat) neschimbat pana cand
# certificatul chiar exista si e configurat, ca sa nu strici build-uri
# existente inainte de a avea abonamentul Apple Developer activ.
#
# Usage:
#   codesigning/sign-and-notarize.sh app   /path/to/MyApp.app
#   codesigning/sign-and-notarize.sh pkg   /path/to/MyInstaller.pkg
set -euo pipefail

KIND="${1:?Usage: sign-and-notarize.sh <app|pkg> <path>}"
TARGET="${2:?Usage: sign-and-notarize.sh <app|pkg> <path>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${APPLE_SIGN_IDENTITY_APP:-}" ]; then
    echo "==> [codesigning] APPLE_SIGN_IDENTITY_APP nesetata - sar peste semnare/notarizare (build ramane nesemnat, ca inainte)."
    exit 0
fi

# ── 1. Semnare ──────────────────────────────────────────────────────────
sign_app() {
    local app_path="$1"
    echo "==> [codesigning] Semnez binarele bundle-uite (dinauntru spre afara)…"
    # Deep-sign e nesigur de folosit ca UNIC pas pentru notarizare (Apple
    # o spune explicit) - semnam intai orice binar/dylib/so gasit in
    # interior, INAINTE de binarul principal, ca sa nu ramana ceva
    # semnat doar "in trecere" de --deep.
    find "$app_path" \( -name "*.so" -o -name "*.dylib" -o -perm +111 -type f \) -print0 2>/dev/null \
        | while IFS= read -r -d '' f; do
            codesign --force --timestamp --options runtime \
                --entitlements "$SCRIPT_DIR/entitlements.plist" \
                --sign "$APPLE_SIGN_IDENTITY_APP" "$f" 2>/dev/null || true
        done

    echo "==> [codesigning] Semnez bundle-ul principal…"
    codesign --force --deep --timestamp --options runtime \
        --entitlements "$SCRIPT_DIR/entitlements.plist" \
        --sign "$APPLE_SIGN_IDENTITY_APP" "$app_path"

    echo "==> [codesigning] Verific semnatura…"
    codesign --verify --deep --strict --verbose=2 "$app_path"
}

sign_pkg() {
    local pkg_path="$1"
    if [ -z "${APPLE_SIGN_IDENTITY_INSTALLER:-}" ]; then
        echo "==> [codesigning] APPLE_SIGN_IDENTITY_INSTALLER nesetata - .pkg ramane nesemnat."
        return 0
    fi
    echo "==> [codesigning] Semnez pachetul .pkg…"
    local tmp_signed="${pkg_path%.pkg}-signed.pkg"
    productsign --sign "$APPLE_SIGN_IDENTITY_INSTALLER" "$pkg_path" "$tmp_signed"
    mv "$tmp_signed" "$pkg_path"
}

# ── 2. Notarizare ────────────────────────────────────────────────────────
# Credentialele notarytool vin fie dintr-un profil de keychain salvat o
# singura data local (recomandat pentru build-uri locale, vezi README),
# fie din 3 variabile de mediu (recomandat pentru GitHub Actions/CI, din
# Secrets) - scriptul alege automat ce gaseste.
notarize() {
    local target="$1"
    local upload_path

    echo "==> [codesigning] Impachetez pentru notarizare…"
    if [ -d "$target" ]; then
        # .app e un director - trebuie arhivat intr-un ZIP real inainte de upload.
        upload_path="/tmp/notarize-$$.zip"
        ditto -c -k --keepParent "$target" "$upload_path"
    else
        # .pkg/.dmg sunt deja fisiere unice, in formatul lor propriu -
        # notarytool identifica formatul dupa EXTENSIE, nu dupa continut.
        # NU redenumi in .zip aici (era bug-ul: un .pkg cu extensie .zip
        # ajungea la Apple ca "arhiva goala", fara executabile gasite).
        local ext="${target##*.}"
        upload_path="/tmp/notarize-$$.${ext}"
        cp "$target" "$upload_path"
    fi

    echo "==> [codesigning] Trimit la Apple (poate dura 1-15 min)…"
    if [ -n "${APPLE_NOTARY_KEY_ID:-}" ]; then
        # Cale CI: API key (App Store Connect), 3 secrete separate.
        # APPLE_NOTARY_KEY_P8 vine ca CONTINUT (secretul GitHub Actions
        # nu poate fi un fisier) - il scriem intr-un fisier temporar aici,
        # niciodata pe disc in afara acestei rulari.
        local key_p8_path="/tmp/notary-key-$$.p8"
        printf '%s' "$APPLE_NOTARY_KEY_P8" > "$key_p8_path"
        xcrun notarytool submit "$upload_path" \
            --key "$key_p8_path" \
            --key-id "$APPLE_NOTARY_KEY_ID" \
            --issuer "$APPLE_NOTARY_ISSUER_ID" \
            --wait
        rm -f "$key_p8_path"
    elif [ -n "${APPLE_NOTARY_APPLE_ID:-}" ]; then
        # Cale CI simpla (fara cheie API): apple-id + parola de aplicatie
        # + team-id, direct ca 3 secrete separate - nu necesita niciun
        # fisier temporar. Vezi codesigning/README.md.
        xcrun notarytool submit "$upload_path" \
            --apple-id "$APPLE_NOTARY_APPLE_ID" \
            --team-id "$APPLE_NOTARY_TEAM_ID" \
            --password "$APPLE_NOTARY_PASSWORD" \
            --wait
    else
        # Cale locala: profil salvat o singura data cu
        # `xcrun notarytool store-credentials gdc-notary` (vezi README).
        xcrun notarytool submit "$upload_path" \
            --keychain-profile "gdc-notary" \
            --wait
    fi
    rm -f "$upload_path"

    echo "==> [codesigning] Staplez biletul de notarizare…"
    xcrun stapler staple "$target"
}

case "$KIND" in
    app)
        sign_app "$TARGET"
        notarize "$TARGET"
        ;;
    pkg)
        sign_pkg "$TARGET"
        notarize "$TARGET"
        ;;
    *)
        echo "Prim argument necunoscut: '$KIND' (astept 'app' sau 'pkg')" >&2
        exit 1
        ;;
esac

echo "==> [codesigning] Gata: $TARGET"
