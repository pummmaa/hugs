---
title: "oh-my-posh-powershell-setup-guide"
date: 2026-08-11T18:57:21Z
lastmod: 2026-08-11T18:57:21Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Oh My Posh PowerShell Setup Guide

## Prerequisites & Dependencies

Install these **in order** before configuring your profile.

---

### 1. Install Scoop (Package Manager)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

| What it does | Why it's needed |
| --- | --- |
| Sets PowerShell execution policy to allow local scripts | Required for Scoop to run |
| Downloads and installs the Scoop package manager | Used to install Oh My Posh and fonts |

---

### 2. Install Oh My Posh

```powershell
scoop install https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/oh-my-posh.json
```

| What it does | Why it's needed |
| --- | --- |
| Installs the Oh My Posh executable and built-in themes | Core prompt engine that renders your custom prompt |

---

### 3. Install a Nerd Font

```powershell
scoop bucket add nerd-fonts
scoop install nerd-fonts/FiraCode-NF
```

| What it does | Why it's needed |
| --- | --- |
| Adds the `nerd-fonts` bucket (collection) to Scoop | Gives Scoop access to patched font packages |
| Installs FiraCode Nerd Font (includes icons/glyphs) | Oh My Posh themes use special icons that only render with Nerd Fonts |

> **After installing:** Open Windows Terminal → Settings → Profiles → Defaults → Appearance → Font face → Select **"FiraCode Nerd Font"**
> 

Other font options: `Meslo-NF`, `JetBrainsMono-NF`, `CascadiaCode-NF`

---

### 4. (Optional) Install Extra Modules

```powershell
Install-Module Terminal-Icons -Scope CurrentUser -Force
Install-Module posh-git -Scope CurrentUser -Force
```

| Module | What it does | Required? |
| --- | --- | --- |
| `Terminal-Icons` | Adds file/folder icons to `Get-ChildItem` (ls) output | No — cosmetic only |
| `posh-git` | Adds git status info to prompt | No — Oh My Posh themes already show git info |

---

## PowerShell Profile Configuration

Your profile lives at:

```
C:\Users\<username>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

Open it with:

```powershell
notepad $PROFILE
```

---

## Profile Contents — Line by Line

```powershell
# Line 1: Set the themes path variable
$env:POSH_THEMES_PATH = "$HOME\scoop\apps\oh-my-posh\current\themes"
```

| What it does | Details |
| --- | --- |
| Creates an environment variable pointing to the themes folder | Oh My Posh installed via Scoop stores themes here. This variable lets you reference themes by name without typing the full path every time. |
| **Dependency** | Oh My Posh installed via Scoop (Step 2) |

---

```powershell
# Line 2: Initialize Oh My Posh with a theme
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression
```

| What it does | Details |
| --- | --- |
| Generates a PowerShell script that sets up the custom prompt, then immediately executes it | `oh-my-posh init pwsh` outputs initialization code; `Invoke-Expression` runs that code in the current session. The `--config` flag points to a theme JSON file that defines colors, segments, and layout. |
| **Dependency** | Oh My Posh executable + a Nerd Font set in your terminal |
| **To change theme** | Replace `jandedobbeleer` with any theme name (e.g., `agnoster`, `dracula`, `paradox`) |

---

```powershell
# Line 3: Smart history search with arrow keys
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
```

| What it does | Details |
| --- | --- |
| Binds the **Up Arrow** key to search backward through command history matching what you've already typed | Type `Get-` then press ↑ — it cycles only through past commands starting with `Get-` instead of scrolling through ALL history. |
| **Dependency** | PSReadLine (bundled with PowerShell — no install needed) |

---

```powershell
# Line 4: Forward history search
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
```

| What it does | Details |
| --- | --- |
| Binds the **Down Arrow** key to search forward through matching history | Companion to Line 3 — lets you go back down if you overshoot with ↑ |
| **Dependency** | PSReadLine (bundled with PowerShell) |

---

```powershell
# Line 5: Set editing mode
Set-PSReadLineOption -EditMode Windows
```

| What it does | Details |
| --- | --- |
| Sets keyboard shortcuts to Windows-style (Ctrl+C = copy, Ctrl+V = paste, Ctrl+Z = undo) | Alternative is `Emacs` mode (default) or `Vi` mode. Windows mode feels most natural on Windows. |
| **Dependency** | PSReadLine (bundled with PowerShell) |

---

```powershell
# Line 6 (Optional): File/folder icons
Import-Module Terminal-Icons
```

| What it does | Details |
| --- | --- |
| Loads the Terminal-Icons module so `Get-ChildItem` / `ls` output shows colored file-type icons | Makes directory listings visually richer (📁 folders, 🐍 .py files, etc.) |
| **Dependency** | `Install-Module Terminal-Icons -Scope CurrentUser -Force` |

---

```powershell
# Line 7 (Optional): Git integration
Import-Module posh-git
```

| What it does | Details |
| --- | --- |
| Loads posh-git for git tab-completion and status variables | Adds git branch tab-completion and `$GitStatus` variable. Note: most Oh My Posh themes already display git info, so this is mainly for tab-completion. |
| **Dependency** | `Install-Module posh-git -Scope CurrentUser -Force` + Git installed |

---

## Complete Minimal Profile (Copy-Paste Ready)

```powershell
# === Oh My Posh Prompt ===
$env:POSH_THEMES_PATH = "$HOME\scoop\apps\oh-my-posh\current\themes"
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression

# === History Navigation (arrow keys match what you've typed) ===
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineOption -EditMode Windows
```

---

## Complete Full Profile (with optional modules)

```powershell
# === Oh My Posh Prompt ===
$env:POSH_THEMES_PATH = "$HOME\scoop\apps\oh-my-posh\current\themes"
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression

# === History Navigation ===
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineOption -EditMode Windows

# === Optional Modules (install first, then uncomment) ===
# Import-Module Terminal-Icons
# Import-Module posh-git
```

---

## Changing Themes

```powershell
# List all available themes:
Get-ChildItem "$env:POSH_THEMES_PATH" -Name

# Preview a theme temporarily (resets on next terminal open):
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\dracula.omp.json" | Invoke-Expression

# Make permanent: edit $PROFILE and change the theme filename
notepad $PROFILE
```

---

## Troubleshooting

| Problem | Solution |
| --- | --- |
| Broken/missing icons in prompt | Set a Nerd Font in terminal settings |
| `oh-my-posh` not recognized | Restart terminal; verify with `scoop list` |
| Theme not found | Run `Get-ChildItem $env:POSH_THEMES_PATH -Name` to see exact filenames |
| Profile doesn't load | Check path: `Test-Path $PROFILE` — create with `New-Item -Path $PROFILE -Type File -Force` |
| Slow prompt in large git repos | Switch to a lighter theme (e.g., `slim`, `robbyrussell`) |

---

## Dependency Summary

| Component | Install Command | Required? |
| --- | --- | --- |
| Scoop | `irm get.scoop.sh | iex` | ✅ Yes |
| Oh My Posh | `scoop install oh-my-posh` | ✅ Yes |
| Nerd Font | `scoop bucket add nerd-fonts && scoop install nerd-fonts/FiraCode-NF` | ✅ Yes |
| Terminal-Icons | `Install-Module Terminal-Icons -Scope CurrentUser -Force` | ❌ Optional |
| posh-git | `Install-Module posh-git -Scope CurrentUser -Force` | ❌ Optional |
| PSReadLine | Bundled with PowerShell | ✅ Already installed |
| Git | `scoop install git` | ❌ Only if using posh-git |
