---
title: "linux-dotfiles-backup-management"
date: 2026-08-21T00:14:15Z
lastmod: 2026-08-21T00:14:15Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Backing Up and Managing Linux Dotfiles

A practical guide to backing up dotfiles that live in `~/` and `~/.config`, and
managing multiple versions across machines with different desktop environments
(niri, KDE, Hyprland) and a headless Debian server.

## Table of Contents

1. Overview
2. Method A — Bare Git Repo (Simple, Identical Machines)
2.1. Why This Works
2.2. Setup Steps
2.3. Restoring on a New Machine
2.4. Pros and Cons
3. Method B — chezmoi (Multiple Versions, Mixed Environments)
3.1. Why Not the Bare Repo Here
3.2. The Mental Model
3.3. Step 1 — Install and Init
3.4. Step 2 — Give Each Machine an Identity
3.5. Step 3 — Conditionally Include Configs with .chezmoiignore
3.6. Step 4 — Per-Machine Tweaks with Templates
3.7. Step 5 — Push to Remote and Clone Elsewhere
3.8. Day-to-Day Workflow
3.9. Handling Secrets
4. Recommendation Summary
5. Alternatives

---

## 1. Overview

Two solid approaches, depending on how similar your machines are:

- **Bare Git repo** — lightweight, no symlinks, files stay in place. Best when
machines are nearly identical.
- **chezmoi** — a purpose-built dotfile manager with templating and per-machine
conditionals. Best when machines differ (different desktops, headless server,
per-host values).

---

## 2. Method A — Bare Git Repo (Simple, Identical Machines)

Keep the repo's metadata *outside* your home directory (so `~` doesn't become one
giant repo), and use an alias to talk to it. No symlinks, no extra tooling.

### 2.1. Why This Works

- Files stay exactly where they live in `~/` and `~/.config`.
- You selectively track only the files you want.
- Transfer to a new machine is a single clone + checkout.

### 2.2. Setup Steps

Initialize a bare repo:

```bash
git init --bare $HOME/.dotfiles
```

Create an alias (add to `~/.bashrc` or `~/.zshrc`):

```bash
alias dot='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

Hide untracked files so status isn't noisy:

```bash
dot config --local status.showUntrackedFiles no
```

Track and commit the files you want:

```bash
dot add ~/.bashrc ~/.config/nvim/init.vim ~/.gitconfig
dot commit -m "Add dotfiles"
dot remote add origin git@github.com:youruser/dotfiles.git
dot push -u origin main
```

### 2.3. Restoring on a New Machine

Clone straight into place:

```bash
git clone --bare git@github.com:youruser/dotfiles.git $HOME/.dotfiles
alias dot='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
dot checkout
```

The files land in `~/` and `~/.config` exactly where they belong — no symlinks to
fix, minimal changes.

### 2.4. Pros and Cons

- **Pros:** minimal, no dependencies, files live in place, trivial transfer.
- **Cons:** checks out everything everywhere; no templating; per-machine
differences require diverging branches (a maintenance trap for many machines).

---

## 3. Method B — chezmoi (Multiple Versions, Mixed Environments)

Best for a fleet like: laptops running niri, KDE, and Hyprland, plus a headless
Debian server. Each machine needs *most* of the same core config but a *different*
subset of desktop configs, and some files need small per-machine tweaks.

### 3.1. Why Not the Bare Repo Here

The bare-repo method checks out **everything, everywhere**, but your machines
aren't identical:

- The Hyprland laptop shouldn't get KDE's `~/.config/plasma*` files.
- The headless server shouldn't get *any* Wayland compositor config.
- `~/.gitconfig` or the shell prompt may need different values per host.

You can hack this with per-machine branches, but branches diverge and merging
shared changes across 4+ branches becomes painful fast.

### 3.2. The Mental Model

chezmoi keeps a **single source repo** (`~/.local/share/chezmoi`) representing the
*desired state* of your home directory. On each machine you run `chezmoi apply`,
and it renders the files that belong on *that* machine into `~` and `~/.config`.

Three features solve the problem:

1. **Templates** — files contain `{{ if ... }}` logic, producing different output
per machine.
2. **Config variables** — each machine has a small local config (e.g.
`role = "hyprland-laptop"`) that drives the templates.
3. **Conditional inclusion** — entire files/directories are included or skipped
per machine via `.chezmoiignore` (itself a template).

One branch; differences expressed as data + conditionals.

### 3.3. Step 1 — Install and Init

On each machine:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)"    # installs the binary
chezmoi init                             # creates ~/.local/share/chezmoi
```

Add files to manage:

```bash
chezmoi add ~/.bashrc
chezmoi add ~/.config/nvim
```

Edit via `chezmoi edit ~/.bashrc`, then `chezmoi apply` to push changes into place.

### 3.4. Step 2 — Give Each Machine an Identity

Define a variable describing the machine in `~/.config/chezmoi/chezmoi.toml`.
This file is **not** shared — it's the one small per-machine bootstrap.

Hyprland laptop:

```toml
[data]
    role = "laptop"
    desktop = "hyprland"
    headless = false
```

KDE laptop:

```toml
[data]
    role = "laptop"
    desktop = "kde"
    headless = false
```

niri laptop:

```toml
[data]
    role = "laptop"
    desktop = "niri"
    headless = false
```

Debian server:

```toml
[data]
    role = "server"
    desktop = "none"
    headless = true
```

### 3.5. Step 3 — Conditionally Include Configs with .chezmoiignore

Create `.chezmoiignore` in the source repo. It's a template evaluated per machine;
anything listed is *skipped* on that machine:

```
{{ if ne .desktop "hyprland" }}
.config/hypr
{{ end }}
{{ if ne .desktop "kde" }}
.config/plasma-workspace
.config/kdeglobals
.config/kwinrc
{{ end }}
{{ if ne .desktop "niri" }}
.config/niri
{{ end }}
{{ if .headless }}
.config/waybar
.config/alacritty
.config/gtk-3.0
{{ end }}
```

Result:

- The Hyprland laptop gets `~/.config/hypr` but not `niri`/`plasma`.
- The server (`headless = true`) skips all GUI configs.

(`ne` = "not equal": "if the desktop is not hyprland, ignore the hypr config.")

### 3.6. Step 4 — Per-Machine Tweaks with Templates

For files that are *mostly* shared but need small differences, use a template
(rename with a `.tmpl` suffix, or run `chezmoi add --template ~/.gitconfig`).

Example `~/.gitconfig`:

```
[user]
    name = Ricardo Valencia
{{ if eq .role "server" }}
    email = ricardo@myserver.example
{{ else }}
    email = ricardo@personal.example
{{ end }}

[core]
    editor = {{ if .headless }}vim{{ else }}nvim{{ end }}
```

Example `~/.bashrc.tmpl`:

```bash
{{ if eq .desktop "hyprland" }}
export XDG_CURRENT_DESKTOP=Hyprland
{{ else if eq .desktop "niri" }}
export XDG_CURRENT_DESKTOP=niri
{{ end }}
```

One source file produces correct output on every machine — no branches.

### 3.7. Step 5 — Push to Remote and Clone Elsewhere

The source repo is a normal Git repo:

```bash
chezmoi cd                       # jumps into ~/.local/share/chezmoi
git init && git add . && git commit -m "init"
git remote add origin git@github.com:youruser/dotfiles.git
git push -u origin main
exit
```

Bootstrapping a new machine is a one-liner (install, clone, apply):

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply youruser
```

chezmoi reads that machine's `chezmoi.toml` identity and renders only the right
files.

### 3.8. Day-to-Day Workflow

| Action | Command |
| --- | --- |
| Start managing a file | `chezmoi add ~/.config/foo/bar.conf` |
| Manage it as a template | `chezmoi add --template ~/.gitconfig` |
| Edit a managed file | `chezmoi edit ~/.bashrc` |
| Preview what would change | `chezmoi diff` |
| Apply changes to home dir | `chezmoi apply` |
| Pull others' changes + apply | `chezmoi update` |
| Push your changes | `chezmoi cd` -> `git commit` -> `git push` |

### 3.9. Handling Secrets

Don't commit SSH keys, API tokens, or `.netrc` in plaintext. chezmoi integrates
with password managers and supports age/GPG encryption:

```bash
chezmoi add --encrypt ~/.ssh/id_ed25519
```

Encrypted files are safe to push to a remote and decrypt only on `apply`.

---

## 4. Recommendation Summary

- **chezmoi** is the right tool for a mixed fleet — purpose-built for "same base
config, per-machine variation," exactly what niri/KDE/Hyprland/headless-server
demands.
- Use **`.chezmoiignore`** to include/exclude whole desktop configs per machine.
- Use **templates + a `role`/`desktop` variable** for small in-file differences.
- Keep the source in one Git repo, one branch — branching complexity disappears.
- Use the **bare Git repo** method instead only when machines are nearly identical
and you want zero extra tooling.

---

## 5. Alternatives

- **GNU Stow + per-host directories** — keeps configs organized by app and symlinks
them into place. Works well, but you hand-manage which packages to `stow` per
machine and there's no templating for in-file differences.
- **Bare Git repo with per-host branches** — avoid for mixed fleets; diverging
branches are the maintenance trap chezmoi is designed to prevent.
