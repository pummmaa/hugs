#!/bin/bash
set -euo pipefail

SITE_DIR="/home/debian/hugs"
LOG="/var/log/hugo-deploy.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deploy triggered" >> "$LOG"

cd "$SITE_DIR"

# Pull latest from GitHub
git fetch origin main
git reset --hard origin/main
git submodule update --init --recursive

# Build
hugo --minify --gc 2>> "$LOG"

# Fix permissions on generated files
chown -R user:webdata "$SITE_DIR/public"
find "$SITE_DIR/public" -type d -exec chmod 2750 {} \;
find "$SITE_DIR/public" -type f -exec chmod 640 {} \;

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deploy complete" >> "$LOG"
