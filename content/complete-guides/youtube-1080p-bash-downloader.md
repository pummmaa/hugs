---
title: "youtube-1080p-bash-downloader"
date: 2026-08-11T05:46:11Z
lastmod: 2026-08-11T05:46:11Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# YouTube 1080p Downloader — Bash Script

A Bash script using **yt-dlp** and **FFmpeg** to download YouTube videos in the best available quality up to **1080p**, with the best available audio.

The script also integrates with the **COSMIC desktop notification system**:

* 🔔 Notification when a download completes
* ❌ Notification when a download fails
* Error message included in the failure notification
* Interactive YouTube URL prompt
* Automatic video/audio merging
* MP4 output
* Thumbnail and metadata embedding

> **Note:** Only download videos you have permission to download and comply with YouTube's terms and applicable copyright laws.

---

# Requirements

The script requires:

* `yt-dlp`
* `ffmpeg`
* `libnotify`
* Bash

The `libnotify` package provides the `notify-send` command used to communicate with the desktop notification system.

---

# Installing Dependencies

## Arch Linux / COSMIC

Install everything with:

```bash
sudo pacman -S yt-dlp ffmpeg libnotify
```

Verify the notification command:

```bash
notify-send "Test Notification" "COSMIC notifications are working!"
```

You should receive a desktop notification.

---

## Fedora / COSMIC

```bash
sudo dnf install yt-dlp ffmpeg libnotify
```

Test it:

```bash
notify-send "Test Notification" "COSMIC notifications are working!"
```

---

## Debian / Ubuntu

```bash
sudo apt install yt-dlp ffmpeg libnotify
```

Test:

```bash
notify-send "Test Notification" "Desktop notifications are working!"
```

---

# Create the Script

Create the script:

```bash
nano youtube-download.sh
```

Paste the following:

```bash
#!/usr/bin/env bash

set -o pipefail

# ============================================================
# YouTube 1080p Downloader
# ============================================================

APP_NAME="YouTube Downloader"

# ------------------------------------------------------------
# Notification function
# ------------------------------------------------------------

send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    if command -v notify-send &>/dev/null; then
        notify-send \
            --app-name="$APP_NAME" \
            --urgency="$urgency" \
            "$title" \
            "$message"
    fi
}

# ------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------

MISSING_DEPS=()

for cmd in yt-dlp ffmpeg notify-send; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "Error: Missing required dependencies:"
    printf '  - %s\n' "${MISSING_DEPS[@]}"
    echo

    send_notification \
        "YouTube Downloader Error" \
        "Missing dependencies: ${MISSING_DEPS[*]}" \
        "critical"

    exit 1
fi

# ------------------------------------------------------------
# Display header
# ------------------------------------------------------------

echo "========================================"
echo "        YouTube 1080p Downloader"
echo "========================================"
echo

# ------------------------------------------------------------
# Ask for URL
# ------------------------------------------------------------

read -rp "Paste YouTube video URL: " URL

if [[ -z "$URL" ]]; then
    echo "Error: No URL provided."

    send_notification \
        "YouTube Downloader Error" \
        "No YouTube URL was provided." \
        "critical"

    exit 1
fi

echo
echo "Downloading..."
echo

# ------------------------------------------------------------
# Download
# ------------------------------------------------------------

ERROR_LOG=$(mktemp)

if yt-dlp \
    --format "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
    --merge-output-format mp4 \
    --output "%(title)s.%(ext)s" \
    --embed-thumbnail \
    --embed-metadata \
    --progress \
    "$URL" 2>&1 | tee "$ERROR_LOG"; then

    # Try to extract the downloaded filename
    VIDEO_TITLE=$(yt-dlp \
        --get-title \
        --no-warnings \
        "$URL" 2>/dev/null || echo "Video")

    echo
    echo "========================================"
    echo "Download complete!"
    echo "========================================"

    send_notification \
        "Download Complete" \
        "$VIDEO_TITLE has finished downloading." \
        "normal"

    rm -f "$ERROR_LOG"

    exit 0

else

    # Get the last few lines of the error output
    ERROR_MESSAGE=$(tail -n 5 "$ERROR_LOG" | tr '\n' ' ')

    echo
    echo "========================================"
    echo "Download failed!"
    echo "========================================"
    echo
    echo "Error:"
    cat "$ERROR_LOG"

    # Keep the notification reasonably short
    if [[ ${#ERROR_MESSAGE} -gt 500 ]]; then
        ERROR_MESSAGE="${ERROR_MESSAGE:0:500}..."
    fi

    send_notification \
        "Download Failed" \
        "$ERROR_MESSAGE" \
        "critical"

    rm -f "$ERROR_LOG"

    exit 1

fi
```

---

# Make the Script Executable

Run:

```bash
chmod +x youtube-download.sh
```

Then execute:

```bash
./youtube-download.sh
```

---

# How Notifications Work

The script uses:

```bash
notify-send
```

to communicate with the Linux desktop notification system.

COSMIC provides desktop notifications through the standard Linux desktop notification infrastructure, so the script doesn't need to interact directly with COSMIC.

The notification function is:

```bash
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    if command -v notify-send &>/dev/null; then
        notify-send \
            --app-name="$APP_NAME" \
            --urgency="$urgency" \
            "$title" \
            "$message"
    fi
}
```

This keeps the notification code in one place and makes it easy to reuse.

---

# Successful Download Notification

When `yt-dlp` successfully completes the download, the script sends:

```bash
send_notification \
    "Download Complete" \
    "$VIDEO_TITLE has finished downloading." \
    "normal"
```

You'll receive a notification similar to:

```text
┌──────────────────────────────────────┐
│ YouTube Downloader                   │
│                                      │
│ Download Complete                    │
│ My YouTube Video has finished        │
│ downloading.                         │
└──────────────────────────────────────┘
```

This is especially useful when downloading a long video and you don't want to keep the terminal open.

---

# Failed Download Notification

If `yt-dlp` returns an error, the script captures the error output:

```bash
ERROR_LOG=$(mktemp)
```

The output is simultaneously displayed in the terminal and saved to the temporary error file:

```bash
2>&1 | tee "$ERROR_LOG"
```

If the command fails, the script extracts the last five lines:

```bash
ERROR_MESSAGE=$(tail -n 5 "$ERROR_LOG" | tr '\n' ' ')
```

It then sends a critical notification:

```bash
send_notification \
    "Download Failed" \
    "$ERROR_MESSAGE" \
    "critical"
```

You'll receive something similar to:

```text
┌──────────────────────────────────────┐
│ YouTube Downloader                   │
│                                      │
│ Download Failed                      │
│ ERROR: Video unavailable...          │
└──────────────────────────────────────┘
```

The complete error is still displayed in the terminal.

---

# Why Use `tee`?

The download command uses:

```bash
2>&1 | tee "$ERROR_LOG"
```

This does two things simultaneously:

```text
                 ┌──► Terminal
yt-dlp output ───┤
                 └──► Temporary error log
```

This means you can watch the download normally while the script keeps a copy of the output in case something goes wrong.

---

# Notification Urgency

The script uses three notification urgency levels where appropriate:

### Normal

Used for successful downloads:

```bash
--urgency="normal"
```

### Critical

Used for failures:

```bash
--urgency="critical"
```

This makes download failures more noticeable.

---

# Testing COSMIC Notifications

Before using the downloader, test the notification system manually:

```bash
notify-send \
    --app-name="YouTube Downloader" \
    --urgency="normal" \
    "Download Complete" \
    "This is a test notification."
```

You should see the notification appear through COSMIC.

You can also test a critical notification:

```bash
notify-send \
    --app-name="YouTube Downloader" \
    --urgency="critical" \
    "Download Failed" \
    "This is a test error notification."
```

If both appear, the notification portion of the script is working.

---

# Download Workflow

The complete workflow looks like this:

```text
┌───────────────────────┐
│ Run Script            │
│ ./youtube-download.sh │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ Paste YouTube URL     │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ Check Dependencies    │
│ yt-dlp                │
│ ffmpeg                │
│ notify-send           │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ Download Video        │
│ Best video ≤ 1080p    │
│ Best available audio  │
└───────────┬───────────┘
            │
            ▼
       ┌────┴────┐
       │         │
     Success   Failure
       │         │
       ▼         ▼
┌────────────┐ ┌────────────┐
│ MP4 Saved  │ │ Error Log  │
└─────┬──────┘ └─────┬──────┘
      │              │
      ▼              ▼
┌────────────┐ ┌────────────┐
│ COSMIC     │ │ COSMIC     │
│ Notification│ │ Notification│
│ Complete   │ │ Failed     │
└────────────┘ └────────────┘
```

---

# Installing the Script Globally

If you want to run the downloader from anywhere, create a local binary directory:

```bash
mkdir -p ~/.local/bin
```

Move the script:

```bash
mv youtube-download.sh ~/.local/bin/youtube-download
```

Make it executable:

```bash
chmod +x ~/.local/bin/youtube-download
```

You can now run:

```bash
youtube-download
```

from any directory.

---

# Add `~/.local/bin` to PATH

If the command isn't found, add `~/.local/bin` to your PATH.

## Bash

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Zsh

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Verify:

```bash
command -v youtube-download
```

You should get something similar to:

```text
/home/username/.local/bin/youtube-download
```

---

# Usage

Once installed globally, simply run:

```bash
youtube-download
```

Paste your URL:

```text
Paste YouTube video URL: https://www.youtube.com/watch?v=XXXXXXXX
```

The script downloads:

```text
Best video ≤ 1080p
        +
Best available audio
        ↓
      FFmpeg
        ↓
      MP4 file
```

Then COSMIC displays:

```text
Download Complete
```

or, if something went wrong:

```text
Download Failed
<error message>
```

---

# Checking Available Formats

If you want to see all formats available for a video:

```bash
yt-dlp -F "YOUTUBE_URL"
```

Example:

```bash
yt-dlp -F "https://www.youtube.com/watch?v=XXXXXXXX"
```

This can help troubleshoot videos that don't provide the expected resolution or codec.

---

# Updating yt-dlp

YouTube periodically changes how its video delivery works, so keeping `yt-dlp` updated is recommended.

### Arch Linux

```bash
sudo pacman -Syu yt-dlp
```

### Fedora

```bash
sudo dnf upgrade yt-dlp
```

### Debian / Ubuntu

```bash
sudo apt update
sudo apt upgrade yt-dlp
```

Check the installed version:

```bash
yt-dlp --version
```

---

# Dependency Summary

| Dependency    | Purpose                            |
| ------------- | ---------------------------------- |
| `bash`        | Runs the script                    |
| `yt-dlp`      | Downloads YouTube video/audio      |
| `ffmpeg`      | Merges video and audio             |
| `libnotify`   | Provides `notify-send`             |
| `notify-send` | Sends COSMIC desktop notifications |

---

# Quick Installation — Arch Linux

For a COSMIC/Arch Linux system, everything can be installed with:

```bash
sudo pacman -S yt-dlp ffmpeg libnotify
```

Then create and install the script:

```bash
mkdir -p ~/.local/bin

nano ~/.local/bin/youtube-download

chmod +x ~/.local/bin/youtube-download
```

Test notifications:

```bash
notify-send "YouTube Downloader" "Notification system is working!"
```

Then run:

```bash
youtube-download
```

---

# Complete Script

For convenience, the complete script is reproduced below:

```bash
#!/usr/bin/env bash

set -o pipefail

APP_NAME="YouTube Downloader"

send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    if command -v notify-send &>/dev/null; then
        notify-send \
            --app-name="$APP_NAME" \
            --urgency="$urgency" \
            "$title" \
            "$message"
    fi
}

MISSING_DEPS=()

for cmd in yt-dlp ffmpeg notify-send; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "Error: Missing required dependencies:"
    printf '  - %s\n' "${MISSING_DEPS[@]}"
    echo

    send_notification \
        "YouTube Downloader Error" \
        "Missing dependencies: ${MISSING_DEPS[*]}" \
        "critical"

    exit 1
fi

echo "========================================"
echo "        YouTube 1080p Downloader"
echo "========================================"
echo

read -rp "Paste YouTube video URL: " URL

if [[ -z "$URL" ]]; then
    echo "Error: No URL provided."

    send_notification \
        "YouTube Downloader Error" \
        "No YouTube URL was provided." \
        "critical"

    exit 1
fi

echo
echo "Downloading..."
echo

ERROR_LOG=$(mktemp)

if yt-dlp \
    --format "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
    --merge-output-format mp4 \
    --output "%(title)s.%(ext)s" \
    --embed-thumbnail \
    --embed-metadata \
    --progress \
    "$URL" 2>&1 | tee "$ERROR_LOG"; then

    VIDEO_TITLE=$(yt-dlp \
        --get-title \
        --no-warnings \
        "$URL" 2>/dev/null || echo "Video")

    echo
    echo "========================================"
    echo "Download complete!"
    echo "========================================"

    send_notification \
        "Download Complete" \
        "$VIDEO_TITLE has finished downloading." \
        "normal"

    rm -f "$ERROR_LOG"

    exit 0

else

    ERROR_MESSAGE=$(tail -n 5 "$ERROR_LOG" | tr '\n' ' ')

    echo
    echo "========================================"
    echo "Download failed!"
    echo "========================================"
    echo
    echo "Error:"
    cat "$ERROR_LOG"

    if [[ ${#ERROR_MESSAGE} -gt 500 ]]; then
        ERROR_MESSAGE="${ERROR_MESSAGE:0:500}..."
    fi

    send_notification \
        "Download Failed" \
        "$ERROR_MESSAGE" \
        "critical"

    rm -f "$ERROR_LOG"

    exit 1

fi
```

