---
title: "windows-terminal-as-a-tmux-replacement-keybinds"
date: 2026-08-11T18:58:37Z
lastmod: 2026-08-11T18:58:37Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Windows Terminal as a tmux Replacement

> A guide to configuring Windows Terminal with tmux-style keybindings for tab management, pane splitting, and efficient terminal navigation.
> 

---

## Overview

Windows Terminal supports extensive keybinding customization through its `settings.json` file, allowing you to replicate most tmux workflows natively — without needing a multiplexer layer. This guide maps common tmux operations to Windows Terminal actions.

---

## Getting Started

### Opening Settings

1. Launch Windows Terminal
2. Press **`Ctrl + ,`** to open Settings
3. Click **"Open JSON file"** (bottom-left corner) to edit `settings.json` directly

All keybindings go inside the `"actions"` array in your `settings.json`.

---

## Keybindings Reference

### Jump to a Specific Tab

**tmux equivalent:** `Ctrl+b, 0` through `Ctrl+b, 9`

Instantly switch to any tab by number:

```json
{ "command": { "action": "switchToTab", "index": 0 }, "keys": "alt+1" },
{ "command": { "action": "switchToTab", "index": 1 }, "keys": "alt+2" },
{ "command": { "action": "switchToTab", "index": 2 }, "keys": "alt+3" },
{ "command": { "action": "switchToTab", "index": 3 }, "keys": "alt+4" },
{ "command": { "action": "switchToTab", "index": 4 }, "keys": "alt+5" },
{ "command": { "action": "switchToTab", "index": 5 }, "keys": "alt+6" },
{ "command": { "action": "switchToTab", "index": 6 }, "keys": "alt+7" },
{ "command": { "action": "switchToTab", "index": 7 }, "keys": "alt+8" },
{ "command": { "action": "switchToTab", "index": 8 }, "keys": "alt+9" }
```

---

### Rename a Tab

**tmux equivalent:** `Ctrl+b, ,`

Opens an inline rename prompt for the current tab:

```json
{ "command": "openTabRenamer", "keys": "alt+comma" }
```

---

### See What Tabs Are Open (Tab Switcher)

**tmux equivalent:** `Ctrl+b, w` (window list)

Opens a searchable, filterable list of all open tabs:

```json
{ "command": "tabSearch", "keys": "alt+w" }
```

> **Tip:** You can also use the Command Palette (`Ctrl+Shift+P`) as an alternative way to search and switch between tabs.
> 

---

### Tab Navigation (Next / Previous)

**tmux equivalent:** `Ctrl+b, n` / `Ctrl+b, p`

Cycle through tabs sequentially:

```json
{ "command": "nextTab", "keys": "alt+l" },
{ "command": "prevTab", "keys": "alt+h" }
```

---

### Create and Close Tabs

**tmux equivalent:** `Ctrl+b, c` (new) / `Ctrl+b, &` (close)

```json
{ "command": "newTab", "keys": "alt+c" },
{ "command": "closePane", "keys": "alt+x" }
```

> **Note:** `closePane` closes the active pane. If only one pane exists in the tab, it closes the tab.
> 

---

### Pane Splitting

**tmux equivalent:** `Ctrl+b, %` (vertical) / `Ctrl+b, "` (horizontal)

Split the current tab into multiple panes:

```json
{ "command": { "action": "splitPane", "split": "horizontal" }, "keys": "alt+minus" },
{ "command": { "action": "splitPane", "split": "vertical" }, "keys": "alt+shift+\\" }
```

---

### Pane Navigation

**tmux equivalent:** `Ctrl+b, arrow keys`

Move focus between panes using vim-style directional keys:

```json
{ "command": { "action": "moveFocus", "direction": "left" },  "keys": "alt+shift+h" },
{ "command": { "action": "moveFocus", "direction": "right" }, "keys": "alt+shift+l" },
{ "command": { "action": "moveFocus", "direction": "up" },    "keys": "alt+shift+k" },
{ "command": { "action": "moveFocus", "direction": "down" },  "keys": "alt+shift+j" }
```

---

### Zoom a Pane (Fullscreen Toggle)

**tmux equivalent:** `Ctrl+b, z`

Expand the current pane to fill the entire tab. Press again to restore:

```json
{ "command": "togglePaneZoom", "keys": "alt+z" }
```

---

## Quick Reference Table

| tmux Shortcut | Action | Windows Terminal Binding |
| --- | --- | --- |
| `Ctrl+b, c` | New window/tab | `Alt+C` |
| `Ctrl+b, n` | Next tab | `Alt+L` |
| `Ctrl+b, p` | Previous tab | `Alt+H` |
| `Ctrl+b, 0-9` | Jump to tab by number | `Alt+1` through `Alt+9` |
| `Ctrl+b, ,` | Rename tab | `Alt+,` |
| `Ctrl+b, w` | List all tabs | `Alt+W` |
| `Ctrl+b, %` | Vertical split | `Alt+Shift+\\` |
| `Ctrl+b, "` | Horizontal split | `Alt+-` |
| `Ctrl+b, z` | Zoom/unzoom pane | `Alt+Z` |
| `Ctrl+b, x` | Close pane/tab | `Alt+X` |
| `Ctrl+b, arrows` | Navigate panes | `Alt+Shift+H/J/K/L` |

---

## Complete `settings.json` Snippet

Copy this entire block into your `"actions"` array:

```json
"actions": [
    { "command": { "action": "switchToTab", "index": 0 }, "keys": "alt+1" },
    { "command": { "action": "switchToTab", "index": 1 }, "keys": "alt+2" },
    { "command": { "action": "switchToTab", "index": 2 }, "keys": "alt+3" },
    { "command": { "action": "switchToTab", "index": 3 }, "keys": "alt+4" },
    { "command": { "action": "switchToTab", "index": 4 }, "keys": "alt+5" },
    { "command": { "action": "switchToTab", "index": 5 }, "keys": "alt+6" },
    { "command": { "action": "switchToTab", "index": 6 }, "keys": "alt+7" },
    { "command": { "action": "switchToTab", "index": 7 }, "keys": "alt+8" },
    { "command": { "action": "switchToTab", "index": 8 }, "keys": "alt+9" },
    { "command": "openTabRenamer", "keys": "alt+comma" },
    { "command": "tabSearch", "keys": "alt+w" },
    { "command": "nextTab", "keys": "alt+l" },
    { "command": "prevTab", "keys": "alt+h" },
    { "command": "newTab", "keys": "alt+c" },
    { "command": "closePane", "keys": "alt+x" },
    { "command": { "action": "splitPane", "split": "horizontal" }, "keys": "alt+minus" },
    { "command": { "action": "splitPane", "split": "vertical" }, "keys": "alt+shift+\\" },
    { "command": { "action": "moveFocus", "direction": "left" },  "keys": "alt+shift+h" },
    { "command": { "action": "moveFocus", "direction": "right" }, "keys": "alt+shift+l" },
    { "command": { "action": "moveFocus", "direction": "up" },    "keys": "alt+shift+k" },
    { "command": { "action": "moveFocus", "direction": "down" },  "keys": "alt+shift+j" },
    { "command": "togglePaneZoom", "keys": "alt+z" }
]
```

---

## Design Notes

- **Why `Alt+` as the modifier?** It rarely conflicts with shell programs (unlike `Ctrl+` which clashes with bash/zsh shortcuts). It keeps your muscle memory consistent.
- **No leader key support.** Windows Terminal doesn't natively support two-key chords (like tmux's `Ctrl+b` prefix). Single-modifier combos are the standard approach.
- **Vim-style navigation.** `H/J/K/L` for directional movement keeps things familiar if you're already a vim user. Swap for arrow keys if preferred.

---

## Limitations vs. tmux

| Feature | tmux | Windows Terminal |
| --- | --- | --- |
| Session persistence (detach/reattach) | ✅ | ❌ |
| Remote session survival (SSH disconnect) | ✅ | ❌ |
| Copy mode with vi keys | ✅ | Partial (selection only) |
| Scripted layouts | ✅ | ❌ (no equivalent to `tmuxinator`) |
| Two-key chord prefix | ✅ | ❌ |
| Custom status bar | ✅ | Limited (tab bar only) |

> **If you need session persistence or remote detach/reattach**, you still want tmux (or screen) running inside Windows Terminal. These keybindings handle the *local* tab/pane management layer.
>
