# FLAC Music Management Scripts Documentation

This collection of bash scripts provides a comprehensive toolkit for managing FLAC audio files, from metadata processing to directory organization. The scripts work together to automate the entire workflow of organizing, tagging, and maintaining a FLAC music library, including advanced multi-disc album handling and quality-based sorting.

## Script Overview and Hierarchy

### Core Processing Scripts (Main Workflow)
1. **`setflactrackinfo.sh`** - Low-level metadata setter (foundation script)
2. **`processalbum.sh`** - Single album processor (calls setflactrackinfo.sh)
3. **`processflacs.sh`** - Multi-album processor in current directory
4. **`processmusic.sh`** - Advanced batch processor with multi-disc flattening and quality sorting

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

### 4. processmusic.sh ⭐ ENHANCED
**Purpose**: Advanced batch processor with multi-disc flattening, quality-based sorting, and comprehensive validation

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
- **Multi-Disc Flattening**: Automatically detects and flattens multi-disc albums
- **Genre Extraction**: Reads genre from directory names in square brackets `[Genre]`
- **Quality Detection**: Identifies Hi-Res albums by `[24B-*]` pattern in folder names
- **Automatic Sorting**: Moves processed albums to `_CD/` or `_Hires/` subdirectories
- **FLAC Validation**: Skips directories without FLAC files with warning messages
- **Comprehensive Reporting**: Tracks processing, flattening, errors, and skipped albums

**Multi-Disc Handling**:
- Detects disc folders named "Disc*", "CD*", or "CDx" (case-insensitive)
- Flattens disc structure by moving all FLAC and image files to album root
- Updates metadata with proper disc numbers and per-disc track totals
- Preserves "artwork" and "scans" folders
- Handles filename conflicts with intelligent disambiguation
- Removes empty disc folders after successful flattening

**Example**:
```bash
processmusic.sh -v "/downloads/music_batch/" "Jazz"

# Single-disc albums:
# "Artist - Album [24B-96]" → processes normally → moves to _Hires/
# "Artist - Album" → processes normally → moves to _CD/

# Multi-disc albums:
# "Artist - Album/Disc 1/" → flattens first → processes → moves to appropriate folder
# "Artist - Album/Disc 2/" 

# Albums without FLAC files:
# "Artist - Album" (empty) → skips with warning → leaves in place
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

### Batch Processing with Multi-Disc Support
```bash
# 1. Organize downloads in a batch directory
ls /downloads/music_batch/
# "Artist1 - Album1 [Rock]"                    # Single-disc
# "Artist2 - Album2 [24B-96] [Jazz]/"          # Hi-Res single-disc
#   ├── track1.flac
#   └── cover.jpg
# "Artist3 - Album3/"                          # Multi-disc
#   ├── Disc 1/
#   │   ├── track1.flac
#   │   └── track2.flac
#   ├── Disc 2/
#   │   ├── track1.flac
#   │   └── track2.flac
#   └── artwork/
#       └── booklet.pdf

# 2. Process all with automatic flattening and quality sorting
processmusic.sh -v "/downloads/music_batch/" "Pop"

# Results:
# - "Artist1 - Album1" → _CD/ (Rock genre extracted)
# - "Artist2 - Album2" → _Hires/ (Jazz genre, Hi-Res quality)
# - "Artist3 - Album3" → flattened → processed → _CD/
#   ├── track1_disc1.flac (1 of 2 / 1 of 2)
#   ├── track2_disc1.flac (2 of 2 / 1 of 2)
#   ├── track1_disc2.flac (1 of 2 / 2 of 2)
#   ├── track2_disc2.flac (2 of 2 / 2 of 2)
#   ├── cover.jpg
#   └── artwork/ (preserved)
```

### Multi-Disc Album Before and After
```bash
# BEFORE flattening:
Artist - The White Album/
├── Disc 1/
│   ├── 01 - Back In The U.S.S.R..flac
│   ├── 02 - Dear Prudence.flac
│   └── cover.jpg
├── Disc 2/
│   ├── 01 - Birthday.flac
│   ├── 02 - Yer Blues.flac
│   └── back.jpg
└── artwork/
    └── booklet.pdf

# AFTER processmusic.sh processing:
Artist - The White Album/
├── 01 - Back In The U.S.S.R..flac      # (1 of 2 / 1 of 2)
├── 02 - Dear Prudence.flac             # (2 of 2 / 1 of 2) 
├── 01 - Birthday_disc2.flac            # (1 of 2 / 2 of 2)
├── 02 - Yer Blues_disc2.flac           # (2 of 2 / 2 of 2)
├── cover.jpg
├── back_disc2.jpg
└── artwork/                            # (preserved)
    └── booklet.pdf
```

### Quality Control and Maintenance
```bash
# 1. Check metadata before processing
cd "Artist - Album"
getflactrackinfo.sh
# Verify track info looks correct

# 2. Process album (with automatic multi-disc detection)
processalbum.sh . "Genre"

# 3. Verify results
getflactrackinfo.sh
# Confirm metadata was applied correctly

# 4. Clean up empty directories
check_flac_dirs.sh /music --clean
```

### Handling Problem Albums
```bash
# Albums without FLAC files are automatically skipped:
processmusic.sh "/downloads/mixed_content/" "Rock"
# WARNING: Directory 'Artist - Album' contains no FLAC files - skipping processing

# Multi-disc albums that fail flattening are left in partial state:
# ERROR: Failed to flatten Artist - Multi Disc Album - skipping album
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
    ├── Artist3 - Album3/           # Single-disc
    └── Artist4 - Album4/           # Multi-disc
        ├── Disc 1/
        ├── Disc 2/
        └── artwork/
```

### Directory Naming Patterns
- **Standard**: `Artist - Album`
- **With Genre**: `Artist - Album [Genre]`
- **Hi-Res Quality**: `Artist - Album [24B-96]` or `Artist - Album [24B-192]`
- **Combined**: `Artist - Album [24B-96] [Genre]`
- **Multi-Disc**: `Artist - Album/Disc 1/`, `Artist - Album/CD 2/`, etc.

### Multi-Disc Folder Detection
The system automatically detects these disc folder patterns (case-insensitive):
- `Disc 1`, `Disc 2`, `Disc*`
- `CD 1`, `CD 2`, `CD*`  
- `CD1`, `CD2`, `CDx`

### Preserved Folders
These folders are preserved during flattening (case-insensitive):
- `artwork/` - Album artwork and booklets
- `scans/` - Scanned materials

### Text Formatting Rules Applied
- **Capitalization**: First letter of each word
- **Featuring**: "featuring" → "feat."
- **Ampersands**: " & " → " and " (artists) or " And " (albums)
- **Apostrophes**: Lowercase after apostrophes ("don't", "it's")
- **Bracket Removal**: Removes `[year]`, `[label]`, etc. from album names

### Filename Conflict Resolution
When flattening multi-disc albums, filename conflicts are resolved using:
1. **Add disc number**: `track.flac` → `track_disc2.flac`
2. **Add counter if needed**: `track_disc2.flac` → `track_disc2_2.flac`
3. **Apply to all file types**: Works for FLAC files and images

## Advanced Features

### Multi-Disc Album Processing
- **Automatic Detection**: Identifies disc subfolders without user intervention
- **Metadata Preservation**: Maintains proper disc and track numbering
- **Per-Disc Track Totals**: Each disc retains its own track count (e.g., "5 of 18" for disc 1, "3 of 20" for disc 2)
- **File Type Support**: Moves FLAC files (.flac) and images (.jpg, .jpeg, .png, .gif, .bmp)
- **Smart Conflict Resolution**: Renames files when conflicts occur during flattening
- **Folder Preservation**: Keeps artwork and scans folders intact

### Quality-Based Organization
- **Automatic Detection**: Identifies Hi-Res albums by `[24B-*]` pattern
- **Smart Sorting**: Moves albums to `_CD/` or `_Hires/` directories after processing
- **Post-Processing**: Quality determination made before any directory renaming

### Enhanced Validation
- **FLAC File Checking**: Validates presence of FLAC files before processing
- **Multi-Disc Validation**: Ensures disc folders contain FLAC files
- **Error Recovery**: Graceful handling of partial failures

## Dependencies and Requirements

### Required Tools
- `metaflac` (FLAC metadata manipulation)
- `ffprobe` (audio format detection)
- `convert` (ImageMagick - image processing)
- `identify` (ImageMagick - image information)
- Standard Unix tools: `find`, `grep`, `sed`, `sort`, `mv`, `rm`, `rmdir`

### Installation Example (Ubuntu/Debian)
```bash
sudo apt-get install flac ffmpeg imagemagick
```

## Error Handling and Troubleshooting

### Enhanced Error Reporting
The updated `processmusic.sh` provides detailed statistics:
```
Processing complete
-------------------------------------------
Total directories processed: 12
Multi-disc albums flattened: 3
Directories with errors: 1
Directories skipped (no FLAC files): 2
Moved to _Hires: 7
Moved to _CD: 5
-------------------------------------------
```

### Common Issues and Solutions
1. **Missing Dependencies**: Ensure all required tools are installed
2. **File Permissions**: Scripts need read/write access to music directories
3. **Directory Structure**: Ensure directories follow "Artist - Album" naming
4. **JPEG Files**: Each album directory should contain exactly one JPEG/JPG file
5. **FLAC Files**: Directory must contain FLAC files for processing
6. **Multi-Disc Issues**: 
   - Ensure disc folders contain FLAC files
   - Check for proper disc folder naming (Disc*, CD*)
   - Verify sufficient disk space for flattening operations

### Verbose Mode Benefits
- Use `-v` flag for detailed processing information
- Shows before/after metadata values
- Displays file operations and decisions
- Shows flattening progress for multi-disc albums
- Helpful for debugging complex multi-disc scenarios

### Multi-Disc Troubleshooting
- **Partial Flattening**: If flattening fails partway, the album is left in partial state with a warning
- **Missing FLAC Files**: Disc folders without FLAC files are skipped with warnings
- **Filename Conflicts**: Automatic resolution with descriptive naming
- **Preserved Folders**: Artwork and scans folders are never removed

This enhanced toolkit provides a complete solution for managing large FLAC music collections with consistent metadata, artwork, organization, and robust multi-disc album support.