#!/bin/bash
# peon-ping shared pack download engine
# Used by install.sh and `peon packs install`
set -euo pipefail

REGISTRY_URL="https://peonping.github.io/registry/index.json"

# MSYS2/MinGW: Windows Python can't read /c/... paths — convert to C:/... via cygpath
_IS_MSYS2=false
case "$(uname -s)" in MSYS_NT*|MINGW*) _IS_MSYS2=true ;; esac

py_path() {
  if [ "$_IS_MSYS2" = true ]; then
    cygpath -m "$1"
  else
    printf '%s' "$1"
  fi
}

# Fallback pack list (used if registry is unreachable)
FALLBACK_PACKS="acolyte_de acolyte_ru aoe2 aom_greek brewmaster_ru dota2_axe duke_nukem glados hd2_helldiver molag_bal murloc ocarina_of_time peon peon_cz peon_de peon_es peon_fr peon_pl peon_ru peasant peasant_cz peasant_es peasant_fr peasant_ru ra2_kirov ra2_soviet_engineer ra_soviet rick sc_battlecruiser sc_firebat sc_kerrigan sc_medic sc_scv sc_tank sc_terran sc_vessel sheogorath sopranos tf2_engineer wc2_peasant"
FALLBACK_REPO="PeonPing/og-packs"
FALLBACK_REF="v1.1.0"

# Parse arguments
PEON_DIR=""
PACKS_CSV=""
INSTALL_ALL=false
LIST_REGISTRY=false

for arg in "$@"; do
  case "$arg" in
    --dir=*) PEON_DIR="${arg#--dir=}" ;;
    --packs=*) PACKS_CSV="${arg#--packs=}" ;;
    --all) INSTALL_ALL=true ;;
    --list-registry) LIST_REGISTRY=true ;;
  esac
done

# --- Safety validators ---

is_safe_pack_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

is_safe_source_repo() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]
}

is_safe_source_ref() {
  [[ "$1" =~ ^[A-Za-z0-9._/-]+$ ]] && [[ "$1" != *".."* ]] && [[ "$1" != /* ]]
}

is_safe_source_path() {
  [[ "$1" =~ ^[A-Za-z0-9._/-]+$ ]] && [[ "$1" != *".."* ]] && [[ "$1" != /* ]]
}

is_safe_filename() {
  [[ "$1" =~ ^[A-Za-z0-9._?!-]+$ ]]
}

# URL-encode characters that break raw GitHub URLs (e.g. ? in filenames)
urlencode_filename() {
  local f="$1"
  f="${f//\?/%3F}"
  f="${f//\!/%21}"
  f="${f//\#/%23}"
  printf '%s' "$f"
}

# --- Checksum functions ---

# Compute sha256 of a file (portable across macOS and Linux)
file_sha256() {
  if command -v shasum &>/dev/null; then
    shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
  elif command -v sha256sum &>/dev/null; then
    sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  else
    # fallback: use python
    python3 -c "import hashlib; print(hashlib.sha256(open('$(py_path "$1")','rb').read()).hexdigest())" 2>/dev/null
  fi
}

# Check if a downloaded sound file matches its stored checksum
is_cached_valid() {
  local filepath="$1" checksums_file="$2" filename="$3"
  [ -s "$filepath" ] || return 1
  [ -f "$checksums_file" ] || return 1
  local stored_hash current_hash
  stored_hash=$(grep -F "$filename " "$checksums_file" 2>/dev/null | head -1 | cut -d' ' -f2)
  [ -n "$stored_hash" ] || return 1
  current_hash=$(file_sha256 "$filepath")
  [ "$stored_hash" = "$current_hash" ]
}

# Store checksum for a downloaded file
store_checksum() {
  local checksums_file="$1" filename="$2" filepath="$3"
  local hash
  hash=$(file_sha256 "$filepath")
  # Remove old entry if present, then append new one
  grep -vF "$filename " "$checksums_file" > "$checksums_file.tmp" 2>/dev/null || true
  echo "$filename $hash" >> "$checksums_file.tmp"
  mv "$checksums_file.tmp" "$checksums_file"
}

# --- Progress bar ---

draw_progress() {
  local pidx="$1" ptotal="$2" pname="$3"
  local cur="$4" total="$5" bytes="$6"
  local idx_width=${#ptotal}
  local bar_width=20 filled=0 empty i bar=""

  if [ "$total" -gt 0 ]; then
    filled=$(( cur * bar_width / total ))
  fi
  empty=$(( bar_width - filled ))
  for (( i=0; i<filled; i++ )); do bar+="#"; done
  for (( i=0; i<empty; i++ )); do bar+="-"; done

  local size_str
  if [ "$bytes" -ge 1048576 ]; then
    size_str="$(( bytes / 1048576 )).$(( (bytes % 1048576) * 10 / 1048576 )) MB"
  elif [ "$bytes" -ge 1024 ]; then
    size_str="$(( bytes / 1024 )) KB"
  else
    size_str="$bytes B"
  fi

  printf "\r  [%${idx_width}d/%d] %-20s [%s] %d/%d (%s)%-10s" \
    "$pidx" "$ptotal" "$pname" "$bar" "$cur" "$total" "$size_str" ""
}

# --- Registry fetch ---

REGISTRY_JSON=""
ALL_PACKS=""

fetch_registry() {
  echo "Fetching pack registry..."
  if REGISTRY_JSON=$(curl -fsSL "$REGISTRY_URL" 2>/dev/null); then
    ALL_PACKS=$(python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
for p in data.get('packs', []):
    print(p['name'])
" <<< "$REGISTRY_JSON")
    TOTAL_AVAILABLE=$(echo "$ALL_PACKS" | wc -l | tr -d ' ')
    echo "Registry: $TOTAL_AVAILABLE packs available"
  else
    echo "Warning: Could not fetch registry, using fallback pack list" >&2
    ALL_PACKS="$FALLBACK_PACKS"
    REGISTRY_JSON=""
  fi
}

# --- List registry mode ---

if [ "$LIST_REGISTRY" = true ]; then
  fetch_registry
  if [ -n "$REGISTRY_JSON" ]; then
    PEON_DIR="$(py_path "$PEON_DIR")" python3 -c "
import json, sys, os

registry = json.loads(sys.stdin.read())
peon_dir = os.environ.get('PEON_DIR', '')
installed = set()
if peon_dir:
    packs_dir = os.path.join(peon_dir, 'packs')
    if os.path.isdir(packs_dir):
        installed = set(os.listdir(packs_dir))

for p in registry.get('packs', []):
    name = p['name']
    display = p.get('display_name', name)
    marker = ' ✓' if name in installed else ''
    print(f'  {name:24s} {display}{marker}')
" <<< "$REGISTRY_JSON"
  else
    for pack in $ALL_PACKS; do
      if [ -n "$PEON_DIR" ] && [ -d "$PEON_DIR/packs/$pack" ]; then
        echo "  $pack ✓"
      else
        echo "  $pack"
      fi
    done
  fi
  exit 0
fi

# --- Validate arguments ---

if [ -z "$PEON_DIR" ]; then
  echo "Error: --dir is required" >&2
  exit 1
fi

if [ -z "$PACKS_CSV" ] && [ "$INSTALL_ALL" = false ]; then
  echo "Error: --packs=<names> or --all is required" >&2
  exit 1
fi

# --- Fetch registry and select packs ---

fetch_registry

if [ "$INSTALL_ALL" = true ]; then
  PACKS="$ALL_PACKS"
  echo "Installing all $(echo "$PACKS" | wc -l | tr -d ' ') packs..."
else
  PACKS=$(echo "$PACKS_CSV" | tr ',' ' ')
  PACK_COUNT=$(echo "$PACKS" | wc -w | tr -d ' ')
  echo "Installing $PACK_COUNT pack(s)..."
fi

# --- Download packs ---

PACK_ARRAY=($PACKS)
TOTAL_PACKS=${#PACK_ARRAY[@]}
PACK_INDEX=0

IS_TTY=false
[ -t 1 ] && IS_TTY=true

TOTAL_DOWNLOAD_FILES=0
TOTAL_DOWNLOAD_BYTES=0
TOTAL_DOWNLOAD_PACKS=0

echo ""
echo "Downloading packs..."
for pack in $PACKS; do
  if ! is_safe_pack_name "$pack"; then
    echo "  Warning: skipping invalid pack name: $pack" >&2
    continue
  fi

  PACK_INDEX=$((PACK_INDEX + 1))

  mkdir -p "$PEON_DIR/packs/$pack/sounds"

  # Get source info from registry (or use fallback)
  SOURCE_REPO=""
  SOURCE_REF=""
  SOURCE_PATH=""
  if [ -n "$REGISTRY_JSON" ]; then
    PACK_META=$(PACK_NAME="$pack" python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
for p in data.get('packs', []):
    if p.get('name') == __import__('os').environ.get('PACK_NAME'):
        print(p.get('source_repo', ''))
        print(p.get('source_ref', 'main'))
        print(p.get('source_path', ''))
        break
" <<< "$REGISTRY_JSON" 2>/dev/null || true)
    SOURCE_REPO=$(printf '%s\n' "$PACK_META" | sed -n '1p')
    SOURCE_REF=$(printf '%s\n' "$PACK_META" | sed -n '2p')
    SOURCE_PATH=$(printf '%s\n' "$PACK_META" | sed -n '3p')
  fi

  if [ -n "$SOURCE_REPO" ] && ! is_safe_source_repo "$SOURCE_REPO"; then
    SOURCE_REPO=""
  fi
  if [ -n "$SOURCE_REF" ] && ! is_safe_source_ref "$SOURCE_REF"; then
    SOURCE_REF=""
  fi
  if [ -n "$SOURCE_PATH" ] && ! is_safe_source_path "$SOURCE_PATH"; then
    SOURCE_PATH=""
  fi

  if [ -z "$SOURCE_REPO" ] || [ -z "$SOURCE_REF" ] || [ -z "$SOURCE_PATH" ]; then
    SOURCE_REPO="$FALLBACK_REPO"
    SOURCE_REF="$FALLBACK_REF"
    SOURCE_PATH="$pack"
  fi

  # Construct base URL for this pack's files
  if [ -n "$SOURCE_PATH" ]; then
    PACK_BASE="https://raw.githubusercontent.com/$SOURCE_REPO/$SOURCE_REF/$SOURCE_PATH"
  else
    PACK_BASE="https://raw.githubusercontent.com/$SOURCE_REPO/$SOURCE_REF"
  fi

  # Download manifest
  if ! curl -fsSL "$PACK_BASE/openpeon.json" -o "$PEON_DIR/packs/$pack/openpeon.json" 2>/dev/null; then
    echo "  Warning: failed to download manifest for $pack" >&2
    continue
  fi

  # Download sound files
  manifest="$PEON_DIR/packs/$pack/openpeon.json"
  manifest_py="$(py_path "$manifest")"
  SOUND_COUNT=$(python3 -c "
import json, os
m = json.load(open('$manifest_py'))
seen = set()
for cat in m.get('categories', {}).values():
    for s in cat.get('sounds', []):
        seen.add(os.path.basename(s['file']))
print(len(seen))
" 2>/dev/null || echo "?")

  CHECKSUMS_FILE="$PEON_DIR/packs/$pack/.checksums"
  touch "$CHECKSUMS_FILE"

  if [ "$IS_TTY" = true ] && [ "$SOUND_COUNT" != "?" ]; then
    local_file_count=0
    local_byte_count=0

    draw_progress "$PACK_INDEX" "$TOTAL_PACKS" "$pack" 0 "$SOUND_COUNT" 0

    while read -r sfile; do
      if ! is_safe_filename "$sfile"; then
        echo "  Warning: skipped unsafe filename in $pack: $sfile" >&2
        continue
      fi
      if is_cached_valid "$PEON_DIR/packs/$pack/sounds/$sfile" "$CHECKSUMS_FILE" "$sfile"; then
        local_file_count=$((local_file_count + 1))
        fsize=$(wc -c < "$PEON_DIR/packs/$pack/sounds/$sfile" | tr -d ' ')
        local_byte_count=$((local_byte_count + fsize))
      elif curl -fsSL "$PACK_BASE/sounds/$(urlencode_filename "$sfile")" \
           -o "$PEON_DIR/packs/$pack/sounds/$sfile" </dev/null 2>/dev/null; then
        store_checksum "$CHECKSUMS_FILE" "$sfile" "$PEON_DIR/packs/$pack/sounds/$sfile"
        local_file_count=$((local_file_count + 1))
        fsize=$(wc -c < "$PEON_DIR/packs/$pack/sounds/$sfile" | tr -d ' ')
        local_byte_count=$((local_byte_count + fsize))
      else
        echo "  Warning: failed to download $pack/sounds/$sfile" >&2
      fi
      draw_progress "$PACK_INDEX" "$TOTAL_PACKS" "$pack" \
        "$local_file_count" "$SOUND_COUNT" "$local_byte_count"
    done < <(python3 -c "
import json, os
m = json.load(open('$manifest_py'))
seen = set()
for cat in m.get('categories', {}).values():
    for s in cat.get('sounds', []):
        f = s['file']
        basename = os.path.basename(f)
        if basename not in seen:
            seen.add(basename)
            print(basename)
")

    draw_progress "$PACK_INDEX" "$TOTAL_PACKS" "$pack" \
      "$local_file_count" "$SOUND_COUNT" "$local_byte_count"
    printf "\n"

    TOTAL_DOWNLOAD_FILES=$((TOTAL_DOWNLOAD_FILES + local_file_count))
    TOTAL_DOWNLOAD_BYTES=$((TOTAL_DOWNLOAD_BYTES + local_byte_count))
    TOTAL_DOWNLOAD_PACKS=$((TOTAL_DOWNLOAD_PACKS + 1))
  else
    printf "  [%d/%d] %s " "$PACK_INDEX" "$TOTAL_PACKS" "$pack"

    python3 -c "
import json, os
m = json.load(open('$manifest_py'))
seen = set()
for cat in m.get('categories', {}).values():
    for s in cat.get('sounds', []):
        f = s['file']
        basename = os.path.basename(f)
        if basename not in seen:
            seen.add(basename)
            print(basename)
" | while read -r sfile; do
      if ! is_safe_filename "$sfile"; then
        echo "  Warning: skipped unsafe filename in $pack: $sfile" >&2
        continue
      fi
      if is_cached_valid "$PEON_DIR/packs/$pack/sounds/$sfile" "$CHECKSUMS_FILE" "$sfile"; then
        printf "."
      elif curl -fsSL "$PACK_BASE/sounds/$(urlencode_filename "$sfile")" -o "$PEON_DIR/packs/$pack/sounds/$sfile" </dev/null 2>/dev/null; then
        store_checksum "$CHECKSUMS_FILE" "$sfile" "$PEON_DIR/packs/$pack/sounds/$sfile"
        printf "."
      else
        printf "x"
        echo "  Warning: failed to download $pack/sounds/$sfile" >&2
      fi
    done

    printf " %s sounds\n" "$SOUND_COUNT"
    TOTAL_DOWNLOAD_PACKS=$((TOTAL_DOWNLOAD_PACKS + 1))
  fi
done

if [ "$IS_TTY" = true ] && [ "$TOTAL_DOWNLOAD_PACKS" -gt 0 ]; then
  if [ "$TOTAL_DOWNLOAD_BYTES" -ge 1048576 ]; then
    SUMMARY_SIZE="$(( TOTAL_DOWNLOAD_BYTES / 1048576 )).$(( (TOTAL_DOWNLOAD_BYTES % 1048576) * 10 / 1048576 )) MB"
  elif [ "$TOTAL_DOWNLOAD_BYTES" -ge 1024 ]; then
    SUMMARY_SIZE="$(( TOTAL_DOWNLOAD_BYTES / 1024 )) KB"
  else
    SUMMARY_SIZE="$TOTAL_DOWNLOAD_BYTES B"
  fi
  echo ""
  echo "Downloaded $TOTAL_DOWNLOAD_PACKS packs ($TOTAL_DOWNLOAD_FILES files, $SUMMARY_SIZE)"
fi
