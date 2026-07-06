#!/usr/bin/env bash
# Pack personal folders into per-folder archives on an external drive.
# Run on the OLD Mac before moving the drive to the new machine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR_NAME="laptop-migration-files"

# Edit this list before running if needed.
FOLDERS=(
  Desktop
  Documents
  ui-development
  Pictures
  Sites
  contract-development
  myagent
  projects
  bin
  dev-setup
  shares
  nutrametrix-assets
  Downloads
  Movies
  Music
)

# Regenerable / junk directories excluded from every archive.
EXCLUDES=(
  node_modules
  Pods
  dist
  build
  coverage
  graphify-out
  .next
  .expo
  .turbo
  .cache
  .gradle
  DerivedData
  .DS_Store
)

WITH_OLD_HARD_DRIVE=false
DRIVE=""

log() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] /Volumes/YourDrive

Pack personal folders into compressed archives on an external drive.

Options:
  --with-old-hard-drive  Also copy ~/Desktop/old hard drive/ un-archived to the drive
  -h, --help             Show this help

Creates: <drive>/${OUTPUT_DIR_NAME}/
  - One .tar.gz per folder (Desktop.tar.gz, Documents.tar.gz, ...)
  - cursor-setup.tar.gz (Cursor settings, hooks, Fira Code + Operator Mono fonts)
  - hyper-setup.tar.gz (Hyper config + plugin list)
  - MANIFEST.txt
  - checksums.sha256
  - restore.sh (copied from this repo)
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with-old-hard-drive)
        WITH_OLD_HARD_DRIVE=true
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        err "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        if [[ -n "$DRIVE" ]]; then
          err "Unexpected argument: $1"
          usage
          exit 1
        fi
        DRIVE="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$DRIVE" ]]; then
    err "Destination drive path is required."
    usage
    exit 1
  fi

  if [[ ! -d "$DRIVE" ]]; then
    err "Destination does not exist or is not a directory: ${DRIVE}"
    exit 1
  fi

  if [[ ! -w "$DRIVE" ]]; then
    err "Destination is not writable: ${DRIVE}"
    exit 1
  fi
}

folder_extra_excludes() {
  case "$1" in
    Desktop) printf '%s\n' "old hard drive" ;;
    Documents) printf '%s\n' "Adobe" "Library" ;;
    Pictures) printf '%s\n' "Photos Library.photoslibrary" ;;
  esac
}

TAR_EXCLUDES=()

build_tar_excludes() {
  local folder="$1"
  local pattern extra

  TAR_EXCLUDES=()

  for pattern in "${EXCLUDES[@]}"; do
    TAR_EXCLUDES+=(--exclude="${folder}/${pattern}")
    TAR_EXCLUDES+=(--exclude="${folder}/*/${pattern}")
    TAR_EXCLUDES+=(--exclude="${folder}/*/*/${pattern}")
    TAR_EXCLUDES+=(--exclude="${folder}/*/*/*/${pattern}")
    TAR_EXCLUDES+=(--exclude="${folder}/*/*/*/*/${pattern}")
  done

  while IFS= read -r extra; do
    [[ -z "$extra" ]] && continue
    TAR_EXCLUDES+=(--exclude="${folder}/${extra}")
    TAR_EXCLUDES+=(--exclude="${folder}/${extra}/*")
  done < <(folder_extra_excludes "$folder")
}

pack_folder() {
  local folder="$1"
  local src="${HOME}/${folder}"
  local dest="${OUT_DIR}/${folder}.tar.gz"

  if [[ ! -d "$src" ]]; then
    warn "Skipping ${folder} (not found at ${src})"
    return 0
  fi

  build_tar_excludes "$folder"

  log "Packing ${folder} -> ${dest}"
  if ! tar --no-xattrs -czf "$dest" -C "$HOME" "${TAR_EXCLUDES[@]}" "$folder"; then
    warn "Packing ${folder} completed with errors — archive may be partial: ${dest}"
  fi
}

pack_hyper_setup() {
  local dest="${OUT_DIR}/hyper-setup.tar.gz"
  local -a items=()

  if [[ -f "${HOME}/.hyper.js" ]]; then
    items+=(".hyper.js")
  fi
  if [[ -f "${HOME}/.hyper_plugins/package.json" ]]; then
    items+=(".hyper_plugins/package.json")
  fi

  if [[ ${#items[@]} -eq 0 ]]; then
    warn "Skipping hyper-setup (no Hyper config found)"
    return 0
  fi

  log "Packing hyper-setup -> ${dest}"
  log "  Hyper config and plugin list (node_modules excluded — reinstalled on restore)"
  tar -czf "$dest" -C "$HOME" "${items[@]}"
}

pack_cursor_setup() {
  local dest="${OUT_DIR}/cursor-setup.tar.gz"
  local -a items=()
  local cursor_user="${HOME}/Library/Application Support/Cursor/User"
  local font

  if [[ -f "${cursor_user}/settings.json" ]]; then
    items+=("Library/Application Support/Cursor/User/settings.json")
  fi
  if [[ -f "${cursor_user}/keybindings.json" ]]; then
    items+=("Library/Application Support/Cursor/User/keybindings.json")
  fi
  if [[ -f "${HOME}/.cursor/hooks.json" ]]; then
    items+=(".cursor/hooks.json")
  fi
  if [[ -d "${HOME}/.cursor/hooks" ]]; then
    items+=(".cursor/hooks")
  fi
  if [[ -f "${HOME}/.vscode/style.css" ]]; then
    items+=(".vscode/style.css")
  fi

  for font in "${HOME}/Library/Fonts"/FiraCode*.otf "${HOME}/Library/Fonts"/OperatorMono*.otf; do
    [[ -f "$font" ]] || continue
    items+=("Library/Fonts/$(basename "$font")")
  done

  if [[ ${#items[@]} -eq 0 ]]; then
    warn "Skipping cursor-setup (no Cursor config or fonts found)"
    return 0
  fi

  log "Packing cursor-setup -> ${dest}"
  log "  Cursor settings, keybindings, hooks, custom CSS, Fira Code + Operator Mono fonts"
  tar -czf "$dest" -C "$HOME" \
    --exclude=".cursor/hooks/__pycache__" \
    --exclude=".cursor/hooks/*/__pycache__" \
    "${items[@]}"
}

copy_old_hard_drive() {
  local src="${HOME}/Desktop/old hard drive"
  local dest="${OUT_DIR}/Desktop-old-hard-drive"

  if [[ ! -d "$src" ]]; then
    warn "Skipping old hard drive copy (not found at ${src})"
    return 0
  fi

  log "Copying Desktop/old hard drive -> ${dest} (un-archived cold storage)"
  mkdir -p "$dest"
  rsync -a "${src}/" "${dest}/"
}

write_manifest() {
  local manifest="${OUT_DIR}/MANIFEST.txt"

  log "Writing ${manifest}"
  {
    printf 'laptop-migration personal files pack\n'
    printf 'Created: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'Source host: %s\n' "$(scutil --get ComputerName 2>/dev/null || hostname)"
    printf 'Source home: %s\n\n' "$HOME"
    printf 'Archives:\n'
    find "$OUT_DIR" -maxdepth 1 -name '*.tar.gz' -print0 |
      sort -z |
      while IFS= read -r -d '' archive; do
        local bytes
        bytes="$(stat -f '%z' "$archive")"
        printf '  %s  %s bytes\n' "$(basename "$archive")" "$bytes"
      done
    if [[ -d "${OUT_DIR}/Desktop-old-hard-drive" ]]; then
      printf '\nUn-archived cold storage:\n'
      printf '  Desktop-old-hard-drive/\n'
    fi
    if [[ -f "${OUT_DIR}/cursor-setup.tar.gz" ]]; then
      printf '\nCursor + fonts archive:\n'
      printf '  cursor-setup.tar.gz  (settings, keybindings, hooks, style.css, Fira Code, Operator Mono)\n'
    fi
    if [[ -f "${OUT_DIR}/hyper-setup.tar.gz" ]]; then
      printf '\nHyper archive:\n'
      printf '  hyper-setup.tar.gz  (.hyper.js, plugin package.json)\n'
    fi
    printf '\nExcluded patterns (all archives):\n'
    for pattern in "${EXCLUDES[@]}"; do
      printf '  %s\n' "$pattern"
    done
    printf '\nPer-folder excludes:\n'
    printf '  Desktop/old hard drive\n'
    printf '  Documents/Adobe\n'
    printf '  Documents/Library\n'
    printf '  Pictures/Photos Library.photoslibrary\n'
  } >"$manifest"
}

write_checksums() {
  local checksums="${OUT_DIR}/checksums.sha256"

  log "Writing ${checksums}"
  (
    cd "$OUT_DIR"
    shasum -a 256 *.tar.gz 2>/dev/null | sort >checksums.sha256
  )
}

main() {
  parse_args "$@"

  OUT_DIR="${DRIVE%/}/${OUTPUT_DIR_NAME}"
  mkdir -p "$OUT_DIR"

  log "Output directory: ${OUT_DIR}"
  log "Packing ${#FOLDERS[@]} folders from ${HOME}"

  for folder in "${FOLDERS[@]}"; do
    pack_folder "$folder"
  done

  pack_cursor_setup
  pack_hyper_setup

  if [[ "$WITH_OLD_HARD_DRIVE" == true ]]; then
    copy_old_hard_drive
  fi

  write_manifest
  write_checksums

  cp "${SCRIPT_DIR}/restore.sh" "${OUT_DIR}/restore.sh"
  chmod +x "${OUT_DIR}/restore.sh"

  log "Done."
  log "Move the drive to the new Mac and run: ${OUT_DIR}/restore.sh"
}

main "$@"
