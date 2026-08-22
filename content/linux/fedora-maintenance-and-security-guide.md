---
title: "fedora-maintenance-and-security-guide"
date: 2026-08-22T06:50:27Z
lastmod: 2026-08-22T06:50:27Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Fedora Maintenance & Security Guide

A practical routine for keeping a Fedora workstation (including COSMIC / greetd setups) updated, clean, and secure. Follow the **Weekly** tasks for day-to-day health and the **Monthly** tasks for deeper maintenance.

---

## Table of Contents

- 1. Before You Start
- 2. Weekly Tasks
  - 2.1 Refresh & Apply Package Updates
  - 2.2 Update Flatpaks
  - 2.3 Update Firmware (fwupd)
  - 2.4 Reboot If Needed
  - 2.5 Quick Health Check
- 3. Monthly Tasks
  - 3.1 Full Distro-Sync
  - 3.2 Clean Old Kernels
  - 3.3 Clean Package & Flatpak Cruft
  - 3.4 Audit Repositories (incl. COPR)
  - 3.5 Check Disk & Journal Usage
  - 3.6 Review Services & Boot
  - 3.7 Security Review
  - 3.8 Verify Display Manager / Greeter
- 4. Release Upgrades (Every ~6-12 Months)
  - 4.1 Post-Upgrade Cleanup
- 5. Btrfs Snapshots & Rollback (Timeshift / snapper)
  - 5.1 Check You're on Btrfs
  - 5.2 Option A — Timeshift (GUI + CLI, beginner-friendly)
  - 5.3 Option B — snapper (deeper integration, auto-snapshot on dnf)
  - 5.4 Booting Into / Rolling Back a Snapshot
  - 5.5 Maintenance Notes
- 6. Automating Updates
- 7. Quick Reference Cheat Sheet

---

## 1. Before You Start

- Run administrative commands with `sudo`.
- **Back up important data** before major operations (distro-sync, release upgrades, kernel cleanup).
- Read what a command wants to remove **before** confirming — especially anything using `--allowerasing` or `autoremove`.
- Commands below assume **DNF5** (Fedora 41+). Older `dnf` syntax is noted where it differs.

---

## 2. Weekly Tasks

### 2.1 Refresh & Apply Package Updates

Pull fresh metadata and apply all available updates:

```bash
sudo dnf upgrade --refresh
```

Review the transaction summary before confirming. To only *see* what would update without applying:

```bash
dnf check-upgrade
```

### 2.2 Update Flatpaks

If you use Flatpak apps (common on Fedora):

```bash
flatpak update
```

### 2.3 Update Firmware (fwupd)

Fedora ships `fwupd` for BIOS/firmware updates via LVFS:

```bash
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update
```

> Some firmware updates apply on the next reboot — follow the on-screen prompts.
> 

### 2.4 Reboot If Needed

Reboot if a new kernel, `systemd`, `glibc`, or firmware was installed:

```bash
sudo reboot
```

Check whether a reboot is recommended:

```bash
sudo dnf needs-restarting -r        # exit code 1 = reboot advised
```

### 2.5 Quick Health Check

Confirm nothing is failing after updates:

```bash
systemctl --failed                  # list failed units
journalctl -p 3 -b --no-pager       # priority>=err from current boot
```

---

## 3. Monthly Tasks

### 3.1 Full Distro-Sync

Reconcile every package to the exact versions in the enabled repos. This fixes partial-upgrade drift:

```bash
sudo dnf distro-sync
```

### 3.2 Clean Old Kernels

Fedora keeps a limited number of kernels (default 3). Verify and trim:

```bash
rpm -q kernel                       # list installed kernels
sudo dnf remove --oldinstallonly    # remove all but the protected latest kernels
```

To change how many are kept, set `installonly_limit` in `/etc/dnf/dnf.conf`.

### 3.3 Clean Package & Flatpak Cruft

```bash
sudo dnf autoremove                 # remove orphaned dependencies (review first!)
sudo dnf clean all                  # clear cached metadata/packages
flatpak uninstall --unused          # drop unused Flatpak runtimes
```

### 3.4 Audit Repositories (incl. COPR)

Third-party and COPR repos are the most common cause of broken upgrades:

```bash
dnf repolist                        # list enabled repos
dnf copr list                       # list enabled COPR repos
```

Disable any repo you no longer need:

```bash
sudo dnf copr disable <owner>/<project>
```

### 3.5 Check Disk & Journal Usage

```bash
df -h                               # filesystem usage
journalctl --disk-usage             # how much space logs consume
sudo journalctl --vacuum-time=2weeks   # trim logs older than 2 weeks
du -xh / --max-depth=1 2>/dev/null | sort -h   # find big directories
```

### 3.6 Review Services & Boot

```bash
systemctl list-unit-files --state=enabled   # what starts at boot
systemd-analyze blame                        # slowest units at startup
systemctl --failed                           # anything broken
```

### 3.7 Security Review

```bash
# Firewall status
sudo firewall-cmd --state
sudo firewall-cmd --list-all

# SELinux should be enforcing
getenforce
sudo ausearch -m avc -ts recent          # recent SELinux denials

# Check for available security errata specifically
dnf updateinfo list --security

# Review who has sudo / recent auth activity
journalctl _COMM=sudo --since "1 month ago" --no-pager | tail
lastlog | grep -v "Never logged in"
```

Apply only security updates if you want to prioritize them:

```bash
sudo dnf upgrade --security
```

### 3.8 Verify Display Manager / Greeter

Release updates and preset changes can silently reset the active display manager. Confirm the correct one is enabled (relevant for COSMIC/greetd setups):

```bash
systemctl list-unit-files | grep -i greet
ls -l /etc/systemd/system/display-manager.service
```

Only **one** display-manager service should be enabled, and `display-manager.service` should resolve to the greeter you actually want.

---

## 4. Release Upgrades (Every ~6-12 Months)

Fedora releases roughly twice a year; each release is supported ~13 months. Upgrade before your version goes end-of-life:

```bash
# 1. Fully update the current release first
sudo dnf upgrade --refresh
sudo reboot

# 2. Ensure the upgrade plugin is available
sudo dnf install dnf-plugin-system-upgrade

# 3. Download the new release (replace NN)
sudo dnf system-upgrade download --releasever=NN

# 4. Reboot into the offline upgrade
sudo dnf system-upgrade reboot

# 5. After it returns, reconcile
sudo dnf distro-sync
```

> Check that the target release is actually published before setting `--releasever`, and disable COPR/third-party repos that don't yet have builds for it.
> 

### 4.1 Post-Upgrade Cleanup

Release upgrades can pull in packages you didn't ask for and leave autostart entries behind. Review after each upgrade.

**`xwaylandvideobridge`** — a helper that lets **X11 apps screen-share Wayland content** (Discord, Zoom, Teams, OBS running under XWayland). It's often pulled in during upgrades and autostarts with the session; on COSMIC it can show up as a stray/empty window at login. It's harmless, but if you don't want it:

```bash
# Identify it
rpm -qi xwaylandvideobridge | head
ls /etc/xdg/autostart/ | grep -i bridge

# Option A — keep it, but stop the window from appearing at login
mkdir -p ~/.config/autostart
cp /etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop ~/.config/autostart/ 2>/dev/null
echo "Hidden=true" >> ~/.config/autostart/org.kde.xwaylandvideobridge.desktop

# Option B — remove it entirely (only if you don't screen-share from X11 apps)
sudo dnf remove xwaylandvideobridge
```

> Native Wayland apps use COSMIC's own portal (`xdg-desktop-portal-cosmic`) and don't need the bridge — keep it only if you screen-share from an X11 app.
> 

**General post-upgrade checks:**

```bash
sudo dnf autoremove                     # drop orphaned deps the upgrade left behind
ls /etc/xdg/autostart/                  # review what autostarts at login
sudo dnf distro-sync                    # reconcile any version stragglers
```

---

## 5. Btrfs Snapshots & Rollback (Timeshift / snapper)

Fedora's default filesystem is **Btrfs**, which supports instant, space-efficient snapshots. Take a snapshot **before every upgrade** so you can roll back if something breaks. Pick **one** tool — Timeshift or snapper — don't run both against the same subvolumes.

### 5.1 Check You're on Btrfs

```bash
findmnt -no FSTYPE /            # should print: btrfs
sudo btrfs subvolume list /     # list existing subvolumes
```

> Fedora's default layout uses `root` and `home` subvolumes. Snapshotting `root` (the system) while leaving `home` (your data) separate is the usual, safest setup.
> 

### 5.2 Option A — Timeshift (GUI + CLI, beginner-friendly)

Install and pick the **BTRFS** mode (not RSYNC) during setup:

```bash
sudo dnf install timeshift
sudo timeshift-gtk               # GUI: choose "BTRFS" type, select the disk
```

Common CLI operations:

```bash
sudo timeshift --create --comments "before F44 upgrade" --tags D   # manual snapshot
sudo timeshift --list                                              # list snapshots
sudo timeshift --restore --snapshot '2026-08-21_10-00-01'          # restore a snapshot
sudo timeshift --delete --snapshot '2026-08-21_10-00-01'           # delete one
```

Timeshift can auto-schedule daily/weekly/monthly snapshots and auto-prune old ones from its GUI settings.

### 5.3 Option B — snapper (deeper integration, auto-snapshot on dnf)

`snapper` pairs with `dnf` so a snapshot is taken automatically **before and after every transaction**:

```bash
sudo dnf install snapper python3-dnf-plugin-snapper

# Create configs for the subvolumes you want to protect
sudo snapper -c root create-config /
```

Manual and automatic use:

```bash
sudo snapper -c root create --description "before upgrade"   # manual snapshot
sudo snapper -c root list                                     # list snapshots
sudo snapper -c root status 40..41                            # diff two snapshots
sudo snapper -c root undochange 40..41                        # revert file changes
sudo snapper -c root delete 40                                # delete a snapshot
```

With the dnf plugin installed, every `dnf upgrade`/`install` transaction is bracketed by pre/post snapshots automatically — no extra step needed.

### 5.4 Booting Into / Rolling Back a Snapshot

- **Timeshift:** boot a working system (or a live USB if unbootable), run `sudo timeshift --restore`, and select the snapshot. It swaps the default subvolume and updates the bootloader.
- **snapper:** you can roll back the running system's default subvolume, or browse read-only snapshots under `/.snapshots/`. For boot-time selection, pair snapper with `grub-btrfs`:

```bash
sudo dnf install grub-btrfs
sudo systemctl enable --now grub-btrfsd
```

`grub-btrfs` adds a GRUB submenu listing your Btrfs snapshots so you can boot directly into one after a bad update.

### 5.5 Maintenance Notes

- Snapshots are **not backups** — they live on the same disk. Keep separate off-device backups of `/home`.
- Prune old snapshots periodically so they don't consume space:
```bash
sudo btrfs filesystem usage /       # check space
# Timeshift/snapper auto-prune per their retention settings
```
- After heavy snapshot churn, a periodic balance can reclaim space:
```bash
sudo btrfs balance start -dusage=50 /
```

---

## 6. Automating Updates

For hands-off security patching, enable `dnf-automatic`:

```bash
sudo dnf install dnf-automatic
```

Edit `/etc/dnf/automatic.conf`:

- `apply_updates = yes` — actually install (set `no` to only download/notify)
- `upgrade_type = security` — restrict to security errata (or `default` for all)

Enable the timer:

```bash
sudo systemctl enable --now dnf-automatic.timer
systemctl list-timers dnf-automatic.timer
```

> Even with automation, still perform the **monthly** manual review — automation handles patches, not cleanup, repo audits, or reboots.
> 

---

## 7. Quick Reference Cheat Sheet

| Frequency | Command | Purpose |
| --- | --- | --- |
| Weekly | `sudo dnf upgrade --refresh` | Apply all package updates |
| Weekly | `flatpak update` | Update Flatpak apps |
| Weekly | `sudo fwupdmgr refresh && sudo fwupdmgr update` | Firmware updates |
| Weekly | `sudo dnf needs-restarting -r` | Check if reboot needed |
| Weekly | `systemctl --failed` | Spot broken services |
| Monthly | `sudo dnf distro-sync` | Reconcile package versions |
| Monthly | `sudo dnf remove --oldinstallonly` | Remove old kernels |
| Monthly | `sudo dnf autoremove` | Remove orphaned deps |
| Monthly | `sudo dnf clean all` | Clear caches |
| Monthly | `dnf updateinfo list --security` | List security errata |
| Monthly | `sudo journalctl --vacuum-time=2weeks` | Trim logs |
| Monthly | `getenforce` / `firewall-cmd --state` | Security posture |
| Before upgrades | `sudo timeshift --create --comments "pre-upgrade"` | Btrfs snapshot (Timeshift) |
| Before upgrades | `sudo snapper -c root create -d "pre-upgrade"` | Btrfs snapshot (snapper) |
| ~6-12 mo | `sudo dnf system-upgrade download --releasever=NN` | Release upgrade |

---

*Tip: keep this guide handy and tick through the weekly list every Friday and the monthly list on the first of the month.*
