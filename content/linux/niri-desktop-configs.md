---
title: "niri-desktop-configs"
data: 2026-08-17T22:15:01Z
lastmod: 2026-08-17T22:15:01Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# niri desktop configuration

A complete niri setup: scrollable-tiling Wayland compositor, waybar status bar,
mako notifications, fuzzel launcher, foot terminal, swaylock/swayidle idle
handling with dim-before-lock. Tokyo Night throughout.

All paths below are relative to `~/.config/`.

## Contents

| File | Purpose | Mode |
|---|---|---|
| `niri/config.kdl` | compositor: input, outputs, layout, startup, keybinds | `644` |
| `niri/scripts/idle-brightness.sh` | fade the backlight down before locking, restore on activity | `755` |
| `waybar/config.jsonc` | status bar modules | `644` |
| `waybar/style.css` | status bar theme | `644` |
| `waybar/scripts/mako-status.sh` | bar module: notification count + DND state | `755` |
| `waybar/scripts/powermenu.sh` | bar module: power menu via fuzzel | `755` |
| `mako/config` | notification daemon | `644` |
| `fuzzel/fuzzel.ini` | application launcher | `644` |
| `swaylock/config` | screen locker | `644` |
| `foot/foot.ini` | terminal emulator | `644` |

## Install

Create the files below, then:

```bash
chmod +x ~/.config/niri/scripts/idle-brightness.sh \
         ~/.config/waybar/scripts/*.sh
niri validate -c ~/.config/niri/config.kdl
```

### Packages — Arch

```bash
sudo pacman -S --needed \
  niri waybar mako fuzzel foot swaybg swayidle swaylock \
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
  wl-clipboard cliphist grim slurp \
  brightnessctl playerctl \
  pipewire pipewire-pulse pipewire-alsa wireplumber \
  networkmanager network-manager-applet \
  bluez bluez-utils blueman pavucontrol \
  polkit polkit-gnome \
  xwayland-satellite \
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
  adwaita-icon-theme adwaita-cursors \
  qt5-wayland qt6-wayland \
  firefox yazi btop

sudo systemctl enable --now NetworkManager bluetooth
```

Everything is in `core`/`extra` — no AUR required.

**One caveat.** The `screenshots`, `effect-blur`, `effect-vignette` and `fade-in`
lines in `swaylock/config` are `swaylock-effects` extensions. Vanilla swaylock
rejects unknown options rather than ignoring them, so either delete those four
lines or install the fork (`paru -S swaylock-effects`, which replaces
`swaylock`). Test the locker before relying on it.

### Packages — Debian / Ubuntu

```bash
sudo apt install waybar mako-notifier fuzzel foot swaybg swayidle swaylock \
  xdg-desktop-portal-gtk xdg-desktop-portal-wlr wl-clipboard grim slurp \
  brightnessctl playerctl wireplumber pipewire pipewire-pulse pipewire-alsa \
  libspa-0.2-bluetooth network-manager network-manager-gnome policykit-1-gnome \
  pavucontrol blueman fonts-jetbrains-mono fonts-noto-color-emoji \
  adwaita-icon-theme firefox-esr btop
```

`niri`, `xwayland-satellite`, `cliphist` and `yazi` are not in Debian stable —
take them from trixie/sid, or:

```bash
go install go.senan.xyz/cliphist@latest
cargo install --locked yazi-fm yazi-cli
```

Without `cliphist`, `Mod+Y` does nothing. Without `xwayland-satellite`, X11-only
apps will not start — drop that `spawn-at-startup` line and the `DISPLAY`
variable if you skip it.

Debian's `fonts-jetbrains-mono` is the unpatched font, so bar icons render as
boxes. For the patched build:

```bash
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o JetBrainsMono.zip && rm JetBrainsMono.zip && fc-cache -f
```

The configs already handle both distros: the polkit spawn line probes the Debian
and Arch agent paths, and `Mod+B` probes for `firefox` before `firefox-esr`.

## Before first login

- **Set your outputs.** The config ships placeholder connectors. Run
  `niri msg outputs` inside a session and edit the `output` blocks to match.
- **Wallpaper.** swaybg looks for `~/.config/niri/wallpaper.jpg`. Drop any JPEG
  there or edit that spawn line.
- **Secret Service.** Not included. Add `gnome-keyring` if you want
  NetworkManager to store Wi-Fi passwords per-user, or ssh-agent integration.

## Keybinds

`Mod` is Super. Press `Mod+Shift+/` in the session for the full generated list.

| Bind | Action |
|---|---|
| `Mod+Return` | terminal |
| `Mod+D` | launcher |
| `Mod+E` | file manager |
| `Mod+B` | browser |
| `Mod+Q` | close window |
| `Mod+Escape` | lock |
| `Mod+O` | overview |
| `Mod+Y` | clipboard history |
| `Mod+H/J/K/L` | focus left/down/up/right |
| `Mod+Ctrl+<dir>` | move window |
| `Mod+1`..`9` | workspace |
| `Mod+R` / `Mod+F` | cycle width / maximize |
| `Mod+W` / `Mod+V` | tabbed / floating |
| `Mod+,` / `Mod+.` | consume / expel window |
| `Print` | screenshot |
| `Mod+Shift+E` | quit niri |

## Idle behaviour

Driven by the swayidle line in `config.kdl`:

| Time | Action |
|---|---|
| 4:30 | dim the backlight |
| 5:00 | lock |
| 10:00 | power off monitors |
| 30:00 | suspend |

The dim lands 30s before the lock so the fade is a warning you can cancel by
moving the mouse. Adjust the `timeout` values to taste.

---

## `niri/config.kdl`

```kdl
// niri configuration
// Docs: https://yalter.github.io/niri/
// Validate after editing:  niri validate -c ~/.config/niri/config.kdl

input {
    keyboard {
        xkb {
            layout "us"
            // options "ctrl:nocaps"
        }
        repeat-delay 300
        repeat-rate 40
        numlock
    }

    touchpad {
        tap
        dwt
        natural-scroll
        accel-profile "flat"
        scroll-method "two-finger"
        click-method "clickfinger"
    }

    mouse {
        accel-profile "flat"
    }

    // Pointer must cross this much of a window before focus moves, which keeps
    // focus stable while dragging across a column edge.
    focus-follows-mouse max-scroll-amount="0%"
    warp-mouse-to-focus
    workspace-auto-back-and-forth
}

// Run `niri msg outputs` to get the real connector names and modes for your
// machine, then replace the placeholders below.
output "eDP-1" {
    mode "1920x1080@60.000"
    scale 1.0
    transform "normal"
    position x=0 y=0
    variable-refresh-rate on-demand
}

output "HDMI-A-1" {
    // off
    scale 1.0
    position x=1920 y=0
}

layout {
    gaps 12
    center-focused-column "never"

    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    preset-window-heights {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    default-column-width { proportion 0.5; }

    focus-ring {
        width 2
        active-gradient from="#7aa2f7" to="#bb9af7" angle=45
        inactive-color "#3b4261"
    }

    border {
        off
        width 2
        active-color "#7aa2f7"
        inactive-color "#3b4261"
    }

    shadow {
        on
        softness 24
        spread 4
        offset x=0 y=4
        color "#0007"
    }

    tab-indicator {
        width 4
        gap 4
        length total-proportion=1.0
        position "left"
        active-color "#7aa2f7"
        inactive-color "#3b4261"
    }

    insert-hint {
        color "#7aa2f780"
    }

    // Waybar reserves its own space via layer-shell exclusive zone, so no
    // struts are needed here.
    struts {
        left 0
        right 0
        top 0
        bottom 0
    }
}

overview {
    zoom 0.5
    backdrop-color "#1a1b26"
}

// --- Startup -----------------------------------------------------------

spawn-at-startup "waybar"
spawn-at-startup "mako"

// Graphical password prompts for anything needing root (GUI package managers,
// disk mounting). Without it those apps fail silently.
//
// The agent's path differs per distro -- Debian ships it under
// /usr/lib/policykit-1-gnome, Arch under /usr/lib/polkit-gnome -- so probe
// both instead of hardcoding one.
spawn-at-startup "/bin/sh" "-c" "\
    for p in /usr/libexec/polkit-gnome-authentication-agent-1 \
             /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
             /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1; do \
        [ -x \"$p\" ] && exec \"$p\"; \
    done; exit 0"
spawn-at-startup "nm-applet" "--indicator"

// Clipboard history, queried by Mod+Y below.
spawn-at-startup "/bin/sh" "-c" "wl-paste --watch cliphist store"

// Wrapped in sh because spawn-at-startup passes arguments literally -- a bare
// "~" would reach swaybg unexpanded and fail to open the file.
spawn-at-startup "/bin/sh" "-c" "swaybg -m fill -i \"$HOME/.config/niri/wallpaper.jpg\""

// Idle chain. Ordered by timeout, and the dim step lands 30s before the lock
// so the fade acts as a visible warning you can cancel by moving the mouse.
//
//   4:30  dim the backlight
//   5:00  lock
//  10:00  power off monitors
//  30:00  suspend
//
// The dim's `resume` must undim on any activity, including activity that
// arrives after the lock, or the screen would stay dark behind the locker.
//
// Wrapped in sh because spawn-at-startup passes arguments literally, so
// "$HOME" would reach swayidle as an unexpanded string.
spawn-at-startup "/bin/sh" "-c" "exec swayidle -w \
    timeout 270 '$HOME/.config/niri/scripts/idle-brightness.sh dim' \
      resume '$HOME/.config/niri/scripts/idle-brightness.sh restore' \
    timeout 300 'swaylock -f' \
    timeout 600 'niri msg action power-off-monitors' \
      resume 'niri msg action power-on-monitors' \
    timeout 1800 'systemctl suspend' \
    before-sleep 'swaylock -f' \
    after-resume '$HOME/.config/niri/scripts/idle-brightness.sh restore' \
    lock 'swaylock -f' \
    unlock '$HOME/.config/niri/scripts/idle-brightness.sh restore'"

// X11 apps. Requires the `xwayland-satellite` package; drop this line and the
// DISPLAY variable below if you only run Wayland-native software.
spawn-at-startup "xwayland-satellite"

// Single environment section -- niri rejects the config if it appears twice.
environment {
    // Must match the display xwayland-satellite listens on.
    DISPLAY ":0"
    QT_QPA_PLATFORM "wayland"
    MOZ_ENABLE_WAYLAND "1"
    ELECTRON_OZONE_PLATFORM_HINT "auto"
    XDG_CURRENT_DESKTOP "niri"
}

cursor {
    xcursor-theme "Adwaita"
    xcursor-size 24
    hide-when-typing
    hide-after-inactive-ms 5000
}

prefer-no-csd
screenshot-path "~/Pictures/Screenshots/Screenshot-%Y-%m-%d-%H%M%S.png"

hotkey-overlay {
    // skip-at-startup
}

animations {
    slowdown 1.0
}

// --- Window rules ------------------------------------------------------

window-rule {
    geometry-corner-radius 8
    clip-to-geometry true
}

window-rule {
    match app-id=r#"^org\.keepassxc\.KeePassXC$"#
    match app-id=r#"^org\.gnome\.World\.Secrets$"#
    block-out-from "screen-capture"
}

window-rule {
    match app-id=r#"^(pavucontrol|blueman-manager|nm-connection-editor)$"#
    match app-id=r#"^org\.pulseaudio\.pavucontrol$"#
    open-floating true
    default-column-width { proportion 0.4; }
}

window-rule {
    match title=r#"^(Open File|Save File|Save As|Open Folder)$"#
    open-floating true
}

// Picture-in-picture: small, floating, always visible.
window-rule {
    match title=r#"^Picture-in-[Pp]icture$"#
    open-floating true
    default-floating-position x=32 y=32 relative-to="bottom-right"
}

layer-rule {
    match namespace="^waybar$"
    // Keeps the bar out of the overview backdrop dimming.
    place-within-backdrop false
}

layer-rule {
    match namespace="^notifications$"
    block-out-from "screen-capture"
}

// --- Keybinds ----------------------------------------------------------
// Mod = Super. Press Mod+Shift+/ in the session for the live cheat sheet.

binds {
    Mod+Shift+Slash { show-hotkey-overlay; }

    // Launching
    Mod+Return hotkey-overlay-title="Terminal" { spawn "foot"; }
    Mod+D hotkey-overlay-title="Run an Application" { spawn "fuzzel"; }
    Mod+E hotkey-overlay-title="File Manager" { spawn "foot" "-e" "yazi"; }
    // Debian names the binary firefox-esr; upstream builds use firefox.
    Mod+B hotkey-overlay-title="Web Browser" { spawn "/bin/sh" "-c" "command -v firefox >/dev/null && exec firefox || exec firefox-esr"; }
    // Not Mod+L: that is vim-style focus-column-right below.
    Mod+Escape hotkey-overlay-title="Lock the Screen" { spawn "swaylock" "-f"; }
    Mod+Y hotkey-overlay-title="Clipboard History" { spawn "/bin/sh" "-c" "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"; }
    Mod+N hotkey-overlay-title="Dismiss Notification" { spawn "makoctl" "dismiss"; }
    Mod+Shift+N hotkey-overlay-title="Dismiss All Notifications" { spawn "makoctl" "dismiss" "--all"; }

    // Session
    Mod+Shift+E { quit; }
    Ctrl+Alt+Delete { quit; }
    Mod+Shift+Q { close-window; }
    Mod+Q { close-window; }

    // Focus
    Mod+Left  { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up    { focus-window-up; }
    Mod+Down  { focus-window-down; }
    Mod+H     { focus-column-left; }
    Mod+L     { focus-column-right; }
    Mod+K     { focus-window-up; }
    Mod+J     { focus-window-down; }
    Mod+Home  { focus-column-first; }
    Mod+End   { focus-column-last; }

    // Move
    Mod+Ctrl+Left  { move-column-left; }
    Mod+Ctrl+Right { move-column-right; }
    Mod+Ctrl+Up    { move-window-up; }
    Mod+Ctrl+Down  { move-window-down; }
    Mod+Ctrl+H     { move-column-left; }
    Mod+Ctrl+L     { move-column-right; }
    Mod+Ctrl+K     { move-window-up; }
    Mod+Ctrl+J     { move-window-down; }
    Mod+Ctrl+Home  { move-column-to-first; }
    Mod+Ctrl+End   { move-column-to-last; }

    // Monitors
    Mod+Shift+Left  { focus-monitor-left; }
    Mod+Shift+Right { focus-monitor-right; }
    Mod+Shift+Up    { focus-monitor-up; }
    Mod+Shift+Down  { focus-monitor-down; }
    Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
    Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
    Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
    Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }

    // Workspaces
    Mod+Page_Down      { focus-workspace-down; }
    Mod+Page_Up        { focus-workspace-up; }
    Mod+U              { focus-workspace-down; }
    Mod+I              { focus-workspace-up; }
    Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
    Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }
    Mod+Ctrl+U         { move-column-to-workspace-down; }
    Mod+Ctrl+I         { move-column-to-workspace-up; }
    Mod+Shift+Page_Down { move-workspace-down; }
    Mod+Shift+Page_Up   { move-workspace-up; }
    Mod+Tab            { focus-workspace-previous; }

    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }

    Mod+Ctrl+1 { move-column-to-workspace 1; }
    Mod+Ctrl+2 { move-column-to-workspace 2; }
    Mod+Ctrl+3 { move-column-to-workspace 3; }
    Mod+Ctrl+4 { move-column-to-workspace 4; }
    Mod+Ctrl+5 { move-column-to-workspace 5; }
    Mod+Ctrl+6 { move-column-to-workspace 6; }
    Mod+Ctrl+7 { move-column-to-workspace 7; }
    Mod+Ctrl+8 { move-column-to-workspace 8; }
    Mod+Ctrl+9 { move-column-to-workspace 9; }

    // Mouse wheel / touchpad navigation
    Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
    Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
    Mod+WheelScrollRight     { focus-column-right; }
    Mod+WheelScrollLeft      { focus-column-left; }
    Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
    Mod+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

    // Sizing and layout
    Mod+R       { switch-preset-column-width; }
    Mod+Shift+R { switch-preset-window-height; }
    Mod+Ctrl+R  { reset-window-height; }
    Mod+F       { maximize-column; }
    Mod+Shift+F { fullscreen-window; }
    Mod+Ctrl+F  { expand-column-to-available-width; }
    Mod+C       { center-column; }
    Mod+Minus   { set-column-width "-10%"; }
    Mod+Equal   { set-column-width "+10%"; }
    Mod+Shift+Minus { set-window-height "-10%"; }
    Mod+Shift+Equal { set-window-height "+10%"; }

    Mod+Comma        { consume-window-into-column; }
    Mod+Period       { expel-window-from-column; }
    Mod+BracketLeft  { consume-or-expel-window-left; }
    Mod+BracketRight { consume-or-expel-window-right; }
    Mod+W            { toggle-column-tabbed-display; }

    Mod+V       { toggle-window-floating; }
    Mod+Shift+V { switch-focus-between-floating-and-tiling; }

    Mod+O repeat=false { toggle-overview; }

    // Screenshots
    Print           { screenshot; }
    Ctrl+Print      { screenshot-screen; }
    Alt+Print       { screenshot-window; }

    // Media and hardware keys (wireplumber + brightnessctl)
    XF86AudioRaiseVolume  allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1.5" "@DEFAULT_AUDIO_SINK@" "5%+"; }
    XF86AudioLowerVolume  allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
    XF86AudioMute         allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
    XF86AudioMicMute      allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
    XF86AudioPlay         allow-when-locked=true { spawn "playerctl" "play-pause"; }
    XF86AudioNext         allow-when-locked=true { spawn "playerctl" "next"; }
    XF86AudioPrev         allow-when-locked=true { spawn "playerctl" "previous"; }
    XF86MonBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+5%"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "5%-"; }

    // Power
    Mod+Shift+P { power-off-monitors; }
}
```

## `niri/scripts/idle-brightness.sh`  — `chmod +x`

```bash
#!/usr/bin/env bash
#
# Dim the backlight before the screen locks, and restore it on activity.
#
#   idle-brightness.sh dim       save current level, fade down to DIM_PERCENT
#   idle-brightness.sh restore   fade back to the saved level
#
# Uses its own state file rather than `brightnessctl -s/-r` because a second
# dim without an intervening restore would overwrite brightnessctl's saved
# value with the already-dimmed one, leaving no way back to the real level.

set -uo pipefail

DIM_PERCENT="${IDLE_DIM_PERCENT:-10}"
STATE="${XDG_RUNTIME_DIR:-/tmp}/niri-idle-brightness"
STEPS=10
STEP_MS=25

command -v brightnessctl >/dev/null 2>&1 || exit 0

# Bail out on desktops with no backlight (external monitors only), where
# brightnessctl reports no usable device.
current() { brightnessctl --class=backlight get 2>/dev/null; }
maximum() { brightnessctl --class=backlight max 2>/dev/null; }

max=$(maximum) || exit 0
[ -n "${max:-}" ] && [ "$max" -gt 0 ] 2>/dev/null || exit 0

set_raw() { brightnessctl --class=backlight --quiet set "$1" >/dev/null 2>&1 || true; }

# Ease between two raw values so the change reads as a fade, not a jump.
fade_to() {
    local from="$1" to="$2" i value
    for ((i = 1; i <= STEPS; i++)); do
        value=$(( from + (to - from) * i / STEPS ))
        [ "$value" -lt 1 ] && value=1
        set_raw "$value"
        sleep "0.0$STEP_MS"
    done
}

case "${1:-}" in
    dim)
        now=$(current) || exit 0
        [ -n "${now:-}" ] || exit 0

        target=$(( max * DIM_PERCENT / 100 ))
        [ "$target" -lt 1 ] && target=1

        # Already at or below the dim level: nothing to do, and saving now
        # would clobber a pending restore value.
        [ "$now" -le "$target" ] && exit 0

        # Only record the pre-dim level if no restore is outstanding.
        [ -f "$STATE" ] || printf '%s\n' "$now" >"$STATE"

        fade_to "$now" "$target"
        ;;

    restore)
        [ -f "$STATE" ] || exit 0
        saved=$(cat "$STATE" 2>/dev/null)
        rm -f "$STATE"

        [[ "${saved:-}" =~ ^[0-9]+$ ]] || exit 0
        [ "$saved" -gt "$max" ] && saved="$max"

        now=$(current) || exit 0
        # If the user raised brightness by hand while dimmed, respect that
        # instead of yanking it back to the stale saved value.
        [ -n "${now:-}" ] && [ "$now" -gt "$saved" ] && exit 0

        fade_to "${now:-$saved}" "$saved"
        ;;

    *)
        printf 'usage: %s {dim|restore}\n' "${0##*/}" >&2
        exit 1
        ;;
esac
```

## `waybar/config.jsonc`

```jsonc
{
  "layer": "top",
  "position": "top",
  "height": 34,
  "spacing": 6,
  "margin-top": 6,
  "margin-left": 12,
  "margin-right": 12,

  "modules-left": ["niri/workspaces", "niri/window"],
  "modules-center": ["clock"],
  "modules-right": [
    "tray",
    "privacy",
    "idle_inhibitor",
    "pulseaudio",
    "backlight",
    "network",
    "bluetooth",
    "cpu",
    "memory",
    "temperature",
    "battery",
    "custom/notification",
    "custom/power"
  ],

  "niri/workspaces": {
    "format": "{icon}",
    "format-icons": {
      "active": "",
      "default": "",
      "empty": ""
    },
    "on-click": "activate"
  },

  "niri/window": {
    "format": "{}",
    "max-length": 60,
    "separate-outputs": true,
    "rewrite": {
      "(.*) — Mozilla Firefox": "🌍 $1",
      "(.*) - foot": "> $1",
      "": "—"
    }
  },

  "clock": {
    "interval": 1,
    "format": "{:%a %d %b  %H:%M}",
    "format-alt": "{:%Y-%m-%d %H:%M:%S}",
    "tooltip-format": "<tt><small>{calendar}</small></tt>",
    "calendar": {
      "mode": "month",
      "weeks-pos": "right",
      "on-scroll": 1,
      "format": {
        "months": "<span color='#c0caf5'><b>{}</b></span>",
        "days": "<span color='#a9b1d6'>{}</span>",
        "weeks": "<span color='#7dcfff'><b>W{}</b></span>",
        "weekdays": "<span color='#e0af68'><b>{}</b></span>",
        "today": "<span color='#f7768e'><b><u>{}</u></b></span>"
      }
    },
    "actions": {
      "on-click-right": "mode",
      "on-scroll-up": "shift_up",
      "on-scroll-down": "shift_down"
    }
  },

  "tray": {
    "icon-size": 16,
    "spacing": 8
  },

  "privacy": {
    "icon-size": 14,
    "transition-duration": 250,
    "modules": [
      { "type": "screenshare", "tooltip": true },
      { "type": "audio-in", "tooltip": true }
    ]
  },

  "idle_inhibitor": {
    "format": "{icon}",
    "format-icons": { "activated": "", "deactivated": "" },
    "tooltip-format-activated": "Idle inhibited — screen stays awake",
    "tooltip-format-deactivated": "Idle inhibitor off"
  },

  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": " muted",
    "format-bluetooth": "{icon} {volume}%",
    "format-bluetooth-muted": " muted",
    "format-icons": {
      "headphone": "",
      "hands-free": "",
      "headset": "",
      "phone": "",
      "portable": "",
      "car": "",
      "default": ["", "", ""]
    },
    "scroll-step": 5,
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "on-click-right": "pavucontrol",
    "tooltip-format": "{desc} — {volume}%"
  },

  "backlight": {
    "format": "{icon} {percent}%",
    "format-icons": ["", "", "", "", "", "", "", "", ""],
    "on-scroll-up": "brightnessctl --class=backlight set +5%",
    "on-scroll-down": "brightnessctl --class=backlight set 5%-",
    "tooltip": false
  },

  "network": {
    "format-wifi": "  {signalStrength}%",
    "format-ethernet": " ",
    "format-linked": " ",
    "format-disconnected": " ",
    "tooltip-format-wifi": "{essid} ({signalStrength}%)\n{ipaddr}/{cidr}\n {bandwidthUpBits}  {bandwidthDownBits}",
    "tooltip-format-ethernet": "{ifname}\n{ipaddr}/{cidr}\n {bandwidthUpBits}  {bandwidthDownBits}",
    "tooltip-format-disconnected": "Disconnected",
    "on-click": "foot -e nmtui"
  },

  "bluetooth": {
    "format": "",
    "format-disabled": "",
    "format-connected": " {num_connections}",
    "tooltip-format": "{controller_alias}\t{controller_address}",
    "tooltip-format-connected": "{controller_alias}\n{device_enumerate}",
    "tooltip-format-enumerate-connected": "{device_alias}\t{device_address}",
    "on-click": "blueman-manager"
  },

  "cpu": {
    "interval": 3,
    "format": " {usage}%",
    "on-click": "foot -e btop"
  },

  "memory": {
    "interval": 5,
    "format": " {percentage}%",
    "tooltip-format": "{used:0.1f}G / {total:0.1f}G  (swap {swapUsed:0.1f}G)",
    "on-click": "foot -e btop"
  },

  "temperature": {
    "interval": 5,
    "critical-threshold": 82,
    "format": "{icon} {temperatureC}°C",
    "format-critical": " {temperatureC}°C",
    "format-icons": ["", "", ""],
    "tooltip": false
  },

  "battery": {
    "interval": 10,
    "states": { "warning": 25, "critical": 12 },
    "format": "{icon} {capacity}%",
    "format-charging": " {capacity}%",
    "format-plugged": " {capacity}%",
    "format-full": " {capacity}%",
    "format-icons": ["", "", "", "", ""],
    "tooltip-format": "{timeTo} ({power:0.1f} W)"
  },

  "custom/notification": {
    "tooltip": true,
    "format": "{}",
    "exec": "~/.config/waybar/scripts/mako-status.sh",
    "return-type": "json",
    "interval": 3,
    "on-click": "makoctl dismiss --all",
    "on-click-right": "makoctl mode -t do-not-disturb"
  },

  "custom/power": {
    "format": "",
    "tooltip-format": "Power menu",
    "on-click": "~/.config/waybar/scripts/powermenu.sh"
  }
}
```

## `waybar/style.css`

```css
/* Waybar — Tokyo Night */

@define-color bg        #1a1b26;
@define-color bg_alt    #24283b;
@define-color fg        #c0caf5;
@define-color muted     #565f89;
@define-color blue      #7aa2f7;
@define-color cyan      #7dcfff;
@define-color green     #9ece6a;
@define-color yellow    #e0af68;
@define-color orange    #ff9e64;
@define-color red       #f7768e;
@define-color magenta   #bb9af7;

* {
  font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
  font-size: 13px;
  font-weight: 500;
  border: none;
  border-radius: 0;
  min-height: 0;
  /* GTK draws a 1px focus outline on hover without this. */
  box-shadow: none;
  text-shadow: none;
}

window#waybar {
  background: transparent;
  color: @fg;
}

window#waybar.hidden {
  opacity: 0.2;
}

.modules-left,
.modules-center,
.modules-right {
  background-color: alpha(@bg, 0.85);
  border: 1px solid alpha(@blue, 0.25);
  border-radius: 10px;
  padding: 0 4px;
}

#workspaces {
  padding: 0 2px;
}

#workspaces button {
  color: @muted;
  padding: 0 6px;
  margin: 4px 1px;
  border-radius: 8px;
  background: transparent;
  transition: all 200ms ease;
}

#workspaces button:hover {
  color: @fg;
  background-color: alpha(@blue, 0.18);
}

#workspaces button.active {
  color: @blue;
  background-color: alpha(@blue, 0.22);
  padding: 0 12px;
}

#workspaces button.urgent {
  color: @bg;
  background-color: @red;
}

#window {
  color: @fg;
  padding: 0 10px;
}

window#waybar.empty #window {
  background: transparent;
  border: none;
}

#clock {
  color: @cyan;
  font-weight: 700;
  padding: 0 14px;
}

#tray,
#privacy,
#idle_inhibitor,
#pulseaudio,
#backlight,
#network,
#bluetooth,
#cpu,
#memory,
#temperature,
#battery,
#custom-notification,
#custom-power {
  padding: 0 8px;
  margin: 4px 1px;
  border-radius: 8px;
}

#pulseaudio        { color: @magenta; }
#backlight         { color: @yellow; }
#network           { color: @green; }
#bluetooth         { color: @blue; }
#cpu               { color: @cyan; }
#memory            { color: @magenta; }
#temperature       { color: @orange; }
#battery           { color: @green; }
#custom-notification { color: @yellow; }
#idle_inhibitor    { color: @muted; }

#idle_inhibitor.activated {
  color: @bg;
  background-color: @yellow;
}

#pulseaudio.muted,
#network.disconnected,
#bluetooth.disabled {
  color: @muted;
}

#temperature.critical,
#battery.critical:not(.charging) {
  color: @bg;
  background-color: @red;
}

/* Waybar only animates a property when the rule differs between states, so
   the blink alternates against the .critical rule above. */
@keyframes blink {
  to {
    background-color: @bg;
    color: @red;
  }
}

#battery.critical:not(.charging) {
  animation-name: blink;
  animation-duration: 1s;
  animation-timing-function: steps(12);
  animation-iteration-count: infinite;
  animation-direction: alternate;
}

#battery.warning:not(.charging) {
  color: @orange;
}

#battery.charging,
#battery.plugged {
  color: @green;
}

#custom-power {
  color: @red;
  padding: 0 12px 0 8px;
}

#custom-power:hover {
  color: @bg;
  background-color: @red;
}

#tray > .passive {
  -gtk-icon-effect: dim;
}

#tray > .needs-attention {
  -gtk-icon-effect: highlight;
  background-color: @red;
  border-radius: 8px;
}

#privacy-item.screenshare { color: @orange; }
#privacy-item.audio-in    { color: @red; }

tooltip {
  background-color: @bg;
  border: 1px solid alpha(@blue, 0.4);
  border-radius: 8px;
}

tooltip label {
  color: @fg;
  padding: 4px;
}
```

## `waybar/scripts/mako-status.sh`  — `chmod +x`

```bash
#!/usr/bin/env bash
# Waybar custom module: notification count + do-not-disturb state.
set -uo pipefail

if ! command -v makoctl >/dev/null 2>&1; then
    printf '{"text":"","tooltip":"mako is not installed","class":"none"}\n'
    exit 0
fi

modes=$(makoctl mode 2>/dev/null || true)
count=$(makoctl list 2>/dev/null | grep -c '^Notification ' || true)
count=${count:-0}

if grep -qx 'do-not-disturb' <<<"$modes"; then
    printf '{"text":"","tooltip":"Do not disturb (%s waiting)","class":"dnd"}\n' "$count"
elif [ "$count" -gt 0 ]; then
    printf '{"text":" %s","tooltip":"%s notification(s)","class":"unread"}\n' "$count" "$count"
else
    printf '{"text":"","tooltip":"No notifications","class":"none"}\n'
fi
```

## `waybar/scripts/powermenu.sh`  — `chmod +x`

```bash
#!/usr/bin/env bash
# Power menu rendered with fuzzel's dmenu mode.
set -euo pipefail

choice=$(printf '%s\n' \
    " Lock" \
    " Suspend" \
    " Hibernate" \
    " Log out" \
    " Reboot" \
    " Shut down" \
    | fuzzel --dmenu --prompt="power: " --lines=6 --width=18)

case "$choice" in
    *Lock)      swaylock -f ;;
    *Suspend)   systemctl suspend ;;
    *Hibernate) systemctl hibernate ;;
    *"Log out") niri msg action quit --skip-confirmation ;;
    *Reboot)    systemctl reboot ;;
    *"Shut down") systemctl poweroff ;;
esac
```

## `mako/config`

```ini
# mako — notification daemon
# Reload after editing:  makoctl reload

sort=-time
layer=overlay
# Matches the niri layer-rule that blocks notifications from screen capture.
namespace=notifications
anchor=top-right
output=
max-visible=5

font=JetBrainsMono Nerd Font 10
background-color=#1a1b26ee
text-color=#c0caf5
border-color=#7aa2f7
progress-color=over #3d59a1

width=380
height=140
margin=10,14,0,0
padding=12
border-size=2
border-radius=10
icon-path=/usr/share/icons/Adwaita
max-icon-size=48
markup=1
actions=1
format=<b>%s</b>\n%b
default-timeout=6000
ignore-timeout=0

on-button-left=invoke-default-action
on-button-middle=dismiss-all
on-button-right=dismiss
on-touch=dismiss
# Needs `mpv` and `sound-theme-freedesktop`; uncomment for an audible ping.
#on-notify=exec mpv --no-config --really-quiet /usr/share/sounds/freedesktop/stereo/message.oga

[urgency=low]
border-color=#565f89
text-color=#a9b1d6
default-timeout=4000

[urgency=normal]
border-color=#7aa2f7

[urgency=critical]
border-color=#f7768e
text-color=#f7768e
default-timeout=0

[mode=do-not-disturb]
invisible=1

[app-name="Volume"]
group-by=app-name
default-timeout=1500
history=0
```

## `fuzzel/fuzzel.ini`

```ini
# fuzzel — application launcher

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
background=1a1b26f0
text=c0caf5ff
match=7dcfffff
selection=283457ff
selection-text=c0caf5ff
selection-match=7dcfffff
border=7aa2f7ff

[border]
width=2
radius=10

[dmenu]
exit-immediately-if-empty=yes

[key-bindings]
next=Down Control+n Tab
prev=Up Control+p ISO_Left_Tab
```

## `swaylock/config`

```ini
# swaylock — screen locker

ignore-empty-password
show-failed-attempts
daemonize
indicator-caps-lock
indicator-radius=100
indicator-thickness=8
font=JetBrainsMono Nerd Font
font-size=16

screenshots
effect-blur=8x5
effect-vignette=0.3:0.5
fade-in=0.2

color=1a1b26
inside-color=1a1b2600
inside-clear-color=e0af6833
inside-caps-lock-color=ff9e6433
inside-ver-color=7aa2f733
inside-wrong-color=f7768e33

ring-color=3b4261
ring-clear-color=e0af68
ring-caps-lock-color=ff9e64
ring-ver-color=7aa2f7
ring-wrong-color=f7768e

key-hl-color=9ece6a
bs-hl-color=f7768e
caps-lock-key-hl-color=9ece6a
caps-lock-bs-hl-color=f7768e

text-color=c0caf5
text-clear-color=1a1b26
text-caps-lock-color=ff9e64
text-ver-color=c0caf5
text-wrong-color=f7768e

separator-color=00000000
```

## `foot/foot.ini`

```ini
# foot — terminal emulator

font=JetBrainsMono Nerd Font:size=11
font-bold=JetBrainsMono Nerd Font:weight=bold:size=11
line-height=15
pad=10x10
dpi-aware=no
selection-target=clipboard

[scrollback]
lines=10000
multiplier=3.0

[cursor]
style=beam
blink=yes

[mouse]
hide-when-typing=yes

[colors]
alpha=0.95
background=1a1b26
foreground=c0caf5

regular0=15161e
regular1=f7768e
regular2=9ece6a
regular3=e0af68
regular4=7aa2f7
regular5=bb9af7
regular6=7dcfff
regular7=a9b1d6

bright0=414868
bright1=f7768e
bright2=9ece6a
bright3=e0af68
bright4=7aa2f7
bright5=bb9af7
bright6=7dcfff
bright7=c0caf5

selection-foreground=c0caf5
selection-background=283457
urls=7dcfff

[key-bindings]
clipboard-copy=Control+Shift+c XF86Copy
clipboard-paste=Control+Shift+v XF86Paste
search-start=Control+Shift+r
font-increase=Control+plus Control+equal
font-decrease=Control+minus
font-reset=Control+0
```
