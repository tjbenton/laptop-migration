#!/usr/bin/env bash
# Restore personal folders from drive archives into ~.
# Run on the NEW Mac from the external drive copy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Restore personal folders from .tar.gz archives in this directory into \$HOME.

Options:
  --skip-checksums  Skip checksum verification (not recommended)
  -h, --help        Show this help

Run from the drive folder created by pack.sh, e.g.:
  /Volumes/YourDrive/laptop-migration-files/restore.sh
EOF
}

SKIP_CHECKSUMS=false

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-checksums)
        SKIP_CHECKSUMS=true
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
        err "Unexpected argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

verify_checksums() {
  local checksums="${SCRIPT_DIR}/checksums.sha256"

  if [[ ! -f "$checksums" ]]; then
    warn "No checksums.sha256 found — skipping verification."
    return 0
  fi

  log "Verifying archive checksums..."
  (
    cd "$SCRIPT_DIR"
    shasum -a 256 -c checksums.sha256
  )
  log "Checksum verification passed."
}

folder_has_content() {
  local dir="$1"
  local entry name

  [[ ! -d "$dir" ]] && return 1

  for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
    [[ -e "$entry" ]] || continue
    name="$(basename "$entry")"
    case "$name" in
      .localized | .DS_Store) continue ;;
    esac
    return 0
  done
  return 1
}

fix_cursor_settings_paths() {
  local settings="${HOME}/Library/Application Support/Cursor/User/settings.json"

  [[ -f "$settings" ]] || return 0

  # Rewrite custom CSS path for the new machine's $HOME.
  sed -i '' "s|\"file:///Users/[^\"]*/.vscode/style.css\"|\"file://${HOME}/.vscode/style.css\"|g" "$settings"
}

restore_cursor_setup() {
  local archive="${SCRIPT_DIR}/cursor-setup.tar.gz"

  [[ -f "$archive" ]] || return 0

  log "Restoring Cursor config, hooks, custom CSS, and fonts from cursor-setup.tar.gz"
  mkdir -p "${HOME}/Library/Application Support/Cursor/User"
  mkdir -p "${HOME}/Library/Fonts"
  mkdir -p "${HOME}/.cursor"
  mkdir -p "${HOME}/.vscode"

  tar -xzf "$archive" -C "$HOME"
  fix_cursor_settings_paths

  log "Fonts installed to ~/Library/Fonts — restart Cursor if they don't appear immediately."
}

main() {
  parse_args "$@"

  local archive folder
  local -a restored=()
  local -a skipped=()
  local found_archive=false
  local restored_cursor=false

  if [[ "$SKIP_CHECKSUMS" != true ]]; then
    verify_checksums
  fi

  log "Restoring into ${HOME}"

  for archive in "${SCRIPT_DIR}"/*.tar.gz; do
    [[ -e "$archive" ]] || continue
    folder="$(basename "${archive%.tar.gz}")"

    if [[ "$folder" == "cursor-setup" ]]; then
      continue
    fi

    found_archive=true

    if folder_has_content "${HOME}/${folder}"; then
      warn "Skipping ${folder} — ${HOME}/${folder} already has content."
      skipped+=("$folder")
      continue
    fi

    log "Restoring ${folder} from $(basename "$archive")"
    mkdir -p "${HOME}/${folder}"
    tar -xzf "$archive" -C "$HOME"
    restored+=("$folder")
  done

  if [[ -f "${SCRIPT_DIR}/cursor-setup.tar.gz" ]]; then
    restore_cursor_setup
    restored_cursor=true
    found_archive=true
  fi

  if [[ "$found_archive" != true ]]; then
    err "No .tar.gz archives found in ${SCRIPT_DIR}"
    exit 1
  fi

  printf '\n'
  log "Restore complete."

  if [[ ${#restored[@]} -gt 0 ]]; then
    printf 'Restored:\n'
    for folder in "${restored[@]}"; do
      printf '  - %s\n' "$folder"
    done
  fi

  if [[ "$restored_cursor" == true ]]; then
    printf '  - Cursor setup (settings, keybindings, hooks, style.css, fonts)\n'
  fi

  if [[ ${#skipped[@]} -gt 0 ]]; then
    printf '\nSkipped (destination already had content):\n'
    for folder in "${skipped[@]}"; do
      printf '  - %s\n' "$folder"
    done
  fi

  if [[ -d "${SCRIPT_DIR}/Desktop-old-hard-drive" ]]; then
    printf '\nNote: Desktop/old hard drive was packed as cold storage only:\n'
    printf '  %s/Desktop-old-hard-drive/\n' "$SCRIPT_DIR"
    printf 'It is not restored automatically.\n'
  fi

  printf '\n'
  log "Reinstall project dependencies when you open repos:"
  printf '  npm install / yarn / pnpm install\n'
  printf '  bundle install\n'
  printf '  pod install   (iOS projects)\n'
  if [[ "$restored_cursor" == true ]]; then
    printf '\n'
    log "Cursor: quit and reopen the app to pick up settings and fonts."
  fi
}

main "$@"
