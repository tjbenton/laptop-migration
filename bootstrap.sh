#!/usr/bin/env bash
# Fresh Mac bootstrap: Xcode CLT → Homebrew → chezmoi → apply dotfiles.
# Idempotent — safe to re-run on a healthy machine.
set -euo pipefail

REPO="${LAPTOP_MIGRATION_REPO:-tjbenton/laptop-migration}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '==> %s\n' "$*"; }

# --- 1. Xcode Command Line Tools ---
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools (GUI prompt will appear)..."
  xcode-select --install || true
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
  log "Xcode CLT installed."
else
  log "Xcode CLT already installed."
fi

# --- 2. Homebrew ---
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  log "Homebrew already installed."
fi

# Ensure brew is on PATH for Apple Silicon default install
if [[ -x /opt/homebrew/bin/brew ]] && ! command -v brew >/dev/null 2>&1; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- 3. chezmoi ---
if ! command -v chezmoi >/dev/null 2>&1; then
  log "Installing chezmoi..."
  brew install chezmoi
else
  log "chezmoi already installed."
fi

# --- 4. Apply dotfiles ---
if [[ -f "${SCRIPT_DIR}/.chezmoiroot" ]]; then
  log "Local repo detected — applying from ${SCRIPT_DIR}..."
  if chezmoi source-path >/dev/null 2>&1; then
    chezmoi apply
  else
    chezmoi init --apply "${SCRIPT_DIR}"
  fi
else
  log "Applying from GitHub (${REPO})..."
  chezmoi init --apply "${REPO}"
fi

log "Done. Run 'chezmoi doctor' to verify, or 'make doctor' if make is available."
