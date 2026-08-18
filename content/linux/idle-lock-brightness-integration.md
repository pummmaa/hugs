---
title: "idle-lock-brightness-integration"
date: 2026-08-18T20:52:19Z
lastmod: 2026-08-18T20:52:19Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# 🌙 Idle · Lock · Brightness — Integration README

How `idle-brightness.sh`, `lock.sh` (Gruvbox swaylock), and `swayidle` work together on
niri, verified safe to run as one system. Includes the exact edits you need to make.

---

## 🧩 The pieces

| File | Role |
| --- | --- |
| `~/.config/niri/scripts/idle-brightness.sh` | Fades the backlight down before lock, restores on activity. Owns its own state file. |
| `~/.config/niri/scripts/lock.sh` | Gruvbox swaylock: locks with swaybg's current wallpaper, auto-sized per resolution/scale. |
| `~/.config/niri/scripts/wallpaper.sh` | Sets a random wallpaper via swaybg (optional daily rotation). |
| `swayidle` (spawned by niri) | The timer that fires dim / lock / monitor-off / suspend. |

**They are independent:** brightness only touches `brightnessctl`; lock only draws the
swaylock surface. No shared state, so no conflicts.

---

## 🔄 What the idle chain does

| Time | Action | Handler |
| --- | --- | --- |
| 4:30 (270s) | Dim backlight (fade) | `idle-brightness.sh dim` |
| 5:00 (300s) | Lock screen (themed) | `lock.sh` |
| 10:00 (600s) | Power off monitors | `niri msg action power-off-monitors` |
| 30:00 (1800s) | Suspend | `systemctl suspend` |
| on activity | Undim | `idle-brightness.sh restore` (via `resume`/`unlock`/`after-resume`) |
| before sleep | Lock first | `lock.sh` |

The **dim lands 30 s before the lock** so the fade is a cancelable "about to lock" warning.
Restore is **idempotent** — it can fire twice (once from `resume`, once from `unlock`) and the
second run safely no-ops because the state file is already gone.

---

## ✅ Changes you need to make

### 1. `~/.config/niri/config.kdl` — replace the swayidle line

Swap the three `swaylock -f` calls for `lock.sh` (dim/restore lines stay the same):

```kdl
spawn-at-startup "/bin/sh" "-c" "exec swayidle -w timeout 270 '$HOME/.config/niri/scripts/idle-brightness.sh dim' resume '$HOME/.config/niri/scripts/idle-brightness.sh restore' timeout 300 '$HOME/.config/niri/scripts/lock.sh' timeout 600 'niri msg action power-off-monitors' resume 'niri msg action power-on-monitors' timeout 1800 'systemctl suspend' before-sleep '$HOME/.config/niri/scripts/lock.sh' after-resume '$HOME/.config/niri/scripts/idle-brightness.sh restore' lock '$HOME/.config/niri/scripts/lock.sh' unlock '$HOME/.config/niri/scripts/idle-brightness.sh restore'"
```

### 2. `~/.config/niri/config.kdl` — point the lock keybind at lock.sh

```kdl
Mod+Escape hotkey-overlay-title="Lock the Screen" { spawn "/bin/sh" "-c" "$HOME/.config/niri/scripts/lock.sh"; }
```

### 3. `~/.config/niri/scripts/wallpaper.sh` — record the current wallpaper

So `lock.sh` always matches the live background, add this inside `set_one()` right after
`swaybg` starts:

```bash
echo "$img" > "$HOME/.cache/current_wallpaper"
```

(Optional — `lock.sh` also recovers the path from the running swaybg process, but the cache
file is more robust.)

### 4. Make the scripts executable

```bash
chmod +x ~/.config/niri/scripts/{idle-brightness.sh,lock.sh,wallpaper.sh}
```

### 5. Confirm dependencies are installed

| Tool | Used by | Arch | Fedora |
| --- | --- | --- | --- |
| `brightnessctl` | idle-brightness | `sudo pacman -S brightnessctl` | `sudo dnf install brightnessctl` |
| `swaylock` (or `swaylock-effects` for blur) | lock.sh | `swaylock-effects` (AUR) | `sudo dnf install swaylock` |
| `swaybg` | wallpaper.sh | `sudo pacman -S swaybg` | `sudo dnf install swaybg` |
| `jq` | lock.sh (output sizing) | `sudo pacman -S jq` | `sudo dnf install jq` |

`lock.sh` degrades gracefully: no `swaylock-effects` → skips blur; no `jq` → falls back to
1080p sizing; no wallpaper → Gruvbox fallback color.

---

## ⚠️ Notes / edge cases (all handled, FYI)

- **No double-lock:** swaylock is single-instance, so `timeout 300` + `before-sleep` + `lock`
firing together is safe — extra calls just exit.
- **Manual brightness at lock:** if you raise brightness by hand while dimmed, `restore`
respects it (`now > saved → exit`) instead of yanking it back down.
- **`before-sleep` timing:** `lock.sh` does ~200–400 ms of setup (jq/niri msg) then `exec`s
`swaylock -f`, which forks only once locked — so the screen is locked before suspend.
- **`idle-brightness.sh` `STEP_MS`:** the `sleep "0.0$STEP_MS"` form assumes a two-digit value
(25 → `0.025`). Fine as shipped; just don't set it to `100`+ without switching to a
`bc`-based fade.

---

## 🔁 Apply

niri hot-reloads `config.kdl` on save. To restart the idle daemon immediately:

```bash
pkill swayidle    # niri's spawn-at-startup relaunches it on next login,
                  # or just log out/in to pick up the new chain
```

## Lock.sh Script
```bash
#!/usr/bin/env bash
# lock.sh — Gruvbox swaylock using swaybg's current wallpaper, sized per output.

# ---- 1. find the current wallpaper ----
get_wallpaper() {
  if [ -r "$HOME/.cache/current_wallpaper" ]; then
    cat "$HOME/.cache/current_wallpaper"; return
  fi
  for pid in $(pgrep -x swaybg); do
    mapfile -t a < <(tr '\0' '\n' < "/proc/$pid/cmdline")
    for i in "${!a[@]}"; do
      case "${a[$i]}" in
        -i|--image) echo "${a[$((i+1))]}"; return ;;
      esac
    done
  done
}

# ---- 2. logical height of the focused output (accounts for scale) ----
logical_height() {
  if command -v niri >/dev/null && command -v jq >/dev/null; then
    niri msg -j outputs 2>/dev/null \
      | jq -r 'to_entries[].value | select(.logical!=null) | .logical.height' \
      | head -1
  fi
}

IMG="$(get_wallpaper)"
LH="$(logical_height)"; [ -n "$LH" ] || LH=1080

# ---- 3. derive sizes from logical height ----
read -r RING FONT THICK <<EOF
$(awk -v h="$LH" 'BEGIN{
  r=int(h*0.10+0.5); f=int(h*0.0222+0.5); t=int(r/12+0.5); if(t<4)t=4;
  print r, f, t }')
EOF

# ---- 4. capability-gated extras (plain swaylock AND swaylock-effects) ----
have() { swaylock --help 2>&1 | grep -q -- "$1"; }

EXTRA=()
have --clock     && EXTRA+=(--clock)
have --font-size && EXTRA+=(--font-size "$FONT")
if have --effect-blur; then
  EXTRA+=(--effect-blur 7x5 --effect-vignette 0.35:0.45 --fade-in 0.2)
fi

# ---- 5. background: image if found, else Gruvbox color ----
if [ -n "$IMG" ] && [ -f "$IMG" ]; then BG=(-i "$IMG" --scaling=fill)
else BG=(-c 1d2021); fi

exec swaylock -f "${BG[@]}" \
  --indicator \
  --indicator-radius "$RING" --indicator-thickness "$THICK" \
  --font "JetBrainsMono Nerd Font" \
  --inside-color 1d2021aa --inside-ver-color 1d2021aa \
  --inside-wrong-color 1d2021aa --inside-clear-color 1d2021aa \
  --ring-color 504945ff --ring-ver-color 8ec07cff \
  --ring-wrong-color fb4934ff --ring-clear-color fabd2fff \
  --key-hl-color fe8019ff --bs-hl-color fb4934ff \
  --line-color 00000000 --separator-color 00000000 \
  --text-color ebdbb2ff --text-ver-color ebdbb2ff \
  --text-wrong-color fb4934ff --text-clear-color fabd2fff \
  --text-caps-lock-color fe8019ff \
  "${EXTRA[@]}"
```
