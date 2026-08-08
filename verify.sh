#!/bin/bash

echo "=== Hugo + Caddy Permissions Verification ==="
echo ""

echo "1. /home/debian traversal (caddy):"
sudo -u caddy test -x /home/debian && echo "   ✅ PASS" || echo "   ❌ FAIL → chmod 711 /home/debian"

echo "2. /home/debian/hugs traversal (caddy):"
sudo -u caddy test -x /home/debian/hugs && echo "   ✅ PASS" || echo "   ❌ FAIL → check group perms"

echo "3. /home/debian/hugs/public readable (caddy):"
sudo -u caddy test -r /home/debian/hugs/public/index.html 2>/dev/null && echo "   ✅ PASS" || echo "   ❌ FAIL → run hugo --minify first, then check perms"

echo "4. caddy in webdata group:"
groups caddy 2>/dev/null | grep -q webdata && echo "   ✅ PASS" || echo "   ❌ FAIL → sudo usermod -aG webdata caddy && restart caddy"

echo "5. debian in webdata group:"
groups debian 2>/dev/null | grep -q webdata && echo "   ✅ PASS" || echo "   ❌ FAIL → sudo usermod -aG webdata debian"

echo "6. Caddy service running:"
systemctl is-active caddy >/dev/null 2>&1 && echo "   ✅ PASS" || echo "   ❌ FAIL → sudo systemctl start caddy"

echo "7. ProtectHome check:"
systemctl cat caddy 2>/dev/null | grep -q "ProtectHome=true" && echo "   ⚠️  ProtectHome=true — needs override (see Section 10 Step 6)" || echo "   ✅ PASS (not blocking)"

echo "8. Setgid on public/:"
stat -c "%a" /home/debian/hugs/public 2>/dev/null | grep -q "^2" && echo "   ✅ PASS" || echo "   ❌ FAIL → chmod g+s /home/debian/hugs/public"

echo "9. Hugo installed:"
which hugo >/dev/null 2>&1 && echo "   ✅ PASS ($(hugo version 2>&1 | grep -oP 'v[\d.]+' | head -1))" || echo "   ❌ FAIL → install hugo extended"

echo "10. Git remote:"
cd /home/debian/hugs 2>/dev/null && git remote get-url origin 2>/dev/null && echo "   ✅ PASS" || echo "   ❌ FAIL → git remote add origin ..."

echo "11. Webhook service (if using Option B):"
systemctl is-active webhook >/dev/null 2>&1 && echo "   ✅ PASS" || echo "   ⚠️  Not running (OK if using GitHub Actions)"

echo ""
echo "=== Done ==="
