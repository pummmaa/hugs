---
title: "cosmic-complete-mpv-player-script-sticky-autostart"
date: 2026-08-20T20:56:51Z
lastmod: 2026-08-20T20:56:51Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# ▶️ COSMIC — complete `mpv-play.sh` + sticky autostart

Full COSMIC build: the prompt/player script (with background-launch + `cosmicmsg` sticky baked
in), plus a `cosmicmsg subscribe` watcher and its XDG autostart entry.

> Put scripts in `~/.config/scripts/` (compositor-neutral). Needs `cosmicmsg` for sticky
> (build via cargo/nix — not in Arch repos). Everything else is standard.
> 

---

## Contents

- 1. Player script
- 2. Sticky watcher
- 3. Autostart entry
- 4. Wire-up checklist
- 5. Keybind (RON)
- 6. Caveats and limitations

---

## 1. Player script

**File:** `~/.config/scripts/mpv-play.sh` — make executable with `chmod +x`

```bash
#!/usr/bin/env bash
# mpv-play.sh (COSMIC) — Gruvbox fuzzel prompt -> mpv (yt-dlp), floating PiP,
# sticky on all workspaces via cosmicmsg. URL history + self-update.
set -u

# pipx / cosmicmsg live in ~/.local/bin, which spawned procs may lack on PATH.
export PATH="$HOME/.local/bin:$PATH"

HIST="${XDG_DATA_HOME:-$HOME/.local/share}/mpv-play/history"
MAX_HIST=50
mkdir -p "$(dirname "$HIST")"; touch "$HIST"

# ---- dependency check (Arch + Fedora) ----
missing=""
for c in mpv yt-dlp fuzzel; do command -v "$c" >/dev/null 2>&1 || missing="$missing $c"; done
if [ -n "$missing" ]; then
  [ -r /etc/os-release ] && . /etc/os-release
  case " ${ID:-} ${ID_LIKE:-} " in
    *arch*)          hint="sudo pacman -S$missing" ;;
    *fedora*|*rhel*) hint="sudo dnf install$missing" ;;
    *)               hint="install:$missing" ;;
  esac
  notify-send "mpv-play" "Missing:$missing — $hint" 2>/dev/null
  echo "Missing:$missing — $hint" >&2
  exit 1
fi

# ---- Gruvbox fuzzel prompt (bypass user fuzzel.ini via --config=/dev/null) ----
PH=()
fuzzel --help 2>&1 | grep -q -- '--placeholder' && \
  PH=(--placeholder="Paste a video URL (YouTube, Twitch, …)")

url=$(tac "$HIST" 2>/dev/null | fuzzel --dmenu --config=/dev/null \
  --prompt="▶  " "${PH[@]}" \
  --font="JetBrainsMono Nerd Font:size=12" \
  --lines=8 --width=60 \
  --horizontal-pad=20 --vertical-pad=12 --inner-pad=8 \
  --background=1d2021eb --text-color=ebdbb2ff --match-color=fabd2fff \
  --selection-color=fe8019ff --selection-text-color=1d2021ff \
  --selection-match-color=1d2021ff --border-color=fe8019ff \
  --border-width=2 --border-radius=8)
status=$?
if [ "$status" -gt 1 ]; then
  notify-send "mpv-play" "fuzzel failed (exit $status). Test 'echo | fuzzel --dmenu'." 2>/dev/null
  exit 1
fi

url=$(printf '%s' "$url" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
[ -z "$url" ] && exit 0

# ---- history: newest first, de-duplicated, capped ----
tmp=$(mktemp)
{ printf '%s\n' "$url"; grep -vxF "$url" "$HIST" 2>/dev/null; } | head -n "$MAX_HIST" > "$tmp"
mv "$tmp" "$HIST"

# ---- keep yt-dlp fresh (48h silent; escalate on failure) ----
UPDATE_STAMP="$(dirname "$HIST")/last-update"
PM_UPDATE=1
update_ytdl() {
  if yt-dlp -U >/dev/null 2>&1; then return 0; fi
  if command -v pipx >/dev/null 2>&1 && pipx upgrade yt-dlp >/dev/null 2>&1; then return 0; fi
  if [ "${1:-}" = "pm" ] && [ "$PM_UPDATE" = "1" ] && command -v pkexec >/dev/null 2>&1; then
    [ -r /etc/os-release ] && . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
      *arch*)          notify-send "mpv-play" "yt-dlp out of date — run: sudo pacman -Syu" 2>/dev/null; return 1 ;;
      *fedora*|*rhel*) pkexec dnf -y upgrade yt-dlp >/dev/null 2>&1 && return 0 ;;
    esac
  fi
  notify-send "mpv-play" "Couldn't auto-update yt-dlp." 2>/dev/null
  return 1
}
if [ -z "$(find "$UPDATE_STAMP" -newermt '-48 hours' 2>/dev/null)" ]; then
  update_ytdl && touch "$UPDATE_STAMP"
fi

# ---- mpv args (avoid AV1 for Vega; VA-API hwdec; PiP size + title) ----
MPV_ARGS=(--script-opts=ytdl_hook-ytdl_path=yt-dlp
          --ytdl-raw-options-append=extractor-args=youtube:player_client=web_safari,default
          --ytdl-format="bestvideo[vcodec!*=av01][height<=?1080]+bestaudio/bestvideo[height<=?1080]+bestaudio/best"
          --hwdec=auto-safe --vo=gpu
          --force-window=immediate --ontop
          --title=mpv-pip --geometry=640x360)

# ---- COSMIC: mark the window sticky (visible on every workspace) ----
set_sticky() {
  command -v cosmicmsg >/dev/null 2>&1 || return
  for _ in $(seq 1 20); do
    cosmicmsg window set-sticky mpv-pip >/dev/null 2>&1 && return
    sleep 0.25
  done
}

# ---- launch in background so we can talk to the window; retry once on failure ----
notify-send "mpv" "Loading… $url" 2>/dev/null
mpv "${MPV_ARGS[@]}" "$url" &
mpvpid=$!
set_sticky
if ! wait "$mpvpid"; then
  notify-send "mpv" "Playback failed — updating yt-dlp and retrying…" 2>/dev/null
  update_ytdl pm
  mpv "${MPV_ARGS[@]}" "$url" &
  mpvpid=$!
  set_sticky
  wait "$mpvpid"
fi
```

---

## 2. Sticky watcher

**File:** `~/.config/scripts/cosmic-mpv-sticky.sh` — make executable with `chmod +x`

Reactive watcher: re-applies sticky to any `mpv-pip` window as events arrive (in case a fresh
window opens or COSMIC drops the flag).

```bash
#!/usr/bin/env bash
# cosmic-mpv-sticky.sh — keep mpv-pip windows sticky, driven by COSMIC's event stream.
export PATH="$HOME/.local/bin:$PATH"
command -v cosmicmsg >/dev/null 2>&1 || exit 0

cosmicmsg --json subscribe 2>/dev/null | while read -r ev; do
  case "$ev" in
    *toplevel*|*window*|*workspace*)
      cosmicmsg window set-sticky mpv-pip >/dev/null 2>&1 ;;
  esac
done
```

---

## 3. Autostart entry

**File:** `~/.config/autostart/cosmic-mpv-sticky.desktop`

COSMIC honors XDG autostart. **`Exec` must be an absolute path** (no `$HOME` expansion) — edit the
username to match yours:

```ini
[Desktop Entry]
Type=Application
Name=mpv PiP sticky (COSMIC)
Comment=Keep mpv-pip windows visible on all workspaces
Exec=/home/toniiz/.config/scripts/cosmic-mpv-sticky.sh
X-GNOME-Autostart-enabled=true
NoDisplay=true
Terminal=false
```

---

## 4. Wire-up checklist

```bash
mkdir -p ~/.config/scripts ~/.config/autostart
chmod +x ~/.config/scripts/mpv-play.sh ~/.config/scripts/cosmic-mpv-sticky.sh

# cosmicmsg (not in Arch repos):
cargo install --git https://github.com/varbhat/cosmicmsg      # or: nix run github:varbhat/cosmicmsg
cosmicmsg get-workspaces                                       # smoke test

# keybind: COSMIC Settings -> Keyboard -> Custom Shortcuts -> +
#   command:  sh -c "$HOME/.config/scripts/mpv-play.sh"

# auto-float mpv: add a tiling exception for app-id "mpv"
#   (cosmic-tiling-manager GUI, or COSMIC's float shortcut Super+G on the window)
```

Log out/in (or run the watcher once by hand) to start the autostart entry.

---

## 5. Keybind (RON)

COSMIC stores custom shortcuts in:

```
~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom
```

It's a RON map of `Binding -> Action`. Add an entry — use an **absolute path** (don't rely on
shell expansion of `$HOME`):

```ron
{
    (modifiers: [Super, Shift], key: "y", description: Some("Play a Video (mpv)")): Spawn("/home/toniiz/.config/scripts/mpv-play.sh"),
}
```

- **Modifiers:** `Super`, `Ctrl`, `Alt`, `Shift`. **`key`** is the keysym name string
(e.g. `"y"`, `"Return"`, `"space"`).
- If the file **already exists**, merge this entry into the existing `{ … }` map
(comma-separated) — don't overwrite the whole file.
- Log out/in (or restart `cosmic-comp`) for COSMIC to pick it up.

> ⚠️ **The RON schema is version-sensitive.** If this exact shape doesn't load on your COSMIC
> build, do it the bulletproof way: add the shortcut once via **Settings → Keyboard → Custom
> Shortcuts**, then open the `custom` file above to see the precise syntax your version wrote and
> copy that shape. (Adding via GUI first, then editing the file, always matches your build.)
> 

---

## 6. Caveats and limitations

- **Sticky works natively** via `cosmicmsg window set-sticky` — verify the exact on/off arg with
`cosmicmsg window set-sticky --help` if your build differs.
- **No bottom-corner auto-placement** on COSMIC (no positional rule / no set-geometry in
cosmicmsg) — size comes from `--geometry`, you place it by hand once.
- **`--ontop`** is best-effort; sticky+float keeps it visible on every workspace regardless.
- **`cosmicmsg` is third-party** (cargo/nix), not official Arch. Without it, the prompt/play/float
parts still work — only the sticky automation needs it.
