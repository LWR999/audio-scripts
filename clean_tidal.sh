#!/usr/bin/env bash
# Usage:
#   ./clean_tidal.sh [GENRE]
# Examples:
#   ./clean_tidal.sh Rock     # "[Unknown]" -> "[Rock]"
#   ./clean_tidal.sh          # "[Unknown]" -> "[Jazz]" (default)

set -Eeuo pipefail

genre="${1:-Jazz}"
replacement="[$genre]"

# Iterate over top-level directories only
while IFS= read -r -d '' path; do
  # Strip leading "./" for cleaner names
  dir="${path#./}"
  new="$dir"

  # Replace [MP4] -> [FLAC]
  new="${new//\[MP4]/[FLAC]}"
  # Replace [Unknown] -> [$genre]
  new="${new//\[Unknown]/$replacement}"

  # Only attempt rename if name changed
  if [[ "$new" != "$dir" ]]; then
    # Avoid clobbering existing paths
    if [[ -e "$new" ]]; then
      echo "SKIP: '$dir' → '$new' (target exists)"
    else
      mv -- "$dir" "$new"
      echo "RENAMED: '$dir' → '$new'"
    fi
  fi
done < <(find . -mindepth 1 -maxdepth 1 -type d -print0)

