# FLAC Music Management Scripts Documentation

This collection of bash scripts provides a comprehensive toolkit for managing FLAC audio files, from metadata processing to directory organization. The scripts work together to automate the entire workflow of organizing, tagging, and maintaining a FLAC music library.

## Script Overview and Hierarchy

### Core Processing Scripts (Main Workflow)
1. **`setflactrackinfo.sh`** - Low-level metadata setter (foundation script)
2. **`processalbum.sh`** - Single album processor (calls setflactrackinfo.sh)
3. **`processflacs.sh`** - Multi-album processor in current directory
4. **`processmusic.sh`** - Advanced batch processor with quality sorting

### Utility Scripts
5. **`getflactrackinfo.sh`** - Metadata viewer/inspector
6. **`check_flac_dirs.sh`** - Directory cleanup utility
7. **`check_multi_disc.sh`** - Multi-disc detection utility

## Detailed Script Documentation

### 1. setflactrackinfo.sh
**Purpose**: Core metadata processing engine for individual FLAC files

**Usage**: 
```bash
setflactrackinfo.sh [-v] <album_name> <album_artist> <genre> <compilation_flag>
```

**Parameters**:
- `-v`: Verbose mode (optional)
- `album_name`: Name of the album
- `album_artist`: Artist name for the album
- `genre`: Musical genre
- `compilation_flag`: Y/N for compilation albums

**What it does**:
- Processes all FLAC files in the current directory
- Standardizes artist/track name formatting (capitalizes, replaces "featuring" with "feat.", handles ampersands)
- Sets comprehensive metadata tags (TITLE, ARTIST, ALBUM, ALBUMARTIST, GENRE, COMPILATION, track/disc numbers)
- Embeds album artwork from JPEG files
- Optimizes artwork size (resizes if >1400x1400, strips metadata, adjusts quality)
- Calculates total tracks and discs automatically

**Example**:
```bash
cd "/music/Artist - Album Name"
setflactrackinfo.sh "Kind of Blue" "Miles Davis" "Jazz" "N"
```

### 2. processalbum.sh
**Purpose**: Processes a single album directory with intelligent name parsing

**Usage**:
```bash
processalbum.sh [-v] <path> <genre>
```

**Parameters**:
- `-v`: Verbose mode (optional)
- `path`: Path to album directory
- `genre`: Default genre to apply

**What it does**:
- Expects directory format: "Artist - Album Name"
- Extracts artist and album from directory name
- Cleans album names (removes brackets, years in parentheses)
- Applies text formatting rules
- Calls `setflactrackinfo.sh` with processed metadata
- Renames directory to standardized format
- Removes cover.jpg file after processing

**Example**:
```bash
processalbum.sh "/downloads/Miles Davis - Kind Of Blue [1959]" "Jazz"
# Result: Directory renamed to "Miles Davis - Kind Of Blue"
```

### 3. processflacs.sh
**Purpose**: Batch processes multiple album directories in current location

**Usage**:
```bash
processflacs.sh [-v] <genre>
```

**Parameters**:
- `-v`: Verbose mode (optional)
- `genre`: Default genre for all albums

**What it does**:
- Finds all directories matching "Artist - Album" pattern in current directory
- Processes each directory using the same logic as `processalbum.sh`
- Applies consistent formatting and metadata
- Renames directories to standardized format

**Example**:
```bash
cd /downloads/new_albums/
processflacs.sh "Rock"
# Processes all "Artist - Album" directories
```

### 4. processmusic.sh
**Purpose**: Advanced batch processor with quality-based sorting

**Usage**:
```bash
processmusic.sh [-v] [-h] <root_directory> <genre>
```

**Parameters**:
- `-v`: Verbose mode (optional)
- `-h`: Show help
- `root_directory`: Directory containing album folders
- `genre`: Default genre (can be overridden by genre in folder names)

**Advanced Features**:
- **Genre Extraction**: Reads genre from directory names in square brackets `[Genre]`
- **Quality Detection**: Identifies Hi-Res albums by `[24B-*]` pattern in folder names
- **Automatic Sorting**: Moves processed albums to `_CD/` or `_Hires/` subdirectories
- **Comprehensive Reporting**: Tracks processing statistics and errors

**Example**:
```bash
processmusic.sh -v "/downloads/music_batch/" "Jazz"
# Processes all albums, sorts by quality:
# "Artist - Album [24B-96]" → moves to _Hires/
# "Artist - Album" → moves to _CD/
# "Artist - Album [Rock]" → uses Rock as genre instead of Jazz
```

### 5. getflactrackinfo.sh
**Purpose**: Metadata inspection and verification tool

**Usage**:
```bash
getflactrackinfo.sh [filename.flac]    # Single file
getflactrackinfo.sh                     # All FLAC files in directory
```

**Output Format**:
```
Track# of Total# / Disc# of TotalDiscs SampleRate/BitDepth C Genre    Title    Artist / AlbumArtist
```

**Example Output**:
```bash
getflactrackinfo.sh
1 of 9 / 1 of 1 44100/16   Jazz    So What    Miles Davis / Miles Davis
2 of 9 / 1 of 1 44100/16   Jazz    Freddie Freeloader    Miles Davis / Miles Davis
```

### 6. check_flac_dirs.sh
**Purpose**: Directory maintenance and cleanup utility

**Usage**:
```bash
check_flac_dirs.sh [start_directory] [--info|--clean]
```

**Parameters**:
- `start_directory`: Starting point for search (default: current directory)
- `--info`: List empty directories (default)
- `--clean`: Remove empty directories

**What it does**:
- Recursively finds leaf directories (no subdirectories)
- Identifies directories without FLAC files
- Can list or remove empty directories
- Skips directories starting with underscore (`_*`)

**Example**:
```bash
check_flac_dirs.sh /music --info      # List empty directories
check_flac_dirs.sh /music --clean     # Remove empty directories
```

### 7. check_multi_disc.sh
**Purpose**: Simple utility to find multi-disc albums

**Usage**:
```bash
check_multi_disc.sh
```

**What it does**:
- Finds directories named "Disc*" or "CD*"
- Useful for identifying multi-disc releases that need special handling

## Workflow Examples

### Basic Single Album Processing
```bash
# 1. Navigate to album directory
cd "/downloads/Miles Davis - Kind Of Blue [1959] [Jazz]"

# 2. Process the album
processalbum.sh . "Jazz"
# Result: Metadata set, directory renamed to "Miles Davis - Kind Of Blue"
```

### Batch Processing Multiple Albums
```bash
# 1. Organize downloads in a batch directory
ls /downloads/music_batch/
# "Artist1 - Album1 [Rock]"
# "Artist2 - Album2 [24B-96] [Jazz]" 
# "Artist3 - Album3"

# 2. Process all with quality sorting
processmusic.sh -v "/downloads/music_batch/" "Pop"

# Results:
# - "Artist1 - Album1" → _CD/ (Rock genre extracted)
# - "Artist2 - Album2" → _Hires/ (Jazz genre, Hi-Res quality)
# - "Artist3 - Album3" → _CD/ (Pop genre default)
```

### Quality Control and Maintenance
```bash
# 1. Check metadata before processing
cd "Artist - Album"
getflactrackinfo.sh
# Verify track info looks correct

# 2. Process album
processalbum.sh . "Genre"

# 3. Verify results
getflactrackinfo.sh
# Confirm metadata was applied correctly

# 4. Clean up empty directories
check_flac_dirs.sh /music --clean
```

### Multi-Disc Album Handling
```bash
# 1. Find multi-disc albums
check_multi_disc.sh
# ./Artist - Album/Disc 1/
# ./Artist - Album/Disc 2/

# 2. Process each disc separately
processalbum.sh "./Artist - Album/Disc 1/" "Genre"
processalbum.sh "./Artist - Album/Disc 2/" "Genre"
```

## File Naming and Organization Conventions

### Expected Directory Structure
```
Music Collection/
├── _CD/                    # Standard quality albums (44.1kHz/16-bit)
├── _Hires/                 # High-resolution albums (>44.1kHz or >16-bit)
└── Processing/             # Temporary processing area
    ├── Artist1 - Album1 [Genre]/
    ├── Artist2 - Album2 [24B-96] [Genre]/
    └── Artist3 - Album3/
```

### Directory Naming Patterns
- **Standard**: `Artist - Album`
- **With Genre**: `Artist - Album [Genre]`
- **Hi-Res Quality**: `Artist - Album [24B-96]` or `Artist - Album [24B-192]`
- **Combined**: `Artist - Album [24B-96] [Genre]`

### Text Formatting Rules Applied
- **Capitalization**: First letter of each word
- **Featuring**: "featuring" → "feat."
- **Ampersands**: " & " → " and " (artists) or " And " (albums)
- **Apostrophes**: Lowercase after apostrophes ("don't", "it's")
- **Bracket Removal**: Removes `[year]`, `[label]`, etc. from album names

## Dependencies and Requirements

### Required Tools
- `metaflac` (FLAC metadata manipulation)
- `ffprobe` (audio format detection)
- `convert` (ImageMagick - image processing)
- `identify` (ImageMagick - image information)
- Standard Unix tools: `find`, `grep`, `sed`, `sort`, `mv`, `rm`

### Installation Example (Ubuntu/Debian)
```bash
sudo apt-get install flac ffmpeg imagemagick
```

## Error Handling and Troubleshooting

### Common Issues
1. **Missing Dependencies**: Ensure all required tools are installed
2. **File Permissions**: Scripts need read/write access to music directories
3. **Directory Structure**: Ensure directories follow "Artist - Album" naming
4. **JPEG Files**: Each album directory should contain exactly one JPEG/JPG file
5. **FLAC Files**: Directory must contain FLAC files for processing

### Verbose Mode Benefits
- Use `-v` flag for detailed processing information
- Shows before/after metadata values
- Displays file operations and decisions
- Helpful for debugging issues

This toolkit provides a complete solution for managing large FLAC music collections with consistent metadata, artwork, and organization.