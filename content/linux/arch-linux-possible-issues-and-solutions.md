---
title: "Arch Linux Possible Issues and Solutions"
date: 2026-08-09T00:51:06-07:00
lastmod: 2026-08-09T00:51:06-07:00
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

## Network Related Related Test
### Wireguard Tools
Follow the **tldr** solution below
**Issue:** 
`resolv: command not fount`
#### TLDR
**Solution:** 
`sudo pacman -S systemd-resolvconf && sudo systemctl enable --now systemd-resolved`

First you need to install the actual package `sudo pacman -S wireguard-tools`
The issue resides when trying to connect, you might get an error that says `resolv: command not found` 
Fix: install `systemd-resolv` package 
```bash
sudo pacman -S systemd-resolvconf

#Enable the systemd-resolved service
sudo systemctl enable --now systemd-resolved
```
### Fonts No Loading/Showing
**Issue:**  
fonts are not showing up when running `fc-list | grep "Font_Name"`
#### TLDR
**Solution:**
Run `fc-cache --force` if `fc-cache` does not work

### Tuta Email Client/Apps Storing Keys
**Issue:**
Tuta is unable to store encryption key on **Arch** systems that do not have **Gnome-Keyring** installed
#### TLDR
**Solution:**
Install [**Gnome-Keyring**](https://archlinux.org/packages/?sort=&q=gnome-keyring&maintainer=&flagged=) `sudo pacman -S gnome-keyring`

### Neovim Stylua Failing to install
**Issue:**
Installing Neovim Kickoff, Stylua fails to install
#### TLDR
**Solution:**
Install **Unzip** `sudo pacman -S unzip`

### Disable Nouveau Drivers
#### TLDR
**Solution:**
`sudo nvim /etc/modprobe.d/blacklist.conf` 
and paste the following `module_blacklist=nouveau`
last, run `sudo mkinitcpio -P`
Make sure you reboot the laptop

### 
Mount User Permission
**Issue:**
When mounting a drive using `veracrypt` the folder and its content is owned by `root`
**Solution:**
Edit the mounted folder permissions to be owned by `localuser` the location of the mounted drive usually resides in `/run/media/veracrypt#`
```bash
sudo chown -R $USER:$USER /run/media/mountpoint_label
```


