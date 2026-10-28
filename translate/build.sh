#!/usr/bin/env bash
# Translations for The Sub-Etha Guide.
#
#   ./translate/build.sh            refresh template.pot from the sources,
#                                   merge it into every <lang>.po and compile
#                                   them into package/contents/locale/
#   ./translate/build.sh --compile  only compile the .po files as they are
#
# To add a language: msginit -i translate/template.pot -o translate/<lang>.po -l <lang>
set -euo pipefail
cd "$(dirname "$0")/.."

DOMAIN="plasma_applet_com.shani.subethaguide"
COMPILE_ONLY=0
[ "${1:-}" = "--compile" ] && COMPILE_ONLY=1

if [ "$COMPILE_ONLY" = 0 ]; then
    find package/contents/ui package/contents/config -name '*.qml' -o -name '*.js' | sort > translate/.files
    xgettext --from-code=UTF-8 -L JavaScript -f translate/.files -o translate/template.pot \
        --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
        --package-name="The Sub-Etha Guide" --msgid-bugs-address="shani248@gmail.com" \
        --add-comments=i18n --no-location 2>/dev/null
    rm -f translate/.files
    echo "template.pot: $(grep -c '^msgid ' translate/template.pot) strings"
fi

for po in translate/*.po; do
    [ -e "$po" ] || continue
    lang=$(basename "$po" .po)
    [ "$COMPILE_ONLY" = 0 ] && msgmerge --quiet --update --backup=none "$po" translate/template.pot
    out="package/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$out"
    msgfmt --check -o "$out/$DOMAIN.mo" "$po"
    echo "$lang: $(msgfmt --statistics -o /dev/null "$po" 2>&1)"
done
