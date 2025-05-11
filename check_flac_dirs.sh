#!/bin/bash

# Usage: ./check_flac_dirs.sh /path/to/start [--info|--clean]
# Default action is --info

START_DIR="${1:-.}"
ACTION="${2:---info}"

if [[ ! -d "$START_DIR" ]]; then
  echo "Error: '$START_DIR' is not a valid directory."
  exit 1
fi

# Normalize path
START_DIR="$(realpath "$START_DIR")"

# Traverse all directories starting from $START_DIR
find "$START_DIR" -type d -not -name '_*' -print0 | while IFS= read -r -d '' dir; do
  # Skip if it has subdirectories (i.e., not a leaf)
  if find "$dir" -mindepth 1 -type d -not -name '_*' | grep -q .; then
    continue
  fi

  # Check if it contains any .flac files
  if ! find "$dir" -maxdepth 1 -type f -iname '*.flac' | grep -q .; then
    if [[ "$ACTION" == "--info" ]]; then
      echo "$dir"
    elif [[ "$ACTION" == "--clean" ]]; then
      echo "Removing: $dir"
      rm -rf "$dir"
    fi
  fi
done

