---
title: "scrcpy-installation-from-github-on-dnf-and-pacman"
date: 2026-08-22T19:25:44Z
lastmod: 2026-08-22T19:25:44Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Install the latest **scrcpy** on Fedora from the official GitHub repo

## Table of Contents

1. Option A — Prebuilt static build (easiest, no compiling)

  - One-shot install script
  - Or do it manually
2. Option B — Official `install_release.sh` (builds client from source)

  - Install build dependencies (Fedora equivalents)
  - Clone and run the install script
3. Option C — Fedora COPR (maintained `dnf` package)
4. After installing (any option)
5. Which should I pick?

---

Since scrcpy isn't in the official Fedora 44 `dnf` repos, here are **three
official ways** to get the newest version straight from
[Genymobile/scrcpy](https://github.com/Genymobile/scrcpy) — ordered easiest → most involved.

> ⚠️ **adb is always required.** scrcpy talks to your phone through the Android
> Debug Bridge. Install it once, regardless of which option you pick:
> 
> ```bash
> sudo dnf install android-tools
> ```
> 

---

## Option A — Prebuilt static build (easiest, no compiling) ✅ recommended

Since v2.x, scrcpy publishes a **self-contained static Linux binary** on its
GitHub Releases page. It bundles the matching `scrcpy-server`, so you only need `adb`.

### One-shot install script

Save as `install-scrcpy.sh`, then `chmod +x install-scrcpy.sh && ./install-scrcpy.sh`:

```bash
#!/usr/bin/env bash
# Download & install the latest official scrcpy static build for Linux x86_64.
set -euo pipefail

echo ">> Ensuring adb (android-tools) is installed..."
command -v adb >/dev/null 2>&1 || sudo dnf install -y android-tools

echo ">> Querying latest release tag from GitHub..."
TAG=$(curl -fsSL https://api.github.com/repos/Genymobile/scrcpy/releases/latest \
      | grep -oP '"tag_name":\s*"\K[^"]+')
echo "   Latest release: $TAG"

ASSET="scrcpy-linux-x86_64-${TAG}.tar.gz"
URL="https://github.com/Genymobile/scrcpy/releases/download/${TAG}/${ASSET}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

echo ">> Downloading $ASSET ..."
curl -fL -o "$ASSET" "$URL"

echo ">> Extracting..."
mkdir extracted
tar -xzf "$ASSET" -C extracted --strip-components=1

echo ">> Installing to /opt/scrcpy and linking into /usr/local/bin ..."
sudo rm -rf /opt/scrcpy
sudo mkdir -p /opt/scrcpy
sudo cp -r extracted/* /opt/scrcpy/
sudo ln -sf /opt/scrcpy/scrcpy /usr/local/bin/scrcpy

echo ">> Done."
scrcpy --version
```

### Or do it manually

1. Go to [https://github.com/Genymobile/scrcpy/releases/latest](https://github.com/Genymobile/scrcpy/releases/latest)
2. Download `scrcpy-linux-x86_64-vX.Y.tar.gz` (and verify the SHA-256 shown on the page).
3. Extract and run:

```bash
tar -xzf scrcpy-linux-x86_64-*.tar.gz
cd scrcpy-linux-x86_64-*/
./scrcpy
```

**Update later:** just re-run the script (it always fetches the newest tag).
**Uninstall:** `sudo rm -rf /opt/scrcpy /usr/local/bin/scrcpy`

---

## Option B — Official `install_release.sh` (builds client from source)

This is scrcpy's **simplified build process**: it installs build tools, clones
the repo, downloads the matching prebuilt server, and compiles the client with
meson/ninja. Good if the static binary doesn't work on your system.

### 1. Install build dependencies (Fedora equivalents)

```bash
sudo dnf install -y \
    git wget gcc make pkgconf-pkg-config meson ninja-build \
    SDL3-devel libusb1-devel libv4l-devel \
    ffmpeg-devel android-tools
```

> **FFmpeg headers:** `ffmpeg-devel` comes from **RPM Fusion**. If you don't have
> it enabled, either enable it:
> 
> ```bash
> sudo dnf install -y \
>   https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
> ```
> 
> …or use Fedora's own package instead: `sudo dnf install ffmpeg-free-devel`.
> 
> **SDL:** current scrcpy (v3+/v4) uses **SDL3** (`SDL3-devel`). If your Fedora
> only has SDL2, use an older scrcpy tag or Option A/C.
> 

### 2. Clone and run the install script

```bash
git clone https://github.com/Genymobile/scrcpy
cd scrcpy
./install_release.sh          # builds client + downloads prebuilt server, installs
```

- **Update:** `git pull && ./install_release.sh`
- **Uninstall:** `sudo ninja -Cbuild-auto uninstall`

> This simplified path only works for **released** versions (it downloads a
> prebuilt server). To build the `dev` branch you must build the server too —
> see the repo's `doc/build.md`.
> 

---

## Option C — Fedora COPR (maintained `dnf` package)

If you'd rather stay in the `dnf` world and get automatic updates, use the
community COPR repo referenced in scrcpy's own docs:

```bash
sudo dnf copr enable zeno/scrcpy
sudo dnf install scrcpy
```

Updates then flow through your normal `sudo dnf upgrade`.

> COPR is community-maintained (not first-party Meta/Fedora), but it's the route
> the official scrcpy Linux docs point Fedora users to.
> 

---

## After installing (any option)

1. Enable **USB debugging** on the phone (Settings → About → tap *Build number* ×7
→ Developer options → **USB debugging**).
2. Plug in via USB, then:

```bash
adb devices        # accept the "Allow USB debugging?" prompt on the phone
scrcpy             # launch the mirror
```

3. Common flags:

```bash
scrcpy --no-audio --record=file.mkv     # mirror without audio, record session
scrcpy --max-size 1024 -b 2M            # lighter/faster stream
scrcpy -S                               # phone screen off + stay awake
```

Full docs: `man scrcpy`, `scrcpy --help`, or the
[GitHub README](https://github.com/Genymobile/scrcpy).

---

## Which should I pick?

| Option | Effort | Latest? | Auto-updates | Notes |
| --- | --- | --- | --- | --- |
| **A — static build** | ⭐ lowest | ✅ newest release | Re-run script | No compiler needed; bundles server |
| **B — install_release.sh** | medium | ✅ newest release | `git pull && ./install_release.sh` | Needs RPM Fusion + SDL3 dev libs |
| **C — COPR** | ⭐ low | usually current | ✅ via `dnf upgrade` | Community-maintained package |
