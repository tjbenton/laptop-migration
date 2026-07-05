.DEFAULT_GOAL := help
SHELL := /bin/bash

REPO := tjbenton/laptop-migration
BREWFILE := Brewfile

.PHONY: help install bootstrap brew brew-dump apply diff update macos doctor chezmoi-install

help:
	@echo "laptop-migration — one-command Mac dev environment setup"
	@echo ""
	@echo "Fresh Mac (zero prior setup):"
	@echo "  ./bootstrap.sh"
	@echo "  — or —"
	@echo "  sh -c \"\$$(curl -fsLS get.chezmoi.io)\" -- init --apply $(REPO)"
	@echo ""
	@echo "Targets:"
	@echo "  make install       Run bootstrap.sh (Xcode CLT → Homebrew → chezmoi → apply)"
	@echo "  make bootstrap       Same as install"
	@echo "  make brew            brew bundle install --file=$(BREWFILE)"
	@echo "  make brew-dump       Refresh $(BREWFILE) from this machine"
	@echo "  make apply           chezmoi apply"
	@echo "  make diff            chezmoi diff"
	@echo "  make update          chezmoi update (git pull + apply)"
	@echo "  make macos           Apply macOS system defaults"
	@echo "  make doctor          chezmoi doctor + sanity checks"
	@echo "  make chezmoi-install Install chezmoi via Homebrew"

install bootstrap:
	@./bootstrap.sh

brew:
	@brew bundle install --file="$(BREWFILE)"

brew-dump:
	@brew bundle dump --file="$(BREWFILE)" --force
	@echo "Updated $(BREWFILE)"

apply:
	@chezmoi apply

diff:
	@chezmoi diff

update:
	@chezmoi update

macos:
	@bash home/.chezmoiscripts/run_once_after_30-macos-defaults.sh

doctor: chezmoi-install
	@echo "=== chezmoi doctor ==="
	@chezmoi doctor || true
	@echo ""
	@echo "=== toolchain ==="
	@command -v brew && brew --version | head -1 || echo "brew: not installed"
	@command -v chezmoi && chezmoi --version || echo "chezmoi: not installed"
	@command -v mise && mise --version || echo "mise: not installed"
	@command -v mise >/dev/null 2>&1 && mise current || echo "mise: no active runtimes"
	@command -v node && node --version || echo "node: not installed"
	@command -v ruby && ruby --version || echo "ruby: not installed"
	@command -v python3 && python3 --version || echo "python3: not installed"

chezmoi-install:
	@command -v chezmoi >/dev/null 2>&1 || brew install chezmoi
