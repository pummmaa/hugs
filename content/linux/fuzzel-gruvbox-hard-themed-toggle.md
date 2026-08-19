---
title: "fuzzel-gruvbox-hard-themed-toggle"
date: 2026-08-18T03:47:54Z
lastmod: 2026-08-18T03:47:54Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# 🚀 Fuzzel — Gruvbox Dark Hard (matched to Waybar)

Recolored to use the **exact same Gruvbox Dark Hard palette as the waybar theme**,
so the launcher and the bar read as one set. Plus a `Super+D` **toggle** so pressing
it twice opens then closes fuzzel.

---

## 🎨 Palette mapping (waybar → fuzzel)

| Waybar element | Color | Fuzzel role |
| --- | --- | --- |
| module background `alpha(@bg, 0.92)` | `#1d2021` @ 0.92 | `background` = `1d2021eb` |
| foreground `@fg` | `#ebdbb2` | `text` |
| clock / match accent `@yellow` | `#fabd2f` | `match` |
| **active workspace pill** (orange bg, dark text) | `#fe8019` / `#1d2021` | `selection` / `selection-text` |
| focus accent / border `@orange` | `#fe8019` | `border` |
| corner radius | `8px` | `[border] radius=8` |

The selected row now mirrors waybar's **active-workspace pill** — orange background
with dark text — which is the strongest visual tie between the two.

---

## 📄 `~/.config/fuzzel/fuzzel.ini`

```ini
# fuzzel — application launcher, Gruvbox Dark Hard
# Palette matched to the waybar Gruvbox Dark Hard theme.

font=JetBrainsMono Nerd Font:size=11
dpi-aware=no
prompt="❯ "
icon-theme=Adwaita
terminal=foot -e
layer=overlay
lines=12
width=45
tabs=4
horizontal-pad=20
vertical-pad=12
inner-pad=6
line-height=22
exit-on-keyboard-focus-loss=yes

[colors]
# background at 0.92 alpha == waybar's alpha(@bg, 0.92)
background=1d2021eb
text=ebdbb2ff
# matched substring uses waybar's yellow accent
match=fabd2fff
# selected row == waybar's active-workspace pill: orange bg, dark text
selection=fe8019ff
selection-text=1d2021ff
# matched chars inside the selected (orange) row: dark + bold for contrast
selection-match=1d2021ff
# border == waybar's orange focus accent
border=fe8019ff

[border]
width=2
radius=8

[dmenu]
exit-immediately-if-empty=yes

[key-bindings]
# Tab / ISO_Left_Tab are already bound by fuzzel by default (execute-or-next /
# prev-with-wrap); remapping them here makes fuzzel error, so we leave them out.
next=Down Control+n
prev=Up Control+p
```

---

## 🔁 Super+D toggle — edit your niri `config.kdl`

Replace your current launcher bind:

```kdl
Mod+D hotkey-overlay-title="Run an Application" { spawn "fuzzel"; }
```

with a toggle wrapper:

```kdl
Mod+D hotkey-overlay-title="Run/close launcher (toggle)" {
    spawn "/bin/sh" "-c" "pkill -x fuzzel || fuzzel";
}
```

**How it works:** `pkill -x fuzzel` kills a running fuzzel and exits `0`, so `|| fuzzel`
does *not* run — the launcher closes. If no fuzzel is running, `pkill` fails and `fuzzel`
launches. Net effect: first `Super+D` opens it, a second `Super+D` closes it.

- `-x` matches the exact process name `fuzzel` (won't catch unrelated processes).
- You already have `exit-on-keyboard-focus-loss=yes`, so clicking away also closes it —
the toggle just adds keyboard close-on-repeat.

Reload niri config (it hot-reloads on save, or `niri msg action load-config-file`).
