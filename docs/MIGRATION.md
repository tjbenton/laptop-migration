# Personal file migration plan

Reference document carried over from the initial migration planning session. The **dev-environment automation** lives in this repo (chezmoi + Brewfile). **Personal file copy** is a separate follow-up pass.

## Goal

Fresh OS on new laptop — no Time Machine restore. Copy personal files to an external drive, recreate dev environment via `laptop-migration` repo.

## Ignore list (personal file copy)

- Any dot files unless explicitly listed in Tier C below
- `Downloads/`, `Sites/`, `Dropbox/`, `Postman/`
- ColdFusion / CommandBox setup (includes ColdBox)
- `Microsoft User Data/`
- `node_modules/`, `graphify/`, `graphify-out/`
- Anything matched by each repo's `.gitignore` when rsync'ing

**Rule:** Outside `~/ui-development`, target **under ~1,000 files** per folder. If counts exceed that, review — you may be including files you don't want.

---

## File manifest

### Tier A — Copy (personal, mostly under ~1,000 each)

| Copy to drive as | Source | ~Files |
|---|---|---:|
| `Desktop/` | `~/Desktop/` **excluding** `old hard drive/` | 65 |
| `dev-setup/` | `~/dev-setup/` | 39 |
| `bin/` | `~/bin/` | 3 |
| `projects/` | `~/projects/` | 1 |
| `Music/`, `Movies/` | `~/Music/`, `~/Movies/` | 5 |
| `shares/` | `~/shares/` | 1 |
| `Documents/` | `~/Documents/` **excluding** `Microsoft User Data/` | 1,518 ⚠️ |
| `Pictures/new zealand/` | loose photos folder | 34 |
| `Pictures/queenstown-hill-modified.jpg` | single file | 1 |

### Tier B — Needs decision (over 1,000 or special)

| Source | ~Files | Decision needed |
|---|---:|---|
| `~/Pictures/iPhoto Library.migratedphotolibrary/` | 14,768 | iCloud re-sync vs local copy |
| `~/contract-development/` | 38,076 | Keep, archive, or skip |
| `~/myagent/` | 1,106 | Reinstall Azure DevOps agent fresh? |
| `~/Desktop/old hard drive/` | 21,206 | **Recommend skip** |
| `~/ui-development/` | ~168k | Copy selected repos only (no node_modules) |

**Active ui-development repos (suggested subset):**

`shop-rn`, `shop-graphql`, `shopify-marketamerica`, `components`, `common`, `unfranchise`, `unfranchise-graphql`, `code-signing`, `lint-rules`, `color-set`, `translation-ui`, `translation-utility`

### Tier C — Dotfiles & config (explicit dot paths)

**Shell & Git**

- `~/.zshrc`, `~/.bash_profile` (shim) — **handled by chezmoi** (`home/dot_zshrc`, `home/dot_bash_profile`)
- Legacy bash files (`~/.bash_aliases`, `~/.bash_exports`, `~/.bash_functions`) — **replaced** by consolidated `~/.zshrc`; not copied
- `~/.gitconfig` — **handled by chezmoi** (`home/dot_gitconfig.tmpl`)
- `~/.gitignore`, `~/.git_completion.sh`, `~/.inputrc`, `~/.hushlogin` — manual follow-up if still needed
- `~/dev-setup/dotfiles/` (older backup) — skip

**Hyper**

- `~/.hyper.js`
- `~/.hyper_plugins/package.json` (reinstall plugins; skip `node_modules/`)

**Cursor**

- `~/Library/Application Support/Cursor/User/settings.json` — **handled by `migrate/pack.sh`** (`cursor-setup.tar.gz`)
- `~/Library/Application Support/Cursor/User/keybindings.json` — **handled by migrate pack**
- `~/.cursor/hooks/`, `~/.cursor/hooks.json` — **handled by migrate pack**
- `~/.vscode/style.css` (custom CSS for Cursor) — **handled by migrate pack**
- `~/.cursor/skills/`, `~/.cursor/skills-cursor/`, `~/.cursor/plugins/` — skip (reinstall / sync separately)
- Per-project: `~/ui-development/*/.cursor/` rules — included via ui-development archive
- **Skip:** `History/`, `workspaceStorage/`, `globalStorage/`, `chats/`, `plans/`

**Fonts**

- Fira Code + Operator Mono — **handled by migrate pack** (`cursor-setup.tar.gz`)
- Other `~/Library/Fonts/` files — not copied; reinstall or add manually if needed

**SSH** (secure copy — decide copy vs regenerate)

- `~/.ssh/config`, `github_rsa`, `id_rsa`, `codesign_git_rsa` (+ `.pub`)
- **Skip:** `~/.ssh/agent/` (Cursor remote cache)

**Agent / council tooling**

- `~/.agents/`
- `~/.local/claude-council/` + `~/.local/bin/` scripts

### Tier D — Explicitly ignore

- `~/Downloads/`, `~/Sites/`, `~/Dropbox/`, `~/Postman/`
- `~/Documents/Microsoft User Data/`
- `~/.CommandBox/`
- All `node_modules/`, `graphify/`, `graphify-out/`
- `.cache/`, build artifacts

---

## 20 questions (answer to finalize copy script)

1. **New Mac chip?** Apple Silicon (M-series) or Intel?
2. **Photos strategy?** iCloud Photos re-sync vs local export of `iPhoto Library.migratedphotolibrary`?
3. **`~/Desktop/old hard drive/`** — exclude entirely?
4. **`~/contract-development/mobile-rebook/`** (~37k files) — still active?
5. **`contract-development/frontend/`** and **`lint-rules/`** — keep or skip?
6. **Which `~/ui-development` projects?** Active subset only or all 85 repos?
7. **`~/myagent/`** — still running Azure DevOps agent?
8. **`~/nutrametrix-assets/`** and asset folders in ui-development — still needed?
9. **`~/projects/brotherhood/`** — keep?
10. **SSH keys** — copy private keys or generate new?
11. **Git credentials** — copy `~/.git-credentials` or fresh auth?
12. **Cloud/dev credentials** — copy AWS/gcloud/ngrok/OpenVPN or re-auth?
13. **Secrets manager** — 1Password makes dotfile secrets unnecessary?
14. **Android / iOS dev** — full reinstall of Android Studio, Xcode, CocoaPods, Maestro?
15. **Docker** — fresh install or migrate images/volumes?
16. **Adobe + fonts** — skip Adobe CC (not renewing); Fira Code + Operator Mono copied via `cursor-setup.tar.gz`
17. **Hyper** — still daily driver or mostly Cursor terminal?
18. **Cursor extensions** — copy all 31 extensions or reinstall from list?
19. **Browser & cloud** — Firefox bookmarks, Google Drive, iCloud — cloud re-sync or copy?
20. **Homebrew casks** — reproduce full list or trim to what you still use?

---

## Dev environment recreation (handled by this repo)

The `laptop-migration` repo automates most of this via chezmoi + Brewfile. Manual steps remain for secrets and App Store apps until `mas` entries are added.

### Order on new Mac

1. Run bootstrap (see [README.md](../README.md))
2. Copy SSH keys or generate new + add to GitHub
3. `gh auth login`
4. Clone ui-development repos (or rsync from backup drive)
5. Per repo: `yarn`/`npm install`, `bundle install`, `make install`
6. Xcode via `xcodes install` or App Store
7. Android Studio → SDK setup, `pod install` in iOS folders

### Runtime versions (global defaults via mise)

| Tool | Version |
|------|---------|
| Ruby | 3.4.9 (shop-rn `.ruby-version`; overridable per project) |
| Node | 20.19.4 (overridable via `.nvmrc` / `.tool-versions`) |
| Python | 3.12 |

Configured in `~/.config/mise/config.toml` (chezmoi-managed). Override at bootstrap via `LAPTOP_MIGRATION_RUBY`, `LAPTOP_MIGRATION_NODE`, `LAPTOP_MIGRATION_PYTHON`.

### Brewfile

Seeded from `~/dev-setup/migration/Brewfile` (214 lines). Trim casks you no longer need before the new laptop. Refresh from current machine:

```bash
make brew-dump
```

---

## Recommended rsync shape (legacy reference)

The scripts in `migrate/pack.sh` and `migrate/restore.sh` replace manual rsync for the default folder set. Keep this section as reference if you need a one-off copy:

```bash
BACKUP="/Volumes/YourDrive/laptop-migration/personal-files"
mkdir -p "${BACKUP}"

# Desktop (exclude old backup)
rsync -av --progress \
  --exclude 'old hard drive' \
  ~/Desktop/ "${BACKUP}/Desktop/"

# Documents (exclude Adobe and Microsoft User Data)
rsync -av --progress \
  --exclude 'Adobe' \
  --exclude 'Microsoft User Data' \
  ~/Documents/ "${BACKUP}/Documents/"

# ui-development — per-project, gitignore-aware (after Q6)
rsync -av --progress \
  --exclude node_modules \
  --exclude graphify-out \
  --exclude graphify \
  --exclude .git/objects \
  ~/ui-development/shop-rn/ "${BACKUP}/ui-development/shop-rn/"
```

### Scripted pack + restore (preferred)

```bash
# Old Mac
./migrate/pack.sh /Volumes/YourDrive

# New Mac
/Volumes/YourDrive/laptop-migration-files/restore.sh
```

---

## Status

| Item | Status |
|------|--------|
| Brewfile captured | Done (in repo root) |
| chezmoi + Makefile scaffold | Done |
| Dotfile seeding (zsh, bash, Hyper, Cursor) | zsh/bash done via chezmoi; Hyper/Cursor **follow-up** |
| Personal file copy script | Done (`migrate/pack.sh`, `migrate/restore.sh`) |
| `mas` App Store entries | **Follow-up** |
| Secrets (age / 1Password) | **Follow-up** |
