---
title: "waybar-gruvbox-power-menu"
date: 2026-08-18T06:16:41Z
lastmod: 2026-08-18T06:16:41Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# ⏻ Power Menu — Gruvbox Dark Hard (matches Waybar)

A `fuzzel --dmenu` power menu using the **same Gruvbox palette as the waybar theme**:
dark `#1d2021` background @ 0.92 alpha, orange `#fe8019` border + selection (mirrors
the active-workspace pill), yellow `#fabd2f` match, `#ebdbb2` text, 2px border, radius 8.
It's already wired to your bar — `custom/power` calls this script on click.

> Icons are emitted with `printf '\uXXXX'` (Bash), so **no literal Nerd Font glyphs live
> in the file** — it survives copy/paste and still renders correctly with JetBrainsMono
> Nerd Font.
> 

## 📄 `~/.config/waybar/scripts/powermenu.sh`  (`chmod +x`)

```bash
#!/usr/bin/env bash
# powermenu.sh — Gruvbox Dark Hard power menu via fuzzel (matches waybar theme)

# --- Nerd Font icons (printf keeps the file free of literal PUA glyphs) ---
i_lock=$(printf '\uf023')      # 
i_logout=$(printf '\uf2f5')    # 
i_suspend=$(printf '\uf186')   # moon 
i_reboot=$(printf '\uf021')    # 
i_shutdown=$(printf '\uf011')  # 

menu=$(printf '%s  Lock\n%s  Logout\n%s  Suspend\n%s  Reboot\n%s  Shutdown' \
  "$i_lock" "$i_logout" "$i_suspend" "$i_reboot" "$i_shutdown")

# --- fuzzel styled inline to match the waybar Gruvbox theme ---
chosen=$(printf '%s\n' "$menu" | fuzzel --dmenu \
  --prompt="$(printf '\uf011')  " \
  --font="JetBrainsMono Nerd Font:size=12" \
  --lines=5 --width=18 \
  --horizontal-pad=20 --vertical-pad=12 --inner-pad=8 --line-height=24 \
  --background=1d2021eb \
  --text-color=ebdbb2ff \
  --match-color=fabd2fff \
  --selection-color=fe8019ff \
  --selection-text-color=1d2021ff \
  --selection-match-color=1d2021ff \
  --border-color=fe8019ff \
  --border-width=2 --border-radius=8) || exit 0

# --- act on the label after the icon (strip everything up to the last space) ---
case "${chosen##* }" in
  Lock)     swaylock -f ;;
  Logout)   niri msg action quit ;;
  Suspend)  systemctl suspend ;;
  Reboot)   systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
esac
```

## 🎨 Palette mapping (waybar → this menu)

| Waybar element | Color | fuzzel flag |
| --- | --- | --- |
| module bg `alpha(@bg,0.92)` | `#1d2021` @ .92 | `--background=1d2021eb` |
| `@fg` | `#ebdbb2` | `--text-color=ebdbb2ff` |
| active pill bg / text `@orange`/`@bg` | `#fe8019` / `#1d2021` | `--selection-color` / `--selection-text-color` |
| match accent `@yellow` | `#fabd2f` | `--match-color=fabd2fff` |
| orange accent border | `#fe8019` | `--border-color`, `--border-width=2`, `--border-radius=8` |

## 🚀 Setup

```bash
mkdir -p ~/.config/waybar/scripts
# save the script above, then:
chmod +x ~/.config/waybar/scripts/powermenu.sh
# your custom/power module already runs it on click; test directly:
~/.config/waybar/scripts/powermenu.sh
```

## 📝 Notes

- **Actions are niri/systemd-based:** `swaylock -f` (lock), `niri msg action quit`
(logout), `systemctl suspend|reboot|poweroff`. Swap any to taste.
- **Escape / focus-loss** closes the menu with no action (`|| exit 0`).
- **Bash required** for `printf '\uXXXX'` — the shebang is `#!/usr/bin/env bash`.
- Want a **confirmation step** before Reboot/Shutdown, or a `Hibernate` entry
(`systemctl hibernate`)? Easy to add — just ask.
