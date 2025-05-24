#!/bin/bash

# Initialize verbose flag
verbose=false

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

# Check if required arguments are provided
if [ $# -ne 4 ]; then
    echo "Usage: $0 [-v] <album_name> <album_artist> <genre> <compilation_flag Y/N>"
    exit 1
fi

album_name="$1"
album_artist="$2"
genre="$3"
compilation_flag="$4"

# Convert compilation flag to 1 or 0
if [[ "$compilation_flag" =~ ^[Yy]$ ]]; then
    compilation="1"
else
    compilation="0"
fi

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

replace_ampersand() {
    local string="$1"
    local replacement="$2"
    echo "$string" | sed "s/ & / ${replacement} /g"
}

# Function to resize and create _embed.jpg
resize_image() {
    local original="$1"
    local embed="${original%.*}_embed.jpg"
    
    # Get original dimensions
    local orig_dimensions=$(identify -format "%wx%h" "$original")
    
    # Resize only if larger than 1400x1400
    if [[ $(identify -format "%[fx:w>1400||h>1400?1:0]" "$original") -eq 1 ]]; then
        convert "$original" -resize 1400x1400\> -density 72 -units PixelsPerInch -strip -quality 85 "$embed"
    else
        convert "$original" -density 72 -units PixelsPerInch -strip -quality 85 "$embed"
    fi
    
    # Compare file sizes
    local orig_size=$(stat -c%s "$original")
    local new_size=$(stat -c%s "$embed")
    
    echo "Original: $orig_dimensions, ${orig_size} bytes" >&2
    echo "New: $(identify -format "%wx%h" "$embed"), ${new_size} bytes" >&2
    
    echo "$embed"
}

# Function to embed artwork
embed_artwork() {
    local flac_file="$1"
    local original_jpg="$2"
    local embed_jpg

    # Check if files exist
    if [ ! -f "$flac_file" ]; then
        echo "Error: FLAC file $flac_file not found."
        return 1
    fi
    if [ ! -f "$original_jpg" ]; then
        echo "Error: Original JPEG file $original_jpg not found."
        return 1
    fi

    # Create embedded jpg
    embed_jpg=$(resize_image "$original_jpg")

    # Get file sizes
    original_size=$(stat -c%s "$original_jpg")
    embed_size=$(stat -c%s "$embed_jpg")

    # Choose smaller file
    if [ "$embed_size" -lt "$original_size" ]; then
        smaller_jpg="$embed_jpg"
    else
        smaller_jpg="$original_jpg"
    fi

    echo "Attempting to embed artwork from $smaller_jpg into $flac_file"

    # Remove existing pictures and embed new one
    metaflac --remove --block-type=PICTURE --dont-use-padding "$flac_file" 2>&1 || echo "Warning: Failed to remove existing artwork from $flac_file"

    metaflac --import-picture-from="3||||$smaller_jpg" "$flac_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to embed artwork into $flac_file"
        echo "Command used: metaflac --import-picture-from=\"3||||$smaller_jpg\" \"$flac_file\""
        return 1
    fi

    echo "Successfully embedded artwork from $smaller_jpg into $flac_file"
}

# Calculate total number of tracks and discs
total_tracks=$(metaflac --show-tag=TRACKNUMBER *.flac | sed 's/[^=]*=//' | sort -n | tail -n 1)
total_discs=$(metaflac --show-tag=DISCNUMBER *.flac | sed 's/[^=]*=//' | sort -n | tail -n 1)

# Remove leading zeros and set default to 1 if empty
total_tracks=$(echo "$total_tracks" | sed 's/^0*//')
total_tracks=${total_tracks:-1}

total_discs=$(echo "$total_discs" | sed 's/^0*//')
total_discs=${total_discs:-1}

if $verbose; then
    echo "Total tracks: $total_tracks"
    echo "Total discs: $total_discs"
fi

# Main processing
jpeg_file=$(find . -maxdepth 1 -type f -iname "*.jpg" -o -iname "*.jpeg" | head -n 1)

if [ -z "$jpeg_file" ]; then
    echo "No JPEG file found in the current directory."
    exit 1
fi

# Process each FLAC file
for file in *.flac; do
    if $verbose; then
        echo "Processing file: $file"
    fi

    # Get current disc and track number
    disc_number=$(metaflac --show-tag=DISCNUMBER "$file" | sed 's/[^0-9]*//g')
    track_number=$(metaflac --show-tag=TRACKNUMBER "$file" | sed 's/[^0-9]*//g')
    
    # Remove leading zeros
    disc_number=$(echo "$disc_number" | sed 's/^0*//')
    track_number=$(echo "$track_number" | sed 's/^0*//')
    
    # Set to 1 if empty
    disc_number=${disc_number:-1}
    track_number=${track_number:-1}

    # Get and process track name and artist
    old_track_name=$(metaflac --show-tag=TITLE "$file" | sed 's/[^=]*=//')
    old_artist=$(metaflac --show-tag=ARTIST "$file" | sed 's/[^=]*=//')
    
    track_name=$(replace_featuring "$old_track_name")
    track_name=$(capitalize "$track_name")
    track_name=$(replace_ampersand "$track_name" "And")
    
    artist=$(replace_featuring "$old_artist")
    artist=$(capitalize "$artist")
    artist=$(replace_ampersand "$artist" "and")

    if $verbose; then
        echo "  Disc number: $disc_number"
        echo "  Track number: $track_number"
        echo "  Old track name: $old_track_name"
        echo "  New track name: $track_name"
        echo "  Old artist: $old_artist"
        echo "  New artist: $artist"
        echo "  Album name: $album_name"
        echo "  Album artist: $album_artist"
        echo "  Genre: $genre"
        echo "  Compilation: $compilation"
    fi

    # Set metadata
    metaflac --remove-all-tags \
             --set-tag="TITLE=$track_name" \
             --set-tag="ARTIST=$artist" \
             --set-tag="ALBUM=$album_name" \
             --set-tag="ALBUMARTIST=$album_artist" \
             --set-tag="GENRE=$genre" \
             --set-tag="COMPILATION=$compilation" \
             --set-tag="TRACKNUMBER=$track_number" \
             --set-tag="TRACKTOTAL=$total_tracks" \
             --set-tag="DISCNUMBER=$disc_number" \
             --set-tag="DISCTOTAL=$total_discs" \
             "$file"

    # Embed artwork
    embed_artwork "$file" "$jpeg_file"
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to embed artwork in $file"
    fi

    echo "Updated: $file"
    if $verbose; then
        echo "--------------------"
    fi
done

# Clean up the _embed.jpg file
embed_jpg="${jpeg_file%.*}_embed.jpg"
if [ -f "$embed_jpg" ]; then
    rm -f "$embed_jpg"
    echo "Removed temporary file: $embed_jpg"
fi

echo "All files processed."
