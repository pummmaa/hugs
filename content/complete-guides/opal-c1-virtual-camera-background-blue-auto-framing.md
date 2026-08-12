---
title: "opal-c1-virtual-camera-background-blue-auto-framing"
date: 2026-08-12T02:57:11Z
lastmod: 2026-08-12T02:57:11Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Opal C1 Virtual Camera — Background Blur + Auto-Framing

> A Python-based virtual camera pipeline for the Opal C1 that provides real-time background blur and face-tracking auto-framing on Linux.
> 

## Table of Contents

- [Overview](https://metamate.internalmeta.com/#overview)
- [How It Works](https://metamate.internalmeta.com/#how-it-works)
- [Requirements](https://metamate.internalmeta.com/#requirements)
- [Installation](https://metamate.internalmeta.com/#installation)

  - [Fedora](https://metamate.internalmeta.com/#fedora)
  - [Arch Linux](https://metamate.internalmeta.com/#arch-linux)
- [Virtual Camera Setup](https://metamate.internalmeta.com/#virtual-camera-setup)
- [Usage](https://metamate.internalmeta.com/#usage)
- [Live Controls](https://metamate.internalmeta.com/#live-controls)
- [Configuration](https://metamate.internalmeta.com/#configuration)
- [Troubleshooting](https://metamate.internalmeta.com/#troubleshooting)
- [Credits](https://metamate.internalmeta.com/#credits)

---

## Overview

The Opal C1 is built on Luxonis hardware (LCM48 sensor / OAK-1 MAX equivalent), which means we can control it programmatically via the [DepthAI](https://docs.luxonis.com/en/latest/) Python framework. This script:

1. **Captures 4K** (3840×2160) from the Opal C1 via DepthAI
2. **Auto-frames** by detecting your face and smoothly cropping a 1080p region (using the 4K headroom to pan/follow)
3. **Blurs the background** using MediaPipe Selfie Segmentation
4. **Outputs to a virtual camera** via `pyvirtualcam` + `v4l2loopback` for use in Zoom, Meet, Teams, OBS, etc.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  Opal C1 (USB-C)                                                │
│  3840×2160 @ 30fps                                              │
└────────────────┬────────────────────────────────────────────────┘
                 │ DepthAI
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  Auto-Framing                                                    │
│  • Face detection (MediaPipe, runs on 25% scale for speed)      │
│  • EMA smoothing filter (no jitter)                              │
│  • Crops 1920×1080 from 4K centered on face                     │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  Background Blur                                                 │
│  • MediaPipe Selfie Segmentation (person mask)                  │
│  • Gaussian blur on background pixels                            │
│  • Smooth edge blending                                          │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  Virtual Camera Output                                           │
│  • pyvirtualcam → v4l2loopback → /dev/video20                   │
│  • 1920×1080 @ 30fps                                            │
│  • Appears as a webcam in any app                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Requirements

- **Opal C1 camera** connected via USB-C
- **Linux** (Fedora or Arch)
- **Python 3.10+**
- USB3 port recommended for 4K throughput

### Python Dependencies

```
depthai>=2.22.0
opencv-python>=4.8.0
mediapipe>=0.10.0
pyvirtualcam>=0.10.0
numpy>=1.24.0
```

---

## Installation

### Fedora

```bash
# 1. System dependencies
sudo dnf install -y python3 python3-pip python3-devel \
    opencv opencv-devel gcc gcc-c++ cmake \
    v4l-utils libusb1-devel

# 2. Install v4l2loopback kernel module
sudo dnf install -y v4l2loopback akmod-v4l2loopback

# 3. DepthAI udev rules (allows non-root USB access to Opal C1)
echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", MODE="0666"' | \
    sudo tee /etc/udev/rules.d/80-movidius.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# 4. Create project directory
mkdir -p ~/opal-c1-virtual-camera && cd ~/opal-c1-virtual-camera

# 5. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 6. Install Python dependencies
pip install --upgrade pip
pip install depthai opencv-python mediapipe pyvirtualcam numpy

# 7. Verify depthai can see the camera
python3 -c "import depthai as dai; print(dai.Device.getAllAvailableDevices())"
```

### Arch Linux

```bash
# 1. System dependencies
sudo pacman -S --needed python python-pip opencv cmake gcc \
    v4l-utils libusb

# 2. Install v4l2loopback from AUR (use your preferred AUR helper)
yay -S v4l2loopback-dkms
# OR with paru:
# paru -S v4l2loopback-dkms

# 3. DepthAI udev rules (allows non-root USB access to Opal C1)
echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", MODE="0666"' | \
    sudo tee /etc/udev/rules.d/80-movidius.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# 4. Create project directory
mkdir -p ~/opal-c1-virtual-camera && cd ~/opal-c1-virtual-camera

# 5. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 6. Install Python dependencies
pip install --upgrade pip
pip install depthai opencv-python mediapipe pyvirtualcam numpy

# 7. Verify depthai can see the camera
python3 -c "import depthai as dai; print(dai.Device.getAllAvailableDevices())"
```

---

## Virtual Camera Setup

The virtual camera requires loading the `v4l2loopback` kernel module:

```bash
# Load the module (creates /dev/video20)
sudo modprobe v4l2loopback devices=1 video_nr=20 \
    card_label="Opal C1 Virtual" exclusive_caps=1

# Verify it exists
v4l2-ctl --list-devices
```

### Make it persistent across reboots

**Fedora:**

```bash
echo "v4l2loopback" | sudo tee /etc/modules-load.d/v4l2loopback.conf
echo 'options v4l2loopback devices=1 video_nr=20 card_label="Opal C1 Virtual" exclusive_caps=1' | \
    sudo tee /etc/modprobe.d/v4l2loopback.conf
```

**Arch Linux:**

```bash
echo "v4l2loopback" | sudo tee /etc/modules-load.d/v4l2loopback.conf
echo 'options v4l2loopback devices=1 video_nr=20 card_label="Opal C1 Virtual" exclusive_caps=1' | \
    sudo tee /etc/modprobe.d/v4l2loopback.conf
```

---

## Usage

```bash
cd ~/opal-c1-virtual-camera
source venv/bin/activate

# Full features (blur + auto-framing + preview window)
python opal_c1_virtual_camera.py --show-preview

# Just background blur (no auto-framing)
python opal_c1_virtual_camera.py --no-autoframe --show-preview

# Just auto-framing (no blur — best performance)
python opal_c1_virtual_camera.py --no-blur --show-preview

# Headless mode (no preview, just virtual camera output)
python opal_c1_virtual_camera.py

# Custom blur strength and smoothing
python opal_c1_virtual_camera.py --blur-strength 61 --smoothing 0.05 --show-preview
```

### Command-Line Options

| Flag | Default | Description |
| --- | --- | --- |
| `--no-blur` | off | Disable background blur |
| `--no-autoframe` | off | Disable auto-framing |
| `--blur-strength` | 45 | Gaussian blur kernel size (odd number, 5–99) |
| `--output-width` | 1920 | Output resolution width |
| `--output-height` | 1080 | Output resolution height |
| `--fps` | 30 | Target frames per second |
| `--smoothing` | 0.08 | Auto-frame smoothing (0.01=smooth, 0.2=responsive) |
| `--show-preview` | off | Show local OpenCV preview window |

### Using in Video Calls

1. Run the script
2. Open Zoom / Google Meet / Teams / OBS
3. Select **"Opal C1 Virtual"** (or `/dev/video20`) as your camera source

---

## Live Controls

While the script is running (with `--show-preview`):

| Key | Action |
| --- | --- |
| `q` | Quit |
| `b` | Toggle background blur on/off |
| `a` | Toggle auto-framing on/off |
| `+` / `-` | Increase / decrease blur strength |
| `[` / `]` | Adjust framing smoothness (slower ↔ faster tracking) |

---

## Troubleshooting

### Camera not detected

```bash
# Check if Opal C1 is visible on USB
lsusb | grep 03e7

# If not found, try a different USB-C port (must be USB3)
# Re-apply udev rules
sudo udevadm control --reload-rules && sudo udevadm trigger
# Unplug and replug the camera
```

### "No DepthAI device found" error

- Ensure no other app (Opal Desktop, OBS, browser) is using the camera
- Check udev rules are in place
- Try running with `sudo` once to verify it's a permissions issue

### v4l2loopback not loading

```bash
# Fedora: rebuild akmod
sudo akmods --force

# Arch: rebuild dkms
sudo dkms autoinstall

# Check for errors
sudo dmesg | grep v4l2loopback
```

### Low FPS / high CPU usage

- Disable blur (`--no-blur`) — segmentation is the heaviest operation
- Lower output resolution: `--output-width 1280 --output-height 720`
- Ensure you're using a USB3 port (USB2 bottlenecks at ~10fps for 4K)

### Virtual camera not appearing in apps

```bash
# Verify the device exists
ls -la /dev/video20

# Some apps need exclusive_caps=1 — ensure that option is set
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback devices=1 video_nr=20 exclusive_caps=1
```

---

## Credits

- [cansik/open-opal](https://github.com/cansik/open-opal) — Original Opal C1 Python control project
- [Luxonis DepthAI](https://docs.luxonis.com/en/latest/) — Camera framework
- [MediaPipe](https://developers.google.com/mediapipe) — Selfie segmentation & face detection
- [pyvirtualcam](https://github.com/letmaik/pyvirtualcam) — Virtual camera output
- [v4l2loopback](https://github.com/umlaeute/v4l2loopback) — Linux virtual video device

---

## License

MIT — Use freely, modify as needed.
