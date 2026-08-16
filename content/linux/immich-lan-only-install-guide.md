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

# Installing Immich on Linux — LAN-Only Guide

**Immich** is a self-hosted, high-performance photo and video backup solution — a private
alternative to Google Photos with mobile apps, a web UI, facial recognition, object/scene
detection, albums, and multi-user support. The **officially recommended** installation method
is **Docker Compose**. Because this runs on your LAN only, you can skip HTTPS/reverse-proxy
entirely and reach it directly by IP.

---

## Why Docker Compose?

Immich is made up of **several coordinated services** (server, machine-learning container,
PostgreSQL with a vector extension, and Redis). Docker Compose wires these together with the
correct versions and networking. The Immich team recommends against non-Docker installs
because the ML and database components have specific version requirements that are painful to
satisfy manually.

> ⚠️ Immich evolves quickly — **read the release notes before updating**, and keep backups.
> 

---

## Prerequisites

| Requirement | Detail |
| --- | --- |
| **OS** | Any modern Linux (Ubuntu/Debian, Fedora, etc.) |
| **RAM** | 4 GB minimum; **6 GB+ recommended** (ML is memory-hungry) |
| **Storage** | Enough for your library + a bit for the database and thumbnails |
| **Software** | Docker Engine + Docker Compose plugin |

### Install Docker Engine + Compose

```bash
# Install Docker Engine + Compose plugin (official convenience script)
curl -fsSL https://get.docker.com | sudo sh

# Let your user run docker without sudo (log out/in afterward)
sudo usermod -aG docker $USER

# Verify
docker --version
docker compose version
```

Make sure you get the **Compose V2 plugin** (`docker compose`, with a space), not the old
standalone `docker-compose`.

---

## Step-by-Step Installation

### Step 1 — Create a directory

```bash
mkdir -p ~/immich-app
cd ~/immich-app
```

### Step 2 — Download the official compose and env files

```bash
# The docker-compose file
wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml

# The environment template
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env
```

### Step 3 — Configure the `.env` file

```bash
nano .env
```

Key values to review:

| Variable | What it does |
| --- | --- |
| `UPLOAD_LOCATION` | **Where your photos/videos are stored.** Point this at a large disk, e.g. `/mnt/photos/immich`. Most important setting. |
| `DB_DATA_LOCATION` | Where the Postgres database files live (default `./postgres` is fine, but keep it on reliable storage). |
| `DB_PASSWORD` | **Change this to a strong password** (even on LAN — good hygiene). |
| `TZ` | Your timezone, e.g. `America/Los_Angeles`. |
| `IMMICH_VERSION` | Leave as `release` to track latest, or pin a version (e.g. `v1.xxx.x`) for stability. |

> 💡 Pinning `IMMICH_VERSION` to a specific tag gives you control over when you upgrade —
> recommended for a stable home server.
> 

### Step 4 — Start Immich

```bash
docker compose up -d
```

First run takes a few minutes (the ML model download can be large). Check health:

```bash
docker compose ps
docker compose logs -f    # Ctrl-C to stop following
```

### Step 5 — Open the web UI and create your admin account

From any device on your LAN, browse to:

```
http://<your-server-ip>:2283
```

(e.g. `http://192.168.1.50:2283`). On first visit you'll create the **admin user**, then you
can add more users and configure storage templates.

**In the mobile app**, set the server URL to `http://<your-server-ip>:2283`.

---

## LAN-only network notes

Since you're keeping this on your local network:

- **Give the server a static IP** (or a DHCP reservation on your router) so the address never
changes and the mobile app keeps working after reboots.
- **Firewall:** if `ufw` (or firewalld) is active, allow the port on your LAN subnet only:
```bash
sudo ufw allow from 192.168.1.0/24 to any port 2283 proto tcp
```
Adjust `192.168.1.0/24` to match your subnet. This keeps the port open on the LAN without
ever exposing it beyond your network.
- **Do not port-forward 2283** on your router — that's what keeps it LAN-only. If you later
want to reach it from outside, the safe approach is a **VPN back into your LAN**
(e.g. WireGuard or Tailscale) rather than exposing the port.
- **Mobile auto-backup** works great over Wi-Fi at home. It just won't upload when you're away
from your network — which is expected for a LAN-only setup.

---

## Updating Immich

```bash
cd ~/immich-app
docker compose pull       # fetch new images
docker compose up -d      # recreate containers
docker image prune        # reclaim space from old images
```

Check the release notes for breaking changes before each update.

---

## Hardware acceleration (optional)

Immich can offload work to your GPU:

- **Transcoding** (video): via `hwaccel.transcoding.yml` — NVENC (NVIDIA), QuickSync (Intel), VAAPI, etc.
- **Machine learning** (faces, smart search): via `hwaccel.ml.yml` — CUDA (NVIDIA), OpenVINO (Intel), ROCm (AMD).

Download the relevant hwaccel YAML from the release, uncomment your platform's block, and start
with both files:

```bash
docker compose -f docker-compose.yml -f hwaccel.transcoding.yml up -d
```

NVIDIA requires the `nvidia-container-toolkit` on the host.

---

## Backups — do not skip this

Two things to back up separately:

1. **Media files** — everything under `UPLOAD_LOCATION`. Back these up like any important data
(rsync, Borg, restic, another disk).
2. **The database** — contains albums, metadata, faces, users. Dump it regularly:

```bash
docker exec -t immich_postgres pg_dumpall --clean --if-exists -U postgres | gzip > immich-db-backup-$(date +%F).sql.gz
```

A media backup without the database means losing all albums and face data even if the files
survive. Automate both with a cron job.

---

## Quick summary

```bash
mkdir ~/immich-app && cd ~/immich-app
wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env
# edit .env: set UPLOAD_LOCATION, DB_PASSWORD, TZ
docker compose up -d
# visit http://<server-ip>:2283 and create your admin account
```

Give the box a static IP, allow port 2283 on your LAN subnet, don't port-forward, and set up
automated backups. That's a clean, private, LAN-only Immich.

> Since Immich changes quickly, cross-check the exact `.env` variables against the official docs
> at immich.app/docs/install/docker-compose before running — this describes the stable,
> well-established flow, but variable names occasionally shift between releases.
>
