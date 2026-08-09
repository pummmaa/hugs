---
title: "hugo-troubleshooting-guide"
date: 2026-08-09T18:49:26Z
lastmod: 2026-08-09T18:49:26Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Hugo Site Troubleshooting Guide

A reference for diagnosing and fixing common issues with the Hugo + Caddy + GitHub webhook deployment.

---

## 1. Webhook Not Triggering (No Deploy on Push)

### Symptoms

- You push to GitHub but the site doesn't update
- `/var/log/hugo-deploy.log` shows no new entries

### Debug Steps

```bash
# 1. Is webhook service running?
sudo systemctl status webhook

# 2. Can you reach it locally?
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9000/hooks/hugo-deploy
# Expected: 200 or 405

# 3. Can you reach it through Caddy?
curl -s -o /dev/null -w "%{http_code}" -X POST https://notes.naruu.xyz/hooks/hugo-deploy
# Expected: 400 (bad signature) — NOT 404

# 4. Check webhook logs
sudo journalctl -u webhook -n 30 --no-pager
```

### Common Fixes

| Cause | Fix |
|-------|-----|
| Service not running | `sudo systemctl start webhook` |
| `status=217/USER` error | Wrong `User=` in webhook.service — must be `debian` |
| 404 through Caddy | `route /hooks/*` must be BEFORE `file_server` in Caddyfile |
| Signature mismatch | Secret in `/etc/webhook/hooks.json` must match GitHub webhook secret exactly |
| Hook ID mismatch | `"id"` in hooks.json must match the URL path (`hugo-deploy`) |

---

## 2. Deploy Triggered but Not Completing

### Symptoms

- `/var/log/hugo-deploy.log` shows "Deploy triggered" but NO "Deploy complete"
- Site content stays old

### Debug Steps

```bash
# Run deploy.sh manually with debug output
cd /home/debian/hugs
bash -x deploy.sh

# Test as the webhook user (simulates how the service runs it)
sudo -u debian HOME=/home/debian bash /home/debian/hugs/deploy.sh
```

### Common Fixes

| Cause | Fix |
|-------|-----|
| `git fetch` hangs (SSH host key prompt) | `ssh-keyscan github.com >> /home/debian/.ssh/known_hosts` |
| `git fetch` hangs (SSH passphrase) | Remove passphrase: `ssh-keygen -p -f /home/debian/.ssh/id_ed25519` |
| SSH key not found by webhook | Add `Environment="HOME=/home/debian"` to webhook.service override |
| `chown: invalid user` | Change `user:webdata` to `debian:webdata` in deploy.sh |
| Switch to HTTPS (avoids all SSH issues) | `git remote set-url origin https://TOKEN@github.com/user/hugs.git` |

### Fix SSH for Non-Interactive Use

```bash
# Add GitHub to known hosts
mkdir -p /home/debian/.ssh
chmod 700 /home/debian/.ssh
ssh-keyscan github.com >> /home/debian/.ssh/known_hosts
chmod 644 /home/debian/.ssh/known_hosts

# Verify SSH works non-interactively
ssh -T git@github.com
# Should say: "Hi username! You've successfully authenticated..."
```

### Add HOME to Webhook Service

```bash
sudo systemctl edit webhook
```

Add:

```ini
[Service]
Environment="HOME=/home/debian"
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart webhook
```

---

## 3. 403 Forbidden

### Symptoms

- Site returns 403 error in browser
- Caddy can't read the files

### Debug Steps

```bash
# Test as caddy user
sudo -u caddy ls /home/debian/hugs/public/
sudo -u caddy cat /home/debian/hugs/public/index.html
```

### Fixes

```bash
# Fix home directory traversal
chmod 711 /home/debian

# Fix ownership
sudo chown -R debian:webdata /home/debian/hugs
sudo find /home/debian/hugs -type d -exec chmod 2750 {} \;
sudo find /home/debian/hugs -type f -exec chmod 640 {} \;

# Ensure caddy is in webdata group
sudo usermod -aG webdata caddy
sudo systemctl restart caddy

# Check ProtectHome
sudo systemctl cat caddy | grep ProtectHome
# If ProtectHome=true, override it (see main guide Section 7.3)
```

---

## 4. 404 Not Found on All Pages

### Symptoms

- Homepage works but all links go to 404
- OR everything is 404

### Fixes

| Cause | Fix |
|-------|-----|
| `baseURL` wrong in `hugo.yaml` | Set to your actual domain: `https://notes.naruu.xyz` |
| Site not built | Run `~/hugs/rebuild.sh` |
| `public/` is empty | Run `hugo --minify --gc` in `/home/debian/hugs` |

---

## 5. Notes Not Showing Up

### Symptoms

- You created/pushed markdown files but they don't appear on the site

### Debug Steps

```bash
# Check for drafts
grep -r "draft:" /home/debian/hugs/content/

# Check if Hugo sees the files
cd /home/debian/hugs
hugo --minify --gc 2>&1 | tail -10
# Look at "Pages" count

# Verbose build
hugo --minify --gc -v 2>&1 | grep -i "draft\|skip"
```

### Common Fixes

| Cause | Fix |
|-------|-----|
| `draft: true` | Change to `draft: false` |
| No frontmatter | Add `---` block with at least `title` and `draft: false` |
| Date in the future | Change to today or past date |
| File not in `content/` | Move to `/home/debian/hugs/content/section/` |
| Missing `_index.md` in section | Create one with title and weight |

---

## 6. CSS/Theme Not Applying

### Symptoms

- Site looks unstyled or shows default Hugo Book theme (not Gruvbox)

### Fixes

```bash
# Hard refresh browser
# Chrome/Firefox: Ctrl+Shift+R

# Check CSS file exists
ls -la /home/debian/hugs/static/css/gruvbox.css

# Check head inject exists
cat /home/debian/hugs/layouts/partials/docs/inject/head.html
# Should contain: <link rel="stylesheet" href="/css/gruvbox.css">

# Clear Hugo cache and rebuild
rm -rf /home/debian/hugs/resources/ /home/debian/hugs/public/
~/hugs/rebuild.sh
```

---

## 7. Webhook Service Crash Loop (status=217/USER)

### Symptoms

- `sudo systemctl status webhook` shows repeated restarts
- Error code `status=217/USER`

### Fix

The `User=` or `Group=` in the service file doesn't exist on the system.

```bash
# Check your actual username
whoami

# Edit service file
sudo nano /etc/systemd/system/webhook.service
# Set User=debian and Group=debian

sudo systemctl daemon-reload
sudo systemctl restart webhook
```

---

## 8. Git Tracks public/ and resources/

### Symptoms

- `git status` shows changes in `public/` after every build

### Fix

```bash
cd /home/debian/hugs

# Remove from tracking (keeps files on disk)
git rm -r --cached public/
git rm -r --cached resources/

# Ensure .gitignore is correct
cat .gitignore
# Should contain:
# public/
# resources/
# .hugo_build.lock

git add .gitignore
git commit -m "Remove public/ and resources/ from tracking"
git push
```

---

## 9. Hugo Build Warning: No Layout for JSON

### Symptoms

- Warning: `found no layout file for "json" for kind "home"`

### Fix

Remove JSON from outputs in `hugo.yaml`:

```yaml
outputs:
  home:
    - HTML
    - RSS
```

Hugo Book's built-in search doesn't need the JSON output.

---

## 10. Quick Diagnostic Script

Save as `/home/debian/hugs/diagnose.sh`:

```bash
#!/bin/bash
echo "=== Hugo Site Diagnostics ==="
echo ""

echo "1. Caddy status:"
systemctl is-active caddy && echo "   ✅ Running" || echo "   ❌ Not running"

echo "2. Webhook status:"
systemctl is-active webhook && echo "   ✅ Running" || echo "   ❌ Not running"

echo "3. Webhook reachable:"
CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9000/hooks/hugo-deploy)
[ "$CODE" != "000" ] && echo "   ✅ Responding ($CODE)" || echo "   ❌ Not reachable"

echo "4. Caddy can read site:"
sudo -u caddy test -r /home/debian/hugs/public/index.html && echo "   ✅ Readable" || echo "   ❌ Permission denied"

echo "5. Git remote:"
cd /home/debian/hugs && git remote get-url origin 2>/dev/null || echo "   ❌ No remote"

echo "6. Latest commit:"
cd /home/debian/hugs && git log --oneline -1

echo "7. Hugo version:"
hugo version 2>/dev/null | head -1 || echo "   ❌ Not installed"

echo "8. Last deploy:"
tail -1 /var/log/hugo-deploy.log 2>/dev/null || echo "   No log found"

echo ""
echo "=== Done ==="
```

```bash
chmod +x /home/debian/hugs/diagnose.sh
```

Run anytime:

```bash
~/hugs/diagnose.sh
```
