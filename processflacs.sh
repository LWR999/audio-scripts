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

# Check if genre parameter is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 [-v] <genre>"
    exit 1
fi

genre="$1"

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
    local dir="$1"
    local album_artist="${dir%% - *}"
    local album_name="${dir#* - }"

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

    # Change to the directory
    cd "$dir" || return

    # Run setflactrackinfo.sh
    if $verbose; then
        echo "Running: setflactrackinfo.sh -v \"$album_name\" \"$album_artist\" \"$genre\" $comp_flag"
        setflactrackinfo.sh -v "$album_name" "$album_artist" "$genre" "$comp_flag"
    else
        echo "Running: setflactrackinfo.sh \"$album_name\" \"$album_artist\" \"$genre\" $comp_flag"
        setflactrackinfo.sh "$album_name" "$album_artist" "$genre" "$comp_flag"
    fi

    # Change back to parent directory
    cd ..

    # Rename the directory
    new_dir_name="$album_artist - $album_name"
    if [ "$dir" != "$new_dir_name" ]; then
        mv "$dir" "$new_dir_name"
        echo "Renamed directory to: $new_dir_name"
    fi
}

# Main script
for dir in *" - "*; do
    if [ -d "$dir" ]; then
        process_directory "$dir"
    fi
done

echo "All directories processed."
