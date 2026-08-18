---
title: "waybar-gruvbox-1080p"
date: 2026-08-18T03:00:20Z
lastmod: 2026-08-18T03:00:20Z
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

> ### ⚠️ Optimized for a **1920 × 1080 (1080p) display @ scale 1.0**
> 
> This configuration is **tuned specifically for 1080p**. All sizing derives from a
> single `font-size: 12px` with em-based padding, so the bar scales cleanly at that
> resolution. On higher-DPI panels you only need to change one value (see
> **[Scaling to Other Resolutions](https://metamate.internalmeta.com/#-scaling-to-other-resolutions)** below).
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
| **Target display** | **1920 × 1080 (1080p), scale 1.0** ✅ |
| **Base font size** | `12px` (drives the whole bar's scale) |
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
    "icon-size": 15,
    "spacing": 6
  },

  "privacy": {
    "icon-size": 13,
    "transition-duration": 250,
    "modules": [
      { "type": "screenshare", "tooltip": true },
      { "type": "audio-in", "tooltip": true }
    ]
  },

  "idle_inhibitor": {
    "format": "{icon}",
    "format-icons": {
      "activated": "\u25d0",
      "deactivated": "\u25cb"
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
    "tooltip-format": "{desc} \u2014 {volume}%"
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
    "format-ethernet": "  Connected",
    "format-linked": "  Linked",
    "format-disconnected": "\u2717 Disconnected",
    "tooltip-format-wifi": "{essid} ({signalStrength}%)\n{ipaddr}/{cidr}\n {bandwidthUpBits}  {bandwidthDownBits}",
    "tooltip-format-ethernet": "{ifname}\n{ipaddr}/{cidr}\n {bandwidthUpBits}  {bandwidthDownBits}",
    "tooltip-format-disconnected": "Disconnected",
    "on-click": "foot -e nmtui"
  },

  "bluetooth": {
    "format": " {num_connections}",
    "format-disabled": " Off",
    "format-connected": " {num_connections}",
    "tooltip-format": "{controller_alias}\t{controller_address}",
    "tooltip-format-connected": "{controller_alias}\n{device_enumerate}",
    "tooltip-format-enumerate-connected": "{device_alias}\t{device_address}",
    "on-click": "blueman-manager"
  },

  "cpu": {
    "interval": 3,
    "format": "  {usage}%",
    "on-click": "foot -e btop"
  },

  "memory": {
    "interval": 5,
    "format": "  {percentage}%",
    "tooltip-format": "{used:0.1f}G / {total:0.1f}G  (swap {swapUsed:0.1f}G)",
    "on-click": "foot -e btop"
  },

  "temperature": {
    "interval": 5,
    "critical-threshold": 82,
    "format": "{icon}",
    "format-critical": " \ud83c\udf21 {temperatureC}\u00b0C",
    "format-icons": ["", "", ""],
    "tooltip-format": "{temperatureC}\u00b0C"
  },

  "battery": {
    "interval": 10,
    "states": { "warning": 25, "critical": 12 },
    "format": "{icon} {capacity}%",
    "format-charging": "  {capacity}%",
    "format-plugged": "  {capacity}%",
    "format-full": "  {capacity}%",
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
    "format": "  ",
    "tooltip-format": "Power menu",
    "on-click": "~/.config/waybar/scripts/powermenu.sh"
  }
}
```

---

## 🎨 File 2 — `~/.config/waybar/style.css`

> 💡 **1080p note:** the `font-size: 12px` in the `*` block below is the single knob
> that sets the whole bar's scale for 1080p. Everything else uses `em` units and
> `min-height: 0`, so it grows/shrinks proportionally from that one value.
> 

```css
/* Waybar — Gruvbox Dark Hard
 *
 * Tuned for 1920x1080 @ scale 1.0. Everything derives from the font-size and
 * the em-based padding below, so changing font-size alone rescales the bar:
 * 12px suits 1080p, ~14px suits 1440p, ~16px suits 4K at scale 1.
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
  font-size: 12px;
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

**This config is built for 1080p.** To move to another panel, change **only** the
`font-size` in the `*` block of `style.css`:

| Display | Resolution | Recommended `font-size` |
| --- | --- | --- |
| **1080p** ✅ (this config) | 1920 × 1080 @ scale 1.0 | **`12px`** |
| 1440p | 2560 × 1440 @ scale 1.0 | `~14px` |
| 4K | 3840 × 2160 @ scale 1.0 | `~16px` |

Because the bar has **no fixed `height`** and uses `em`-based padding, adjusting that
one value rescales the entire bar proportionally.

---

## 📝 Notes & Tips

- **Focused-app display:** `niri/window` uses `{app_id}`. If you see reverse-DNS names
(e.g. `org.mozilla.firefox`) and prefer clean labels, add a `rewrite` map to the
`niri/window` module, or switch `{app_id}` → `{title}` for the full window title.
- **Fonts:** requires **JetBrainsMono Nerd Font** for the glyph icons to render.
- **Scripts:** `custom/notification` and `custom/power` expect
`~/.config/waybar/scripts/mako-status.sh` and `powermenu.sh` to exist and be executable.
