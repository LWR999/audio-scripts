#!/bin/bash

get_flac_info() {
    local file="$1"
    
    # Get metadata
    artist=$(metaflac --show-tag=ARTIST "$file" | sed 's/[^=]*=//')
    album_artist=$(metaflac --show-tag=ALBUMARTIST "$file" | sed 's/[^=]*=//')
    title=$(metaflac --show-tag=TITLE "$file" | sed 's/[^=]*=//')
    genre=$(metaflac --show-tag=GENRE "$file" | sed 's/[^=]*=//')
    track_number=$(metaflac --show-tag=TRACKNUMBER "$file" | sed 's/[^=]*=//')
    total_tracks=$(metaflac --show-tag=TRACKTOTAL "$file" | sed 's/[^=]*=//')
    disc_number=$(metaflac --show-tag=DISCNUMBER "$file" | sed 's/[^=]*=//')
    total_discs=$(metaflac --show-tag=DISCTOTAL "$file" | sed 's/[^=]*=//')
    compilation=$(metaflac --show-tag=COMPILATION "$file" | sed 's/[^=]*=//')
    
    # Get technical info
    sample_rate=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$file")
    bit_depth=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=bits_per_raw_sample -of default=noprint_wrappers=1:nokey=1 "$file")

    # Set default values if empty
    track_number=${track_number:-0}
    total_tracks=${total_tracks:-0}
    disc_number=${disc_number:-1}
    total_discs=${total_discs:-1}
    
    # Set compilation flag
    if [ "$compilation" = "1" ]; then
        compilation="C"
    else
        compilation=" "
    fi

    # Format track and disc information
    track_disc_info="${track_number} of ${total_tracks} / ${disc_number} of ${total_discs}"
    tech_info="${sample_rate}/${bit_depth}"

    # Output formatted line
    printf "%s %s %s %s    %s    %s / %s\n" \
        "$track_disc_info" \
        "$tech_info" \
        "$compilation" \
        "$genre" \
        "$title" \
        "$artist" \
        "$album_artist"
}

# Check if a filename was provided as an argument
if [ $# -eq 1 ]; then
    if [ -f "$1" ]; then
        get_flac_info "$1"
    else
        echo "File not found: $1"
        exit 1
    fi
else
    # If no argument, process all .flac files in the current directory
    for file in *.flac; do
        if [ -f "$file" ]; then
            get_flac_info "$file"
        fi
    done
fi
