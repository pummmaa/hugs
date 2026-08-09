#!/bin/bash
cd /home/debian/hugs
hugo --minify --gc
chown -R debian:webdata /home/debian/hugs/public
find /home/debian/hugs/public -type d -exec chmod 2750 {} \;
find /home/debian/hugs/public -type f -exec chmod 640 {} \;
echo "✅ Site rebuilt"
