#!/usr/bin/env bash
# Fresh Mac bootstrap: Xcode CLT → Homebrew → chezmoi → apply dotfiles.
# Idempotent — safe to re-run on a healthy machine.
set -euo pipefail

REPO="${LAPTOP_MIGRATION_REPO:-tjbenton/laptop-migration}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '==> %s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

brew_binary() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    printf '%s\n' /opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    printf '%s\n' /usr/local/bin/brew
  fi
}

activate_brew() {
  local brew_bin
  brew_bin="$(brew_binary || true)"
  [[ -n "$brew_bin" ]] || return 0
  # shellcheck source=/dev/null
  eval "$("$brew_bin" shellenv)"
}

persist_brew_shellenv() {
  local brew_bin zprofile="${HOME}/.zprofile"

  brew_bin="$(brew_binary || true)"
  [[ -n "$brew_bin" ]] || return 0

  touch "${zprofile}"
  if ! grep -qF 'brew shellenv' "${zprofile}" 2>/dev/null; then
    log "Persisting Homebrew PATH in ${zprofile}"
    printf '\n# Homebrew (added by laptop-migration bootstrap)\n' >>"${zprofile}"
    printf 'eval "$(%s shellenv)"\n' "${brew_bin}" >>"${zprofile}"
  fi
}

ensure_brew_available() {
  activate_brew

  if command -v brew >/dev/null 2>&1; then
    persist_brew_shellenv
    return 0
  fi

  err "Homebrew is not on PATH after install."
  if [[ -x /opt/homebrew/bin/brew ]]; then
    err "Run: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
  elif [[ -x /usr/local/bin/brew ]]; then
    err "Run: eval \"\$(/usr/local/bin/brew shellenv)\""
  else
    err "Homebrew does not appear to be installed. Re-run this script after installing Homebrew."
  fi
  exit 1
}

print_brew_recovery_hint() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  log "If 'which brew' is empty in this terminal, run:"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    printf '  eval "$(/opt/homebrew/bin/brew shellenv)"\n'
  elif [[ -x /usr/local/bin/brew ]]; then
    printf '  eval "$(/usr/local/bin/brew shellenv)"\n'
  fi
  log "Then open a new terminal tab, or re-run this bootstrap script."
}

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
if ! command -v brew >/dev/null 2>&1 && [[ -z "$(brew_binary || true)" ]]; then
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log "Homebrew already installed."
fi

ensure_brew_available

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
print_brew_recovery_hint
