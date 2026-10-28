#!/usr/bin/env bash
# Bundle every community skin in skins/<id>/ into skins/dist/<id>.tar.gz and
# rewrite skins/registry.json from the skins' own skin.json, with each
# archive's sha256. Run before pushing to GitHub.
#
#   tools/package_skins.sh
#
# SKIN_BASE_URL overrides where the published files live (default: this
# repository's main branch on raw.githubusercontent.com).
#
# The archives are reproducible (sorted, zeroed owners and mtimes, gzip -n),
# so an unchanged skin keeps its hash and the registry diff stays quiet.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_URL="${SKIN_BASE_URL:-https://raw.githubusercontent.com/Shani2480/subetha-guide/main/skins}"
SKINS=skins
DIST="$SKINS/dist"
command -v jq >/dev/null || { echo "package_skins: jq is required" >&2; exit 1; }

rm -rf "$DIST"
mkdir -p "$DIST"
entries=()
for dir in "$SKINS"/*/; do
    id=$(basename "$dir")
    [ "$id" = dist ] && continue
    if ! [[ "$id" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]]; then
        echo "skip $id: ids are lowercase letters, digits, '.', '_' and '-'" >&2; continue
    fi
    if ! jq -e '.colors | type == "object"' "$dir/skin.json" >/dev/null 2>&1; then
        echo "skip $id: no skin.json with colors" >&2; continue
    fi

    archive="$DIST/$id.tar.gz"
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --format=gnu \
        -C "$dir" -cf - . | gzip -9n > "$archive"
    sum=$(sha256sum "$archive" | cut -d' ' -f1)
    preview=""
    [ -f "$dir/preview.png" ] && preview="$BASE_URL/$id/preview.png"

    entries+=("$(jq -c --arg id "$id" --arg preview "$preview" --arg tarball "$BASE_URL/dist/$id.tar.gz" --arg sum "$sum" \
        '{id: $id, name: (.name // $id), author: (.author // ""), version: (.version // "0"),
          description: (.description // ""), previewUrl: $preview, tarballUrl: $tarball, sha256: $sum}' "$dir/skin.json")")
    echo "packed $id -> $archive ($sum)"
done

printf '%s\n' "${entries[@]}" | jq -s '{schemaVersion: 1, skins: .}' > "$SKINS/registry.json"
echo "wrote $SKINS/registry.json (${#entries[@]} skins)"
