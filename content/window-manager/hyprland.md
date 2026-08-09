---
title: "hyprland"
date: 2026-08-09T21:56:22Z
lastmod: 2026-08-09T21:56:22Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

## Hyprland Family Apps

**Arch - One Liner (Official Repo)**
```bash
sudo pacman -S hyprland hyprpaper hyprlock hypridle hyprpicker xdg-desktop-portal-hyprland hyprsunset hyprpolkitagent hyprland-qt-support hyprqt6engine
```

**Arch - One Liner (AUR)**
```bash
yay -S hypyland-git hypaper hyprlock-git xdg-desktop-portal-hyprland-git hyprpolkitagent-git hyprsysteminfo-git hyprland-qt-support-git hyprcursor-git
```
### Non essential but cool tools/apps 
A list of applications that make **hyprland** more appealing/provides more functionality
- [**SwayOSD**](https://github.com/ErikReider/SwayOSD) - A GTK based on screen display for keyboard shortcuts like caps-lock and volume
- 
### Hyprlock
Simple, yet fast, multi-threaded and GPU-accelerated screen lock for hyprland

Installation From Package Managers
```bash
sudo pacman -S hyprlock # Arch
# Create a config at ~/.config/hypr/hyprlock.conf
```
For more detailed information visit the [Wiki Page](https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/)
### Hyprpaper
Fast, IPC-controlled wallpaper utility for Hyprland
### Installation From Package Managers
```bash
sudo pacman -S hyprpaper # Arch
# Create config at ~/.config/hypr/hypaper.conf
```
For more detailed information visit the [Wiki Page](https://wiki.hyprland.org/Hypr-Ecosystem/hyprpaper/)

### XDG-desktop-portal-hyprland
Hyprland's xdg-desktop-portal implementation. It allows for screensharing, global shortcuts, etc.

Installation From Package Managers
```bash
sudo pacman -S xdg-desktop-portal-hyprland # Arch
# Create config at ~/.config/hypr/xdph.conf
```
For more detailed information visit the [Wiki Page](https://wiki.hyprland.org/Hypr-Ecosystem/xdg-desktop-portal-hyprland/)

### Hyprsome
Hyprsome is a binary that interacts with Hyprland's Unix socket to make workspaces behave similarly to AwesomeWM in a multi-monitor setup
### Installation
```bash

```

### Hyprpm
Plugin manager for **Hyprland** this is the official one and the only one I should trust
### Installation
```bash
sudo pacman -S cpio meson cmake hyprwayland-scanner # Install all of these first

hyprpm update # You must run this command after installing all needed dependencies

hyprpm add https://github.com/hyprwm/hyprland-plugins # This add the plugins repo
```
For more information [Source](https://wiki.hyprland.org/Plugins/Using-Plugins/#hyprpm)

### Popular plugins

### Useful Applications
- **Network Manager Applet** - App indicator that launches wifi window menu picker
	- `sudo pacman -S network-manager-applet`
	- To initialize make sure that `exec-once nm-applet` is added on `hyprland` config
- **wl-clipboard** - Simple copy/paste tool for wayland
	- This is required for **Neovim** clipboard **yank** and **hyprpicker** to work fine
	- `sudo pacman -S wl-clipboard`
- 
### Possible Issues/Solutions
Session keeps asking for WiFi password
1. If running *KDE alongside Hyprland* disable **KDE Wallet**
2. Install **Gnome-keyring** and create a password for it to store passwords securely
	1. `sudo pacman -S gnome-keyring`
	2. When it start it will ask you to set up a password for it

## Independent Installation/Configurations
### Lenovo Idepad Pro 5



## Essential Packages

Enables **Intel Hardware Acceleration**
```bash
sudo pacman intel-media-driver
```

### Taking Screenshot
1. Install its dependencies
	`sudo pacman -S hyprpicker slurp grim wl-clipboard`
2. Download and give *execute* access to *grimblast* [Download from here](https://github.com/hyprwm/contrib)
3. Add the following lines to *hyprland.conf* to create shortcuts
```bash
# Screenshot
bind = $mainMod, S, exec, grimblast save screen
bind = $mainMod SHIFT, S, exec, grimblast save area
```

### Setting up windowrules (in case an app glitches such as *wofi*)
1. within the *~/.config/hypr/rules.conf* add the following
```bash
# Ignore animation for Wofi
windowrule = noanim, class:^(wofi)$

```


### Hyprland plugins
[Split-monitor-workspaces](https://github.com/Duckonaut/split-monitor-workspaces) - A small plugin to provide *awesome/dwm* like behavior with workspaces
	Installation
	`hyprpm add https://github.com/Duckonaut/split-monitor-workspaces # Add the plugin repository`
	`hyprpm enable split-monitor-workspaces # Enable the plugin`
	`hyprpm reload # Reload the plugins`

[Hyprsplit](https://github.com/shezdy/hyprsplit) - Awesome / dwm like workspaces for hyprland ***Note: this is a fork of Spli-Monitor-Workspaces***
	Installation
	`hyprpm update`
	`hyprpm add https://github.com/shezdy/hyprsplit`
	`hyprpm enable hyprsplit`

### Backend Miscs
[Brightnessctl](https://archlinux.org/packages/extra/x86_64/brightnessctl/) - Lightweight brightness control tool
	Installation
	`sudo pacman -S brightnessctl`
[Gnome-Keyring](https://wiki.archlinux.org/title/GNOME/Keyring) - It helps storing secrets, passwords
	Installation
	`sudo pacman -S gnome-keyring`
### Global Installation
This provides vanilla settings, and most likely everything might work out of the box, if not. You will need to tweak a bit `Hyprland` config to fit your device, all devices have different driver and hardware. This config is my personal starting point

### Keybindings
| **Keys**         | **Action**                         |
| ---------------- | ---------------------------------- |
| Meta+Q           | Close Window                       |
| Meta+Enter       | Kitty                              |
| Meta+Shift+Enter | Alacritty                          |
| Meta+Shift+R     | Hyprland Reload                    |
| Meta+Tab         | Move Active Window To Next Monitor |
|                  |                                    |

