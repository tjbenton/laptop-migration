#!/usr/bin/env bash
# Installs global Ruby, Node, and Python via mise (~/.config/mise/config.toml).
set -euo pipefail

ensure_brew_path() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_mise_tools() {
  local config="${HOME}/.config/mise/config.toml"

  if ! command -v mise >/dev/null 2>&1; then
    echo "mise not found — skip runtime install (run brew bundle first)"
    return 0
  fi

  if [[ ! -f "${config}" ]]; then
    echo "mise config not found at ${config} — skip runtime install"
    return 0
  fi

  mise trust "${config}" 2>/dev/null || true

  echo "==> mise install (global tools from ${config})"
  mise install

  echo "==> mise current"
  mise current
}

ensure_brew_path
install_mise_tools
