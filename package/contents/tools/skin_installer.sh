#!/bin/sh
# Installs, removes and lists Sub-Etha skins under
# ${XDG_DATA_HOME:-~/.local/share}/subetha/themes/<skinId>/.
#
#   skin_installer.sh install <tarballUrl> <skinId> [sha256]
#   skin_installer.sh remove <skinId>
#   skin_installer.sh list
#
# A skin is data only: skin.json (colours, typography, quips, sprite lists)
# with its images, preview.png and SVGs under assets/. The archive is checked
# before anything is extracted: no absolute paths, no "..", no links or
# devices; it is unpacked into a scratch directory beside the target and
# moved into place only once it is complete, so a failed install leaves the
# previous version untouched.
#
# list prints one line per installed skin:
# "<skinId><TAB><skin directory><TAB><skin.json on one line>".
# Exit status: 0 on success; errors go to stderr.
set -eu

THEMES="${XDG_DATA_HOME:-$HOME/.local/share}/subetha/themes"
MAX_BYTES=5242880   # 5 MiB: a palette, a thumbnail and some SVGs, nothing more

die() { echo "skin_installer: $*" >&2; exit 1; }

valid_id() {
    case "$1" in
        ""|.*|*[!a-z0-9._-]*) return 1 ;;
    esac
    [ "${#1}" -le 64 ]
}

fetch() {   # fetch <url> <file>
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --proto '=https' --max-time 120 --max-filesize "$MAX_BYTES" -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --https-only --timeout=120 -O "$2" "$1"
    else
        die "neither curl nor wget is installed"
    fi
}

install_skin() {
    url=$1 id=$2 sum=${3:-}
    valid_id "$id" || die "invalid skin id: $id"
    case "$url" in https://*) ;; *) die "only https:// archives are accepted" ;; esac

    mkdir -p "$THEMES"
    work=$(mktemp -d "$THEMES/.install-$id.XXXXXX")
    trap 'rm -rf "$work"' EXIT INT TERM
    archive="$work/skin.tar.gz"

    fetch "$url" "$archive" || die "download failed: $url"
    [ "$(wc -c < "$archive")" -le "$MAX_BYTES" ] || die "archive is larger than $MAX_BYTES bytes"
    if [ -n "$sum" ]; then
        got=$(sha256sum "$archive" | cut -d' ' -f1)
        [ "$got" = "$sum" ] || die "checksum mismatch (expected $sum, got $got)"
    fi

    # Only plain files and directories, all inside the archive root.
    tar -tvzf "$archive" > "$work/listing" || die "not a gzip tar archive"
    if cut -c1 "$work/listing" | grep -qv '[-d]'; then
        die "archive holds links or special files"
    fi
    tar -tzf "$archive" > "$work/names"
    if grep -qE '^/|(^|/)\.\.(/|$)' "$work/names"; then
        die "archive holds paths outside the skin directory"
    fi

    mkdir "$work/skin"
    tar -xzf "$archive" -C "$work/skin" --no-same-owner --no-same-permissions
    [ -f "$work/skin/skin.json" ] || die "archive has no skin.json at its root"

    rm -rf "${THEMES:?}/$id"
    mv "$work/skin" "$THEMES/$id"
}

remove_skin() {
    valid_id "$1" || die "invalid skin id: $1"
    rm -rf "${THEMES:?}/$1"
}

list_skins() {
    [ -d "$THEMES" ] || return 0
    for f in "$THEMES"/*/skin.json; do
        [ -f "$f" ] || continue
        id=$(basename "$(dirname "$f")")
        valid_id "$id" || continue
        printf '%s\t%s\t%s\n' "$id" "$THEMES/$id" "$(tr -d '\n\r\t' < "$f")"
    done
}

case "${1:-}" in
    install) [ $# -ge 3 ] || die "usage: $0 install <tarballUrl> <skinId> [sha256]"; install_skin "$2" "$3" "${4:-}" ;;
    remove)  [ $# -eq 2 ] || die "usage: $0 remove <skinId>"; remove_skin "$2" ;;
    list)    list_skins ;;
    *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
