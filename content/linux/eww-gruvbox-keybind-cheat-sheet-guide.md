---
title: "eww-gruvbox-keybind-cheat-sheet-guide"
date: 2026-08-18T23:18:30Z
lastmod: 2026-08-18T23:18:30Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# 🎛️ eww Gruvbox Keybind Cheat-Sheet for niri — Full Guide

Replaces niri's built-in hotkey overlay with a **fully Gruvbox-themed floating panel** built
in [eww](https://github.com/elkowar/eww). It **auto-populates from your `config.kdl`** (reads
every `hotkey-overlay-title`), toggles on `Mod+Shift+/`, and matches your waybar/fuzzel theme.

---

## 1. Dependencies

| Tool | Purpose | Arch | Fedora |
| --- | --- | --- | --- |
| `eww` (wayland build) | the widget engine | `paru -S eww` (AUR) | build via `cargo` (below) |
| `jq` | build keybind JSON | `sudo pacman -S jq` | `sudo dnf install jq` |

> **eww must be built with Wayland/layer-shell support.** The AUR `eww` package already is.
> On **Fedora** there's no official package — build it:
> 
> ```bash
> sudo dnf install cargo gtk3-devel gtk-layer-shell-devel
> git clone https://github.com/elkowar/eww && cd eww
> cargo build --release --no-default-features --features=wayland
> install -Dm755 target/release/eww ~/.local/bin/eww
> ```
> 

**Quick dependency check:**

```bash
command -v eww >/dev/null || echo "eww missing — see install above"
command -v jq  >/dev/null || echo "jq missing — install jq"
```

---

## 2. File tree

```
~/.config/eww/
├── eww.yuck                    # widget + window definitions
├── eww.scss                    # Gruvbox styling
└── scripts/
    ├── parse-keybinds.sh       # config.kdl -> JSON
    └── toggle-cheatsheet.sh    # open/close toggle
```

```bash
mkdir -p ~/.config/eww/scripts
```

---

## 3. `~/.config/eww/scripts/parse-keybinds.sh`  (`chmod +x`)

Parses every titled bind, splits its `Category: Label` title into a category + label, and groups them (preserving first-appearance order) into JSON `[{category, binds:[…]}, …]`.

```bash
#!/usr/bin/env bash
# Extract "Key" + hotkey-overlay-title from niri config.kdl as JSON.
CONFIG="${1:-$HOME/.config/niri/config.kdl}"

grep -oE '^[[:space:]]*[^[:space:]]+[[:space:]]+.*hotkey-overlay-title="[^"]*"' "$CONFIG" 2>/dev/null \
| while IFS= read -r line; do
    key=$(printf '%s' "$line" | awk '{print $1}')
    title=$(printf '%s' "$line" | sed -E 's/.*hotkey-overlay-title="([^"]*)".*/\1/')
    # strip Pango markup + unescape entities for clean display
    title=$(printf '%s' "$title" | sed -E 's/<[^>]+>//g; s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g')
    # split "Category: Label" on the first colon; no colon => "Other"
    if [ "$title" != "${title#*:}" ]; then
      cat=${title%%:*}; label=${title#*:}
    else
      cat="Other"; label="$title"
    fi
    cat=$(printf '%s' "$cat" | sed -E 's/^ +| +$//g')
    label=$(printf '%s' "$label" | sed -E 's/^ +| +$//g')
    printf '%s\t%s\t%s\n' "$cat" "$key" "$label"
  done \
| jq -R -s -c '
    split("\n") | map(select(length>0)) | map(split("\t"))
    | map({cat: .[0], key: .[1], title: .[2]}) as $rows
    | ($rows | map(.cat) | reduce .[] as $c ([]; if index($c) then . else . + [$c] end)) as $order
    | $order | map(. as $c | {category: $c, binds: ($rows | map(select(.cat==$c) | {key, title}))})'
```

---

## 4. `~/.config/eww/scripts/toggle-cheatsheet.sh`  (`chmod +x`)

```bash
#!/usr/bin/env bash
# Toggle the cheat sheet; refresh keybinds each time it opens.
if eww active-windows 2>/dev/null | grep -q '^cheatsheet'; then
  eww close cheatsheet
else
  eww update keybinds="$("$HOME/.config/eww/scripts/parse-keybinds.sh")"
  eww open cheatsheet
fi
```

---

## 5. `~/.config/eww/eww.yuck`

```lisp
(defvar keybinds "[]")

(defwidget keyrow [key title]
  (box :class "bind" :orientation "h" :space-evenly false
    (label :class "key"   :text key)
    (label :class "title" :text title)))

(defwidget category [category binds]
  (box :class "category" :orientation "v" :space-evenly false :valign "start"
    (label :class "cat-header" :text category)
    (for entry in binds
      (keyrow :key {entry.key} :title {entry.title}))))

(defwidget cheatsheet []
  (box :class "cheatsheet" :orientation "v" :space-evenly false
    (label :class "header" :text "  Keybinds")
    (scroll :vscroll true :hscroll false :height 560
      (box :class "groups" :orientation "v" :space-evenly false
        (for grp in keybinds
          (category :category {grp.category} :binds {grp.binds}))))
    (label :class "hint" :text "Mod+Shift+/ to close")))

(defwindow cheatsheet
  :monitor 0
  :stacking "overlay"
  :focusable true
  :geometry (geometry :anchor "center" :width "640px" :height "70%")
  (cheatsheet))
```

---

## 6. `~/.config/eww/eww.scss`  (Gruvbox Dark Hard)

```scss
* {
  all: unset;                                   // eww needs this reset
  font-family: "JetBrainsMono Nerd Font";
  font-size: 15px;
}

.cheatsheet {
  background-color: rgba(29, 32, 33, 0.96);     // #1d2021 @ .96
  border: 2px solid #fe8019;                    // orange accent
  border-radius: 12px;
  padding: 18px 22px;
}

.header {
  color: #fabd2f;                               // yellow
  font-size: 20px; font-weight: bold;
  margin-bottom: 14px;
}

.groups   { margin-bottom: 6px; }
.category { margin-bottom: 12px; }
.cat-header {
  color: #83a598;                               // blue
  font-size: 14px; font-weight: bold;
  margin: 6px 0 4px 2px;
}

.bind { padding: 5px 2px; }

.key {                                          // mirrors waybar active pill
  color: #1d2021; background-color: #fe8019;
  font-weight: bold; border-radius: 6px;
  padding: 2px 10px; margin-right: 16px;
  min-width: 130px;
}

.title { color: #ebdbb2; }                      // fg

.hint { color: #928374; font-size: 12px; margin-top: 6px; }  // muted
```

---

## 7. niri `config.kdl` changes

**a. Start the eww daemon at login** (add near your other `spawn-at-startup` lines):

```kdl
spawn-at-startup "eww" "daemon"
```

**b. Bind `Mod+Shift+/` to the toggle** (replace the existing
`Mod+Shift+Slash { show-hotkey-overlay; }` line):

```kdl
Mod+Shift+Slash hotkey-overlay-title="Show Keybinds" {
    spawn "/bin/sh" "-c" "$HOME/.config/eww/scripts/toggle-cheatsheet.sh";
}
```

> Keep using `hotkey-overlay-title="…"` on your other binds — that's exactly what the parser
> reads, so the panel stays in sync with your real keybinds automatically.
> 

**c. (Optional) center it cleanly via a layer rule** — eww uses the layer namespace `eww-cheatsheet`:

```kdl
layer-rule {
    match namespace="^eww-cheatsheet$"
    // e.g. keep it out of the overview backdrop dimming
    place-within-backdrop false
}
```

---

## 7.5 Adding & editing categories

Categories aren't hard-coded — **each bind declares its own** via a `Category: Label` prefix in
its `hotkey-overlay-title`. To place a bind in a section, prefix the title:

```kdl
Mod+Return hotkey-overlay-title="Launchers: Terminal"          { spawn "foot"; }
Mod+D      hotkey-overlay-title="Launchers: Run an Application" { spawn "fuzzel"; }
Mod+Q      hotkey-overlay-title="Window: Close Window"          { close-window; }
Mod+Escape hotkey-overlay-title="System: Lock the Screen"       { spawn "/bin/sh" "-c" "$HOME/.config/eww/scripts/lock.sh"; }
Mod+P      hotkey-overlay-title="System: Cycle Power Profile"   { spawn "/bin/sh" "-c" "..."; }
```

**Rules:**

- Text **before the first `:`** = category; text **after** = the label shown.
- **No colon** → the bind falls into a catch-all **`Other`** section.
- **Section order = order each category first appears** in `config.kdl`. Reorder sections by
moving the *first* bind of a category — no script edits needed.
- **Invent any category** (`Media`, `Screenshots`, `Workspaces`, …); its section appears
automatically the first time you use the name. Spelling must match to share a section.
- Pango color markup still works around the whole title, e.g.
`hotkey-overlay-title="<span foreground='#fabd2f'>System: Lock</span>"` — markup is stripped
for display and the `System` prefix still groups it.

---

## 8. Run & verify

```bash
chmod +x ~/.config/eww/scripts/*.sh
eww daemon                     # (niri also starts it at login)
~/.config/eww/scripts/toggle-cheatsheet.sh   # opens the panel; run again to close
```

Reload after editing SCSS/yuck: `eww reload`.

---

## 9. Troubleshooting

- **Panel empty / `[]`:** your binds may lack `hotkey-overlay-title="…"`. Only titled binds
appear. Test the parser directly: `~/.config/eww/scripts/parse-keybinds.sh | jq`.
- **`eww: command not found` in niri but works in terminal:** the daemon needs `~/.local/bin`
on PATH — either full-path the binary in the `spawn-at-startup`/toggle, or add the dir to
niri's `environment { PATH "…" }`.
- **No window appears:** confirm eww was built with `--features=wayland` (X11 builds won't
layer-shell onto niri). `eww --version` and check logs with `eww logs`.
- **Won't close on second press:** `eww active-windows` must list `cheatsheet`. If your eww
version prints a different format, adjust the `grep` in the toggle script.
- **Too tall on small screens:** lower the `:height` in the `scroll` and `defwindow :geometry`.

---

## 10. What you get

A centered, Gruvbox-framed, scrollable keybind panel — orange border, yellow header, orange
"key" pills with dark text (mirroring your waybar active-workspace pill), `#ebdbb2` labels —
**grouped into your own categories** (declared as `Category:` prefixes on each bind), that
rebuilds its contents from `config.kdl` every time you open it. Fully themed, unlike niri's built-in overlay.
