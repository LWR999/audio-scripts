#!/usr/bin/env bash
# flactags.sh — Inspect or overwrite a specific Vorbis/FLAC tag on .flac files in a directory.
#
# MODES
#   -i  Inspect: print "<abs_path>\t<tag_value or (none)>". Optional regex filter on value.
#   -o  Overwrite: if value matches <regex>, rewrite tag (replacement may be empty '').
#   -n  Dry-run overwrite: same as -o but no writes.
#
# FLAGS
#   -r | --recursive        Recurse into subdirectories (default: no).
#   -d | --delete-on-match  With -o/-n: delete the tag entirely instead of rewriting.
#        --stats            Print summary counts to stderr.
#        --hide-missing     Don’t print “(no tag) — skipped”.
#        --hide-nomatch     Don’t print “(no match) — kept: …”.
#        --quiet            Same as --hide-missing + --hide-nomatch.
#
# NOTES
#   • Tag KEY match is case-insensitive (LOCATION == Location == location).
#   • Multiple values for the same key are joined with ';' for matching/rewrite.
#   • Non-recursive scans only files directly in <path>. Recursive scans all levels.
#   • Symlinks are NOT followed.
#
# USAGE
#   flactags.sh -i <path> <tag> [<regex>] [-r|--recursive] [--stats] [--quiet|--hide-missing|--hide-nomatch]
#   flactags.sh -o <path> <tag> <regex> <replacement> [-r] [-d] [--stats] [--quiet|--hide-missing|--hide-nomatch]
#   flactags.sh -n <path> <tag> <regex> <replacement> [-r] [-d] [--stats] [--quiet|--hide-missing|--hide-nomatch]
#
# EXIT CODES: 0 ok, 1 usage/deps/mode error, 2 <path> not a directory.

set -Eeuo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  flactags.sh -i <path> <tag> [<regex>] [-r|--recursive] [--stats] [--quiet|--hide-missing|--hide-nomatch]
  flactags.sh -o <path> <tag> <regex> <replacement> [-r|--recursive] [-d|--delete-on-match] [--stats] [--quiet|--hide-missing|--hide-nomatch]
  flactags.sh -n <path> <tag> <regex> <replacement> [-r|--recursive] [-d|--delete-on-match] [--stats] [--quiet|--hide-missing|--hide-nomatch]
EOF
  exit 1
}

die() { echo "Error: $*" >&2; exit 1; }

[[ $# -ge 3 ]] || usage

MODE="$1"; BASE="$2"; TAG_INPUT="$3"

# Defaults / flags
REGEX_SEARCH=""
REGEX_CHANGE=""
DELETE_ON_MATCH=0
RECURSIVE=0
STATS=0
HIDE_MISSING=0
HIDE_NOMATCH=0

command -v metaflac >/dev/null 2>&1 || die "'metaflac' not found. Install FLAC tools."
[[ -d "$BASE" ]] || exit 2

# Absolute base path
if command -v realpath >/dev/null 2>&1; then
  BASE_ABS="$(realpath "$BASE")"
else
  pushd "$BASE" >/dev/null || die "cannot enter base directory"
  BASE_ABS="$(pwd -P)"
  popd >/dev/null || true
fi

shift 3

parse_common_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r|--recursive) RECURSIVE=1 ;;
      -d|--delete-on-match) DELETE_ON_MATCH=1 ;;
      --stats) STATS=1 ;;
      --hide-missing) HIDE_MISSING=1 ;;
      --hide-nomatch) HIDE_NOMATCH=1 ;;
      --quiet) HIDE_MISSING=1; HIDE_NOMATCH=1 ;;
      *) die "unknown option '$1'";;
    esac
    shift
  done
}

case "$MODE" in
  -i)
    if [[ $# -gt 0 && "${1:-}" != -* ]]; then REGEX_SEARCH="$1"; shift; fi
    parse_common_flags "$@"
    ;;
  -o|-n)
    [[ $# -ge 2 ]] || usage
    REGEX_SEARCH="$1"; REGEX_CHANGE="${2-}"; shift 2
    parse_common_flags "$@"
    ;;
  *)
    die "invalid mode '$MODE' (use -i, -o, or -n)"
    ;;
esac

# Read tag(s) case-insensitively; join multiple with ';'
read_tag_joined() {
  local f="$1" t="$2"
  metaflac --export-tags-to=- "$f" 2>/dev/null \
    | awk -v tt="$t" 'BEGIN{IGNORECASE=1}
        { p=index($0,"="); if(p>1){
            key=substr($0,1,p-1); val=substr($0,p+1);
            if (tolower(key)==tolower(tt)) print val;
          }}' \
    | paste -sd ';' -
}

# Escape '/' for sed delimiter
escape_sed_delims() { sed 's,/,\\/,g' <<<"$1"; }

# Build the find command (no symlinks)
if [[ "$RECURSIVE" -eq 1 ]]; then
  FIND=(find "$BASE_ABS" -type f -iname '*.flac')
else
  FIND=(find "$BASE_ABS" -mindepth 1 -maxdepth 1 -type f -iname '*.flac')
fi

# Optional stats
STATS_FILE=""
if [[ "$STATS" -eq 1 ]]; then
  STATS_FILE="$(mktemp -t flactags.XXXXXX)"
  export FLACTAGS_STATS="$STATS_FILE"
fi

# Helpers used inside the per-file worker
export MODE TAG_INPUT REGEX_SEARCH REGEX_CHANGE DELETE_ON_MATCH HIDE_MISSING HIDE_NOMATCH
export -f read_tag_joined escape_sed_delims

process_one() {
  local f="$1"
  local vals old_vals new_vals
  [[ -n "${FLACTAGS_STATS:-}" ]] && echo scanned >>"$FLACTAGS_STATS"

  if [[ "$MODE" == "-i" ]]; then
    vals="$(read_tag_joined "$f" "$TAG_INPUT")" || vals=""
    if [[ -z "$vals" ]]; then
      [[ -n "${FLACTAGS_STATS:-}" ]] && echo no_tag >>"$FLACTAGS_STATS"
      vals="(none)"
    else
      [[ -n "${FLACTAGS_STATS:-}" ]] && echo with_tag >>"$FLACTAGS_STATS"
    fi

    if [[ -n "$REGEX_SEARCH" ]]; then
      if grep -E -q -- "$REGEX_SEARCH" <<<"$vals"; then
        printf "%s\t%s\n" "$f" "$vals"
        [[ -n "${FLACTAGS_STATS:-}" ]] && { echo matched >>"$FLACTAGS_STATS"; echo printed >>"$FLACTAGS_STATS"; }
      else
        [[ -n "${FLACTAGS_STATS:-}" ]] && echo kept_nomatch >>"$FLACTAGS_STATS"
      fi
    else
      printf "%s\t%s\n" "$f" "$vals"
      [[ -n "${FLACTAGS_STATS:-}" ]] && echo printed >>"$FLACTAGS_STATS"
    fi
    return 0
  fi

  # overwrite / dry-run
  old_vals="$(read_tag_joined "$f" "$TAG_INPUT")" || old_vals=""
  if [[ -z "$old_vals" ]]; then
    [[ "$HIDE_MISSING" -eq 0 ]] && printf "%s\t(no tag) — skipped\n" "$f"
    [[ -n "${FLACTAGS_STATS:-}" ]] && echo no_tag >>"$FLACTAGS_STATS"
    return 0
  else
    [[ -n "${FLACTAGS_STATS:-}" ]] && echo with_tag >>"$FLACTAGS_STATS"
  fi

  if ! grep -E -q -- "$REGEX_SEARCH" <<<"$old_vals"; then
    [[ "$HIDE_NOMATCH" -eq 0 ]] && printf "%s\t(no match) — kept: %s\n" "$f" "$old_vals"
    [[ -n "${FLACTAGS_STATS:-}" ]] && echo kept_nomatch >>"$FLACTAGS_STATS"
    return 0
  fi
  [[ -n "${FLACTAGS_STATS:-}" ]] && echo matched >>"$FLACTAGS_STATS"

  if [[ "$DELETE_ON_MATCH" -eq 1 ]]; then
    if [[ "$MODE" == "-n" ]]; then
      printf "%s\tDRY-RUN: would DELETE tag '%s' (was: %s)\n" "$f" "$TAG_INPUT" "$old_vals"
    else
      metaflac --remove-tag="$TAG_INPUT" "$f"
      printf "%s\tdeleted tag '%s' (was: %s)\n" "$f" "$TAG_INPUT" "$old_vals"
    fi
    [[ -n "${FLACTAGS_STATS:-}" ]] && echo deleted >>"$FLACTAGS_STATS"
    return 0
  fi

  local search_esc change_esc
  search_esc="$(escape_sed_delims "$REGEX_SEARCH")"
  change_esc="$(escape_sed_delims "$REGEX_CHANGE")"
  new_vals="$(sed -E "s/${search_esc}/${change_esc}/g" <<<"$old_vals")"

  if [[ "$new_vals" == "$old_vals" ]]; then
    printf "%s\t(match but unchanged) — kept: %s\n" "$f" "$old_vals"
    [[ -n "${FLACTAGS_STATS:-}" ]] && echo unchanged >>"$FLACTAGS_STATS"
    return 0
  fi

  if [[ "$MODE" == "-n" ]]; then
    printf "%s\tDRY-RUN: would update: %s -> %s\n" "$f" "$old_vals" "$new_vals"
  else
    metaflac --remove-tag="$TAG_INPUT" "$f"
    metaflac --set-tag="$TAG_INPUT=$new_vals" "$f"
    printf "%s\tupdated: %s -> %s\n" "$f" "$old_vals" "$new_vals"
  fi
  [[ -n "${FLACTAGS_STATS:-}" ]] && echo updated >>"$FLACTAGS_STATS"
}
export -f process_one

# Process files one-by-one
"${FIND[@]}" -exec bash -c 'process_one "$1"' _ {} \;

# Stats footer
if [[ -n "${FLACTAGS_STATS:-}" && -s "$FLACTAGS_STATS" ]]; then
  awk '
    {count[$1]++}
    END{
      print "---- flactags stats ('"${MODE}"')" ;
      printf "Files scanned:     %d\n", count["scanned"];
      printf "Files with tag:    %d\n", count["with_tag"];
      printf "Files without tag: %d\n", count["no_tag"];
      printf "Matched:           %d\n", count["matched"];
      printf "Deleted:           %d\n", count["deleted"];
      printf "Updated:           %d\n", count["updated"];
      printf "Unchanged:         %d\n", count["unchanged"];
      printf "Kept (no match):   %d\n", count["kept_nomatch"];
      if ("'"$MODE"'" == "-i") {
        printf "Printed:           %d\n", count["printed"];
      }
    }' "$FLACTAGS_STATS" >&2
  rm -f -- "$FLACTAGS_STATS"
fi

