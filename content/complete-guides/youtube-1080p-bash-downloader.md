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

A simple Bash script that uses **yt-dlp** and **FFmpeg** to download YouTube videos in the best available quality up to **1080p**, including the best available audio.

The script prompts you to paste a YouTube video URL and automatically downloads and merges the video and audio into an MP4 file.

---

## Features

* Downloads YouTube videos up to **1080p**
* Selects the **best available video quality**
* Selects the **best available audio**
* Automatically merges video and audio using FFmpeg
* Saves the result as an **MP4**
* Embeds the video's thumbnail
* Embeds available metadata
* Displays download progress
* Simple interactive URL prompt

---

## Requirements

The script requires:

* `yt-dlp`
* `ffmpeg`
* Bash

### Arch Linux

Install both dependencies with:

```bash
sudo pacman -S yt-dlp ffmpeg
```

### Fedora

```bash
sudo dnf install yt-dlp ffmpeg
```

### Debian / Ubuntu

```bash
sudo apt install yt-dlp ffmpeg
```

---

# Create the Script

Create a new file called:

```text
youtube-download.sh
```

You can create it with:

```bash
nano youtube-download.sh
```

Paste the following script:

```bash
#!/usr/bin/env bash

set -e

# Check dependencies
for cmd in yt-dlp ffmpeg; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed."
        echo "Please install yt-dlp and ffmpeg first."
        exit 1
    fi
done

echo "========================================"
echo "        YouTube 1080p Downloader"
echo "========================================"
echo

read -rp "Paste YouTube video URL: " URL

if [[ -z "$URL" ]]; then
    echo "Error: No URL provided."
    exit 1
fi

echo
echo "Downloading..."
echo

yt-dlp \
    --format "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
    --merge-output-format mp4 \
    --output "%(title)s.%(ext)s" \
    --embed-thumbnail \
    --embed-metadata \
    --progress \
    "$URL"

echo
echo "========================================"
echo "Download complete!"
echo "========================================"
```

---

# Make the Script Executable

After saving the file, make it executable:

```bash
chmod +x youtube-download.sh
```

You can verify the permissions with:

```bash
ls -l youtube-download.sh
```

You should see executable permissions similar to:

```text
-rwxr-xr-x 1 user user ... youtube-download.sh
```

---

# Run the Downloader

Execute the script:

```bash
./youtube-download.sh
```

The script will display:

```text
========================================
        YouTube 1080p Downloader
========================================

Paste YouTube video URL:
```

Paste your YouTube URL and press **Enter**:

```text
https://www.youtube.com/watch?v=XXXXXXXX
```

The download will then begin.

When finished, you'll see:

```text
========================================
Download complete!
========================================
```

The downloaded video will be saved in the **current directory**.

---

# How Video Quality Is Selected

The most important part of the script is:

```bash
--format "bestvideo[height<=1080]+bestaudio/best[height<=1080]"
```

This tells `yt-dlp` to select:

1. The best available video stream with a maximum height of **1080p**
2. The best available audio stream
3. Merge the streams together
4. Fall back to a combined video/audio stream if separate streams aren't available

## Why use separate video and audio streams?

YouTube frequently provides high-quality video and audio as separate streams.

For example:

```text
Video:
1080p H.264/AV1/VP9

Audio:
Opus/AAC
```

`yt-dlp` downloads both streams and uses FFmpeg to combine them into a single video file.

This generally provides better quality than requesting a pre-combined stream.

---

# Output Format

The script uses:

```bash
--merge-output-format mp4
```

This tells `yt-dlp` to produce an MP4 container when merging the downloaded streams.

The filename is generated using:

```bash
--output "%(title)s.%(ext)s"
```

For example:

```text
My YouTube Video.mp4
```

---

# Metadata and Thumbnail

The script also includes:

```bash
--embed-thumbnail
--embed-metadata
```

These options attempt to embed:

* Video thumbnail
* Title
* Artist/uploader information
* Other available metadata

into the downloaded file.

---

# Dependency Check

Before downloading, the script checks whether `yt-dlp` and `ffmpeg` are installed:

```bash
for cmd in yt-dlp ffmpeg; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed."
        echo "Please install yt-dlp and ffmpeg first."
        exit 1
    fi
done
```

If one of the programs is missing, the script exits instead of failing halfway through the download.

---

# Updating yt-dlp

It is a good idea to keep `yt-dlp` updated because YouTube can change how its video delivery works.

Depending on your distribution, update it through your package manager.

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

You can check the installed version with:

```bash
yt-dlp --version
```

---

# Troubleshooting

## `yt-dlp: command not found`

Install `yt-dlp` using your distribution's package manager.

For example, Arch Linux:

```bash
sudo pacman -S yt-dlp
```

---

## `ffmpeg: command not found`

Install FFmpeg.

Arch Linux:

```bash
sudo pacman -S ffmpeg
```

Fedora:

```bash
sudo dnf install ffmpeg
```

Debian/Ubuntu:

```bash
sudo apt install ffmpeg
```

---

## Video Is Not Available in 1080p

The script requests:

```text
best video <= 1080p
```

If the original video is only available in 720p, for example, yt-dlp will automatically select the best available quality below 1080p.

It will **not upscale** a lower-resolution video to 1080p.

---

## Check Available Formats

If you want to see every format available for a video, run:

```bash
yt-dlp -F "YOUTUBE_URL"
```

For example:

```bash
yt-dlp -F "https://www.youtube.com/watch?v=XXXXXXXX"
```

This is useful for troubleshooting quality or codec issues.

---

# Optional: Install the Script Globally

If you want to run the downloader from anywhere, you can place it in your personal `bin` directory.

Create the directory if necessary:

```bash
mkdir -p ~/.local/bin
```

Move the script:

```bash
mv youtube-download.sh ~/.local/bin/youtube-download
```

Make sure it is executable:

```bash
chmod +x ~/.local/bin/youtube-download
```

You can then run:

```bash
youtube-download
```

from any directory.

If `~/.local/bin` isn't in your `$PATH`, add it to your shell configuration.

For Bash:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

For Zsh:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

# Complete Workflow

After everything is installed, the normal workflow is simply:

```bash
./youtube-download.sh
```

Then:

```text
Paste YouTube video URL:
```

Paste the URL:

```text
https://www.youtube.com/watch?v=XXXXXXXX
```

The script will:

```text
YouTube URL
     │
     ▼
   yt-dlp
     │
     ├── Best video ≤ 1080p
     │
     └── Best available audio
             │
             ▼
           FFmpeg
             │
             ▼
        MP4 video file
```

---

## Script Summary

| Feature             | Configuration      |
| ------------------- | ------------------ |
| Maximum resolution  | 1080p              |
| Video               | Best available     |
| Audio               | Best available     |
| Container           | MP4                |
| Video/audio merging | FFmpeg             |
| Thumbnail           | Embedded           |
| Metadata            | Embedded           |
| Filename            | YouTube title      |
| URL input           | Interactive prompt |
| Progress            | Enabled            |
| Dependency check    | Enabled            |

> **Note:** Only download videos you have permission to download and comply with YouTube's terms and applicable copyright laws.

