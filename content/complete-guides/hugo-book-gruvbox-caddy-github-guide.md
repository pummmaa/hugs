---
title: "Hugo Book Gruvbox Caddy Github Guide"
date: 2026-08-09T05:34:24Z
lastmod: 2026-08-09T05:34:24Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Complete Guide: Hugo Book + Gruvbox + Caddy + GitHub

**Server user:** `debian`  
**Site path:** `/home/debian/hugs`  
**Theme:** Hugo Book (sidebar navigation)  
**Colors:** Gruvbox Dark  
**Web server:** Caddy (auto HTTPS)  
**Repository:** GitHub (webhook auto-deploy)

---

## Architecture

```
┌──────────────┐         ┌──────────────────┐       ┌───────────────┐
│ GitHub Repo  │─webhook─▶│  Hugo + Book     │──────▶│ Caddy (Serve) │──▶ Users
│ (Markdown)   │         │ /home/debian/hugs│       │ Auto HTTPS    │
└──────────────┘         └──────────────────┘       └───────────────┘
```

---

## 1. Install Prerequisites

```bash
# Hugo Extended (required for SCSS)
wget https://github.com/gohugoio/hugo/releases/download/v0.140.1/hugo_extended_0.140.1_linux-amd64.deb
sudo dpkg -i hugo_extended_0.140.1_linux-amd64.deb
hugo version  # Must say "extended"

# Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# Git and webhook listener
sudo apt install git webhook
```

---

## 2. Create the Hugo Site

```bash
mkdir -p /home/debian/hugs
cd /home/debian/hugs

hugo new site . --force
git init
git branch -M main

# Add Hugo Book theme
git submodule add --depth=1 https://github.com/alex-shpak/hugo-book.git themes/hugo-book
```

---

## 3. Hugo Configuration (`hugo.yaml`)

Delete any `hugo.toml` and create `hugo.yaml`:

```bash
rm -f hugo.toml
```

**Contents of `hugo.yaml`:**

```yaml
baseURL: "https://yourdomain.com"
languageCode: "en-us"
title: "Knowledge Hub"
theme: "hugo-book"

enableGitInfo: true
enableEmoji: true

params:
  BookTheme: "auto"
  BookToC: true
  BookSection: "/"
  BookSearch: true
  BookDateFormat: "Jan 2, 2006"
  BookComments: false
  BookRepo: ""

markup:
  goldmark:
    renderer:
      unsafe: true
  highlight:
    style: gruvbox-dark
    codeFences: true
    guessSyntax: true
  tableOfContents:
    startLevel: 2
    endLevel: 4

outputs:
  home:
    - HTML
    - RSS
    - JSON

menu: {}
```

> **Replace `https://yourdomain.com` with your actual domain.**

---

## 4. Create Content Structure

### Homepage (`content/_index.md`)

```markdown
---
title: "Welcome"
---

# 📚 Welcome to the Knowledge Hub

A free and open collection of notes, guides, and references — built for anyone looking to learn, explore, and grow.

---

## What you'll find here

This site is a living knowledge base covering topics in **Linux**, **DevOps**, **Programming**, **Networking**, and more. Whether you're a beginner taking your first steps or an experienced practitioner looking for a quick reference, there's something here for you.

### 🧭 Browse by topic

- **Linux** — System administration, commands, configuration, and troubleshooting
- **DevOps** — CI/CD, containers, infrastructure as code, and automation
- **Programming** — Languages, patterns, tools, and best practices
- **Networking** — Protocols, firewalls, DNS, and connectivity

---

## Philosophy

> Knowledge should be accessible to everyone. These notes are written to be clear, practical, and straight to the point — no gatekeeping, no fluff.

Pick a topic from the sidebar and start exploring. Happy learning. 🚀
```

### Section pages

Create these `_index.md` files in each section directory:

**`content/linux/_index.md`:**
```markdown
---
title: "Linux"
weight: 1
bookCollapseSection: true
---
```

**`content/devops/_index.md`:**
```markdown
---
title: "DevOps"
weight: 2
bookCollapseSection: true
---
```

**`content/programming/_index.md`:**
```markdown
---
title: "Programming"
weight: 3
bookCollapseSection: true
---
```

**`content/networking/_index.md`:**
```markdown
---
title: "Networking"
weight: 4
bookCollapseSection: true
---
```

### Archetype template (`archetypes/default.md`)

```markdown
---
title: "{{ replace .Name \"-\" \" \" | title }}"
date: {{ .Date }}
draft: true
weight: 10
---

## Overview

Write your notes here...
```

---

## 5. Gruvbox Dark Theme

### Create CSS file (`static/css/gruvbox.css`)

```css
:root {
  --body-background: #282828 !important;
  --body-font-color: #ebdbb2 !important;
  --color-link: #83a598 !important;
  --color-visited-link: #d3869b !important;
}

html, body {
  background: #282828 !important;
  color: #ebdbb2 !important;
}

.book-menu, .book-menu nav {
  background: #1d2021 !important;
}

.book-menu a {
  color: #d5c4a1 !important;
}

.book-menu a:hover {
  color: #fabd2f !important;
}

.book-page {
  background: #282828 !important;
  color: #ebdbb2 !important;
}

.container, .container main {
  background: #282828 !important;
}

h1, h2, h3, h4, h5, h6 {
  color: #fe8019 !important;
}

a {
  color: #83a598 !important;
}

a:hover {
  color: #8ec07c !important;
}

code:not(pre code) {
  background: #3c3836 !important;
  color: #b8bb26 !important;
  padding: 2px 5px;
  border-radius: 3px;
}

pre {
  background: #1d2021 !important;
  border: 1px solid #504945 !important;
  border-radius: 6px;
}

pre code {
  background: transparent !important;
  color: #ebdbb2 !important;
}

.book-toc {
  background: #282828 !important;
}

.book-toc a {
  color: #a89984 !important;
}

.book-toc a:hover {
  color: #fabd2f !important;
}

table th {
  background: #3c3836 !important;
  color: #fabd2f !important;
  border-color: #504945 !important;
}

table td {
  border-color: #504945 !important;
  color: #d5c4a1 !important;
}

table tr:nth-child(even) {
  background: #32302f !important;
}

blockquote {
  border-left: 4px solid #8ec07c !important;
  background: #32302f !important;
  color: #d5c4a1 !important;
}

.book-search input {
  background: #3c3836 !important;
  color: #ebdbb2 !important;
  border: 1px solid #665c54 !important;
}

.book-search input::placeholder {
  color: #a89984 !important;
}

.book-brand {
  color: #fbf1c7 !important;
}

.book-header {
  background: #1d2021 !important;
}

hr {
  border-color: #504945 !important;
}

.book-footer {
  border-color: #504945 !important;
}

.markdown {
  color: #ebdbb2 !important;
}

::selection {
  background: #83a598;
  color: #282828;
}
```

### Inject CSS into theme (`layouts/partials/docs/inject/head.html`)

```html
<link rel="stylesheet" href="/css/gruvbox.css">
```

---

## 6. .gitignore

```
public/
resources/
.hugo_build.lock
```

---

## 7. System Permissions

### Create shared group and set membership

```bash
sudo groupadd webdata
sudo usermod -aG webdata debian
sudo usermod -aG webdata caddy
```

### Set file ownership and permissions

```bash
sudo chown -R debian:webdata /home/debian/hugs
sudo find /home/debian/hugs -type d -exec chmod 2750 {} \;
sudo find /home/debian/hugs -type f -exec chmod 640 {} \;
chmod 711 /home/debian
```

### Fix Caddy's systemd ProtectHome (if set)

```bash
# Check
sudo systemctl cat caddy | grep ProtectHome
```

If it shows `ProtectHome=true`:

```bash
sudo systemctl edit caddy
```

Add:

```ini
[Service]
ProtectHome=false
ReadOnlyPaths=/home/debian/hugs/public
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart caddy
```

### Permissions summary

| Path | Owner | Group | Mode | Purpose |
|------|-------|-------|------|---------|
| `/home/debian` | debian | debian | `711` | Traversal only |
| `/home/debian/hugs/` | debian | webdata | `2750` | Site root, setgid |
| `/home/debian/hugs/public/` | debian | webdata | `2750` | Built output |
| `/home/debian/hugs/public/**` (dirs) | debian | webdata | `2750` | Subdirs |
| `/home/debian/hugs/public/**` (files) | debian | webdata | `640` | Static files |
| `/home/debian/hugs/deploy.sh` | debian | webdata | `750` | Deploy script |

---

## 8. Caddy Configuration (`/etc/caddy/Caddyfile`)

```caddyfile
yourdomain.com {
    encode zstd gzip

    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        -Server
    }

    # Webhook (must be before file_server)
    route /hooks/* {
        reverse_proxy localhost:9000
    }

    # Static site
    root * /home/debian/hugs/public
    file_server

    @static {
        path *.css *.js *.svg *.png *.jpg *.jpeg *.gif *.woff *.woff2 *.ico *.webp
    }
    header @static Cache-Control "public, max-age=31536000, immutable"

    handle_errors {
        @404 expression {http.error.status_code} == 404
        rewrite @404 /404.html
        file_server
    }

    log {
        output file /var/log/caddy/notes-access.log {
            roll_size 10mb
            roll_keep 5
        }
        format json
    }
}

www.yourdomain.com {
    redir https://yourdomain.com{uri} permanent
}
```

> **Replace `yourdomain.com` with your actual domain.**

```bash
sudo mkdir -p /var/log/caddy
sudo chown caddy:caddy /var/log/caddy
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl enable caddy
sudo systemctl restart caddy
```

---

## 9. Deploy Script (`deploy.sh`)

```bash
#!/bin/bash
set -euo pipefail

SITE_DIR="/home/debian/hugs"
LOG="/var/log/hugo-deploy.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deploy triggered" >> "$LOG"

cd "$SITE_DIR"
git fetch origin main
git reset --hard origin/main
git submodule update --init --recursive

hugo --minify --gc 2>> "$LOG"

chown -R debian:webdata "$SITE_DIR/public"
find "$SITE_DIR/public" -type d -exec chmod 2750 {} \;
find "$SITE_DIR/public" -type f -exec chmod 640 {} \;

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deploy complete" >> "$LOG"
```

```bash
chmod 750 /home/debian/hugs/deploy.sh
sudo touch /var/log/hugo-deploy.log
sudo chown debian:webdata /var/log/hugo-deploy.log
sudo chmod 664 /var/log/hugo-deploy.log
```

---

## 10. Rebuild Script (`rebuild.sh`) — For Manual Rebuilds

```bash
#!/bin/bash
cd /home/debian/hugs
hugo --minify --gc
chown -R debian:webdata /home/debian/hugs/public
find /home/debian/hugs/public -type d -exec chmod 2750 {} \;
find /home/debian/hugs/public -type f -exec chmod 640 {} \;
echo "✅ Site rebuilt"
```

```bash
chmod 750 /home/debian/hugs/rebuild.sh
```

---

## 11. Webhook (Auto-Deploy on Push)

### Generate the secret

```bash
openssl rand -hex 20
# Save this output — used in two places below
```

### Webhook config (`/etc/webhook/hooks.json`)

```json
[
  {
    "id": "hugo-deploy",
    "execute-command": "/home/debian/hugs/deploy.sh",
    "command-working-directory": "/home/debian/hugs",
    "trigger-rule": {
      "and": [
        {
          "match": {
            "type": "payload-hmac-sha256",
            "secret": "YOUR_SECRET_HERE",
            "parameter": {
              "source": "header",
              "name": "X-Hub-Signature-256"
            }
          }
        },
        {
          "match": {
            "type": "value",
            "value": "refs/heads/main",
            "parameter": {
              "source": "payload",
              "name": "ref"
            }
          }
        }
      ]
    }
  }
]
```

> **Replace `YOUR_SECRET_HERE` with the output from `openssl rand -hex 20`.**

### Webhook systemd service (`/etc/systemd/system/webhook.service`)

```ini
[Unit]
Description=Webhook listener for Hugo deployment
After=network.target

[Service]
Type=simple
User=debian
Group=debian
ExecStart=/usr/bin/webhook -hooks /etc/webhook/hooks.json -port 9000 -verbose
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable webhook
sudo systemctl start webhook
sudo systemctl status webhook  # Should say "active (running)"
```

### Verify webhook works locally

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/hooks/hugo-deploy
# Should return 200 or 405 (not 404 or connection refused)
```

---

## 12. Push to GitHub

### Create the repo

1. Go to [github.com/new](https://github.com/new)
2. Name: `hugs`
3. Do NOT initialize with README

### Push

```bash
cd /home/debian/hugs
git add .
git commit -m "Initial Hugo Book site with Gruvbox theme"
git remote add origin git@github.com:yourusername/hugs.git
git push -u origin main
```

### Configure GitHub webhook

1. Repo → **Settings → Webhooks → Add webhook**
2. Fill in:

| Field | Value |
|-------|-------|
| Payload URL | `https://yourdomain.com/hooks/hugo-deploy` |
| Content type | `application/json` |
| Secret | Same value from `openssl rand -hex 20` |
| Events | Just the push event |
| Active | ✅ |

3. Click **Add webhook** — check Recent Deliveries for green ✅

---

## 13. Initial Build

```bash
cd /home/debian/hugs
hugo --minify --gc
~/hugs/rebuild.sh
```

Visit `https://yourdomain.com` — your site should be live.

---

## 14. Firewall

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

---

## 15. Day-to-Day Workflow

### Add a new note

```bash
cd /home/debian/hugs
hugo new content/linux/my-note.md
nano content/linux/my-note.md
```

### Publish it

Change `draft: true` → `draft: false`, then:

```bash
git add .
git commit -m "Add my-note"
git push
```

Site auto-rebuilds via webhook. Done.

### Save as draft (in repo but hidden from live site)

Keep `draft: true` and push normally.

### Delete a note

```bash
rm content/section/note.md
git add -A
git commit -m "Remove note"
git push
```

### Add a new section

```bash
mkdir -p content/newsection
```

Create `content/newsection/_index.md`:
```markdown
---
title: "New Section"
weight: 5
bookCollapseSection: true
---
```

### Manual rebuild (if webhook isn't working)

```bash
~/hugs/rebuild.sh
```

---

## 16. Frontmatter Reference

### Minimal (most notes)

```markdown
---
title: "Note Title"
date: 2026-08-08
draft: false
weight: 10
---
```

### Full options

```markdown
---
title: "Note Title"
date: 2026-08-08
draft: false
weight: 10
bookCollapseSection: true   # For _index.md: collapse in sidebar
bookHidden: true            # Hide from sidebar but accessible via URL
bookToC: false              # Disable TOC for this page
---
```

---

## 17. Directory Structure (Final)

```
/home/debian/hugs/
├── .gitignore
├── archetypes/
│   └── default.md
├── content/
│   ├── _index.md              # Homepage
│   ├── linux/
│   │   ├── _index.md
│   │   └── *.md
│   ├── devops/
│   │   ├── _index.md
│   │   └── *.md
│   ├── programming/
│   │   ├── _index.md
│   │   └── *.md
│   └── networking/
│       ├── _index.md
│       └── *.md
├── layouts/
│   └── partials/
│       └── docs/
│           └── inject/
│               └── head.html  # Loads gruvbox.css
├── static/
│   └── css/
│       └── gruvbox.css        # Gruvbox dark theme
├── themes/
│   └── hugo-book/             # Git submodule
├── deploy.sh
├── rebuild.sh
└── hugo.yaml
```

---

## 18. Quick Reference

| Task | Command |
|------|---------|
| New note | `hugo new content/section/name.md` |
| Publish draft | Change `draft: true` → `draft: false` |
| Preview locally | `hugo server -D --bind 0.0.0.0 --port 1313` |
| Push & deploy | `git add . && git commit -m "msg" && git push` |
| Manual rebuild | `~/hugs/rebuild.sh` |
| Delete note | `rm content/section/name.md && git add -A && git commit -m "rm" && git push` |
| Update theme | `git submodule update --remote themes/hugo-book && git add . && git commit -m "Update theme" && git push` |
| Check webhook | `sudo systemctl status webhook` |
| Check Caddy | `sudo systemctl status caddy` |
| Caddy logs | `sudo tail -f /var/log/caddy/notes-access.log` |
| Deploy logs | `tail -f /var/log/hugo-deploy.log` |
| Verify perms | `sudo -u caddy ls /home/debian/hugs/public/` |

---

## 19. Troubleshooting

| Problem | Fix |
|---------|-----|
| 403 Forbidden | Re-run permissions (Section 7) — verify with `sudo -u caddy ls /home/debian/hugs/public/` |
| Notes not showing | Check `draft: false` in frontmatter |
| Webhook 404 | Ensure `route /hooks/*` is before `file_server` in Caddyfile |
| Webhook `status=217/USER` | Wrong `User=` in webhook.service — must be `debian` |
| Old CSS cached | Hard refresh: `Ctrl+Shift+R` |
| git tracks public/ | `git rm -r --cached public/ resources/` then commit |
| baseURL wrong | All links broken — update `baseURL` in `hugo.yaml` to actual domain |
| Webhook not triggering | Check: `sudo systemctl status webhook` and `curl http://localhost:9000/hooks/hugo-deploy` |

