---
title: "immich-lan-only-install-guide"
date: 2026-08-16T06:49:13Z
lastmod: 2026-08-16T06:49:13Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Immich on Debian 13 — Complete LAN-Only Self-Hosting Guide

A start-to-finish guide for running **Immich** (self-hosted photo & video backup, a private
alternative to Google Photos) on a **Debian 13** host, **LAN-only** (no reverse proxy, no
port-forwarding), with photos stored on a dedicated **SSD mounted at `/mnt/pics`**.

Includes host prerequisites, Docker install, storage configuration, permissions, a
**mount-guard** so Immich never writes to the wrong disk, security hardening, and backups.

---

## 0. Overview & architecture

Immich runs as **several coordinated Docker services**:

| Service | Role |
| --- | --- |
| `immich-server` | Web/API server + the app you interact with |
| `immich-machine-learning` | Facial recognition, smart search, object detection |
| `database` | PostgreSQL with a vector extension (stores albums, metadata, faces, users) |
| `redis` | Cache / job queue |

Docker Compose is the **officially recommended and supported** method — the ML and database
components have specific version requirements that are painful to satisfy manually.

**This setup:**

- Debian 13 host (a VM with a USB3 SSD passed through, ext4, mounted at `/mnt/pics`)
- Photos + library stored on the SSD via `UPLOAD_LOCATION=/mnt/pics`
- Reachable only on the LAN at `http://<server-ip>:2283`

> ⚠️ Immich evolves quickly — **read the release notes before every update**, and keep backups.
> 

---

## 1. Host prerequisites (Debian 13)

### 1.1 System requirements

| Requirement | Detail |
| --- | --- |
| **RAM** | 4 GB minimum; **6 GB+ recommended** (ML is memory-hungry) |
| **Storage** | Enough for your library + database + thumbnails/transcodes |
| **Filesystem** | Photos disk **must be a native Linux FS** (ext4/xfs/btrfs). **Not** exFAT/NTFS — Immich + Postgres need real permissions and hardlinks |

### 1.2 Update the base system

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.3 Confirm the SSD is mounted and on ext4

```bash
# Is it mounted?
mountpoint /mnt/pics            # -> "/mnt/pics is a mountpoint"

# What filesystem? (want ext4/xfs/btrfs, NOT exfat/ntfs/vfat)
df -Th /mnt/pics
lsblk -f
```

Make the mount persistent and boot-safe in `/etc/fstab` (use `nofail` so a missing SSD
doesn't hang boot):

```
UUID=<your-uuid>  /mnt/pics  ext4  defaults,nofail,x-systemd.device-timeout=10  0  2
```

Test the fstab entry **before** rebooting:

```bash
sudo mount -a        # should mount cleanly with no errors
```

---

## 2. Install Docker Engine + Compose

```bash
# Official convenience script (installs Engine + Compose V2 plugin)
curl -fsSL https://get.docker.com | sudo sh

# Run docker without sudo (log out/in afterward to apply group change)
sudo usermod -aG docker $USER

# Verify — you want Compose V2 (`docker compose`, with a space)
docker --version
docker compose version
```

Enable Docker on boot (so Immich comes back after a reboot):

```bash
sudo systemctl enable --now docker
```

---

## 3. Download Immich

```bash
mkdir -p ~/immich-app
cd ~/immich-app

# Official compose file
wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml

# Environment template
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env
```

---

## 4. Configure storage on the SSD (`/mnt/pics`)

### 4.1 How `UPLOAD_LOCATION` works

Immich stores its **entire managed library** wherever `UPLOAD_LOCATION` points, creating and
owning these subfolders:

```
/mnt/pics/
├── library/          # your original photos/videos (the important stuff)
├── upload/           # in-progress uploads
├── thumbs/           # generated thumbnails
├── encoded-video/    # transcoded videos
├── profile/          # user profile images
└── backups/          # internal DB dumps (if enabled)
```

> ⚠️ This is Immich's **own managed structure** — don't dump an existing photo collection
> directly into `/mnt/pics` expecting Immich to see it. That's what *External Libraries* are
> for (a separate read-only mount). For a fresh, Immich-managed setup, just point it here and
> upload via the app/web.
> 

### 4.2 Edit `.env`

```bash
nano ~/immich-app/.env
```

| Variable | Set to | Notes |
| --- | --- | --- |
| `UPLOAD_LOCATION` | `/mnt/pics` | Photos + library live on the SSD |
| `DB_DATA_LOCATION` | `/mnt/pics/database` *(optional)* | Keeps DB on the SSD too; or leave default `./postgres` |
| `DB_PASSWORD` | a strong password | Good hygiene even on LAN |
| `TZ` | `America/Los_Angeles` | Your timezone |
| `PUID` / `PGID` | `1000` / `1000` | Run Immich as your user so files aren't root-owned (see 4.3) |
| `IMMICH_VERSION` | `release` or a pinned tag | Pin (e.g. `v1.xxx.x`) for a stable home server |

Find your UID/GID with:

```bash
id     # e.g. uid=1000(youruser) gid=1000(youruser)
```

### 4.3 Set folder ownership & permissions

```bash
# Make sure the SSD is mounted first!
mountpoint /mnt/pics

# Own it to your user (match PUID/PGID) and lock out other users
sudo chown -R 1000:1000 /mnt/pics
sudo chmod -R 750 /mnt/pics
```

**Permission summary:**

| Setting | Value | Why |
| --- | --- | --- |
| **Owner** | your UID:GID (e.g. `1000:1000`) matching `PUID/PGID` | Immich can read/write; files owned by you |
| **Mode** | `750` (`rwxr-x---`) | Owner full, group read, **nothing for others** — private photos |
| **Filesystem** | ext4 ✅ | POSIX perms + hardlinks required |

> If you skip `PUID/PGID`, the server runs as **root** and writes `root:root` files. That works
> too — files are just root-owned (annoying for backups/browsing). Either is valid.
> 

---

## 5. Mount-guard — never write to the wrong disk

**Problem:** if `/mnt/pics` ever fails to mount, Docker will happily create `/mnt/pics/library`
on the VM's **root disk** and start writing there — silently filling root and splitting your
library. Two layers of protection:

### 5.1 Sentinel file (lives on the SSD)

```bash
# With the SSD mounted — this marker only exists when the disk is present:
touch /mnt/pics/.immich-mounted
```

### 5.2 Add a mount-guard service to `docker-compose.yml`

`depends_on` only orders services *within* compose — it can't check a host mount by itself. A
tiny guard service that verifies the sentinel, combined with `depends_on`, gives you a real gate.

Add this new service near the top of `services:`:

```yaml
  immich-mount-guard:
    image: busybox:latest
    container_name: immich_mount_guard
    volumes:
      - ${UPLOAD_LOCATION}:/mnt/check
    command:
      - sh
      - -c
      - >
        test -f /mnt/check/.immich-mounted
        && echo "Mount OK: /mnt/pics is present"
        || (echo "FATAL: /mnt/pics not mounted (sentinel .immich-mounted missing) — refusing to start"; exit 1)
    restart: "no"
```

### 5.3 Make `immich-server` depend on the guard

Find `immich-server`'s `depends_on`. It's likely the short list form:

```yaml
    depends_on:
      - redis
      - database
```

Replace with the **long form** (required for conditions) and add the guard:

```yaml
    depends_on:
      redis:
        condition: service_started
      database:
        condition: service_healthy
      immich-mount-guard:
        condition: service_completed_successfully
```

`service_completed_successfully` = start Immich **only after** the guard exits 0. No SSD →
guard exits 1 → Immich refuses to start.

### 5.4 (Optional, strongest) Make the bare mountpoint immutable

So nothing can write to `/mnt/pics` unless the SSD is mounted over it:

```bash
sudo umount /mnt/pics
sudo chattr +i /mnt/pics     # block writes to the empty mountpoint
sudo mount /mnt/pics         # SSD now mounts over it; writes go to the SSD
```

### 5.5 (Optional, most robust for boot) systemd dependency

Because Debian creates a `mnt-pics.mount` unit, you can make Docker itself wait for it with a
drop-in that adds `Requires=mnt-pics.mount` and `After=mnt-pics.mount` to the docker service —
so the stack won't even attempt to start until the kernel confirms the mount.

> **`depends_on` gates at startup only.** If the SSD drops *while running*, the guard won't
> catch it — that's what 5.4's immutability trick protects against. Use them together.
> 

---

## 6. Deploy

```bash
cd ~/immich-app
docker compose up -d
```

First run downloads images + the ML model (a few minutes).

---

## 7. Verify

```bash
# Guard passed?
docker compose logs immich-mount-guard      # "Mount OK: /mnt/pics is present"

# Everything up?
docker compose ps

# Server logs
docker compose logs -f immich-server         # Ctrl-C to stop

# Immich created its folders on the SSD?
ls -la /mnt/pics                              # library/ upload/ thumbs/ ...
```

**Test that the guard actually fires** (do this once):

```bash
docker compose down
sudo umount /mnt/pics
docker compose up -d
docker compose logs immich-mount-guard        # FATAL message
docker compose ps                              # immich-server NOT running
sudo mount /mnt/pics && docker compose up -d   # restore
```

---

## 8. First login

From any LAN device, browse to:

```
http://<your-server-ip>:2283
```

(e.g. `http://192.168.1.50:2283`). Create the **admin user**, then add users / storage
templates. In the **mobile app**, set the server URL to the same address for auto-backup over
Wi-Fi.

---

## 9. LAN-only networking

- **Static IP / DHCP reservation** on your router so the address never changes.
- **Firewall scoped to your subnet** (Debian):
```bash
sudo apt install -y ufw
sudo ufw allow from 192.168.1.0/24 to any port 2283 proto tcp
sudo ufw enable
```
Adjust `192.168.1.0/24` to match your LAN.
- **Do not port-forward 2283.** For remote access later, use a **VPN** (WireGuard/Tailscale)
into your LAN — never an open port.
- Auto-backup works on home Wi-Fi; it just won't upload when you're away (expected).

---

## 10. Security hardening (must-dos)

- **Enable 2FA (TOTP)** on the admin account in Account Settings — the biggest account win.
- **Strong, unique passwords** for admin and `DB_PASSWORD`.
- **Separate admin from daily use** — create a normal user for browsing, reserve admin for admin.
- **Disable public link sharing** if unused, or set expiry + passwords on links.
- **Keep host + Immich patched:** `apt upgrade` regularly; `docker compose pull && up -d` for Immich.
- **Harden the host:** SSH keys only (disable password SSH), consider `unattended-upgrades`.
- **Encryption at rest:** consider LUKS on the SSD + any backup drives.
- **Segment IoT/guest devices** onto a separate VLAN/network if your router supports it.

---

## 11. Updating Immich

```bash
cd ~/immich-app
docker compose pull       # fetch new images
docker compose up -d      # recreate containers
docker image prune        # reclaim space from old images
```

Check the release notes for breaking changes before each update.

---

## 12. Hardware acceleration (optional)

- **Transcoding:** `hwaccel.transcoding.yml` — NVENC (NVIDIA), QuickSync (Intel), VAAPI.
- **Machine learning:** `hwaccel.ml.yml` — CUDA (NVIDIA), OpenVINO (Intel), ROCm (AMD).

```bash
docker compose -f docker-compose.yml -f hwaccel.transcoding.yml up -d
```

NVIDIA requires `nvidia-container-toolkit` on the host.

---

## 13. Backups — do not skip

Back up **both**, and **test a restore** once:

1. **Media** — everything under `/mnt/pics` (rsync, Borg, restic, another disk; keep a 3-2-1 copy).
2. **Database** — albums, metadata, faces, users:

```bash
docker exec -t immich_postgres pg_dumpall --clean --if-exists -U postgres \
  | gzip > immich-db-backup-$(date +%F).sql.gz
```

Automate both with cron and verify the dump is non-empty (a silent backup failure is worse than
none). RAID/snapshots are **not** a substitute for an offsite copy.

---

## Quick-reference cheat sheet

```bash
# Host prep
sudo apt update && sudo apt upgrade -y
mountpoint /mnt/pics && df -Th /mnt/pics          # confirm ext4 + mounted

# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER                     # re-login after
sudo systemctl enable --now docker

# Immich files
mkdir -p ~/immich-app && cd ~/immich-app
wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env
# edit .env: UPLOAD_LOCATION=/mnt/pics, DB_PASSWORD, TZ, PUID/PGID

# Storage perms + sentinel
sudo chown -R 1000:1000 /mnt/pics && sudo chmod -R 750 /mnt/pics
touch /mnt/pics/.immich-mounted
# add mount-guard service + depends_on (see section 5)

# Deploy + verify
docker compose up -d
docker compose logs immich-mount-guard
docker compose ps
# visit http://<server-ip>:2283
```

> Immich changes fast — cross-check exact `.env` variable names against the official docs at
> immich.app/docs/install/docker-compose before running. This describes the stable,
> well-established flow, but names occasionally shift between releases.
>
