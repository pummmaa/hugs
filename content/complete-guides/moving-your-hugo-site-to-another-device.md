---
title: "moving-your-hugo-site-to-another-device"
date: 2026-08-09T06:03:49Z
lastmod: 2026-08-09T06:03:49Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Moving Your Hugo Site to Another Device

---

## What you need

Everything is already in your GitHub repo. You don't need to copy files manually — just clone.

---

## On the new device


### 1. Install Hugo Extended v0.164.0 (same version)

```bash
# Debian/Ubuntu
wget https://github.com/gohugoio/hugo/releases/download/v0.164.0/hugo_extended_0.164.0_linux-amd64.deb
sudo dpkg -i hugo_extended_0.164.0_linux-amd64.deb

# macOS
brew install hugo

# Windows: download from https://github.com/gohugoio/hugo/releases/tag/v0.164.0

# Verify
hugo version
# Should show: hugo v0.164.0+extended linux/amd64
```

> **Important:** Always match the version. Different Hugo versions can render differently.


### 2. Clone your repo (includes everything)

```bash
git clone --recursive git@github.com:yourusername/hugs.git
cd hugs
```

The `--recursive` flag pulls the Hugo Book theme submodule too.

If you forgot `--recursive`:

```bash
git submodule update --init --recursive
```

### 3. Preview locally

```bash
hugo server -D --bind 0.0.0.0 --port 1313
```

That's it — you're working on the site.

---

## What's in the repo (everything needed)

| File/Folder | What it is |
|-------------|-----------|
| `hugo.yaml` | Site config |
| `content/` | All your markdown notes |
| `archetypes/` | Note templates |
| `layouts/` | Head inject (loads gruvbox.css) |
| `static/css/gruvbox.css` | Gruvbox theme |
| `static/fonts/` | Self-hosted fonts (if used) |
| `themes/hugo-book` | Theme (submodule reference) |
| `.gitignore` | Ignores public/ and resources/ |
| `deploy.sh` | Server deploy script |
| `rebuild.sh` | Manual rebuild script |
| `.hugo-version` | Pinned Hugo version |

### What's NOT in the repo (generated/server-specific)

| Item | Why | What to do |
|------|-----|-----------|
| `public/` | Generated on build | Run `hugo --minify --gc` |
| `resources/` | Hugo cache | Auto-regenerated |
| `/etc/caddy/Caddyfile` | Server config | Recreate from guide |
| `/etc/webhook/hooks.json` | Server config | Recreate from guide |
| Webhook secret | Sensitive | Generate new or reuse |
| SSH keys | Per-device | Generate new deploy key |

---

## Workflow: Edit on laptop, deploy to server

```
Laptop (write notes) ──git push──▶ GitHub ──webhook──▶ Server (builds & serves)
```

1. Clone repo on laptop
2. Write/edit notes
3. `git push` → server auto-deploys

You only need Hugo locally for **previewing** before pushing.

---

## If moving to a NEW server (replacing the current one)

1. Install Hugo Extended v0.164.0, Caddy, Git, webhook
2. Clone the repo to `/home/debian/hugs`
3. Set up permissions (group, setgid, chmod 711)
4. Configure Caddyfile
5. Configure webhook (generate new secret or reuse)
6. Update GitHub webhook URL to new server's domain/IP
7. Build: `hugo --minify --gc && ~/hugs/rebuild.sh`

---

## Pin Hugo version in your repo

```bash
cd /home/debian/hugs
echo "0.164.0" > .hugo-version
git add .hugo-version
git commit -m "Pin Hugo version to 0.164.0"
git push
```

On any new device, check before installing:

```bash
cat .hugo-version
# Install that exact version
```

---

## For Arch Linux
If you are on Arch install `hugo` from its `pacman`
```bash
# From official repos (always extended version)
sudo pacman -S hugo

# Verify version
hugo version
```

## Quick summary

| Scenario | What to do |
|----------|-----------|
| New laptop (just editing) | `git clone --recursive` + install Hugo v0.164.0 |
| New server (full deploy) | Clone + full guide setup (Caddy, webhook, permissions) |
| Same server, fresh OS | Clone + full guide setup |
| Collaborator joining | They just clone and push — server handles the rest |

