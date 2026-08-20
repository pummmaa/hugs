---
title: "mpv-video-prompt-gruvbox-fuzzel+yt-dlp"
date: 2026-08-19T19:59:28Z
lastmod: 2026-08-19T19:59:28Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# ▶️ mpv Video Prompt — Gruvbox (fuzzel + yt-dlp)

Press a keybind → a **Gruvbox fuzzel prompt** appears → paste any video URL (YouTube, Twitch,
Vimeo, direct links, …) → it plays in **mpv** using **yt-dlp** as the backend. It also keeps a
**history** of what you've watched, so the prompt is "updatable": your recent URLs show as
pickable entries and new ones are remembered.

---

## 🧩 What you'll create

| File | Role |
| --- | --- |
| `~/.config/niri/scripts/mpv-play.sh` | the prompt + launcher + history |
| `~/.local/share/mpv-play/history` | auto-created list of recent URLs |
| `~/.config/mpv/mpv.conf` *(optional)* | Gruvbox OSD tint |

---

## 1. Dependencies

| Tool | Arch | Fedora |
| --- | --- | --- |
| `mpv` | `sudo pacman -S mpv` | `sudo dnf install mpv` |
| `yt-dlp` | `sudo pacman -S yt-dlp` | `sudo dnf install yt-dlp` |
| `fuzzel` | `sudo pacman -S fuzzel` | `sudo dnf install fuzzel` |

The script also checks these at runtime and tells you the exact install command for your distro.

---

## 2. `~/.config/niri/scripts/mpv-play.sh`  (`chmod +x`)

```bash
#!/usr/bin/env bash
# mpv-play.sh — Gruvbox fuzzel prompt -> mpv (yt-dlp backend), with URL history.
set -u

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

# ---- Gruvbox fuzzel prompt: history as entries; type a new URL or pick one ----
# --placeholder needs fuzzel >= 1.9; gate it so older builds don't error out.
PH=()
fuzzel --help 2>&1 | grep -q -- '--placeholder' && \
  PH=(--placeholder="Paste a video URL (YouTube, Twitch, …)")

# --config=/dev/null: ignore ~/.config/fuzzel/fuzzel.ini so its
# "exit-immediately-if-empty=yes" doesn't kill the prompt when history is empty.
# All styling is supplied via the flags below, so the look is unchanged.
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

# 0 = picked/typed, 1 = cancelled (Esc). Anything else = fuzzel error, e.g. a bad
# flag or a broken ~/.config/fuzzel/fuzzel.ini -> surface it instead of hiding it.
if [ "$status" -gt 1 ]; then
  notify-send "mpv-play" "fuzzel failed (exit $status). Test 'echo | fuzzel --dmenu' and check ~/.config/fuzzel/fuzzel.ini" 2>/dev/null
  echo "fuzzel exited $status — test 'echo | fuzzel --dmenu'; check fuzzel.ini" >&2
  exit 1
fi

# trim whitespace; bail if empty (cancelled)
url=$(printf '%s' "$url" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
[ -z "$url" ] && exit 0

# ---- update history: new URL on top, de-duplicated, capped ----
tmp=$(mktemp)
{ printf '%s\n' "$url"; grep -vxF "$url" "$HIST" 2>/dev/null; } | head -n "$MAX_HIST" > "$tmp"
mv "$tmp" "$HIST"

# ---- keep yt-dlp fresh (self-update) ----
UPDATE_STAMP="$(dirname "$HIST")/last-update"
PM_UPDATE=1   # 1 = dnf auto-update via pkexec (Fedora); Arch just prompts you to run -Syu

# $1="pm" -> may escalate to the distro package manager (GUI auth via pkexec).
update_ytdl() {
  if yt-dlp -U >/dev/null 2>&1; then return 0; fi                                             # binary / pip
  if command -v pipx >/dev/null 2>&1 && pipx upgrade yt-dlp >/dev/null 2>&1; then return 0; fi  # pipx
  if [ "${1:-}" = "pm" ] && [ "$PM_UPDATE" = "1" ] && command -v pkexec >/dev/null 2>&1; then
    [ -r /etc/os-release ] && . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
      *arch*)          notify-send "mpv-play" "yt-dlp is out of date — run: sudo pacman -Syu" 2>/dev/null; return 1 ;;
      *fedora*|*rhel*) pkexec dnf -y upgrade yt-dlp >/dev/null 2>&1 && return 0 ;;
    esac
  fi
  notify-send "mpv-play" "Couldn't auto-update yt-dlp — update it manually." 2>/dev/null
  return 1
}

# every 48h, no-prompt refresh (binary/pip/pipx only — never escalates)
if [ -z "$(find "$UPDATE_STAMP" -newermt '-48 hours' 2>/dev/null)" ]; then
  update_ytdl && touch "$UPDATE_STAMP"
fi

# ---- launch mpv (yt-dlp backend); on failure, escalate update + retry once ----
MPV_ARGS=(--script-opts=ytdl_hook-ytdl_path=yt-dlp
          --ytdl-format="bestvideo[height<=?1080]+bestaudio/best"
          --force-window=immediate)
notify-send "mpv" "Loading… $url" 2>/dev/null
if ! mpv "${MPV_ARGS[@]}" "$url"; then
  notify-send "mpv" "Playback failed — updating yt-dlp and retrying…" 2>/dev/null
  update_ytdl pm            # allow pacman/dnf here (pops a pkexec auth dialog)
  mpv "${MPV_ARGS[@]}" "$url"
fi
```

---

## 3. Bind it in niri `config.kdl`

```kdl
Mod+Shift+Y hotkey-overlay-title="Media: Play a Video (mpv)" {
    spawn "/bin/sh" "-c" "$HOME/.config/niri/scripts/mpv-play.sh";
}
```

*(The `Media:` prefix means it also shows up in your eww cheat-sheet under a **Media** section.)*

---

## 4. (Optional) Gruvbox OSD — `~/.config/mpv/mpv.conf`

mpv's window is video, but you can tint its on-screen display to match:

```ini
osd-color='#ebdbb2'
osd-border-color='#1d2021'
osd-back-color='#1d2021'
osd-font='JetBrainsMono Nerd Font'
osd-bar-align-y=0.9
background='#1d2021'
force-window=immediate
```

---

## 5. Setup & test

```bash
mkdir -p ~/.config/niri/scripts
chmod +x ~/.config/niri/scripts/mpv-play.sh
~/.config/niri/scripts/mpv-play.sh        # prompt appears; paste a URL; Enter
```

Type a URL and press **Enter**. Pick an earlier URL from the list to replay it.

---

## 🔄 Update behavior at a glance

- **Every 48 h (silent, no prompt):** a background refresh runs `yt-dlp -U` then
`pipx upgrade yt-dlp` — effective only for **binary/pip/pipx** installs. Cadence is tracked in
`last-update` (beside the history file).
- **On playback failure** the script updates yt-dlp and **retries the URL once**:

  - **Fedora:** `pkexec dnf -y upgrade yt-dlp` — shows a GUI polkit password dialog.
  - **Arch (safer):** it does **not** run a partial `pacman -Sy`; instead it **notifies you to run
`sudo pacman -Syu`** (avoids Arch's partial-upgrade risk). Run it, then re-try the video.
- **Toggle:** set **`PM_UPDATE=0`** at the top of the script to disable the dnf escalation.
- **Most hands-off setup:** install yt-dlp as a self-updatable binary or via `pipx install yt-dlp`
so the silent 48 h refresh keeps it current without any prompts. Distro packages update on your
normal system-update cadence.

---

## ⚠️ Caveats

- **Typing a new URL:** in `--dmenu` mode, fuzzel returns the **typed text** when it doesn't match
a history entry — so just paste and press Enter. This relies on fuzzel ≥ 1.9. If your build
returns nothing for non-matching input, tell me and I'll switch the prompt to a plain
`fuzzel --dmenu --index`-free read.
- **`--placeholder` is now auto-gated** — the script only passes it if `fuzzel --help` lists it,
so older fuzzel won't error on it.
- **Prompt opens then instantly closes / never shows on first run?** If your `fuzzel.ini` has
`[dmenu] exit-immediately-if-empty=yes`, fuzzel quits when stdin is empty (empty history) — the
script now passes `--config=/dev/null` to avoid inheriting that. (Styling is all via CLI flags.)
- **Prompt doesn't appear at all?** fuzzel reads `~/.config/fuzzel/fuzzel.ini` on every launch, so
a **broken fuzzel.ini blocks *all* fuzzel windows** (e.g. a `[key-bindings]` "already mapped"
error). Test with `echo | fuzzel --dmenu` — if that shows nothing, fix `fuzzel.ini` first. The
script now notifies on fuzzel errors instead of exiting silently.
- **mpv must find yt-dlp:** `--script-opts=ytdl_hook-ytdl_path=yt-dlp` forces mpv's hook to use
`yt-dlp` (not the abandoned `youtube-dl`).
- **Self-update (built in, pacman/dnf aware):** a **no-prompt refresh every 48h** tries
`yt-dlp -U` then `pipx upgrade` (for binary/pip/pipx installs). If playback **fails**, it
escalates:

  - **Fedora:** `pkexec dnf -y upgrade yt-dlp`, then retries once.
  - **Arch (safer):** it does **not** run a partial `pacman -Sy` (Arch discourages partial
upgrades — they can pull an out-of-sync dependency). Instead it **notifies you to run
`sudo pacman -Syu`**, keeping your system consistent. Run that, then re-try the video.
  - **pkexec needs a polkit agent** — you already start `polkit-gnome` in niri, so the Fedora
path shows a GUI password dialog (no terminal/passwordless-sudo needed).
  - Set **`PM_UPDATE=0`** at the top of the script to disable the dnf escalation.
  - The 48h cadence is tracked in `last-update` beside the history file.
- **Auth / age-restricted / subscriber content:** add browser cookies, e.g. append
`--ytdl-raw-options=cookies-from-browser=firefox` to the mpv line.
- **Twitch:** live works; expect some ad segments. For low latency add
`--cache=yes --demuxer-max-bytes=...` to taste.
- **Format cap:** `height<=?1080` caps at 1080p (the `?` means "prefer, don't hard-fail"). Raise
to `1440`/`2160` or drop it for max quality.
- **Hardware decoding** (smoother 4K, less CPU): add `hwdec=auto` to `mpv.conf`.
- **History file:** plain text at `~/.local/share/mpv-play/history`, newest first, capped at 50.
Delete it to clear, or edit by hand. URLs are stored **unencrypted** — mind shared machines.
- **Playlists / live streams** work; very long playlists just load lazily via yt-dlp.
- **niri window:** mpv opens tiled by default. To float it, add a window-rule matching
`app-id="mpv"` with `open-floating true`.

---

## 6. What you get

A Gruvbox-matched popup (orange border + selection, dark bg, JetBrainsMono Nerd Font — same look
as your waybar/fuzzel) that plays any yt-dlp-supported URL in mpv and remembers your recent links
for one-key replay.
