#!/usr/bin/env bash
# Fresh Mac bootstrap: Xcode CLT → Homebrew → chezmoi → apply dotfiles.
# Idempotent — safe to re-run; auto-recovers from partial/failed chezmoi state.
set -eo pipefail

REPO="${LAPTOP_MIGRATION_REPO:-tjbenton/laptop-migration}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
set -u
CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"
CHEZMOI_CONFIG="${HOME}/.config/chezmoi"

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

dotfiles_source() {
  if [[ -f "${SCRIPT_DIR}/.chezmoiroot" ]]; then
    printf '%s\n' "${SCRIPT_DIR}"
  else
    printf '%s\n' "${REPO}"
  fi
}

chezmoi_from_github() {
  [[ "$(dotfiles_source)" != "${SCRIPT_DIR}" ]]
}

chezmoi_prompt_args() {
  CHEZMOI_INIT_ARGS=()

  local name email
  name="$(git config --global user.name 2>/dev/null || true)"
  if [[ -z "${name}" ]]; then
    name="$(id -F 2>/dev/null || true)"
  fi
  email="$(git config --global user.email 2>/dev/null || true)"

  if [[ -n "${name}" ]]; then
    CHEZMOI_INIT_ARGS+=(--promptString "Your full name=${name}")
  fi
  if [[ -n "${email}" ]]; then
    CHEZMOI_INIT_ARGS+=(--promptString "Your email address=${email}")
  fi
}

chezmoi_initialized() {
  local src
  src="$(chezmoi source-path 2>/dev/null || true)"
  [[ -n "${src}" && -d "${src}/.git" ]]
}

chezmoi_stale_state() {
  [[ -d "${CHEZMOI_SOURCE}" || -d "${CHEZMOI_CONFIG}" ]]
}

reset_chezmoi_state() {
  log "Resetting chezmoi state..."
  rm -rf "${CHEZMOI_SOURCE}" "${CHEZMOI_CONFIG}"
}

maybe_regenerate_chezmoi_config() {
  local source
  source="$(dotfiles_source)"

  if chezmoi_initialized && [[ ! -f "${CHEZMOI_CONFIG}/chezmoi.toml" ]]; then
    log "Regenerating chezmoi config..."
    chezmoi init "${CHEZMOI_INIT_ARGS[@]}" "${source}"
  fi
}

init_dotfiles() {
  local source
  source="$(dotfiles_source)"

  chezmoi_prompt_args
  log "Initializing chezmoi from ${source}..."
  chezmoi init --apply "${CHEZMOI_INIT_ARGS[@]}" "${source}"
}

update_or_apply_dotfiles() {
  chezmoi_prompt_args
  maybe_regenerate_chezmoi_config

  if chezmoi_from_github; then
    log "chezmoi initialized — pulling latest from GitHub and applying..."
    if chezmoi update -v; then
      return 0
    fi
    return 1
  fi

  log "chezmoi initialized — applying local dotfiles..."
  if chezmoi apply -v; then
    return 0
  fi
  return 1
}

apply_dotfiles_once() {
  if chezmoi_initialized; then
    if update_or_apply_dotfiles; then
      return 0
    fi
    return 1
  fi

  if chezmoi_stale_state; then
    log "Stale chezmoi state detected (previous run may have failed)..."
    reset_chezmoi_state
  fi

  if init_dotfiles; then
    return 0
  fi
  return 1
}

apply_dotfiles() {
  if apply_dotfiles_once; then
    return 0
  fi

  if chezmoi_initialized; then
    log "chezmoi apply failed — retrying apply (keeping source)..."
    if update_or_apply_dotfiles; then
      return 0
    fi
    err "chezmoi apply failed after retry. Run 'chezmoi doctor' for details."
    exit 1
  fi

  log "chezmoi state broken — resetting and re-initializing..."
  reset_chezmoi_state
  init_dotfiles || {
    err "chezmoi failed after retry. Run 'chezmoi doctor' for details."
    exit 1
  }
}

verify_bootstrap() {
  log "Verifying bootstrap..."
  local failed=0

  if ! command -v brew >/dev/null 2>&1; then
    err "brew is not on PATH"
    failed=1
  fi

  if ! command -v chezmoi >/dev/null 2>&1; then
    err "chezmoi is not installed"
    failed=1
  fi

  if ! chezmoi_initialized; then
    err "chezmoi is not initialized"
    failed=1
  fi

  if ! chezmoi doctor; then
    err "chezmoi doctor reported problems"
    failed=1
  fi

  if [[ "${failed}" -ne 0 ]]; then
    exit 1
  fi

  log "Bootstrap verified: brew, chezmoi, and dotfiles are ready."
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

# --- 4. Apply dotfiles (init, update, or recover from failed prior run) ---
apply_dotfiles

# --- 5. Verify ---
verify_bootstrap

log "Done. Open a new terminal tab so ~/.zshrc loads, then run: chezmoi doctor"
