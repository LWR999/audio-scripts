#!/bin/bash

# Initialize verbose flag
verbose=false
# ANSI color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse command line arguments
while getopts ":v" opt; do
  case ${opt} in
    v )
      verbose=true
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

# Check if path and genre parameters are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 [-v] <path> <genre>"
  exit 1
fi

target_dir="$1"
genre="$2"

# Function to capitalize first letter of each word and after periods
capitalize() {
  echo "$1" | sed -E '
    s/\b(.)/\u\1/g;
    s/\.(.)/.\u\1/g;
    s/'"'"'./\L&/g;
    s/\bFeat\./feat./g;
    s/\bFeaturing\b/feat./g;
  '
}

# Function to replace "featuring" with "feat." (case-insensitive)
replace_featuring() {
  echo "$1" | sed -E 's/\bfeaturing\b/feat./gi'
}

# Function to replace ' & ' with ' And ' or ' and '
replace_ampersand() {
  local string="$1"
  local replacement="$2"
  echo "$string" | sed "s/ & / ${replacement} /g"
}

# Function to clean and format album name
clean_album_name() {
  local name="$1"
  # Remove anything in [ ] and remove any 4 digit years in ()
  name=$(echo "$name" | sed -E 's/\[.*\]//g; s/\([0-9]{4}\)//g')
  # Remove any remaining () and []
  name=$(echo "$name" | tr -d '()[]')
  # Trim leading and trailing whitespace
  name=$(echo "$name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  # Apply capitalization rules
  name=$(replace_featuring "$name")
  name=$(capitalize "$name")
  name=$(replace_ampersand "$name" "And")
  echo "$name"
}

# Function to format artist name
format_artist_name() {
  local name="$1"
  name=$(replace_featuring "$name")
  name=$(capitalize "$name")
  name=$(replace_ampersand "$name" "and")
  echo "$name"
}

# Function to process a single directory
process_directory() {
  local dir_path="$1"
  local dir_name=$(basename "$dir_path")
  
  # Skip if doesn't contain " - " pattern
  if [[ "$dir_name" != *" - "* ]]; then
    echo "Directory '$dir_name' doesn't match the artist-album pattern (Artist - Album)."
    return
  fi
  
  local album_artist="${dir_name%% - *}"
  local album_name="${dir_name#* - *}"
  
  # Clean and format album name and artist
  album_name=$(clean_album_name "$album_name")
  album_artist=$(format_artist_name "$album_artist")
  
  echo -e "${RED}PROCESSING : $album_artist - $album_name${NC}"
  
  # Set compilation flag
  if [ "$album_artist" = "Various Artists" ]; then
    comp_flag="Y"
  else
    comp_flag="N"
  fi
  
  # Save current directory
  local current_dir=$(pwd)
  
  # Change to the directory
  cd "$dir_path" || return
  
  # Run setflactrackinfo.sh
  if $verbose; then
    echo "Running: setflactrackinfo.sh -v \"$album_name\" \"$album_artist\" \"$genre\" $comp_flag"
    setflactrackinfo.sh -v "$album_name" "$album_artist" "$genre" "$comp_flag"
    status=$?
  else
    echo "Running: setflactrackinfo.sh \"$album_name\" \"$album_artist\" \"$genre\" $comp_flag"
    setflactrackinfo.sh "$album_name" "$album_artist" "$genre" "$comp_flag"
    status=$?
  fi
  
  # Delete cover.jpg if processing was successful
  echo "Checking for cover.jpg file..."
  if [ -f "cover.jpg" ]; then
    echo "Found cover.jpg, removing it..."
    rm -v "cover.jpg"
    if [ ! -f "cover.jpg" ]; then
      echo "cover.jpg successfully removed."
    else
      echo "WARNING: Failed to remove cover.jpg!"
    fi
  else
    echo "No cover.jpg file found in this directory."
  fi
  
  # Change back to original directory
  cd "$current_dir" || return
  
  # Get parent directory of the processed directory
  local parent_dir=$(dirname "$dir_path")
  local new_dir_name="$album_artist - $album_name"
  
  # Rename the directory
  if [ "$dir_name" != "$new_dir_name" ]; then
    mv "$dir_path" "$parent_dir/$new_dir_name"
    echo "Renamed directory to: $new_dir_name"
    # Update dir_path for potential future use
    dir_path="$parent_dir/$new_dir_name"
  fi
  
  return 0
}

# Check if the path is a directory
if [ -d "$target_dir" ]; then
  # Process the specific directory
  process_directory "$(realpath "$target_dir")"
  echo "Directory processed."
else
  echo "Error: '$target_dir' is not a valid directory"
  exit 1
fi
