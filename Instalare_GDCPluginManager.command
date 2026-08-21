#!/bin/bash
# Instalare_GDCPluginManager.command
# Launcher de prima rulare: elimina flag-ul de carantina Gatekeeper de
# pe instalatorul .pkg (pus de browser la descarcare) si il deschide,
# ca sa apara direct promptul normal "Open" in loc de avertismentul
# "unidentified developer" / drumul click-dreapta -> Open.
#
# Nu re-semneaza nimic (nu e nevoie pentru un .pkg descarcat).

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKG_PATH="$(find "${DIR}" -maxdepth 1 -iname "*.pkg" -print -quit)"

if [ -n "${PKG_PATH}" ] && [ -f "${PKG_PATH}" ]; then
    echo "==> Pregatesc $(basename "${PKG_PATH}") pentru prima lansare..."
    xattr -dr com.apple.quarantine "${PKG_PATH}" 2>/dev/null
    open "${PKG_PATH}"
    sleep 1
    osascript -e 'tell application "Terminal" to close front window' 2>/dev/null &
else
    echo "Eroare: nu am gasit niciun instalator .pkg in acest folder (${DIR})."
    read -p "Apasa Enter pentru a inchide..."
fi
