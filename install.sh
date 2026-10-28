#!/usr/bin/env bash
# Install or upgrade The Sub-Etha Guide for the current user.
#
#   ./install.sh             install / upgrade the widget
#   ./install.sh --restart   ...then restart plasmashell so the new version
#                            loads at once
set -euo pipefail
cd "$(dirname "$0")"

RESTART=0
for arg in "$@"; do
    case "$arg" in
        -r|--restart) RESTART=1 ;;
        -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
    esac
done

if kpackagetool6 -t Plasma/Applet --upgrade package >/dev/null 2>&1; then
    echo "Upgraded  com.shani.subethaguide"
else
    kpackagetool6 -t Plasma/Applet --install package >/dev/null
    echo "Installed com.shani.subethaguide"
fi

# Plasma resolves metadata "Icon" from the icon theme, so install it there.
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR"
cp package/icon.png "$ICON_DIR/com.shani.subethaguide.png"
gtk-update-icon-cache -q -t "${ICON_DIR%/256x256/apps}" 2>/dev/null || true

if [ "$RESTART" = 1 ]; then
    echo "Restarting plasmashell..."
    if ! systemctl --user restart plasma-plasmashell.service 2>/dev/null; then
        (setsid plasmashell --replace >/dev/null 2>&1 &)
    fi
else
    echo "Restart the shell to load the new version:  ./install.sh --restart"
fi
