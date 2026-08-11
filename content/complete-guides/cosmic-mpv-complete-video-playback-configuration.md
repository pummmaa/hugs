---
title: "cosmic-mpv-complete-video-playback-configuration"
date: 2026-08-11T06:23:52Z
lastmod: 2026-08-11T06:23:52Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# COSMIC + mpv Complete Video Player Configuration

A lightweight `mpv` configuration for Linux/COSMIC designed to provide a convenient local video-player experience without requiring a media server such as Jellyfin or Plex.

This setup provides:

* Recursive folder playback
* Automatic playlist creation
* Playback-position persistence
* Watch-later support
* Detached mpv launching from Zsh
* COSMIC-friendly desktop playback
* Hardware acceleration
* Playlist navigation
* Shuffle and playlist looping
* Screenshot support
* Subtitle handling
* Audio-track switching
* Custom keyboard shortcuts

---

# Table of Contents

1. [Requirements](#requirements)
2. [Install mpv](#install-mpv)
3. [Create mpv Configuration Directory](#create-mpv-configuration-directory)
4. [Create mpv.conf](#create-mpvconf)
5. [Create input.conf](#create-inputconf)
6. [Configure Zsh mpvf Function](#configure-zsh-mpvf-function)
7. [Using mpvf](#using-mpvf)
8. [Playing an Entire Folder](#playing-an-entire-folder)
9. [Recursive Folder Playback](#recursive-folder-playback)
10. [Automatic Resume](#automatic-resume)
11. [Watch-Later Files](#watch-later-files)
12. [Playlist Controls](#playlist-controls)
13. [Viewing the Playlist](#viewing-the-playlist)
14. [Shuffle](#shuffle)
15. [Playlist Looping](#playlist-looping)
16. [Subtitles](#subtitles)
17. [Audio Tracks](#audio-tracks)
18. [Screenshots](#screenshots)
19. [Fullscreen](#fullscreen)
20. [Playback Speed](#playback-speed)
21. [Testing the Configuration](#testing-the-configuration)
22. [Troubleshooting](#troubleshooting)
23. [Final Directory Structure](#final-directory-structure)
24. [Daily Usage](#daily-usage)

---

# Requirements

The setup requires:

* Linux
* COSMIC Desktop
* Zsh
* mpv
* GPU with supported hardware acceleration

The configuration does not require a media server.

---

# Install mpv

## Arch Linux

```bash
sudo pacman -S mpv
```

## Fedora

```bash
sudo dnf install mpv
```

## Debian / Ubuntu

```bash
sudo apt install mpv
```

Verify:

```bash
mpv --version
```

---

# Create mpv Configuration Directory

Create the mpv configuration directory:

```bash
mkdir -p ~/.config/mpv
```

Create the screenshot directory:

```bash
mkdir -p ~/Pictures/mpv
```

Your configuration will eventually look like:

```text
~/.config/mpv/
├── mpv.conf
└── input.conf
```

---

# Create mpv.conf

Open the configuration:

```bash
nano ~/.config/mpv/mpv.conf
```

Add:

```ini
##############################################
# COSMIC / MPV CONFIGURATION
##############################################

# --------------------------------------------
# Playback
# --------------------------------------------

# Automatically save playback position when
# quitting.
save-position-on-quit=yes

# Resume from previously saved position.
resume-playback=yes

# Write the original filename into the
# watch-later configuration.
write-filename-in-watch-later-config=yes

# Automatically create a playlist when opening
# a media file.
autocreate-playlist=same

# Do not keep the last video open after ending.
keep-open=no

# --------------------------------------------
# Video Output
# --------------------------------------------

# GPU video output.
vo=gpu-next

# Hardware decoding.
hwdec=auto-safe

# High-quality scaling.
scale=ewa_lanczossharp
cscale=ewa_lanczossharp

# Allow HDR metadata to influence output when
# supported.
target-colorspace-hint=yes

# --------------------------------------------
# Audio
# --------------------------------------------

# Client name reported to the audio system.
audio-client-name=mpv

# Keep audio pitch correct when changing speed.
audio-pitch-correction=yes

# --------------------------------------------
# On-Screen Controller
# --------------------------------------------

# Enable mpv's OSC.
osc=yes

# Show the OSC when moving the mouse.
osc-visibility=auto

# Show OSD information when seeking.
osd-on-seek=msg-bar

# --------------------------------------------
# OSD
# --------------------------------------------

# OSD information level.
osd-level=1

# Display messages for 2 seconds.
osd-duration=2000

# OSD font size.
osd-font-size=32

# --------------------------------------------
# Screenshots
# --------------------------------------------

screenshot-format=png

screenshot-directory=~/Pictures/mpv

# --------------------------------------------
# Subtitles
# --------------------------------------------

# Automatically search for external subtitles.
sub-auto=fuzzy

# Load embedded fonts when available.
embeddedfonts=yes

# --------------------------------------------
# Playlist
# --------------------------------------------

# Do not automatically loop playlists.
loop-playlist=no

# --------------------------------------------
# Performance
# --------------------------------------------

# Enable file caching.
cache=yes

# Do not use terminal output for normal mpv use.
terminal=no
```

Save with:

```text
Ctrl+O
Enter
Ctrl+X
```

---

# Create input.conf

Create the keyboard configuration:

```bash
nano ~/.config/mpv/input.conf
```

Add:

```text
##############################################
# COSMIC / MPV KEYBOARD CONFIGURATION
##############################################

# ============================================
# PLAYBACK
# ============================================

# Play / Pause
SPACE cycle pause

# ============================================
# PLAYLIST
# ============================================

# F8 = Display playlist
F8 show-text ${playlist}

# Ctrl+N = Next video
Ctrl+n playlist-next

# Ctrl+B = Previous video
Ctrl+b playlist-prev

# > = Next video
> playlist-next

# < = Previous video
< playlist-prev

# ============================================
# SHUFFLE
# ============================================

# Ctrl+S = Shuffle playlist
Ctrl+s playlist-shuffle
Ctrl+s show-text "Playlist shuffled"

# Ctrl+U = Restore playlist order
Ctrl+u playlist-unshuffle
Ctrl+u show-text "Playlist order restored"

# ============================================
# LOOP
# ============================================

# Ctrl+L = Toggle playlist loop
Ctrl+l cycle-values loop-playlist no inf

# ============================================
# PLAYLIST MANAGEMENT
# ============================================

# Ctrl+X = Remove current playlist entry
Ctrl+x playlist-remove current
Ctrl+x show-text "Removed current video"

# ============================================
# RESUME
# ============================================

# Shift+Q = Save position and quit
Shift+q quit-watch-later

# ============================================
# SEEKING
# ============================================

# Left / Right = 5 seconds
LEFT seek -5
RIGHT seek 5

# Shift + Left / Right = 30 seconds
Shift+LEFT seek -30
Shift+RIGHT seek 30

# Up / Down = 1 minute
UP seek 60
DOWN seek -60

# ============================================
# VOLUME
# ============================================

# Increase / decrease volume
+ add volume 5
- add volume -5

# Mute
m cycle mute

# ============================================
# SPEED
# ============================================

# Slow down playback
[ multiply speed 0.9091

# Speed up playback
] multiply speed 1.1

# Reset playback speed
BS set speed 1
BS show-text "Playback speed: 1x"

# ============================================
# VIDEO
# ============================================

# Fullscreen
f cycle fullscreen

# Reset video zoom/pan
Ctrl+f set video-zoom 0
Ctrl+f set video-pan-x 0
Ctrl+f set video-pan-y 0

# ============================================
# SUBTITLES
# ============================================

# Toggle subtitles
v cycle sub-visibility

# Cycle subtitle tracks
j cycle sub

# ============================================
# AUDIO
# ============================================

# Cycle audio tracks
Ctrl+a cycle audio

# ============================================
# INFORMATION
# ============================================

# Display statistics
i script-binding stats/display-stats

# ============================================
# SCREENSHOTS
# ============================================

# Screenshot
s screenshot

# ============================================
# QUIT
# ============================================

# Quit
q quit
```

Save and exit.

---

# Important Playlist Key

The default mpv configuration uses:

```text
F8
```

for displaying playlist information.

Do **not** use:

```text
Ctrl+H
```

for this purpose.

`Ctrl+H` is associated with other mpv functionality, including hardware-decoding controls depending on the current mpv configuration/version.

If `F8` does not work as expected, inspect your active key bindings with:

```bash
mpv --input-test
```

---

# Configure Zsh mpvf Function

The goal is to create a command called:

```bash
mpvf
```

that launches mpv independently from the terminal.

This allows you to do:

```bash
mpvf ~/Videos/
```

and then close the terminal without terminating mpv.

---

## Edit `.zshrc`

Open:

```bash
nano ~/.zshrc
```

### Important

If you previously created an alias such as:

```bash
alias mpvf='...'
```

remove it first.

Otherwise Zsh will produce:

```text
defining function based on alias `mpvf'
parse error near `()'
```

---

## Add the function

Add this to the bottom of `~/.zshrc`:

```bash
mpvf() {
    nohup mpv --directory-mode=recursive "$@" >/dev/null 2>&1 &!
}
```

Save the file.

Reload Zsh:

```bash
source ~/.zshrc
```

Or restart Zsh:

```bash
exec zsh
```

Verify:

```bash
type mpvf
```

You should see:

```text
mpvf is a shell function
```

---

# Using mpvf

You can now run:

```bash
mpvf ~/Videos/
```

Or:

```bash
mpvf ~/Videos/Movies/
```

Or:

```bash
mpvf ~/Videos/TV-Shows/
```

The terminal will immediately return to the prompt while mpv continues running.

You can close the terminal and mpv should continue playing.

---

# Playing an Entire Folder

Instead of specifying files individually:

```bash
mpv video1.mp4 video2.mp4 video3.mp4
```

you can simply use:

```bash
mpvf ~/Videos/
```

For example:

```text
Videos/
├── Video 01.mp4
├── Video 02.mp4
├── Video 03.mp4
├── Video 04.mp4
└── Video 05.mp4
```

Run:

```bash
mpvf ~/Videos/
```

mpv will create a playlist from the directory contents.

Playback becomes:

```text
Video 01
   ↓
Video 02
   ↓
Video 03
   ↓
Video 04
   ↓
Video 05
```

---

# Recursive Folder Playback

The `mpvf` function uses:

```bash
--directory-mode=recursive
```

This allows mpv to search through subdirectories.

For example:

```text
Videos/
├── Movies/
│   ├── Movie 1.mkv
│   └── Movie 2.mkv
│
├── TV Shows/
│   ├── Show A/
│   │   ├── Episode 01.mkv
│   │   └── Episode 02.mkv
│   │
│   └── Show B/
│       ├── Episode 01.mkv
│       └── Episode 02.mkv
│
└── YouTube/
    ├── Video 1.mp4
    └── Video 2.mp4
```

You can run:

```bash
mpvf ~/Videos/
```

and mpv can build a playlist from the media it finds.

---

# Automatic Resume

The configuration enables:

```ini
save-position-on-quit=yes
resume-playback=yes
```

This allows mpv to remember playback positions.

For example:

```text
Movie.mkv
```

You watch until:

```text
01:17:42
```

Then quit using:

```text
Shift+Q
```

When you open the same video again, mpv can resume around:

```text
01:17:42
```

This is particularly useful for:

* Movies
* TV episodes
* Lectures
* Tutorials
* Long YouTube downloads
* Audiobooks
* Documentaries

---

# Watch-Later Files

mpv stores playback state in its watch-later directory.

On Linux this is normally:

```bash
~/.local/state/mpv/watch_later/
```

Inspect it with:

```bash
ls -lah ~/.local/state/mpv/watch_later/
```

The configuration also enables:

```ini
write-filename-in-watch-later-config=yes
```

This makes the watch-later files easier to identify because mpv records the original media filename inside them.

---

# Playlist Controls

The customized keyboard controls are:

| Key       | Action                       |
| --------- | ---------------------------- |
| `F8`      | Display playlist             |
| `Ctrl+N`  | Next video                   |
| `Ctrl+B`  | Previous video               |
| `>`       | Next video                   |
| `<`       | Previous video               |
| `Ctrl+S`  | Shuffle playlist             |
| `Ctrl+U`  | Restore playlist order       |
| `Ctrl+L`  | Toggle playlist looping      |
| `Ctrl+X`  | Remove current playlist item |
| `Space`   | Play/Pause                   |
| `q`       | Quit                         |
| `Shift+Q` | Save position and quit       |

---

# Viewing the Playlist

While mpv is playing, press:

```text
F8
```

The playlist will be displayed through mpv's OSD.

For example:

```text
Playlist

  Episode 01.mkv
  Episode 02.mkv
> Episode 03.mkv
  Episode 04.mkv
  Episode 05.mkv
```

The currently playing item is marked.

---

# Next / Previous Video

Next:

```text
Ctrl+N
```

or:

```text
>
```

Previous:

```text
Ctrl+B
```

or:

```text
<
```

This makes it easy to navigate through TV episodes or a folder of videos.

---

# Shuffle

Press:

```text
Ctrl+S
```

The playlist will be shuffled.

You can restore the playlist order with:

```text
Ctrl+U
```

---

# Playlist Looping

Press:

```text
Ctrl+L
```

This toggles playlist looping.

Normal:

```text
Episode 1
   ↓
Episode 2
   ↓
Episode 3
   ↓
Stop
```

Loop:

```text
Episode 1
   ↓
Episode 2
   ↓
Episode 3
   ↓
Episode 1
   ↓
...
```

---

# Playlist Management

Remove the currently playing entry:

```text
Ctrl+X
```

This removes the item from the current mpv playlist.

It does **not** delete the actual video file from disk.

---

# Subtitles

Toggle subtitles:

```text
v
```

Cycle subtitle tracks:

```text
j
```

The configuration also enables:

```ini
sub-auto=fuzzy
```

This allows mpv to automatically find matching external subtitle files.

For example:

```text
Movie.mkv
Movie.en.srt
```

---

# Audio Tracks

Cycle audio tracks:

```text
Ctrl+A
```

This is useful for files containing multiple audio streams.

For example:

```text
English
Spanish
Japanese
Commentary
```

---

# Fullscreen

Press:

```text
f
```

to toggle fullscreen.

---

# Playback Speed

Slow down playback:

```text
[
```

Speed up playback:

```text
]
```

Reset to normal speed:

```text
Backspace
```

---

# Seeking

Basic seeking:

```text
Left Arrow   → 5 seconds backward
Right Arrow  → 5 seconds forward
```

Larger jumps:

```text
Shift + Left   → 30 seconds backward
Shift + Right  → 30 seconds forward
```

Large jumps:

```text
Up Arrow    → 1 minute forward
Down Arrow  → 1 minute backward
```

---

# Volume

Increase volume:

```text
+
```

Decrease volume:

```text
-
```

Mute:

```text
m
```

---

# Screenshots

Screenshots are configured to use PNG:

```ini
screenshot-format=png
```

and saved to:

```text
~/Pictures/mpv/
```

Press:

```text
s
```

while a video is playing.

Screenshots will appear in:

```bash
~/Pictures/mpv/
```

---

# Video Information

Press:

```text
i
```

to display mpv's statistics.

This can be useful for checking:

* Video codec
* Resolution
* FPS
* Hardware decoding
* Bitrate
* Audio codec
* Dropped frames
* Cache information

---

# Hardware Acceleration

The configuration uses:

```ini
vo=gpu-next
hwdec=auto-safe
```

mpv will attempt to use hardware decoding when supported.

You can test this by pressing:

```text
i
```

while a video is playing.

You can also run:

```bash
mpv --hwdec=auto-safe video.mkv
```

---

# Testing Hardware Decoding

Run:

```bash
mpv --hwdec=auto-safe ~/Videos/test.mkv
```

Then press:

```text
i
```

Look for information indicating that hardware decoding is being used.

If you encounter graphical issues, temporarily test software decoding:

```bash
mpv --hwdec=no ~/Videos/test.mkv
```

If the video works correctly with hardware decoding disabled, your GPU/driver configuration may need attention.

---

# Testing the Configuration

Before using the detached `mpvf` command, test mpv normally:

```bash
mpv ~/Videos/
```

Check the playlist:

```text
F8
```

Test playback:

```text
Space
```

Test next video:

```text
Ctrl+N
```

Test previous video:

```text
Ctrl+B
```

Test fullscreen:

```text
f
```

Test screenshot:

```text
s
```

Test resume:

```text
Shift+Q
```

Then open the same video again.

---

# Test mpvf

After confirming normal mpv operation, test:

```bash
mpvf ~/Videos/
```

The terminal should immediately return to the prompt.

For example:

```text
$ mpvf ~/Videos/

$
```

mpv should remain open.

You can then close the terminal.

The mpv window should continue playing.

---

# Troubleshooting

## `mpvf` says it is an alias

Run:

```bash
type mpvf
```

If you see:

```text
mpvf is an alias
```

remove the alias from:

```bash
~/.zshrc
```

Then keep only:

```bash
mpvf() {
    nohup mpv --directory-mode=recursive "$@" >/dev/null 2>&1 &!
}
```

Reload:

```bash
source ~/.zshrc
```

---

## Zsh says:

```text
defining function based on alias `mpvf'
parse error near `()'
```

This means an alias named `mpvf` already exists.

Find it:

```bash
grep -n "mpvf" ~/.zshrc
```

Remove the old alias.

You should have only:

```bash
mpvf() {
    nohup mpv --directory-mode=recursive "$@" >/dev/null 2>&1 &!
}
```

---

## `F8` Doesn't Show the Playlist

First check whether another configuration has overridden the key.

Run:

```bash
grep -n "F8" ~/.config/mpv/input.conf
```

You should have:

```text
F8 show-text ${playlist}
```

You can also temporarily remove the custom `input.conf` and test the mpv default behavior.

---

## mpv Doesn't Resume Videos

Check:

```bash
grep -E "save-position|resume-playback" ~/.config/mpv/mpv.conf
```

You should see:

```text
save-position-on-quit=yes
resume-playback=yes
```

Also make sure you quit with:

```text
Shift+Q
```

instead of killing the process.

Check the watch-later directory:

```bash
ls -lah ~/.local/state/mpv/watch_later/
```

---

## mpv Closes When the Terminal Closes

Make sure your Zsh function contains:

```bash
mpvf() {
    nohup mpv --directory-mode=recursive "$@" >/dev/null 2>&1 &!
}
```

Check:

```bash
type mpvf
```

Do not use:

```bash
mpv ~/Videos/ &
```

because that does not provide the same terminal independence.

---

## Folder Playback Doesn't Work

Test directly:

```bash
mpv --directory-mode=recursive ~/Videos/
```

If this works, check your Zsh function:

```bash
type mpvf
```

---

## mpv Doesn't Find Files in Subdirectories

Make sure your `mpvf` function contains:

```bash
--directory-mode=recursive
```

For example:

```bash
mpvf() {
    nohup mpv --directory-mode=recursive "$@" >/dev/null 2>&1 &!
}
```

---

# Useful mpv Commands

You can launch a directory directly:

```bash
mpv ~/Videos/
```

Recursive:

```bash
mpv --directory-mode=recursive ~/Videos/
```

Detached:

```bash
nohup mpv ~/Videos/ >/dev/null 2>&1 &!
```

Check version:

```bash
mpv --version
```

Show help:

```bash
mpv --help
```

Test hardware decoding:

```bash
mpv --hwdec=auto-safe ~/Videos/test.mkv
```

Test software decoding:

```bash
mpv --hwdec=no ~/Videos/test.mkv
```

---

# Final Directory Structure

Your complete setup should look like:

```text
~
├── .zshrc
│
│   mpvf() {
│       nohup mpv --directory-mode=recursive "$@" >/dev/null 2>&1 &!
│   }
│
├── .config/
│   └── mpv/
│       ├── mpv.conf
│       └── input.conf
│
├── .local/
│   └── state/
│       └── mpv/
│           └── watch_later/
│
├── Pictures/
│   └── mpv/
│
└── Videos/
    ├── Movies/
    ├── TV Shows/
    ├── Anime/
    └── YouTube/
```

---

# Complete Workflow

Once everything is configured, your normal workflow becomes extremely simple.

Start an entire video library:

```bash
mpvf ~/Videos/
```

Start a specific category:

```bash
mpvf ~/Videos/Anime/
```

Start a TV show:

```bash
mpvf ~/Videos/TV-Shows/MyShow/
```

Then use:

```text
F8          Playlist
Ctrl+N      Next video
Ctrl+B      Previous video
Ctrl+S      Shuffle
Ctrl+U      Restore order
Ctrl+L      Loop playlist
Ctrl+X      Remove playlist item
Space       Play/Pause
f           Fullscreen
v           Subtitles
j           Subtitle track
Ctrl+A      Audio track
s           Screenshot
i           Statistics
Shift+Q     Save position and quit
q           Quit
```

---

# Recommended COSMIC Setup

The final setup is intentionally lightweight:

```text
                 COSMIC Desktop
                       │
                       ▼
                  Zsh Terminal
                       │
                       │ mpvf ~/Videos/
                       ▼
                  ┌──────────┐
                  │   mpv    │
                  └────┬─────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
      Playlist      Resume       Hardware
      Management    Position     Decoding
          │            │            │
          ▼            ▼            ▼
       Videos/     watch_later    GPU
```

There is no database, server, browser interface, or background service required.

The result is a simple local video-player workflow:

```text
mpvf ~/Videos/
       │
       ▼
   Find videos
       │
       ▼
    Playlist
       │
       ▼
   Play videos
       │
       ├──────► Remember position
       │
       ├──────► Next / Previous
       │
       ├──────► Shuffle
       │
       └──────► Loop
```

This gives you a lightweight **local "Continue Watching" style workflow using mpv's built-in playlist and watch-later functionality**, while keeping COSMIC and your Linux desktop free from an additional media server.

