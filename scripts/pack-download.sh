#!/bin/bash
# peon-ping shared pack download engine
# Used by install.sh and `peon packs install`
set -euo pipefail

# Restore cursor on exit (in case we hid it for progress bars)
trap '[ -t 1 ] && printf "\033[?25h"' EXIT

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
LANG_FILTER=""

for arg in "$@"; do
  case "$arg" in
    --dir=*) PEON_DIR="${arg#--dir=}" ;;
    --packs=*) PACKS_CSV="${arg#--packs=}" ;;
    --all) INSTALL_ALL=true ;;
    --list-registry) LIST_REGISTRY=true ;;
    --lang=*) LANG_FILTER="${arg#--lang=}" ;;
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
  [[ "$1" =~ ^[A-Za-z0-9._?!\ \(\)/-]+$ ]] && [[ "$1" != *".."* ]] && [[ "$1" != /* ]]
}

# URL-encode characters that break raw GitHub URLs (e.g. ? or spaces in filenames)
urlencode_filename() {
  local f="$1"
  f="${f// /%20}"
  f="${f//\(/%28}"
  f="${f//\)/%29}"
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
  stored_hash=$(grep -F "$filename " "$checksums_file" 2>/dev/null | head -1 | rev | cut -d' ' -f1 | rev)
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

  printf "\r  [%${idx_width}d/%d] %-20s [%s] %d/%d (%s)%-16s" \
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

# --- Language filter ---
# When --lang is specified, filter ALL_PACKS and REGISTRY_JSON to only include
# packs whose language field prefix-matches any requested code.
# Multi-language packs (e.g. "en,ru") match if any token matches.
apply_lang_filter() {
  if [ -z "$LANG_FILTER" ]; then
    return
  fi
  if [ -z "$REGISTRY_JSON" ]; then
    echo "Warning: --lang filtering unavailable without registry" >&2
    return
  fi
  local filtered
  filtered=$(LANG_FILTER="$LANG_FILTER" python3 -c "
import json, sys, os

registry = json.loads(sys.stdin.read())
codes = [c.strip() for c in os.environ['LANG_FILTER'].split(',') if c.strip()]

def matches(pack):
    lang = pack.get('language', '')
    if not lang:
        return False
    pack_langs = [l.strip() for l in lang.split(',')]
    for pl in pack_langs:
        for code in codes:
            if pl == code or pl.startswith(code + '-'):
                return True
    return False

filtered_packs = [p for p in registry.get('packs', []) if matches(p)]
registry['packs'] = filtered_packs
print(json.dumps(registry))
" <<< "$REGISTRY_JSON")
  REGISTRY_JSON="$filtered"
  ALL_PACKS=$(python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
for p in data.get('packs', []):
    print(p['name'])
" <<< "$REGISTRY_JSON")
  if [ -z "$ALL_PACKS" ]; then
    echo "Warning: no packs match language(s): $LANG_FILTER. Use 'peon packs list --registry --lang' to see available languages." >&2
  fi
}

# --- List registry mode ---

if [ "$LIST_REGISTRY" = true ]; then
  fetch_registry
  apply_lang_filter
  if [ -n "$LANG_FILTER" ] && [ -z "$ALL_PACKS" ]; then
    exit 0
  fi
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
apply_lang_filter

# Exit gracefully if language filter yielded zero packs
if [ -n "$LANG_FILTER" ] && [ -z "$ALL_PACKS" ]; then
  exit 0
fi

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
TOTAL_SKIPPED_PACKS=0
TOTAL_FAILED_PACKS=0
FAILED_PACK_NAMES=()
PARTIAL_PACK_NAMES=()
TOTAL_PARTIAL_PACKS=0

echo ""
echo "Syncing packs..."
for pack in $PACKS; do
  if ! is_safe_pack_name "$pack"; then
    continue
  fi

  PACK_INDEX=$((PACK_INDEX + 1))
  idx_width=${#TOTAL_PACKS}

  # Skip packs where every manifest sound has a valid checksum
  if [ -s "$PEON_DIR/packs/$pack/openpeon.json" ] && [ -f "$PEON_DIR/packs/$pack/.checksums" ]; then
    manifest_check="$(py_path "$PEON_DIR/packs/$pack/openpeon.json")"
    checksums_check="$PEON_DIR/packs/$pack/.checksums"
    pack_complete=$(CHECKSUMS="$checksums_check" PACKS_DIR="$(py_path "$PEON_DIR/packs/$pack")" python3 -c "
import json, os, posixpath, hashlib
m = json.load(open('$manifest_check'))
checksums = {}
cf = os.environ['CHECKSUMS']
packs_dir = os.environ['PACKS_DIR']
if os.path.isfile(cf):
    for line in open(cf):
        parts = line.strip().rsplit(' ', 1)
        if len(parts) == 2:
            checksums[parts[0]] = parts[1]
seen = set()
for cat in m.get('categories', {}).values():
    for s in cat.get('sounds', []):
        f = s['file']
        rel = f[len('sounds/'):] if f.startswith('sounds/') else posixpath.basename(f)
        seen.add(rel)
def is_valid(rel):
    stored = checksums.get(rel)
    if not stored:
        return False
    fp = os.path.join(packs_dir, 'sounds', rel)
    if not os.path.isfile(fp):
        return False
    actual = hashlib.sha256(open(fp, 'rb').read()).hexdigest()
    return actual == stored
print('yes' if seen and all(is_valid(r) for r in seen) else 'no')
" 2>/dev/null || echo "no")
    if [ "$pack_complete" = "yes" ]; then
      TOTAL_SKIPPED_PACKS=$((TOTAL_SKIPPED_PACKS + 1))
      printf "  [%${idx_width}d/%d] %s ✓\n" "$PACK_INDEX" "$TOTAL_PACKS" "$pack"
      continue
    fi
  fi

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

  # Note: empty SOURCE_PATH is valid — it means the manifest is at the repo root.
  # Only fall back when repo or ref are missing.
  if [ -z "$SOURCE_REPO" ] || [ -z "$SOURCE_REF" ]; then
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

  # Verify manifest exists before creating any local directories
  if ! curl -fsSL --head "$PACK_BASE/openpeon.json" >/dev/null 2>&1; then
    TOTAL_FAILED_PACKS=$((TOTAL_FAILED_PACKS + 1))
    FAILED_PACK_NAMES+=("$pack")
    printf "  [%${idx_width}d/%d] %s ❌\n" "$PACK_INDEX" "$TOTAL_PACKS" "$pack"
    continue
  fi

  mkdir -p "$PEON_DIR/packs/$pack/sounds"

  # Download manifest
  if ! curl -fsSL "$PACK_BASE/openpeon.json" -o "$PEON_DIR/packs/$pack/openpeon.json" 2>/dev/null; then
    TOTAL_FAILED_PACKS=$((TOTAL_FAILED_PACKS + 1))
    FAILED_PACK_NAMES+=("$pack")
    printf "  [%${idx_width}d/%d] %s ❌\n" "$PACK_INDEX" "$TOTAL_PACKS" "$pack"
    continue
  fi

  # Download sound files
  manifest="$PEON_DIR/packs/$pack/openpeon.json"
  manifest_py="$(py_path "$manifest")"
  ICON_LIST=$(python3 -c "
import json
m = json.load(open('$manifest_py'))
seen = []
def add(v):
    if not isinstance(v, str) or not v or v.startswith(('http://', 'https://')):
        return
    if v not in seen:
        seen.append(v)
add(m.get('icon'))
for cat in m.get('categories', {}).values():
    add(cat.get('icon'))
    for s in cat.get('sounds', []):
        add(s.get('icon'))
for v in seen:
    print(v)
" 2>/dev/null || true)
  SOUND_COUNT=$(python3 -c "
import json, posixpath
m = json.load(open('$manifest_py'))
seen = set()
for cat in m.get('categories', {}).values():
    for s in cat.get('sounds', []):
        f = s['file']
        # Strip leading 'sounds/' to get relative path; fall back to basename
        if f.startswith('sounds/'):
            rel = f[len('sounds/'):]
        else:
            rel = posixpath.basename(f)
        seen.add(rel)
print(len(seen))
" 2>/dev/null || echo "?")

  CHECKSUMS_FILE="$PEON_DIR/packs/$pack/.checksums"
  touch "$CHECKSUMS_FILE"

  if [ -n "$ICON_LIST" ]; then
    while read -r ifile; do
      ifile="${ifile%$'\r'}"  # strip Windows CRLF trailing CR (Python on Windows outputs \r\n)
      [ -z "$ifile" ] && continue
      is_safe_filename "$ifile" || continue
      mkdir -p "$PEON_DIR/packs/$pack/$(dirname "$ifile")"
      curl -fsSL "$PACK_BASE/$(urlencode_filename "$ifile")" \
           -o "$PEON_DIR/packs/$pack/$ifile" </dev/null 2>/dev/null || true
    done <<< "$ICON_LIST"
  fi

  if [ "$IS_TTY" = true ] && [ "$SOUND_COUNT" != "?" ]; then
    local_file_count=0
    local_byte_count=0

    printf '\033[?25l'  # hide cursor during progress
    draw_progress "$PACK_INDEX" "$TOTAL_PACKS" "$pack" 0 "$SOUND_COUNT" 0

    while read -r sfile; do
      sfile="${sfile%$'\r'}"  # strip Windows CRLF trailing CR (Python on Windows outputs \r\n)
      is_safe_filename "$sfile" || continue
      mkdir -p "$PEON_DIR/packs/$pack/sounds/$(dirname "$sfile")"
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
        break
      fi
      draw_progress "$PACK_INDEX" "$TOTAL_PACKS" "$pack" \
        "$local_file_count" "$SOUND_COUNT" "$local_byte_count"
    done < <(python3 -c "
import json, posixpath
m = json.load(open('$manifest_py'))
seen = set()
for cat in m.get('categories', {}).values():
    for s in cat.get('sounds', []):
        f = s['file']
        if f.startswith('sounds/'):
            rel = f[len('sounds/'):]
        else:
            rel = posixpath.basename(f)
        if rel not in seen:
            seen.add(rel)
            print(rel)
")

    # Clear the progress bar line and print final status on a clean line
    printf '\033[?25h'  # restore cursor
    printf "\r%80s\r" ""
    if [ "$local_file_count" -eq "$SOUND_COUNT" ]; then
      printf "  [%${idx_width}d/%d] %s ✅\n" "$PACK_INDEX" "$TOTAL_PACKS" "$pack"
      TOTAL_DOWNLOAD_PACKS=$((TOTAL_DOWNLOAD_PACKS + 1))
    else
      printf "  [%${idx_width}d/%d] %s (%d/%d) ⚠️\n" "$PACK_INDEX" "$TOTAL_PACKS" "$pack" "$local_file_count" "$SOUND_COUNT"
      TOTAL_PARTIAL_PACKS=$((TOTAL_PARTIAL_PACKS + 1))
      PARTIAL_PACK_NAMES+=("$pack")
    fi

    TOTAL_DOWNLOAD_FILES=$((TOTAL_DOWNLOAD_FILES + local_file_count))
    TOTAL_DOWNLOAD_BYTES=$((TOTAL_DOWNLOAD_BYTES + local_byte_count))
  else
    printf "  [%${idx_width}d/%d] %s " "$PACK_INDEX" "$TOTAL_PACKS" "$pack"
    local_file_count=0

    while read -r sfile; do
      sfile="${sfile%$'\r'}"  # strip Windows CRLF trailing CR (Python on Windows outputs \r\n)
      is_safe_filename "$sfile" || continue
      mkdir -p "$PEON_DIR/packs/$pack/sounds/$(dirname "$sfile")"
      if is_cached_valid "$PEON_DIR/packs/$pack/sounds/$sfile" "$CHECKSUMS_FILE" "$sfile"; then
        printf "."
        local_file_count=$((local_file_count + 1))
      elif curl -fsSL "$PACK_BASE/sounds/$(urlencode_filename "$sfile")" -o "$PEON_DIR/packs/$pack/sounds/$sfile" </dev/null 2>/dev/null; then
        store_checksum "$CHECKSUMS_FILE" "$sfile" "$PEON_DIR/packs/$pack/sounds/$sfile"
        printf "."
        local_file_count=$((local_file_count + 1))
      else
        break
      fi
    done < <(python3 -c "
import json, posixpath
m = json.load(open('$manifest_py'))
seen = set()
for cat in m.get('categories', {}).values():
    for s in cat.get('sounds', []):
        f = s['file']
        if f.startswith('sounds/'):
            rel = f[len('sounds/'):]
        else:
            rel = posixpath.basename(f)
        if rel not in seen:
            seen.add(rel)
            print(rel)
")

    if [ "$SOUND_COUNT" != "?" ] && [ "$local_file_count" -eq "$SOUND_COUNT" ]; then
      printf " ✅ %s sounds\n" "$SOUND_COUNT"
      TOTAL_DOWNLOAD_PACKS=$((TOTAL_DOWNLOAD_PACKS + 1))
    else
      printf " ⚠️%s/%s sounds\n" "$local_file_count" "$SOUND_COUNT"
      TOTAL_PARTIAL_PACKS=$((TOTAL_PARTIAL_PACKS + 1))
      PARTIAL_PACK_NAMES+=("$pack")
    fi
  fi
done

# --- Summary ---
echo ""
SUMMARY_PARTS=()
if [ "$TOTAL_DOWNLOAD_PACKS" -gt 0 ]; then
  if [ "$IS_TTY" = true ] && [ "$TOTAL_DOWNLOAD_BYTES" -gt 0 ]; then
    if [ "$TOTAL_DOWNLOAD_BYTES" -ge 1048576 ]; then
      SUMMARY_SIZE="$(( TOTAL_DOWNLOAD_BYTES / 1048576 )).$(( (TOTAL_DOWNLOAD_BYTES % 1048576) * 10 / 1048576 )) MB"
    elif [ "$TOTAL_DOWNLOAD_BYTES" -ge 1024 ]; then
      SUMMARY_SIZE="$(( TOTAL_DOWNLOAD_BYTES / 1024 )) KB"
    else
      SUMMARY_SIZE="$TOTAL_DOWNLOAD_BYTES B"
    fi
    SUMMARY_PARTS+=("✅ $TOTAL_DOWNLOAD_PACKS downloaded ($TOTAL_DOWNLOAD_FILES files, $SUMMARY_SIZE)")
  else
    SUMMARY_PARTS+=("✅ $TOTAL_DOWNLOAD_PACKS downloaded")
  fi
fi
if [ "$TOTAL_SKIPPED_PACKS" -gt 0 ]; then
  SUMMARY_PARTS+=("✓ $TOTAL_SKIPPED_PACKS already installed")
fi
if [ "$TOTAL_PARTIAL_PACKS" -gt 0 ]; then
  SUMMARY_PARTS+=("⚠️ $TOTAL_PARTIAL_PACKS partial")
fi
if [ "$TOTAL_FAILED_PACKS" -gt 0 ]; then
  SUMMARY_PARTS+=("❌ $TOTAL_FAILED_PACKS unavailable")
fi
if [ "${#SUMMARY_PARTS[@]}" -gt 0 ]; then
  IFS="  " ; echo "${SUMMARY_PARTS[*]}" ; unset IFS
fi
if [ "${#PARTIAL_PACK_NAMES[@]}" -gt 0 ]; then
  echo ""
  echo "Partial downloads (some sounds unavailable):"
  for p in "${PARTIAL_PACK_NAMES[@]}"; do echo "  - $p"; done
fi
if [ "${#FAILED_PACK_NAMES[@]}" -gt 0 ]; then
  echo ""
  echo "Failed downloads (manifest unavailable):"
  for p in "${FAILED_PACK_NAMES[@]}"; do echo "  - $p"; done
fi

# Report total disk usage for all packs
PACKS_PATH="$PEON_DIR/packs"
# Resolve symlink to show actual storage location
PACKS_REAL="$(cd "$PACKS_PATH" 2>/dev/null && pwd -P)"
DISK_BYTES=$(du -sk "$PACKS_REAL" 2>/dev/null | cut -f1)
if [ -n "$DISK_BYTES" ] && [ "$DISK_BYTES" -gt 0 ]; then
  DISK_MB=$(( DISK_BYTES / 1024 ))
  echo ""
  if [ "$PACKS_REAL" != "$PACKS_PATH" ]; then
    echo "Disk usage: ${DISK_MB} MB ($PACKS_REAL)"
  else
    echo "Disk usage: ${DISK_MB} MB"
  fi
fi
