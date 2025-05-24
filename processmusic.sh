#!/bin/bash

# Initialize verbose flag
verbose=false
# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
  echo "Usage: $0 [-v] [-h] <root_directory> <genre>"
  echo "Process all music album directories within a root directory."
  echo ""
  echo "Options:"
  echo "  -v    Enable verbose mode"
  echo "  -h    Display this help message"
  echo ""
  echo "Arguments:"
  echo "  root_directory    Directory containing album folders to process"
  echo "  genre             Genre to apply to all albums (fallback if not found in folder name)"
  echo ""
  echo "Example:"
  echo "  $0 -v /home/user/downloads/new_music \"Jazz\""
}

# Parse command line arguments
while getopts ":vh" opt; do
  case ${opt} in
    v )
      verbose=true
      ;;
    h )
      show_help
      exit 0
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      show_help
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# Check if required parameters are provided
if [ $# -ne 2 ]; then
  echo "Error: Missing required parameters."
  show_help
  exit 1
fi

root_dir="$1"
genre="$2"

# Check if root directory exists
if [ ! -d "$root_dir" ]; then
  echo "Error: '$root_dir' is not a valid directory"
  exit 1
fi

# Check if processalbum.sh exists and is executable
if ! command -v processalbum.sh &> /dev/null; then
  echo "Error: processalbum.sh not found in PATH or not executable"
  echo "Make sure processalbum.sh is in your PATH and has executable permissions"
  exit 1
fi

echo -e "${GREEN}Starting music processing in: $root_dir${NC}"
echo -e "${GREEN}Default genre (if none found in directory name): $genre${NC}"
echo ""

# Check if we're in a directory with both _CD and _Hires folders
has_cd_hires_dirs=false
if [ -d "$root_dir/_CD" ] && [ -d "$root_dir/_Hires" ]; then
  has_cd_hires_dirs=true
  echo -e "${GREEN}Detected _CD and _Hires directories. Will sort albums after processing.${NC}"
fi

# Initialize counters and arrays
processed_count=0
error_count=0
skipped_count=0
flattened_count=0
moved_to_hires=0
moved_to_cd=0
declare -A quality_map

# Check for empty counters and set defaults
: ${processed_count:=0}
: ${error_count:=0}
: ${skipped_count:=0}
: ${flattened_count:=0}
: ${moved_to_hires:=0}
: ${moved_to_cd:=0}

# Function to check if directory contains FLAC files
has_flac_files() {
  local dir_path="$1"
  # Check if directory contains any .flac files (case-insensitive)
  if find "$dir_path" -maxdepth 1 -type f -iname "*.flac" | grep -q .; then
    return 0  # true - has FLAC files
  else
    return 1  # false - no FLAC files
  fi
}

# Function to check if directory has disc subfolders
has_disc_subfolders() {
  local dir_path="$1"
  # Check for directories matching disc patterns: Disc*, CD*, CDx
  if find "$dir_path" -maxdepth 1 -type d \( -iname "disc*" -o -iname "cd*" \) | grep -q .; then
    return 0  # true - has disc subfolders
  else
    return 1  # false - no disc subfolders
  fi
}

# Function to check if folder should be preserved (artwork, scans)
is_preserved_folder() {
  local folder_name="$1"
  # Convert to lowercase for case-insensitive comparison
  local lower_name=$(echo "$folder_name" | tr '[:upper:]' '[:lower:]')
  
  if [[ "$lower_name" == "artwork" || "$lower_name" == "scans" ]]; then
    return 0  # true - preserve this folder
  else
    return 1  # false - don't preserve
  fi
}

# Function to generate unique filename if conflict exists
get_unique_filename() {
  local target_dir="$1"
  local filename="$2"
  local disc_num="$3"
  
  local base_name="${filename%.*}"
  local extension="${filename##*.}"
  
  # First try: add disc number
  local new_name="${base_name}_disc${disc_num}.${extension}"
  
  if [ ! -f "$target_dir/$new_name" ]; then
    echo "$new_name"
    return 0
  fi
  
  # If still conflicts, add counter
  local counter=2
  while [ -f "$target_dir/${base_name}_disc${disc_num}_${counter}.${extension}" ]; do
    ((counter++))
  done
  
  echo "${base_name}_disc${disc_num}_${counter}.${extension}"
}

# Function to flatten multi-disc album
flatten_multi_disc_album() {
  local album_dir="$1"
  
  echo -e "${CYAN}Flattening multi-disc album: $(basename "$album_dir")${NC}"
  
  # Find all disc directories
  local disc_dirs=()
  while IFS= read -r -d '' disc_dir; do
    disc_dirs+=("$disc_dir")
  done < <(find "$album_dir" -maxdepth 1 -type d \( -iname "disc*" -o -iname "cd*" \) -print0)
  
  if [ ${#disc_dirs[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No disc directories found for flattening${NC}"
    return 1
  fi
  
  # Sort disc directories to process in order
  IFS=$'\n' disc_dirs=($(sort <<<"${disc_dirs[*]}"))
  unset IFS
  
  local total_discs=${#disc_dirs[@]}
  local current_disc=1
  
  if $verbose; then
    echo "Found $total_discs disc directories to process"
  fi
  
  # Process each disc directory
  for disc_dir in "${disc_dirs[@]}"; do
    local disc_name=$(basename "$disc_dir")
    echo -e "${BLUE}Processing $disc_name (disc $current_disc of $total_discs)${NC}"
    
    # Check if this disc has FLAC files
    if ! has_flac_files "$disc_dir"; then
      echo -e "${YELLOW}WARNING: $disc_name contains no FLAC files - skipping${NC}"
      ((current_disc++))
      continue
    fi
    
    # Count FLAC files in this disc
    local track_count=$(find "$disc_dir" -maxdepth 1 -type f -iname "*.flac" | wc -l)
    
    if $verbose; then
      echo "Found $track_count FLAC files in $disc_name"
    fi
    
    # Process FLAC files - update metadata and move
    while IFS= read -r -d '' flac_file; do
      local filename=$(basename "$flac_file")
      local target_file="$album_dir/$filename"
      
      # Handle filename conflicts
      if [ -f "$target_file" ]; then
        local new_filename=$(get_unique_filename "$album_dir" "$filename" "$current_disc")
        target_file="$album_dir/$new_filename"
        echo -e "${YELLOW}Filename conflict resolved: $filename → $new_filename${NC}"
      fi
      
      # Update FLAC metadata before moving
      metaflac --set-tag="DISCNUMBER=$current_disc" \
               --set-tag="DISCTOTAL=$total_discs" \
               --set-tag="TRACKTOTAL=$track_count" \
               "$flac_file"
      
      if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to update metadata for $filename${NC}"
        return 1
      fi
      
      # Move the file
      mv "$flac_file" "$target_file"
      if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to move $filename${NC}"
        return 1
      fi
      
      if $verbose; then
        echo "Moved and updated: $filename"
      fi
      
    done < <(find "$disc_dir" -maxdepth 1 -type f -iname "*.flac" -print0)
    
    # Move image files (jpg, jpeg, png, gif, bmp)
    while IFS= read -r -d '' image_file; do
      local filename=$(basename "$image_file")
      local target_file="$album_dir/$filename"
      
      # Handle filename conflicts
      if [ -f "$target_file" ]; then
        local new_filename=$(get_unique_filename "$album_dir" "$filename" "$current_disc")
        target_file="$album_dir/$new_filename"
        echo -e "${YELLOW}Image filename conflict resolved: $filename → $new_filename${NC}"
      fi
      
      mv "$image_file" "$target_file"
      if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to move image file $filename${NC}"
        return 1
      fi
      
      if $verbose; then
        echo "Moved image: $filename"
      fi
      
    done < <(find "$disc_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" \) -print0)
    
    ((current_disc++))
  done
  
  # Remove empty disc directories (but preserve artwork/scans folders)
  for disc_dir in "${disc_dirs[@]}"; do
    local disc_name=$(basename "$disc_dir")
    
    if is_preserved_folder "$disc_name"; then
      echo -e "${BLUE}Preserving folder: $disc_name${NC}"
      continue
    fi
    
    # Check if directory is empty
    if [ -z "$(ls -A "$disc_dir")" ]; then
      rmdir "$disc_dir"
      if [ $? -eq 0 ]; then
        if $verbose; then
          echo "Removed empty directory: $disc_name"
        fi
      else
        echo -e "${YELLOW}WARNING: Failed to remove directory $disc_name${NC}"
      fi
    else
      echo -e "${YELLOW}WARNING: Directory $disc_name is not empty after flattening${NC}"
    fi
  done
  
  echo -e "${GREEN}Successfully flattened multi-disc album${NC}"
  return 0
}

# Function to extract genre from directory name
extract_genre() {
  local dir_name="$1"
  # Use grep to find the last square bracket content
  local extracted_genre=$(echo "$dir_name" | grep -o '\[[^]]*\]' | tail -n 1 | tr -d '[]')
  
  # If no genre found in brackets, use the provided default genre
  if [ -z "$extracted_genre" ]; then
    echo "$genre"
  else
    echo "$extracted_genre"
  fi
}

# Function to determine if a folder is Hi-Res
is_hires() {
  local dir_name="$1"
  # Debug output to verify pattern matching
  echo -e "${BLUE}Checking HiRes status for: $dir_name${NC}"
  
  if [[ $dir_name == *\[24B-* ]]; then
    echo -e "${BLUE}Detected as Hi-Res${NC}"
    return 0  # true
  else
    echo -e "${BLUE}Detected as CD quality${NC}"
    return 1  # false
  fi
}

# Function to move processed folder to _CD or _Hires
move_to_quality_dir() {
  local dir_path="$1"
  local dir_name=$(basename "$dir_path")
  
  # Debug output
  echo -e "${BLUE}Making decision for directory: $dir_name${NC}"
  
  if is_hires "$dir_name"; then
    # Hi-Res album - move to _Hires
    echo -e "${BLUE}Moving to Hi-Res directory: $dir_name${NC}"
    mv "$dir_path" "$root_dir/_Hires/"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Successfully moved to: $root_dir/_Hires/$dir_name${NC}"
      ((moved_to_hires++))
    else
      echo -e "${RED}Failed to move to: $root_dir/_Hires/$dir_name${NC}"
    fi
  else
    # CD quality - move to _CD
    echo -e "${BLUE}Moving to CD directory: $dir_name${NC}"
    mv "$dir_path" "$root_dir/_CD/"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Successfully moved to: $root_dir/_CD/$dir_name${NC}"
      ((moved_to_cd++))
    else
      echo -e "${RED}Failed to move to: $root_dir/_CD/$dir_name${NC}"
    fi
  fi
}

# Process all directories in the root directory
for dir in "$root_dir"/*; do
  if [ -d "$dir" ]; then
    # Get directory name
    dir_name=$(basename "$dir")
    
    # Skip special directories
    if [[ "$dir_name" == "_"* || "$dir_name" == "." || "$dir_name" == ".." ]]; then
      echo -e "${BLUE}Skipping special directory: $dir_name${NC}"
      continue
    fi
    
    # Check if directory name matches artist-album pattern
    if [[ "$dir_name" == *" - "* ]]; then
      echo -e "${BLUE}Checking directory: $dir_name${NC}"
      
      # Check if directory has disc subfolders OR direct FLAC files
      has_discs=false
      has_direct_flacs=false
      
      if has_disc_subfolders "$dir"; then
        has_discs=true
      fi
      
      if has_flac_files "$dir"; then
        has_direct_flacs=true
      fi
      
      # If no FLAC files and no disc subfolders, skip
      if ! $has_discs && ! $has_direct_flacs; then
        echo -e "${YELLOW}WARNING: Directory '$dir_name' contains no FLAC files or disc subfolders - skipping processing${NC}"
        ((skipped_count++))
        echo "-------------------------------------------"
        continue
      fi
      
      # If has disc subfolders, flatten first
      if $has_discs; then
        echo -e "${CYAN}Multi-disc album detected: $dir_name${NC}"
        
        if flatten_multi_disc_album "$dir"; then
          echo -e "${GREEN}Successfully flattened: $dir_name${NC}"
          ((flattened_count++))
        else
          echo -e "${RED}ERROR: Failed to flatten $dir_name - skipping album${NC}"
          ((error_count++))
          echo "-------------------------------------------"
          continue
        fi
      fi
      
      # Now check if we have FLAC files (either originally or after flattening)
      if ! has_flac_files "$dir"; then
        echo -e "${YELLOW}WARNING: Directory '$dir_name' contains no FLAC files after processing - skipping${NC}"
        ((skipped_count++))
        echo "-------------------------------------------"
        continue
      fi
      
      echo -e "${BLUE}Processing directory: $dir_name${NC}"
      
      # Extract genre from directory name or use default
      local_genre=$(extract_genre "$dir_name")
      echo -e "${BLUE}Using genre: $local_genre${NC}"
      
      # Call processalbum.sh with appropriate options
      if $verbose; then
        processalbum.sh -v "$dir" "$local_genre"
        status=$?
      else
        processalbum.sh "$dir" "$local_genre"
        status=$?
      fi
      
      # Check the result
      if [ $status -eq 0 ]; then
        echo -e "${GREEN}Successfully processed: $dir_name${NC}"
        ((processed_count++))
        
        # Move to appropriate directory if sorting is enabled
        if $has_cd_hires_dirs; then
          # Store the original artist name before any processing changes it
          original_artist=$(echo "$dir_name" | sed -E 's/^([^-]+) -.*/\1/')
          
          # Track quality determination before processing
          is_high_res=false
          if is_hires "$dir_name"; then
            echo -e "${GREEN}This is a Hi-Res album - will move to _Hires${NC}"
            is_high_res=true
          else
            echo -e "${GREEN}This is a CD quality album - will move to _CD${NC}"
            is_high_res=false
          fi
          
          # Get the current directory name (it might have been renamed by processalbum.sh)
          processed_dir="$dir"
          if [ -d "$dir" ]; then
            # Directory still exists with same name
            if $is_high_res; then
              echo -e "${BLUE}Moving to Hi-Res directory: $dir_name${NC}"
              mv "$dir" "$root_dir/_Hires/"
              if [ $? -eq 0 ]; then
                echo -e "${GREEN}Successfully moved to: $root_dir/_Hires/$dir_name${NC}"
                ((moved_to_hires++))
              else
                echo -e "${RED}Failed to move to: $root_dir/_Hires/$dir_name${NC}"
              fi
            else
              echo -e "${BLUE}Moving to CD directory: $dir_name${NC}"
              mv "$dir" "$root_dir/_CD/"
              if [ $? -eq 0 ]; then
                echo -e "${GREEN}Successfully moved to: $root_dir/_CD/$dir_name${NC}"
                ((moved_to_cd++))
              else
                echo -e "${RED}Failed to move to: $root_dir/_CD/$dir_name${NC}"
              fi
            fi
          else
            # Directory was likely renamed, need to find it
            parent_dir=$(dirname "$dir")
            album_artist=$(echo "$dir_name" | sed -E 's/^([^-]+) -.*/\1/')
            # Clean up artist name to match processalbum.sh formatting
            album_artist=$(echo "$album_artist" | sed -E 's/\b(.)/\u\1/g; s/ & / and /g')
            # Look for directories that start with the artist name
            for new_dir_path in "$parent_dir/$album_artist"*; do
              if [ -d "$new_dir_path" ] && [ "$new_dir_path" != "$dir" ] && [[ "$(basename "$new_dir_path")" != "_"* ]]; then
                echo -e "${BLUE}Found renamed directory: $(basename "$new_dir_path")${NC}"
                
                # Use the quality determination we made before processing
                if $is_high_res; then
                  echo -e "${BLUE}Moving to Hi-Res directory (based on pre-processing determination)${NC}"
                  mv "$new_dir_path" "$root_dir/_Hires/"
                  if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Successfully moved to: $root_dir/_Hires/$(basename "$new_dir_path")${NC}"
                    ((moved_to_hires++))
                  else
                    echo -e "${RED}Failed to move to: $root_dir/_Hires/$(basename "$new_dir_path")${NC}"
                  fi
                else
                  echo -e "${BLUE}Moving to CD directory (based on pre-processing determination)${NC}"
                  mv "$new_dir_path" "$root_dir/_CD/"
                  if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Successfully moved to: $root_dir/_CD/$(basename "$new_dir_path")${NC}"
                    ((moved_to_cd++))
                  else
                    echo -e "${RED}Failed to move to: $root_dir/_CD/$(basename "$new_dir_path")${NC}"
                  fi
                fi
                break
              fi
            done
          fi
        fi
      else
        echo -e "${RED}Error processing: $dir_name${NC}"
        ((error_count++))
      fi
      echo "-------------------------------------------"
    else
      echo -e "${RED}Skipping $dir_name: Does not match Artist - Album format${NC}"
    fi
  fi
done

# Display summary
echo ""
echo -e "${GREEN}Processing complete${NC}"
echo "-------------------------------------------"
echo "Total directories processed: ${processed_count:-0}"
echo "Multi-disc albums flattened: ${flattened_count:-0}"
echo "Directories with errors: ${error_count:-0}"
echo "Directories skipped (no FLAC files): ${skipped_count:-0}"
if $has_cd_hires_dirs; then
  echo "Moved to _Hires: ${moved_to_hires:-0}"
  echo "Moved to _CD: ${moved_to_cd:-0}"
fi
echo "-------------------------------------------"

# Check if there were errors and set exit code
if [ "${error_count:-0}" -gt 0 ]; then
  exit 1
else
  exit 0
fi