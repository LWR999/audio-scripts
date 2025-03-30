#!/bin/bash

# Initialize verbose flag
verbose=false
# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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
moved_to_hires=0
moved_to_cd=0
declare -A quality_map

# Check for empty counters and set defaults
: ${processed_count:=0}
: ${error_count:=0}
: ${moved_to_hires:=0}
: ${moved_to_cd:=0}

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
echo "Directories with errors: ${error_count:-0}"
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
