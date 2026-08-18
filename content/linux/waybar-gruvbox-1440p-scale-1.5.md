---
title: "waybar-gruvbox-1440p-scale-1.5"
date: 2026-08-18T03:23:06Z
lastmod: 2026-08-18T03:23:06Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# 🖥️ Waybar Config — Gruvbox Dark Hard

> ### ⚠️ Optimized for a **2560 × 1440 (1440p) display @ compositor scale 1.5**
> 
> This configuration is **tuned for 1440p running at niri output `scale 1.5`**.
> **Important:** at scale 1.5 the compositor multiplies every *logical* pixel by
> 1.5 before drawing, so the values here are deliberately kept **small** — a
> `font-size: 11px` logical renders ≈ 16px physical. Do **not** manually inflate
> sizes on top of a 1.5 scale, or the bar will look oversized. Set `scale 1.5` on
> the output in your niri `config.kdl` (this file only controls waybar itself).
> 

---

## 📑 Table of Contents

1. [Overview](https://metamate.internalmeta.com/#-overview)
2. [File 1 — `config` (jsonc)](https://metamate.internalmeta.com/#-file-1--configjsonc)
3. [File 2 — `style.css`](https://metamate.internalmeta.com/#-file-2--stylecss)
4. [Installation](https://metamate.internalmeta.com/#-installation)
5. [Scaling to Other Resolutions](https://metamate.internalmeta.com/#-scaling-to-other-resolutions)
6. [Notes & Tips](https://metamate.internalmeta.com/#-notes--tips)

---

## 📌 Overview

| Property | Value |
| --- | --- |
| **Theme** | Gruvbox Dark Hard |
| **Target display** | **2560 × 1440 (1440p) @ compositor scale 1.5** ✅ |
| **Base font size** | `11px` logical → ≈16px physical after ×1.5 |
| **Bar height** | Font-driven (no fixed `height`) |
| **Compositor** | niri (`niri/workspaces`, `niri/window`) |
| **Font** | JetBrainsMono Nerd Font |

---

## 📄 File 1 — `~/.config/waybar/config` (jsonc)

```jsonc
{
  "layer": "top",
  "position": "top",
  // Height removed intentionally: style.css is font-driven (min-height: 0),
  // so the bar sizes itself from font-size. Re-add "height" only if you want
  // a hard-pinned bar height.
  // At scale 1.5 niri multiplies these logical px by 1.5, so keep them
  // modest here -- do NOT pre-inflate them.
  "spacing": 4,
  "margin-top": 4,
  "margin-left": 8,
  "margin-right": 8,

  "modules-left": [
    "niri/workspaces",
    "niri/window"
  ],
  "modules-center": [
    "clock"
  ],
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
    "custom/powerprofile",
    "custom/notification",
    "custom/power"
  ],

  "niri/workspaces": {
    "format": "{index}",
    "on-click": "activate"
  },

  "niri/window": {
    "format": "{app_id}",
    "max-length": 24,
    "separate-outputs": true
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
        "months":   "<span color='#ebdbb2'><b>{}</b></span>",
        "days":     "<span color='#d5c4a1'>{}</span>",
        "weeks":    "<span color='#8ec07c'><b>W{}</b></span>",
        "weekdays": "<span color='#fabd2f'><b>{}</b></span>",
        "today":    "<span color='#fb4934'><b><u>{}</u></b></span>"
      }
    },
    "actions": {
      "on-click-right": "mode",
      "on-scroll-up": "shift_up",
      "on-scroll-down": "shift_down"
    }
  },

  "tray": {
    "icon-size": 12,
    "spacing": 6
  },

  "privacy": {
    "icon-size": 10,
    "transition-duration": 250,
    "modules": [
      { "type": "screenshare", "tooltip": true },
      { "type": "audio-in", "tooltip": true }
    ]
  },

  "idle_inhibitor": {
    "format": "{icon}",
    "format-icons": {
      "activated": "\uf06e",
      "deactivated": "\uf070"
    },
    "tooltip-format-activated": "Idle inhibited \u2014 screen stays awake",
    "tooltip-format-deactivated": "Idle inhibitor off"
  },

  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": "\ufc5d muted",
    "format-bluetooth": " {icon} {volume}%",
    "format-bluetooth-muted": " \ufc5d muted",
    "format-icons": {
      "headphone": "\uf025",
      "hands-free": "\uf590",
      "headset": "\uf590",
      "phone": "\uf095",
      "portable": "\uf10b",
      "car": "\uf1b9",
      "default": ["\uf026", "\uf027", "\uf028"]
    },
    "scroll-step": 5,
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "on-click-right": "pavucontrol",
    "tooltip-format": "{desc} \u2014 {volume}%"
  },

  "backlight": {
    "format": "{icon} {percent}%",
    "format-icons": ["\uf185", "\uf185", "\uf185", "\uf185", "\uf185", "\uf185", "\uf185", "\uf185", "\uf185"],
    "on-scroll-up": "brightnessctl --class=backlight set +5%",
    "on-scroll-down": "brightnessctl --class=backlight set 5%-",
    "tooltip": false
  },

  "network": {
    "format-wifi": "\uf1eb  {signalStrength}%",
    "format-ethernet": "\uf0e8  Connected",
    "format-linked": "\uf0e8  Linked",
    "format-disconnected": "\u2717 Disconnected",
    "tooltip-format-wifi": "{essid} ({signalStrength}%)\n{ipaddr}/{cidr}\n {bandwidthUpBits}  {bandwidthDownBits}",
    "tooltip-format-ethernet": "{ifname}\n{ipaddr}/{cidr}\n {bandwidthUpBits}  {bandwidthDownBits}",
    "tooltip-format-disconnected": "Disconnected",
    "on-click": "foot -e nmtui"
  },

  "bluetooth": {
    "format": "\uf293 {num_connections}",
    "format-disabled": "\uf294 Off",
    "format-connected": "\uf293 {num_connections}",
    "tooltip-format": "{controller_alias}\t{controller_address}",
    "tooltip-format-connected": "{controller_alias}\n{device_enumerate}",
    "tooltip-format-enumerate-connected": "{device_alias}\t{device_address}",
    "on-click": "blueman-manager"
  },

  "cpu": {
    "interval": 3,
    "format": "\uf2db  {usage}%",
    "on-click": "foot -e btop"
  },

  "memory": {
    "interval": 5,
    "format": "\uf538  {percentage}%",
    "tooltip-format": "{used:0.1f}G / {total:0.1f}G  (swap {swapUsed:0.1f}G)",
    "on-click": "foot -e btop"
  },

  "temperature": {
    "interval": 5,
    "critical-threshold": 82,
    "format": "{icon}",
    "format-critical": " \ud83c\udf21 {temperatureC}\u00b0C",
    "format-icons": ["\uf2cb", "\uf2c9", "\uf2c7"],
    "tooltip-format": "{temperatureC}\u00b0C"
  },

  "battery": {
    "interval": 10,
    "states": { "warning": 25, "critical": 12 },
    "format": "{icon} {capacity}%",
    "format-charging": "\uf0e7  {capacity}%",
    "format-plugged": "\uf1e6  {capacity}%",
    "format-full": "\uf240  {capacity}%",
    "format-icons": ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"],
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

  "custom/powerprofile": {
    "exec": "~/.config/waybar/scripts/powerprofile.sh",
    "return-type": "json",
    "interval": 5,
    "on-click": "~/.config/waybar/scripts/powerprofile.sh toggle",
    "tooltip": true
  },

  "custom/power": {
    "format": "\uf011",
    "tooltip-format": "Power menu",
    "on-click": "~/.config/waybar/scripts/powermenu.sh"
  }
}
```

---

## 🎨 File 2 — `~/.config/waybar/style.css`

> 💡 **Scale-1.5 note:** the `font-size: 11px` in the `*` block below is *logical* —
> niri upscales it ×1.5 to ≈16px physical. It is the single knob for the bar's
> scale; everything else uses `em` units and `min-height: 0` and follows it.
> 

```css
/* Waybar — Gruvbox Dark Hard
 *
 * Tuned for 2560x1440 at compositor scale 1.5. niri multiplies every logical
 * pixel by 1.5, so use a MODEST logical font here -- it is upscaled by the
 * compositor: 11px logical renders ~16px physical. Do not inflate it manually.
 */

@define-color bg        #1d2021;
@define-color bg1       #3c3836;
@define-color bg2       #504945;
@define-color fg        #ebdbb2;
@define-color muted     #928374;
@define-color red       #fb4934;
@define-color green     #b8bb26;
@define-color yellow    #fabd2f;
@define-color blue      #83a598;
@define-color purple    #d3869b;
@define-color aqua      #8ec07c;
@define-color orange    #fe8019;

* {
  font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
  font-size: 11px;
  font-weight: 500;
  border: none;
  border-radius: 0;
  /* Let each widget claim only what its font needs -- combined with no fixed
     bar height, this is what makes the bar scale with font-size. */
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
  background-color: alpha(@bg, 0.92);
  border: 1px solid @bg2;
  border-radius: 8px;
  padding: 0 0.25em;
}

#workspaces {
  padding: 0 0.15em;
}

#workspaces button {
  color: @muted;
  /* em padding so the pill grows with the font rather than staying 6px. */
  padding: 0.15em 0.5em;
  margin: 0.25em 0.08em;
  border-radius: 6px;
  background: transparent;
  transition: all 200ms ease;
}

#workspaces button:hover {
  color: @fg;
  background-color: @bg1;
}

#workspaces button.active {
  color: @bg;
  background-color: @orange;
  padding: 0.15em 0.9em;
}

#workspaces button.urgent {
  color: @bg;
  background-color: @red;
}

#window {
  color: @fg;
  padding: 0 0.6em;
}

window#waybar.empty #window {
  background: transparent;
  border: none;
}

#clock {
  color: @yellow;
  font-weight: 700;
  padding: 0 0.9em;
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
#custom-powerprofile,
#custom-power {
  padding: 0.2em 0.55em;
  margin: 0.25em 0.08em;
  border-radius: 6px;
}

#pulseaudio        { color: @purple; }
#backlight         { color: @yellow; }
#network           { color: @green; }
#bluetooth         { color: @blue; }
#cpu               { color: @aqua; }
#memory            { color: @purple; }
#temperature       { color: @orange; }
#battery           { color: @green; }
#custom-notification { color: @yellow; }
#idle_inhibitor    { color: @muted; }
#custom-powerprofile             { color: @green; }
#custom-powerprofile.balanced    { color: @yellow; }
#custom-powerprofile.performance { color: @red; }

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
  padding: 0.2em 0.7em 0.2em 0.55em;
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
  border-radius: 6px;
}

#privacy-item.screenshare { color: @orange; }
#privacy-item.audio-in    { color: @red; }

tooltip {
  background-color: @bg;
  border: 1px solid @bg2;
  border-radius: 6px;
}

tooltip label {
  color: @fg;
  padding: 0.25em;
}
```

---

## 🚀 Installation

```bash
# Save both files:
#   ~/.config/waybar/config
#   ~/.config/waybar/style.css

# Reload waybar to apply changes:
killall -SIGUSR2 waybar
# ...or restart it:
killall waybar && waybar &
```

---

## 📐 Scaling to Other Resolutions

**This config targets 1440p at compositor `scale 1.5`.** The *logical* font-size
you set is what matters — niri multiplies it by the output scale. Pick the logical
`font-size` from the scale you run:

| Display | Compositor scale | Recommended *logical* `font-size` | ≈ physical |
| --- | --- | --- | --- |
| 1440p | 1.0 | `14px` | 14px |
| **1440p** ✅ (this config) | **1.5** | **`11px`** | **≈16px** |
| 1440p | 2.0 | `~8–9px` | ≈16–18px |

Set the matching `scale` on the `output` block in your niri `config.kdl`; waybar
picks up the compositor scale automatically. Because the bar has **no fixed
`height`** and uses `em`-based padding, the logical `font-size` rescales it all.

---

## 🔋 Power Profile Toggle (`power-profiles-daemon`)

A click-to-cycle module that switches the laptop between **power-saver → balanced →
performance** using `powerprofilesctl`. It shows a Nerd Font icon per state
( saver ·  balanced ·  performance) and colors itself green /
yellow / red.

> Requires the `power-profiles-daemon` package (provides `powerprofilesctl`).
> 

**Script — `~/.config/waybar/scripts/powerprofile.sh`** (make it executable: `chmod +x`):

```sh
#!/bin/sh
# powerprofile.sh — waybar module + toggle for power-profiles-daemon
# Usage:
#   powerprofile.sh          -> print JSON status for waybar
#   powerprofile.sh toggle   -> cycle power-saver -> balanced -> performance

cur=$(powerprofilesctl get 2>/dev/null)

if [ "$1" = "toggle" ]; then
  case "$cur" in
    power-saver) next=balanced ;;
    balanced)    next=performance ;;
    performance) next=power-saver ;;
    *)           next=balanced ;;
  esac
  powerprofilesctl set "$next" 2>/dev/null
  exit 0
fi

case "$cur" in
  power-saver) icon=""; cls=power-saver ;;
  balanced)    icon="";  cls=balanced ;;
  performance) icon=""; cls=performance ;;
  *)           icon="";  cls=balanced ;;
esac

printf '{"text":"%s","class":"%s","tooltip":"Power profile: %s (click to cycle)"}\n' "$icon" "$cls" "${cur:-unknown}"
```

**Cycle from the keyboard — niri `config.kdl`:**

```kdl
Mod+P hotkey-overlay-title="Cycle Power Profile" {
    spawn "/bin/sh" "-c" "~/.config/waybar/scripts/powerprofile.sh toggle";
}
```

Press `Mod+P` to advance **power-saver → balanced → performance** (same action as
clicking the bar module).

---

## 📝 Notes & Tips

- **Focused-app display:** `niri/window` uses `{app_id}`. If you see reverse-DNS names
(e.g. `org.mozilla.firefox`) and prefer clean labels, add a `rewrite` map to the
`niri/window` module, or switch `{app_id}` → `{title}` for the full window title.
- **Scale-1.5 tuning:** because niri upscales ×1.5, the JSON uses *smaller* logical
values — `tray.icon-size: 12`, `privacy.icon-size: 10`, `spacing: 4`, margins `8` —
which the compositor enlarges to match the text. Also set `scale 1.5` on the
output in niri `config.kdl`, e.g. `output "DP-1" { mode "2560x1440@..."; scale 1.5 }`.
- **Fonts:** requires **JetBrainsMono Nerd Font** for the glyph icons to render.
- **Scripts:** `custom/notification` and `custom/power` expect
`~/.config/waybar/scripts/mako-status.sh` and `powermenu.sh` to exist and be executable.
