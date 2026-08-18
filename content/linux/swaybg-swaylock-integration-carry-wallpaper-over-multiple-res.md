---
title: "swaybg-swaylock-integration-carry-wallpaper-over-multiple-res"
date: 2026-08-18T15:54:31Z
lastmod: 2026-08-18T15:54:31Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# 🔒 swaylock — Gruvbox Dark Hard, wallpaper-aware, multi-resolution

Locks with the **same image swaybg is showing**, themed to match your Gruvbox setup, with
ring/font sizes that **auto-scale** across 1080p, 1440p and 4K at scale 1.0 and 1.5.

## 🧠 What it does

1. **Finds the current wallpaper.** Reads `~/.cache/current_wallpaper` if present; otherwise
recovers swaybg's `-i`/`--image` path from `/proc/<pid>/cmdline` of the running process —
so the lock screen always matches your live desktop background.
2. **Detects the screen.** Queries `niri msg -j outputs` for the focused output's *logical*
height (which already accounts for the compositor scale).
3. **Sizes itself.** Derives ring, font and thickness from that height
(`ring = H×0.10`, `font = H×0.022`, `thickness = ring/12`), so it looks right on any
resolution/scale — 1080p, 1440p or 4K, at scale 1.0 or 1.5.
4. **Applies the Gruvbox theme.** Passes the full palette (idle / verify / wrong / clear /
caps states) plus a `--clock` to swaylock.
5. **Adds polish if available.** Enables blur + vignette + fade-in only when
`swaylock-effects` is installed; plain swaylock skips them gracefully.
6. **Locks.** Runs `swaylock -f` with the image (or a Gruvbox fallback color if no image is
found), safe for keybinds and `before-sleep`.

## 📄 `~/.config/niri/scripts/lock.sh`  (`chmod +x`)

```bash
#!/usr/bin/env bash
# lock.sh — Gruvbox swaylock using swaybg's current wallpaper, sized per output.

# ---- 1. find the current wallpaper ----
get_wallpaper() {
  # preferred: state file written by wallpaper.sh (see note below)
  if [ -r "$HOME/.cache/current_wallpaper" ]; then
    cat "$HOME/.cache/current_wallpaper"; return
  fi
  # fallback: recover the -i / --image path from the running swaybg
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
LH="$(logical_height)"; [ -n "$LH" ] || LH=1080   # sane default

# ---- 3. derive sizes from logical height ----
read -r RING FONT THICK <<EOF
$(awk -v h="$LH" 'BEGIN{
  r=int(h*0.10+0.5); f=int(h*0.0222+0.5); t=int(r/12+0.5); if(t<4)t=4;
  print r, f, t }')
EOF

# ---- 4. optional blur (only if swaylock-effects is installed) ----
EFFECTS=()
if swaylock --help 2>&1 | grep -q -- --effect-blur; then
  EFFECTS=(--effect-blur 7x5 --effect-vignette 0.35:0.45 --fade-in 0.2)
fi

# ---- 5. background arg: image if found, else Gruvbox color ----
if [ -n "$IMG" ] && [ -f "$IMG" ]; then BG=(-i "$IMG" --scaling=fill)
else BG=(-c 1d2021); fi

exec swaylock -f "${BG[@]}" \
  --indicator --clock \
  --indicator-radius "$RING" --indicator-thickness "$THICK" \
  --font "JetBrainsMono Nerd Font" --font-size "$FONT" \
  --inside-color 1d2021aa --inside-ver-color 1d2021aa \
  --inside-wrong-color 1d2021aa --inside-clear-color 1d2021aa \
  --ring-color 504945ff --ring-ver-color 8ec07cff \
  --ring-wrong-color fb4934ff --ring-clear-color fabd2fff \
  --key-hl-color fe8019ff --bs-hl-color fb4934ff \
  --line-color 00000000 --separator-color 00000000 \
  --text-color ebdbb2ff --text-ver-color ebdbb2ff \
  --text-wrong-color fb4934ff --text-clear-color fabd2fff \
  --text-caps-lock-color fe8019ff \
  "${EFFECTS[@]}"
```

## 📐 Sizes it produces (logical height → ring / font / thickness)

| Display | Scale | Logical H | ring | font | thick |
| --- | --- | --- | --- | --- | --- |
| 1080p | 1.0 | 1080 | 108 | 24 | 9 |
| 1080p | 1.5 | 720 | 72 | 16 | 6 |
| 1440p | 1.0 | 1440 | 144 | 32 | 12 |
| 1440p | 1.5 | 960 | 96 | 21 | 8 |
| 4K | 1.0 | 2160 | 216 | 48 | 18 |
| 4K | 1.5 | 1440 | 144 | 32 | 12 |
| 1080p | 2.0 | 540 | 54 | 12 | 5 |
| 1440p | 2.0 | 720 | 72 | 16 | 6 |
| 4K | 2.0 | 1080 | 108 | 24 | 9 |

`ring = H×0.10`, `font = H×0.022`, `thickness = ring/12` — so any other resolution/scale
also scales sensibly, not just those listed. **Note:** because sizes come from a formula, the script needs *no edits* to support 4K — it already computes the values above.

## 🎨 Gruvbox color map

| State | Color |
| --- | --- |
| ring idle | `#504945` (bg2) · key press `#fe8019` orange |
| verifying | ring `#8ec07c` aqua |
| wrong | ring/text `#fb4934` red |
| clear / caps | `#fabd2f` yellow / `#fe8019` orange |
| text · inside | `#ebdbb2` fg · `#1d2021` @ ~0.67 |

## 🔌 Wire it up

Point your lock triggers at the script (replace raw `swaylock -f`):

```kdl
# niri config.kdl
Mod+Escape hotkey-overlay-title="Lock the Screen" { spawn "/bin/sh" "-c" "$HOME/.config/niri/scripts/lock.sh"; }
```

And in your **swayidle** chain, swap every `swaylock -f` for
`$HOME/.config/niri/scripts/lock.sh` (timeout lock, `before-sleep`, and `lock` handlers).

## 📝 Notes

- **Best reliability:** add one line to `wallpaper.sh`'s `set_one()` so the lock always
knows the exact image:
```bash
echo "$img" > "$HOME/.cache/current_wallpaper"
```
Without it, the script still recovers the path from the running swaybg process.
- **Blur/vignette** needs the `swaylock-effects` package; plain `swaylock` just skips them
(Arch: `swaylock-effects` AUR · Fedora: `swaylock-effects` if packaged, else plain swaylock).
- Requires `jq` for output detection (falls back to 1080p sizing if absent).
- `--clock` shows time in the indicator; `-f` makes it safe for `before-sleep`.
