#!/usr/bin/env bash
#
# Dezinstalare_GDCPluginManager.command
# Dezinstalare & curatare completa pentru GDC Plugin Manager (Client).
#
# Ce face:
#   1. Opreste fortat orice instanta ramasa in fundal.
#   2. Reseteaza permisiunile TCC (System Settings -> Privacy & Security)
#      pentru bundle ID-ul GDC Plugin Manager, ca sistemul sa le ceara din
#      nou, curat, la o reinstalare.
#   3. Sterge aplicatia + toate fisierele de preferinte/cache/suport asociate.
#
# Bundle ID real: com.gordasgdc.pluginmanager (Info.plist).
#
# Rulare: dublu-click, sau click-dreapta -> Open (Terminal), sau din terminal:
#   chmod +x Dezinstalare_GDCPluginManager.command && ./Dezinstalare_GDCPluginManager.command
#
# NOTA 1: daca fisierul a fost descarcat separat (nu din arhiva .zip
# originala), poate avea flag-ul de quarantine si/sau bitul de executie
# lipsa - ruleaza intai:
#   xattr -d com.apple.quarantine Dezinstalare_GDCPluginManager.command
#   chmod +x Dezinstalare_GDCPluginManager.command
#
# NOTA 2: daca rulezi de pe un disc extern/USB, macOS poate bloca
# executia cu "operation not permitted" (Terminal nu are acces la
# "Removable Volumes" in Privacy & Security) - copiaza fisierul pe
# discul local (Desktop/Downloads) inainte sa il rulezi.
#
# NOTA 3: stergerea /Applications/GDCPluginManager.app poate cere parola
# de administrator (sudo) - depinde daca a fost instalata prin .pkg
# (owned de root) sau prin .zip/drag-and-drop (owned de user). Scriptul
# cere sudo DOAR daca stergerea normala esueaza, nu de la inceput.

set -uo pipefail

BUNDLE_ID="com.gordasgdc.pluginmanager"
APP_PATH="/Applications/GDCPluginManager.app"

echo "=================================================="
echo " GDC Plugin Manager — Dezinstalare & Curatare completa"
echo "=================================================="
echo ""

# ---- Pasul 1: Oprire procese -------------------------------------------
echo "[1/3] Opresc orice instanta GDCPluginManager ramasa in fundal..."
pkill -x "GDCPluginManager" 2>/dev/null
pkill -f "GDCPluginManager.app" 2>/dev/null
sleep 1
echo "[+] Procese oprite."
echo ""

# ---- Pasul 2: Resetare permisiuni TCC ----------------------------------
echo "[2/3] Resetez permisiunile din System Settings -> Privacy & Security..."
echo "      (bundle ID: $BUNDLE_ID)"
for service in Accessibility ScreenCapture ListenEvent All; do
    if tccutil reset "$service" "$BUNDLE_ID" 2>/dev/null; then
        echo "      - $service: resetat"
    else
        echo "      - $service: nimic de resetat (sau tccutil nesuportat pentru acest serviciu)"
    fi
done
echo "[+] Permisiuni resetate — la urmatoarea lansare, macOS le va cere din nou, curat."
echo ""

# ---- Pasul 3: Stergere aplicatie + fisiere -----------------------------
echo "[3/3] Sterg aplicatia si toate fisierele asociate..."

remove_if_exists() {
    local path="$1"
    if [ ! -e "$path" ]; then
        return
    fi
    # Incearca fara sudo intai (majoritatea fisierelor din ~/Library sunt
    # ale userului) - doar daca esueaza real (verificat prin [ -e ] dupa),
    # reincearca cu sudo. Fara verificarea existentei dupa `rm`, un esec
    # pe /Applications (app instalata prin .pkg, owned de root) ar fi
    # raportat gresit ca succes.
    if rm -rf "$path" 2>/dev/null && [ ! -e "$path" ]; then
        echo "      - sters: $path"
        return
    fi
    echo "      - necesita permisiuni de administrator: $path"
    if sudo rm -rf "$path" && [ ! -e "$path" ]; then
        echo "      - sters (cu sudo): $path"
    else
        echo "      - EROARE: nu am putut sterge $path"
    fi
}

remove_if_exists "$APP_PATH"
remove_if_exists "$HOME/Library/Application Support/GDCPluginManager"
remove_if_exists "$HOME/Library/Caches/$BUNDLE_ID"
remove_if_exists "$HOME/Library/Caches/$BUNDLE_ID.ShipIt"
remove_if_exists "$HOME/Library/Preferences/$BUNDLE_ID.plist"
remove_if_exists "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
remove_if_exists "$HOME/Library/Logs/GDCPluginManager"
remove_if_exists "$HOME/Library/HTTPStorages/$BUNDLE_ID"
remove_if_exists "$HOME/Library/WebKit/$BUNDLE_ID"

echo "[+] Fisiere sterse."
echo ""
echo "=================================================="
echo " [+] Curatare completa finalizata cu succes!"
echo " Poti reinstala GDC Plugin Manager de la zero acum."
echo "=================================================="
echo ""
read -p "Apasa Enter pentru a inchide fereastra..."
