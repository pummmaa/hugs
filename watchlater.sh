#!/bin/bash
set -euo pipefail

SITE_DIR="/home/debian/hugs"
WATCHFILE="$SITE_DIR/content/watchlater/_index.md"

# Prompt for video URL
read -p "🔗 Paste video URL: " URL

# Try to fetch the video title automatically
TITLE=""
if command -v curl &>/dev/null; then
    TITLE=$(curl -sL "$URL" | grep -oP '(?<=<title>).*?(?=</title>)' | head -1 | sed 's/ - YouTube//' | sed 's/ - Invidious//' | sed 's/&amp;/\&/g' | sed 's/&#39;/'"'"'/g' | xargs)
fi

# If auto-fetch failed or is empty, ask manually
if [ -z "$TITLE" ]; then
    read -p "📝 Video title: " TITLE
else
    echo "📝 Title detected: $TITLE"
    read -p "   Keep this title? (Enter=yes, or type new): " NEW_TITLE
    if [ -n "$NEW_TITLE" ]; then
        TITLE="$NEW_TITLE"
    fi
fi

# Ask for category
echo ""
echo "📂 Categories:"
echo "   1) Linux"
echo "   2) DevOps"
echo "   3) Programming"
echo "   4) Networking"
echo "   5) General"
echo "   6) Other (type your own)"
read -p "   Choose (1-6): " CAT_CHOICE

case $CAT_CHOICE in
    1) CATEGORY="Linux" ;;
    2) CATEGORY="DevOps" ;;
    3) CATEGORY="Programming" ;;
    4) CATEGORY="Networking" ;;
    5) CATEGORY="General" ;;
    6) read -p "   Enter category name: " CATEGORY ;;
    *) CATEGORY="General" ;;
esac

# Optional: add a note
read -p "💬 Note (optional, press Enter to skip): " NOTE

# Build the entry
DATE=$(date '+%Y-%m-%d')
ENTRY="- [$TITLE]($URL)"
if [ -n "$NOTE" ]; then
    ENTRY="$ENTRY — $NOTE"
fi
ENTRY="$ENTRY (added $DATE)"

# Check if category section exists in the file
if grep -q "^## $CATEGORY" "$WATCHFILE"; then
    # Append under existing category (after the ## heading)
    sed -i "/^## $CATEGORY/a\\$ENTRY" "$WATCHFILE"
else
    # Add new category section at the end
    echo "" >> "$WATCHFILE"
    echo "## $CATEGORY" >> "$WATCHFILE"
    echo "" >> "$WATCHFILE"
    echo "$ENTRY" >> "$WATCHFILE"
fi

echo ""
echo "✅ Added to Watch Later:"
echo "   $ENTRY"
echo "   Category: $CATEGORY"
echo ""

# Ask to push
read -p "🚀 Push to GitHub now? (y/n): " PUSH
if [[ "$PUSH" =~ ^[Yy]$ ]]; then
    cd "$SITE_DIR"
    git add .
    git commit -m "Add video: $TITLE"
    git push
    echo "✅ Pushed! Site will auto-rebuild."
else
    echo "ℹ️  Not pushed. Run 'git add . && git commit -m \"msg\" && git push' when ready."
fi
