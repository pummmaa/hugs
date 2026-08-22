---
title: "zsh-config-complete-guide-no-plugings"
date: 2026-08-22T21:56:58Z
lastmod: 2026-08-22T21:56:58Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# houssamouhra/zsh-config — Complete Guide

A modular, framework-free, XDG-based Zsh configuration. This guide documents every keybinding, everything the config changes on your system, and how to install its dependencies.

> **Source / credit:** This configuration is created by **houssamouhra** — [https://github.com/houssamouhra/zsh-config](https://github.com/houssamouhra/zsh-config)
> 

## Table of Contents

1. Overview
2. What It Changes on Your System
3. Environment Variables & PATH
4. Directory & File Layout
5. Plugins (Auto-Installed)
6. Keybindings

  - Line Editing & History
  - FZF Widgets
  - fzf-git (Ctrl-G) Menus
  - Keys Inside fzf Menus
7. Aliases
8. Functions
9. Prompt Behavior
10. History Settings
11. Dependencies
12. Installation Script
13. Post-Install Steps

---

## Overview

The setup is deliberately minimal: no Oh My Zsh, no plugin framework — just a small custom loader (`plugins.zsh`) plus a curated set of plugins. It uses an **XDG-based layout**: `~/.zshenv` sets `ZDOTDIR` to `~/.config/zsh`, and all real configuration lives there, split into focused modules (`prompt`, `history`, `keybinds`, `aliases`, `fzf`, `functions`).

Startup is fast (~17 ms first prompt) thanks to deferred plugin loading (`zsh-defer`), cached completions (`ez-compinit`), lazy-loaded widgets, and a non-blocking `gitstatus`-based prompt.

---

## What It Changes on Your System

On first launch and every startup the config will:

- **Redirect Zsh's config location** — `~/.zshenv` points `ZDOTDIR` at `~/.config/zsh`, so Zsh reads its startup files from there instead of `~/`.
- **Clone 9 plugin repos** into `~/.config/zsh/plugins/` (via `git`, needs network) the first time.
- **Compile a Rust binary** — `zsh-patina` is built with `cargo build --release` into `plugins/zsh-patina/target/release/`.
- **Create directories** — the plugin dir and `~/.cache/zsh/` (for history).
- **Modify `PATH`** — prepends `~/.local/bin`, `~/.cargo/bin`, and a pnpm bin path.
- **Set many environment variables** (editor, pager, locale, cursor theme, ATAC, GPG — see below).
- **Register Zsh hooks** — `precmd`/`preexec`/`chpwd` hooks, a background `gitstatus` daemon, and lazy activators for fzf, fnm, and zsh-patina.
- **Override commands** with functions/aliases — e.g. `git`, `ls`, `grep`, `df`, and lazy wrappers `z`, `y`.
- **Run package/power/process actions** through aliases & functions (poweroff, pacman cleanup, killing processes/ports) — see Functions.
- **Make outbound network calls** in some functions (`weather` → wttr.in, `myip` → ifconfig.me/ipinfo.io).

---

## Environment Variables & PATH

Set in `~/.zshenv`:

| Variable | Value |
| --- | --- |
| `XDG_CONFIG_HOME` | `$HOME/.config` |
| `ZDOTDIR` | `$XDG_CONFIG_HOME/zsh` |
| `LANG` / `LC_ALL` | `en_US.UTF-8` |

Set in `$ZDOTDIR/.zshenv`:

| Variable | Value / Purpose |
| --- | --- |
| `XDG_DATA_HOME` | `$HOME/.local/share` |
| `XDG_BIN_HOME` | `$HOME/.local/bin` |
| `XDG_CACHE_HOME` | `$HOME/.cache` |
| `ZSH_CONFIG_DIR` | `$ZDOTDIR/config` |
| `ZSH_PLUGIN_DIR` | `$ZDOTDIR/plugins` |
| `ZSH_PATINA_PATH` | path to the compiled zsh-patina binary |
| `CARGO_BIN_HOME` | `$HOME/.cargo/bin` |
| `PNPM_HOME` | `$XDG_DATA_HOME/pnpm/bin/bin/bin` |
| `ATAC_CONFIG_DIR` / `ATAC_THEME` / `ATAC_KEY_BINDINGS` | ATAC HTTP client config |
| `DOCKER_CLI_HINTS` | `false` |
| `EDITOR` / `VISUAL` | `nvim` |
| `PAGER` / `MANPAGER` | `less` |
| `GPG_TTY` | `$(tty)` |
| `XCURSOR_THEME` / `XCURSOR_SIZE` / `GTK_CURSOR_THEME` | Bibata-Modern-Classic, 22 |

**PATH** (deduped via `typeset -gU path`) prepends: `$XDG_BIN_HOME`, `$CARGO_BIN_HOME`, `$PNPM_HOME`.

---

## Directory & File Layout

```
~/.zshenv                     # bootstraps ZDOTDIR
~/.config/zsh/
├── .zshenv                   # env vars + PATH
├── .zshrc                    # sources plugins + modules
├── plugins.zsh               # custom plugin loader/updater
├── plugins/                  # (auto-created) cloned plugins live here
└── config/
    ├── prompt.zsh
    ├── history.zsh
    ├── keybinds.zsh
    ├── aliases.zsh
    ├── fzf.zsh
    └── functions.zsh
~/.config/fzf/config          # FZF default options
~/.config/fzf/preview.sh      # fzf preview (eza/bat)
~/.config/fzf-git/fzf-git.sh  # Junegunn's fzf-git integration
~/.cache/zsh/history          # (auto-created) history file
```

---

## Plugins (Auto-Installed)

`plugins.zsh` clones each of these on first use. `gitstatus` and `zsh-defer` load immediately; the rest are deferred. `update-plugin` updates them all (and rebuilds zsh-patina).

| Plugin | Owner | Purpose |
| --- | --- | --- |
| gitstatus | romkatv | Extremely fast Git status for the prompt (background daemon) |
| zsh-defer | romkatv | Defers non-critical plugin loading |
| ez-compinit | mattmc3 | Fast, cached completion initialization |
| zsh-completions | zsh-users | Extra completion definitions |
| fzf-tab | aloxaf | Interactive fzf completion menu |
| zsh-autosuggestions | zsh-users | Fish-like history suggestions |
| zsh-history-substring-search | zsh-users | Substring history search |
| colored-man-pages | houssamouhra | Colored man pages |
| zsh-patina | michel-kraemer | Rust syntax highlighter (built via cargo) |

---

## Keybindings

Emacs keymap is active (`bindkey -e`).

### Line Editing & History

| Key | Action |
| --- | --- |
| `Ctrl-A` | Beginning of line |
| `Ctrl-E` | End of line |
| `Ctrl-W` | Backward kill word |
| `Ctrl-U` | Backward kill line |
| `Ctrl-_` | Undo |
| `Ctrl-B` | Backward char |
| `Ctrl-F` | Forward char |
| `Up` | History search backward (prefix-aware) |
| `Down` | History search forward (prefix-aware) |
| `Ctrl-P` | History substring search up |
| `Ctrl-N` | History substring search down |

### FZF Widgets

Widgets are lazy-loaded — fzf initializes on first use.

| Key | Action |
| --- | --- |
| `Ctrl-R` | Fuzzy reverse history search (dedup, exact, inline info) |
| `Ctrl-T` | Fuzzy file finder (multi-select; `Ctrl-O` opens selection in `nvim`) |
| `Alt-C` | Fuzzy `cd` into a directory (with preview) |
| `Ctrl-Space` | Toggle selection inside any fzf menu |

Previews use `~/.config/fzf/preview.sh`: directories → `eza --tree`, text files → `bat`, binaries → "Binary file".

### fzf-git (Ctrl-G) Menus

Loaded lazily the first time you run `git`. Two-key sequences under the `Ctrl-G` prefix:

| Key | Menu |
| --- | --- |
| `Ctrl-G ?` | Show this bindings list |
| `Ctrl-G Ctrl-F` | Files |
| `Ctrl-G Ctrl-B` | Branches |
| `Ctrl-G Ctrl-T` | Tags |
| `Ctrl-G Ctrl-R` | Remotes |
| `Ctrl-G Ctrl-H` | Commit hashes |
| `Ctrl-G Ctrl-S` | Stashes |
| `Ctrl-G Ctrl-L` | Reflogs |
| `Ctrl-G Ctrl-W` | Worktrees |
| `Ctrl-G Ctrl-E` | Each ref (for-each-ref) |

> **Note:** `keybinds.zsh` also does `bindkey -s '^G' 'tmux-sessionizer'` (type-and-run). This can collide with the fzf-git `Ctrl-G` prefix depending on load order — if you rely on the fzf-git menus, adjust one of the two bindings.
> 

### Keys Inside fzf Menus

Available within the fzf-git pickers:

| Key | Action |
| --- | --- |
| `Ctrl-O` | Open selection in browser (GitHub) |
| `Alt-E` | Open in `$EDITOR` |
| `Alt-A` | Show all (branches / hashes / refs) |
| `Alt-H` | List commit hashes (from branches) |
| `Alt-Enter` | Accept branch/ref without remote prefix |
| `Ctrl-D` | Diff (hashes) |
| `Ctrl-S` | Toggle sort (hashes) |
| `Alt-R` | Toggle raw mode |
| `Alt-F` | List files (from hashes) |
| `Ctrl-X` | Drop stash / remove worktree |
| `Ctrl-/` | Cycle preview window layout |

---

## Aliases

| Alias | Expands to / Purpose |
| --- | --- |
| `bye` | Prompt, then `sudo poweroff` |
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza -lh --icons --group-directories-first --time-style=long-iso` |
| `la` | `eza -lha ... --time-style=long-iso` |
| `tree` | `eza --tree --icons=auto` |
| `grep` | `grep --color=auto` |
| `pacclean` | `sudo pacman -Sc` + `sudo paccache -r` |
| `fonts` | `fc-list : family | sort -u` |
| `pacorphans` | Remove orphan packages (`pacman -Rns $(pacman -Qdtq)`) |
| `update` | `yay -Syu` |
| `df` | `df -h` |
| `n` | `nvim` |
| `gs` | `git status -s` |
| `ds` | `git diff --staged` |
| `dsn` | `git diff --staged | diffnav` |
| `ta` / `tl` / `tkill` / `tks` | tmux attach / list-sessions / kill-server / kill-session |
| `ssh-on` | Start SSH agent via `_ssh_agent_lazy` |
| `ruffle` | Run `ruffle` (Vulkan, immediate present mode) |
| `stream` | `mpv` webcam stream (v4l2, low-latency, hflip) |

---

## Functions

| Function | What it does |
| --- | --- |
| `_ssh_agent_lazy` (`ssh-on`) | Reuses or starts an SSH agent via `keychain` with `~/.ssh/id_ed25519` |
| `z` | Lazy-loads **zoxide**, then jumps (`zoxide init zsh`) |
| `y` | Opens **yazi** at a path or a zoxide-resolved query |
| `_fnm_lazy_load` / `fnm-on` | Activates **fnm** (Node) automatically when a `package.json` is present, or manually |
| `extract` | Universal archive extractor — handles `.tar.bz2/.gz/.bz2/.rar/.gz/.tar/.tbz2/.tgz/.zip/.Z/.7z` (uses tar, bunzip2, unrar, gunzip, unzip, uncompress, 7z) |
| `port <n> [kill]` | Shows (via `lsof`) or kills the process on a port |
| `fkill` | Fuzzy-pick a process with fzf and `kill` it |
| `myip` | Local IP + public IP + geolocation (curl to ifconfig.me / ipinfo.io) |
| `pingmap <url>` | Detailed curl timing breakdown (DNS, TCP, TLS, TTFB, total) |
| `weather [opts] [loc]` | Terminal weather from wttr.in (`-s/-o/-f/-m` formats) |
| `git` (wrapper) | On first call, sources `fzf-git.sh`, then runs real git |
| `fzf_ssh` | Pick a host from `~/.ssh/config` and connect |

> **System-affecting functions:** `extract` writes files to the current dir; `port ... kill` and `fkill` send `kill -9`; the `bye` alias powers the machine off; `pacclean`/`pacorphans`/`update` modify installed packages.
> 

---

## Prompt Behavior

A minimal native prompt (no external prompt framework), driven by `gitstatus` asynchronously so it never blocks:

- **Line 1:** current path (smart-truncated) + Git context.
- **Git segment:** branch/tag/short-HEAD plus status icons — `+` staged, `!` unstaged, `?` untracked, `✘` deleted, `=` conflicts, `$` stashes, `⇡`/`⇣` ahead/behind.
- **Line 2:** a colored `➜` that turns **red** on a non-zero exit status, **magenta** on success.
- **Right prompt:** command duration (shown when a command takes ≥ 2s, formatted `Ns` or `Mm Ss`).

---

## History Settings

- `HISTFILE=$XDG_CACHE_HOME/zsh/history` (dir auto-created)
- `HISTSIZE=SAVEHIST=100000`
- Options: `SHARE_HISTORY`, `HIST_IGNORE_ALL_DUPS`, `HIST_EXPIRE_DUPS_FIRST`, `HIST_SAVE_NO_DUPS`, `HIST_FIND_NO_DUPS`, `HIST_REDUCE_BLANKS`, `HIST_IGNORE_SPACE`, `HIST_VERIFY`.

---

## Dependencies

**Core (to boot):** `zsh`, `git`, network access, and `cargo`/Rust (to build zsh-patina).

**External CLI tools the config assumes exist:**

- fzf stack: `fzf` (recent ≥0.53 for fzf-git flags), `bat`, `eza`, `file`
- editor/pager: `neovim`, `less`
- nav/node/shell: `zoxide`, `yazi`, `fnm`, `keychain` + `openssh`, `tmux`
- networking/functions: `curl`, `lsof`, `bind` (dig), `iputils` (ping), `xdg-utils`, `gnupg`
- archives: `tar`, `gzip`, `bzip2`, `unzip`, `unrar`, `p7zip`, `ncompress`
- misc: `fontconfig` (fc-list), `pacman-contrib` (paccache), `mpv`, `diffnav`, `ruffle`
- not packaged: **`tmux-sessionizer`** (bound to Ctrl-G — supply it yourself)

The 9 Zsh plugins are **not** installed manually — the loader git-clones them on first launch.

---

## Installation Script

Save as `install-deps.sh`, then `chmod +x install-deps.sh && ./install-deps.sh`.

```bash
#!/usr/bin/env bash
#
# install-deps.sh — Install dependencies for houssamouhra/zsh-config on Arch Linux
# ------------------------------------------------------------------------------
# Usage:
#   chmod +x install-deps.sh
#   ./install-deps.sh
#
# Notes:
#   * Run as your normal user (NOT root). pacman steps use sudo; yay must not be root.
#   * Idempotent: `--needed` skips already-installed packages.
#   * The zsh config auto-clones its zsh plugins on first launch, so you do NOT
#     install those here — you only need git + network + cargo (for zsh-patina).
# ------------------------------------------------------------------------------
set -euo pipefail

# --- 0. Make sure an AUR helper (yay) exists ---------------------------------
if ! command -v yay >/dev/null 2>&1; then
  echo "==> yay not found — bootstrapping it from the AUR..."
  sudo pacman -S --needed --noconfirm base-devel git
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

# --- 1. Official-repo packages (pacman) --------------------------------------
# Core + build toolchain (base-devel/rustup are needed to build zsh-patina)
pacman_pkgs=(
  zsh git base-devel rustup          # core + zsh-patina build deps

  # fzf stack
  fzf bat eza file

  # editor / pager
  neovim less

  # navigation / node / shell tools
  zoxide yazi keychain openssh tmux

  # networking / functions
  curl lsof bind iputils xdg-utils gnupg

  # archive tools for extract()
  tar gzip bzip2 unzip unrar p7zip ncompress

  # misc aliases
  fontconfig pacman-contrib mpv

  # optional: the author's terminal (comment out if you don't want it)
  ghostty
)
echo "==> Installing official-repo packages..."
sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"

# --- 2. Rust toolchain (zsh-patina compiles a release binary with cargo) -----
echo "==> Setting up Rust stable toolchain..."
rustup default stable

# --- 3. AUR packages (yay) ---------------------------------------------------
# fnm is in the AUR (also sometimes in extra — yay resolves either).
aur_pkgs=(
  fnm-bin            # Fast Node Manager (lazy-loaded in functions.zsh)
  diffnav            # used by the `dsn` git alias
  ruffle-nightly-bin # used by the `ruffle` alias (optional)
)
echo "==> Installing AUR packages..."
yay -S --needed --noconfirm "${aur_pkgs[@]}"

# --- 4. Manual step: tmux-sessionizer ----------------------------------------
# keybinds.zsh binds Ctrl-G to `tmux-sessionizer`, a script that is NOT in the
# repo and NOT packaged. Grab it and put it on your PATH, e.g.:
#   curl -fsSL https://raw.githubusercontent.com/ThePrimeagen/.dotfiles/master/bin/.local/scripts/tmux-sessionizer \
#     -o ~/.local/bin/tmux-sessionizer && chmod +x ~/.local/bin/tmux-sessionizer
echo
echo "==> DONE. Remaining manual steps:"
echo "    - Install a 'tmux-sessionizer' script on your PATH (bound to Ctrl-G)."
echo "    - Set zsh as your login shell:  chsh -s \"\$(command -v zsh)\""
echo "    - On first zsh launch the config will git-clone its plugins and"
echo "      cargo-build zsh-patina automatically."
```

---

## Post-Install Steps

1. Install a `tmux-sessionizer` script on your `PATH` (bound to `Ctrl-G`).
2. Set Zsh as your login shell: `chsh -s "$(command -v zsh)"`.
3. Place the repo files at the paths in Directory & File Layout.
4. Start a new Zsh session — the loader clones plugins and builds `zsh-patina` automatically.
