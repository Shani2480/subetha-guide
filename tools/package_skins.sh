#!/usr/bin/env bash
# Validate every skin in skins/<id>/ against the 2.0.0 skin contract, bundle
# each into skins/dist/<id>.tar.gz and rewrite skins/registry.json from the
# skins' own skin.json, with each archive's sha256. Run before pushing to
# GitHub. A skin that fails validation stops the run, so a broken one never
# reaches the registry.
#
#   tools/package_skins.sh
#
# SKIN_BASE_URL overrides where the published files live (default: this
# repository's main branch on raw.githubusercontent.com).
#
# A skin marked "builtin" (h2g2, which both apps draw themselves) is
# validated and listed, but has no archive: the Theme Store offers only
# entries with a tarballUrl.
#
# The archives are reproducible (sorted, zeroed owners and mtimes, gzip -n),
# so an unchanged skin keeps its hash and the registry diff stays quiet.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_URL="${SKIN_BASE_URL:-https://raw.githubusercontent.com/Shani2480/subetha-guide/main/skins}"
SKINS=skins
DIST="$SKINS/dist"
command -v jq >/dev/null || { echo "package_skins: jq is required" >&2; exit 1; }

# The 2.0.0 contract. Each failure is printed as "<id>: <what>".
read -r -d '' SCHEMA <<'JQ' || true
def color: type == "string" and test("^(#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})|rgba?\\(\\s*\\d{1,3}\\s*,\\s*\\d{1,3}\\s*,\\s*\\d{1,3}\\s*(,\\s*[0-9.]+\\s*)?\\))$");
def asset: type == "string" and test("^[A-Za-z0-9_-]+(/[A-Za-z0-9_-][A-Za-z0-9_.-]*)*\\.(svg|png)$");
def oneof($xs): . as $v | $xs | index([$v]) != null;
def need($cond; $msg): if $cond then empty else $msg end;
["background", "cardBackground", "cardBackgroundHover", "textPrimary", "textSecondary", "accent",
 "accentSecondary", "border", "gaugeTrack", "gaugeUsage", "gaugeTemp", "badgeBackground", "badgeText"] as $colors
| ["enableCrtScanlines", "enablePhosphorDecay", "enableCornerBrackets", "enableGlassBlur"] as $features
| (.builtin == true) as $builtin
| need(.id == $id; "id must be the folder name, \($id)"),
  need((.name | type) == "string" and (.name | length) > 0; "name is required"),
  need(.version | type == "string" and test("^2\\.[0-9]+\\.[0-9]+$"); "version must be 2.x.y (the contract this validates), not \(.version)"),
  need((.fontFamily | type) == "string" and (.fontFamily | length) > 0; "fontFamily is required (a CSS-style list)"),
  need((.fonts // []) | type == "array" and all(.[]; type == "string" and test("^[A-Za-z0-9_/.-]+\\.(ttf|otf)$")); "fonts: ttf/otf paths"),
  need((.features | type) == "object"; "features is required"),
  ($features[] as $f | need((.features[$f] | type) == "boolean"; "features.\($f) must be true or false")),
  need((.geometry | type) == "object"; "geometry is required"),
  need((.geometry.cardShape // "rounded") | oneof(["rounded", "chamfer", "sharp", "stadium", "custom"]); "geometry.cardShape"),
  need((.geometry.pillShape // "rounded") | oneof(["rounded", "chamfer", "sharp", "stadium"]); "geometry.pillShape"),
  need(.geometry.gaugeShape | oneof(["wavy", "segmented", "stadium", "chamfer", "flat", "analog-dial"]); "geometry.gaugeShape: wavy, segmented, stadium, chamfer, flat or analog-dial"),
  need((.chrome.style // "plain") | oneof(["luna", "aqua", "aero", "material", "terminal", "kiroshi", "hud", "plain"]); "chrome.style"),
  need((.sections.style // "card") | oneof(["card", "groupband", "gadget", "flagtab"]); "sections.style: card, groupband, gadget or flagtab"),
  need((.controls.meter // "") | oneof(["", "bevel", "ascii", "gadget", "angled", "slime"]); "controls.meter: bevel, ascii, gadget, angled or slime"),
  need(((.icons // {}) | to_entries | all(.value | type == "string" and test("^[A-Za-z0-9_/.-]+\\.svg$"))); "icons: svg paths"),
  need(([.variants[]?.icons // {} | .[]] | all(type == "string" and test("^[A-Za-z0-9_/.-]+\\.svg$"))); "variants.*.icons: svg paths"),
  need((.sections.lights // "traffic") | oneof(["traffic"]); "sections.lights: traffic"),
  need((.sections.toggle // "angled") | oneof(["angled", "glass", "box"]); "sections.toggle: angled, glass or box"),
  (["dark", "light"][] as $v
   | need((.variants[$v] | type) == "object"; "variants.\($v) is required"),
     ($colors[] as $c | need(.variants[$v][$c] | color; "variants.\($v).\($c) must be a colour"))),
  need((.narrative | type) == "object"; "narrative is required"),
  need((.narrative.badgeLabel | type) == "string" and (.narrative.badgeLabel | length) <= 40; "narrative.badgeLabel (at most 40 characters)"),
  (["weatherSkyHazard", "roamerPrimary", "roamerSecondary"][] as $k
   | need($builtin or (.narrative[$k] | asset); "narrative.\($k) must be an svg/png inside the skin")),
  need((.narrative.weatherSkyHazardSecondary == null) or $builtin or (.narrative.weatherSkyHazardSecondary | asset); "narrative.weatherSkyHazardSecondary"),
  (["nominal", "critical"][] as $q | need(.narrative.quips[$q] | type == "string" and length > 0; "narrative.quips.\($q) is required"))
JQ

rm -rf "$DIST"
mkdir -p "$DIST"
entries=()
failed=0
for dir in "$SKINS"/*/; do
    id=$(basename "$dir")
    [ "$id" = dist ] && continue
    if ! [[ "$id" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]]; then
        echo "$id: ids are lowercase letters, digits, '.', '_' and '-'" >&2; failed=1; continue
    fi
    if ! jq -e 'type == "object"' "$dir/skin.json" >/dev/null 2>&1; then
        echo "$id: no readable skin.json" >&2; failed=1; continue
    fi
    problems=$(jq -r --arg id "$id" "$SCHEMA" "$dir/skin.json")
    # every file the skin names must be in it
    while read -r rel; do
        [ -n "$rel" ] && [ ! -f "$dir/$rel" ] && problems+=$'\n'"missing file $rel"
    done < <(jq -r 'select(.builtin != true) | [.fonts[]?, .narrative.weatherSkyHazard, .narrative.weatherSkyHazardSecondary,
                     .narrative.roamerPrimary, .narrative.roamerSecondary, (.roamers[]?.frames[]?), (.icons // {} | .[]),
                     .chrome.logo, .chrome.badge, .frame.tubes, .frame.siren, .frame.portal, .frame.toolbelt, .frame.decorations, .frame.hudLeft, .frame.hudRight, (.narrative.vignettes // [] | .[].art), .sections.gear, .sections.close, .controls.dialRim, (.art // {} | .[]), (.variants[]?.art // {} | .[]), .sections.flagMark, .footer.mark, .footer.endMark, (.variants[]?.icons // {} | .[])]
                    | map(select(type == "string")) | .[]' "$dir/skin.json")
    problems=$(sed '/^$/d' <<<"$problems")
    if [ -n "$problems" ]; then
        sed "s/^/$id: /" <<<"$problems" >&2; failed=1; continue
    fi

    if jq -e '.builtin == true' "$dir/skin.json" >/dev/null; then
        entries+=("$(jq -c '{id, name, author: (.author // ""), version, description: (.description // ""), builtin: true}' "$dir/skin.json")")
        echo "listed $id (built in)"
        continue
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
if [ "$failed" = 1 ]; then
    echo "package_skins: fix the skins above; registry.json left as it was" >&2
    exit 1
fi

printf '%s\n' "${entries[@]}" | jq -s '{schemaVersion: 2, skins: .}' > "$SKINS/registry.json"
echo "wrote $SKINS/registry.json (${#entries[@]} skins)"
