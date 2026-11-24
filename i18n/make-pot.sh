#!/bin/bash

# ============================================
# Based on https://github.com/step-/i18n-table
# Depends: GNU gawk, gsed, xgettext
# ============================================

cd "$(dirname "$0")" || exit 1

if [ "$(uname -s)" = "Darwin" ]
then
  export HOMEBREW_NO_ASK=1
  GSED="gsed"
  GAWK="gawk"
  if [ -z "$(command -v "$GSED")" ]
  then
    brew install gnu-sed || exit 1
  fi
  if [ -z "$(command -v xgettext)" ]
  then
    brew install gettext
  fi
  if [ -z "$(command -v "$GAWK")" ]
  then
    brew install gawk
  fi
else
  GSED="sed"
  GAWK="gawk"
  if [ -f /etc/os-release ]
  then
    . /etc/os-release
  fi
  if [ -z "$(command -v gettext)" ]
  then
    echo "installing gettext..."
    if [ "${ID:-}" == "centos" ]
    then
      yum -y install gettext
    else
      apt-get -y install gettext
    fi
  fi
fi

if [ -z "$(command -v gettext)" ] || [ -z "$(command -v xgettext)" ]
then
  echo "gettext / xgettext not found!"
  exit 1
fi

PACKAGE_NAME=aios.sh # aios.sh, v2.sh, x.sh, nx.sh, or.sh, cf.sh, ibm.sh, arm.sh, pve.sh
PACKAGE_POT_LANGUAGE=$1 # en, zh_CN
PACKAGE_PO_LANGUAGE=$2 # ru, de ...

XSRC=../docs/$PACKAGE_NAME

PACKAGE_VERSION=$(grep 'sh_ver="' < "$XSRC" | "$GAWK" -F "=" '{print $NF}' | "$GSED" 's/"//g' | head -1)
PACKAGE_TITLE="Locale ${PACKAGE_PO_LANGUAGE:-en} For $PACKAGE_NAME v$PACKAGE_VERSION"

restore_po_from_mo() # $1-po-path $2-mo-path
{
  local po_path=$1 mo_path=$2
  if [ ! -e "$po_path" ] && [ -e "$mo_path" ]
  then
    if [ -z "$(command -v msgunfmt)" ]
    then
      echo >&2 "${0##*/}: error: $po_path missing and msgunfmt not found to restore from $mo_path."
      exit 1
    fi
    mkdir -p "$(dirname "$po_path")"
    msgunfmt --no-wrap -o "$po_path" "$mo_path" || exit 1
  fi
}

if [ "$1" == "b" ]
then
  restore_po_from_mo "po/$PACKAGE_NAME-en.po" "po/$PACKAGE_NAME-en.mo"
  if [ ! -e "po/$PACKAGE_NAME-en.po" ]
  then
    echo >&2 "${0##*/}: error: po/$PACKAGE_NAME-en.po not found."
    exit 1
  fi

  "$GAWK" '
    BEGIN { RS=""; first=1 }
    {
      if (first) {
        first=0
        printf "%s\n\n", $0
        next
      }
      n = split($0, lines, "\n")
      meta = ""
      ms = ""
      state = ""
      for (i = 1; i <= n; i++) {
        l = lines[i]
        if (l ~ /^msgid "/) {
          state = "id"
          continue
        } else if (l ~ /^msgstr "/) {
          state = "str"
          ms = substr(l, 9, length(l) - 9)
          continue
        } else if (l ~ /^"/ && state != "") {
          if (state == "str") {
            ms = ms substr(l, 2, length(l) - 2)
          }
          continue
        } else {
          state = ""
          meta = meta l "\n"
        }
      }
      if (ms != "") {
        printf "%smsgid \"%s\"\nmsgstr \"\"\n\n", meta, ms
      }
    }
  ' "po/$PACKAGE_NAME-en.po" > "$PACKAGE_NAME.pot"
  msguniq --no-wrap -o "$PACKAGE_NAME.pot" "$PACKAGE_NAME.pot" || exit 1
  "$GSED" -i '
  {
    s~Locale .*$~'"$PACKAGE_TITLE"'~
    s~Project-Id-Version: .*$~Project-Id-Version: '"$PACKAGE_NAME"' '"$PACKAGE_VERSION"'\\n"~
  }' "$PACKAGE_NAME.pot"
  exit 0
fi

if [ -z "$PACKAGE_PO_LANGUAGE" ]
then
  echo >&2 "${0##*/}: error: one or more values not set or wrong.
usage: ${0##*/} [pot-language (en, zh_CN)] [po-language (ru, de ...)]"
  exit 1
fi

if [ "$PACKAGE_POT_LANGUAGE" != "en" ] && [ "$PACKAGE_POT_LANGUAGE" != "zh_CN" ]
then
  echo "pot-language must be en or zh_CN"
  exit 1
fi

# Output file name
FPOT=$PACKAGE_NAME-$PACKAGE_POT_LANGUAGE.pot
FPO=$PACKAGE_NAME-$PACKAGE_PO_LANGUAGE.po
FMO=$PACKAGE_NAME-$PACKAGE_PO_LANGUAGE.mo

# Input encoding
IENC=UTF-8
# Output encoding
OENC=UTF-8

PACKAGE_COPYRIGHT="GPL Version 3 License"
PACKAGE_FIRST_POT_AUTHOR="AIOS https://github.com/woniuzfb/aios"
PACKAGE_POT_CREATION_TZ="UTC"
PACKAGE_CHARSET="$OENC"
PACKAGE_POT_BUGS_ADDRESS="tg @woniuzfb"

if ! [ -e "$XSRC" ]
then
  echo >&2 "${0##*/}: error: file $XSRC not found."
  exit 1
fi

create_pot_file() # $1-pot-file $2...-xgettext-options
{
  local fpot=$1
  shift

  if ! scan_source_file "$XSRC" "$fpot" "$@"
  then
    echo >&2 "${0##*/}: ERRORS:scan_source_file '$XSRC'"
    exit 1
  fi
}

scan_source_file() # $1-filepath $2-potfile...-xgettext-options
{
  local f=$1 o=$2
  shift
  shift
  echo >&2 "scan_source_file $f"
  env TZ="$PACKAGE_POT_CREATION_TZ" \
    "$GSED" "s/\\$'\\\x80'-\\$'\\\xFF'//g" "$f" | xgettext ${IENC:+--from-code=$IENC} -L Shell "$@" --no-wrap -o "$o" \
      --package-name="$PACKAGE_NAME" \
      --package-version="$PACKAGE_VERSION" \
      --msgid-bugs-address="$PACKAGE_POT_BUGS_ADDRESS" -
  "$GSED" -i '
  {
    s~SOME DESCRIPTIVE TITLE~'"$PACKAGE_TITLE"'~
    s~Locale .*$~'"$PACKAGE_TITLE"'~
    s~YEAR THE PACKAGE.*$~'"$PACKAGE_COPYRIGHT"'~
    s~FIRST AUTHOR.*$~'"$PACKAGE_FIRST_POT_AUTHOR"'~
    s~Language: ~&'"$PACKAGE_PO_LANGUAGE"'~
    s~=CHARSET~='"$PACKAGE_CHARSET"'~
    s~'"$(printf '\xE2\x81\xA8')"'standard input'"$(printf '\xE2\x81\xA9')"'~'"$PACKAGE_NAME"'~g
  }' "$o"
}

remap_en_msgid_to_zh() # $1-target-po-file
{
  local target_po=$1
  local en_ref=""
  local tmp_en=""

  if [ -e "po/$PACKAGE_NAME-en.po" ]
  then
    en_ref="po/$PACKAGE_NAME-en.po"
  elif [ -e "po/$PACKAGE_NAME-en.mo" ] && [ -n "$(command -v msgunfmt)" ]
  then
    tmp_en=$(mktemp)
    if ! msgunfmt --no-wrap -o "$tmp_en" "po/$PACKAGE_NAME-en.mo"
    then
      rm -f "$tmp_en"
      return 1
    fi
    en_ref="$tmp_en"
  else
    return 0
  fi

  local tmp_out
  tmp_out=$(mktemp)
  if ! "$GAWK" '
    BEGIN { RS=""; SEP="\034" }
    NR == FNR {
      n = split($0, lines, "\n")
      mid = ""; mstr = ""; state = ""
      for (i = 1; i <= n; i++) {
        l = lines[i]
        if (l ~ /^msgid "/) {
          state = "id"
          mid = substr(l, 8, length(l) - 8)
        } else if (l ~ /^msgstr "/) {
          state = "str"
          mstr = substr(l, 9, length(l) - 9)
        } else if (l ~ /^"/ && state != "") {
          part = substr(l, 2, length(l) - 2)
          if (state == "id") mid = mid part
          else if (state == "str") mstr = mstr part
        } else {
          state = ""
        }
      }
      if (mid != "") {
        is_zh[mid] = 1
        if (mstr != "") {
          if (mstr in en2zh) {
            en2zh[mstr] = en2zh[mstr] SEP mid
          } else {
            en2zh[mstr] = mid
          }
        }
      }
      next
    }
    {
      n = split($0, lines, "\n")
      meta = ""; mid = ""; mstr = ""; state = ""; has_id = 0
      for (i = 1; i <= n; i++) {
        l = lines[i]
        if (l ~ /^msgid "/) {
          has_id = 1
          state = "id"
          mid = substr(l, 8, length(l) - 8)
        } else if (l ~ /^msgstr "/) {
          state = "str"
          mstr = substr(l, 9, length(l) - 9)
        } else if (l ~ /^"/ && state != "") {
          part = substr(l, 2, length(l) - 2)
          if (state == "id") mid = mid part
          else if (state == "str") mstr = mstr part
        } else {
          state = ""
          meta = meta l "\n"
        }
      }
      if (has_id && mid != "" && !(mid in is_zh) && (mid in en2zh)) {
        cnt = split(en2zh[mid], zh_list, SEP)
        for (j = 1; j <= cnt; j++) {
          printf "%smsgid \"%s\"\nmsgstr \"%s\"\n\n", meta, zh_list[j], mstr
        }
      } else {
        printf "%s\n\n", $0
      }
    }
  ' "$en_ref" "$target_po" > "$tmp_out"
  then
    rm -f "$tmp_out" "$tmp_en"
    return 1
  fi

  mv "$tmp_out" "$target_po"
  [ -n "$tmp_en" ] && rm -f "$tmp_en"
}

mkdir -p "po"

# Restore po/<lang>.po from tracked po/<lang>.mo if missing (e.g. fresh clone for en).
restore_po_from_mo "po/$FPO" "po/$FMO"

# When switching a translated non-English .po from English msgid back to zh_CN msgid,
# remap by exact English->Chinese 1-to-many dictionary lookup (multiline PO safe).
if [ "$PACKAGE_POT_LANGUAGE" == "zh_CN" ] && [ "$PACKAGE_PO_LANGUAGE" != "en" ] && [ -e "po/$FPO" ]
then
  remap_en_msgid_to_zh "po/$FPO" || exit 1
fi

if [ "$PACKAGE_POT_LANGUAGE" == "en" ]
then
  if [ ! -e "$PACKAGE_NAME.pot" ]
  then
    echo >&2 "${0##*/}: error: $PACKAGE_NAME.pot not found. Run '${0##*/} b' first."
    exit 1
  fi
  cp -f "$PACKAGE_NAME.pot" "$FPOT"
else
  create_pot_file "$FPOT"
fi

if ! [ -e "po/$FPO" ]
then
  cp -f "$FPOT" "po/$FPO"
else
  msgmerge --update -N --backup=none --no-wrap "po/$FPO" "$FPOT"
  msgattrib --no-obsolete --no-wrap -o "po/$FPO" "po/$FPO"
  "$GSED" -i '
  {
    s~Locale .*$~'"$PACKAGE_TITLE"'~
    s~Project-Id-Version: .*$~Project-Id-Version: '"$PACKAGE_NAME"' '"$PACKAGE_VERSION"'\\n"~
  }' "po/$FPO"
fi

if [ "$PACKAGE_POT_LANGUAGE" == "zh_CN" ]
then
  msgfmt --check -o "po/$FMO" "po/$FPO"
fi
