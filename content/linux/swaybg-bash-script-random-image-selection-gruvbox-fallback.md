---
title: "swaybg-bash-script-random-image-selection-gruvbox-fallback"
date: 2026-08-18T15:29:47Z
lastmod: 2026-08-18T15:29:47Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# 🖼️ Random Daily Wallpaper — niri + swaybg

Picks a random image from a folder and sets it with **swaybg**, rotating on a schedule.
One variable controls the timing, and it checks/installs the wallpaper engine on
**Arch** and **Fedora**. Fallback color is Gruvbox `#1d2021` to match your theme.

## 📄 `~/.config/niri/scripts/wallpaper.sh`  (`chmod +x`)

```bash
#!/usr/bin/env bash
# wallpaper.sh — random wallpaper for niri/swaybg, with daily rotation.
#   wallpaper.sh            set one random wallpaper now
#   wallpaper.sh --daemon   set now, then rotate every $INTERVAL (use at startup)

# ============ CONFIG — edit these ============
WALLPAPER_DIR="${WALLPAPER_DIR:-/home/toniiz/Pictures/wallpapers}"
INTERVAL="1d"              # ← EASY TIME KNOB. sleep syntax: 30m, 2h, 1d, 12h ...
FALLBACK_COLOR="#1d2021"   # shown while images load / if one is smaller than screen
# =============================================

set -u

# ---- dependency checker: swaybg (Arch + Fedora) ----
check_deps() {
  command -v swaybg >/dev/null 2>&1 && return 0
  echo "swaybg (wallpaper engine) is not installed." >&2
  [ -r /etc/os-release ] && . /etc/os-release
  case " ${ID:-} ${ID_LIKE:-} " in
    *arch*)          hint="sudo pacman -S --needed swaybg" ;;
    *fedora*|*rhel*) hint="sudo dnf install -y swaybg" ;;
    *)               hint="install 'swaybg' with your package manager" ;;
  esac
  echo "Install it with:  $hint" >&2
  # offer to auto-install when run interactively
  if [ -t 0 ] && [ -t 1 ]; then
    printf "Install now? [y/N] " >&2; read -r ans
    case "$ans" in
      [yY]*)
        if   command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed swaybg
        elif command -v dnf    >/dev/null 2>&1; then sudo dnf install -y swaybg
        else echo "No pacman/dnf found; install manually." >&2
        fi ;;
    esac
  fi
  command -v swaybg >/dev/null 2>&1
}

# ---- set one random wallpaper (swap without flicker) ----
set_one() {
  local img
  img=$(find "$WALLPAPER_DIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.bmp' \) 2>/dev/null | shuf -n1)
  if [ -z "$img" ]; then
    echo "No images found in: $WALLPAPER_DIR" >&2
    return 1
  fi
  # start the new instance first, then kill older ones -> minimal flicker
  swaybg -m fill -i "$img" -c "$FALLBACK_COLOR" >/dev/null 2>&1 &
  local newpid=$!
  sleep 0.3
  for pid in $(pgrep -x swaybg); do
    [ "$pid" != "$newpid" ] && kill "$pid" 2>/dev/null
  done
  echo "Wallpaper set: $img"
}

check_deps || { echo "Cannot continue without swaybg." >&2; exit 1; }

if [ "${1:-}" = "--daemon" ]; then
  while :; do set_one; sleep "$INTERVAL"; done
else
  set_one
fi
```

## ⏱️ Changing the rotation time

Edit the single `INTERVAL` line (it's plain `sleep` syntax):

| Want | Set |
| --- | --- |
| **Daily** (default) | `INTERVAL="1d"` |
| Every 12 hours | `INTERVAL="12h"` |
| Every 2 hours | `INTERVAL="2h"` |
| Every 30 minutes | `INTERVAL="30m"` |

## 🚀 Run it on login (niri)

You currently start swaybg directly. **Replace** that line in `~/.config/niri/config.kdl`:

```kdl
# OLD — remove this:
# spawn-at-startup "/bin/sh" "-c" "swaybg -m fill -i \"$HOME/.config/niri/wallpaper.jpg\" -c '#1d2021'"

# NEW — random rotation daemon:
spawn-at-startup "/bin/sh" "-c" "exec $HOME/.config/niri/scripts/wallpaper.sh --daemon"
```

Running under niri guarantees `WAYLAND_DISPLAY` is set, so swaybg connects reliably.

## 🗓️ Alternative: systemd user timer

Prefer a real scheduler (survives crashes, catches up if the machine was off)? Use a
timer instead of `--daemon`. `OnCalendar` is the time knob here.

```ini
# ~/.config/systemd/user/wallpaper.service
[Service]
Type=oneshot
ExecStart=%h/.config/niri/scripts/wallpaper.sh

# ~/.config/systemd/user/wallpaper.timer
[Timer]
OnCalendar=daily          # ← time knob: hourly, *-*-* 09:00:00, etc.
Persistent=true
[Install]
WantedBy=timers.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now wallpaper.timer
```

> For the timer, swaybg needs the Wayland env. In your niri config add once:
> `spawn-at-startup "/bin/sh" "-c" "systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR"`
> (the `--daemon` method above avoids this entirely, so it's simpler for niri).
> 

## 📝 Notes

- **Point it elsewhere** by editing `WALLPAPER_DIR` (or run `WALLPAPER_DIR=/path wallpaper.sh`).
- Supported formats: jpg, jpeg, png, webp, bmp.
- Also needs `shuf`, `find`, `pgrep` — all standard (coreutils/findutils/procps), so no extra install.
- **Bash** shebang (`#!/usr/bin/env bash`) for the `[[`/array-free logic used here.
