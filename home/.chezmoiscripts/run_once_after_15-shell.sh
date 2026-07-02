#!/usr/bin/env bash
# Installs oh-my-zsh, zsh-syntax-highlighting, and sets Homebrew zsh as default shell.
set -euo pipefail

log() { printf '==> %s\n' "$*"; }

install_oh_my_zsh() {
  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    log "oh-my-zsh already installed."
    return 0
  fi

  log "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_syntax_highlighting() {
  local plugin_dir="${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

  if [[ -d "${plugin_dir}/.git" ]]; then
    log "zsh-syntax-highlighting already installed."
    return 0
  fi

  mkdir -p "${HOME}/.oh-my-zsh/custom/plugins"
  log "Installing zsh-syntax-highlighting OMZ plugin..."
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${plugin_dir}"
}

set_default_shell() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Homebrew not found — skip default shell change."
    return 0
  fi

  local zsh_path
  zsh_path="$(brew --prefix)/bin/zsh"

  if [[ ! -x "${zsh_path}" ]]; then
    log "Homebrew zsh not found at ${zsh_path} — skip default shell change."
    return 0
  fi

  if ! grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
    log "Adding ${zsh_path} to /etc/shells (sudo required)..."
    echo "${zsh_path}" | sudo tee -a /etc/shells >/dev/null
  fi

  if [[ "${SHELL}" != "${zsh_path}" ]]; then
    log "Setting default shell to ${zsh_path}..."
    chsh -s "${zsh_path}"
  else
    log "Default shell is already ${zsh_path}."
  fi
}

install_oh_my_zsh
install_syntax_highlighting
set_default_shell

log "Shell setup complete. Open a new terminal tab for changes to take effect."
