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

```python
#!/usr/bin/env python3
"""
Opal C1 Virtual Camera — Background Blur + Auto-Framing
========================================================
Uses the NEW MediaPipe Tasks API (0.10.14+).

Requirements:
    pip install depthai opencv-python mediapipe pyvirtualcam numpy

Usage:
    python opal_c1_virtual_camera.py [options]
"""

import argparse
import time
import sys
import os
import urllib.request
from collections import deque

import cv2
import numpy as np

try:
    import depthai as dai
except ImportError:
    print("ERROR: depthai not installed. Run: pip install depthai")
    sys.exit(1)

try:
    import mediapipe as mp
    from mediapipe.tasks import python as mp_tasks
    from mediapipe.tasks.python import vision
except ImportError:
    print("ERROR: mediapipe not installed. Run: pip install mediapipe")
    sys.exit(1)

try:
    import pyvirtualcam
except ImportError:
    print("ERROR: pyvirtualcam not installed. Run: pip install pyvirtualcam")
    sys.exit(1)


# =============================================================================
# Model Downloads
# =============================================================================

MODELS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")

SELFIE_SEGMENTER_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite"
)
FACE_DETECTOR_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite"
)


def ensure_model(url: str, filename: str) -> str:
    """Download model if not already present. Returns local path."""
    os.makedirs(MODELS_DIR, exist_ok=True)
    path = os.path.join(MODELS_DIR, filename)
    if not os.path.exists(path):
        print(f"[INFO] Downloading {filename}...")
        urllib.request.urlretrieve(url, path)
        print(f"[INFO] Saved to {path}")
    return path


# =============================================================================
# Configuration
# =============================================================================

class Config:
    CAPTURE_WIDTH = 3840
    CAPTURE_HEIGHT = 2160
    OUTPUT_WIDTH = 1920
    OUTPUT_HEIGHT = 1080
    FPS = 30

    BLUR_ENABLED = True
    BLUR_STRENGTH = 45
    BLUR_EDGE_SMOOTH = 7
    SEGMENTATION_THRESHOLD = 0.6

    AUTOFRAME_ENABLED = True
    AUTOFRAME_SMOOTHING = 0.08
    AUTOFRAME_PADDING = 0.3
    AUTOFRAME_MIN_FACE_CONF = 0.5
    FACE_LOST_TIMEOUT = 2.0

    SHOW_PREVIEW = False


# =============================================================================
# Smoothing Filter
# =============================================================================

class ExponentialMovingAverage:
    def __init__(self, alpha=0.08):
        self.alpha = alpha
        self.value = None

    def update(self, new_value):
        if self.value is None:
            self.value = new_value
        else:
            self.value = self.alpha * new_value + (1 - self.alpha) * self.value
        return self.value

    def reset(self):
        self.value = None


# =============================================================================
# DepthAI Pipeline (Opal C1 Capture)
# =============================================================================

def create_depthai_pipeline(config: Config) -> dai.Pipeline:
    pipeline = dai.Pipeline()
    cam_rgb = pipeline.create(dai.node.ColorCamera)
    cam_rgb.setResolution(dai.ColorCameraProperties.SensorResolution.THE_4_K)
    cam_rgb.setInterleaved(False)
    cam_rgb.setColorOrder(dai.ColorCameraProperties.ColorOrder.BGR)
    cam_rgb.setFps(config.FPS)
    cam_rgb.setIspScale(1, 1)

    xout_rgb = pipeline.create(dai.node.XLinkOut)
    xout_rgb.setStreamName("rgb")
    xout_rgb.input.setBlocking(False)
    xout_rgb.input.setQueueSize(1)
    cam_rgb.isp.link(xout_rgb.input)

    return pipeline


# =============================================================================
# Background Blur (New MediaPipe Tasks API)
# =============================================================================

class BackgroundBlur:
    """Applies background blur using MediaPipe Image Segmenter (Tasks API)."""

    def __init__(self, config: Config):
        self.config = config
        model_path = ensure_model(SELFIE_SEGMENTER_URL, "selfie_segmenter.tflite")

        base_options = mp_tasks.BaseOptions(model_asset_path=model_path)
        options = vision.ImageSegmenterOptions(
            base_options=base_options,
            output_category_mask=True,
            running_mode=vision.RunningMode.VIDEO,
        )
        self.segmenter = vision.ImageSegmenter.create_from_options(options)
        self._timestamp_ms = 0

    def process(self, frame: np.ndarray) -> np.ndarray:
        if not self.config.BLUR_ENABLED:
            return frame

        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)

        self._timestamp_ms += 33  # ~30fps
        result = self.segmenter.segment_for_video(mp_image, self._timestamp_ms)

        if not result.category_mask:
            return frame

        # category_mask: person pixels = non-zero
        mask = result.category_mask.numpy_view().astype(np.float32)
        # Normalize: person=1, background=0
        mask = np.where(mask > 0, 1.0, 0.0).astype(np.float32)

        # Smooth mask edges
        if self.config.BLUR_EDGE_SMOOTH > 0:
            k = self.config.BLUR_EDGE_SMOOTH * 2 + 1
            mask = cv2.GaussianBlur(mask, (k, k), 0)

        mask_3ch = np.stack([mask] * 3, axis=-1)

        # Blur background
        blur_size = self.config.BLUR_STRENGTH
        if blur_size % 2 == 0:
            blur_size += 1
        blurred = cv2.GaussianBlur(frame, (blur_size, blur_size), 0)

        # Composite
        output = (frame * mask_3ch + blurred * (1 - mask_3ch)).astype(np.uint8)
        return output

    def release(self):
        self.segmenter.close()


# =============================================================================
# Auto-Framing (New MediaPipe Tasks API)
# =============================================================================

class AutoFramer:
    """Face-tracking auto-framing using MediaPipe Face Detector (Tasks API)."""

    def __init__(self, config: Config):
        self.config = config
        model_path = ensure_model(FACE_DETECTOR_URL, "blaze_face_short_range.tflite")

        base_options = mp_tasks.BaseOptions(model_asset_path=model_path)
        options = vision.FaceDetectorOptions(
            base_options=base_options,
            min_detection_confidence=config.AUTOFRAME_MIN_FACE_CONF,
            running_mode=vision.RunningMode.VIDEO,
        )
        self.face_detector = vision.FaceDetector.create_from_options(options)
        self._timestamp_ms = 0

        self.smooth_x = ExponentialMovingAverage(alpha=config.AUTOFRAME_SMOOTHING)
        self.smooth_y = ExponentialMovingAverage(alpha=config.AUTOFRAME_SMOOTHING)
        self.last_face_time = time.time()
        self.face_detected = False

    def process(self, frame: np.ndarray) -> np.ndarray:
        if not self.config.AUTOFRAME_ENABLED:
            return cv2.resize(frame, (self.config.OUTPUT_WIDTH, self.config.OUTPUT_HEIGHT))

        h, w = frame.shape[:2]
        out_w = self.config.OUTPUT_WIDTH
        out_h = self.config.OUTPUT_HEIGHT

        # Detect on downscaled frame for performance
        scale = 0.25
        small = cv2.resize(frame, (int(w * scale), int(h * scale)))
        rgb_small = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_small)

        self._timestamp_ms += 33
        result = self.face_detector.detect_for_video(mp_image, self._timestamp_ms)

        if result.detections:
            # Use most confident face
            best = max(result.detections, key=lambda d: d.categories[0].score)
            bbox = best.bounding_box

            # Center in normalized coords
            face_cx = (bbox.origin_x + bbox.width / 2) / (w * scale)
            face_cy = (bbox.origin_y + bbox.height / 2) / (h * scale)

            target_x = face_cx * w
            target_y = face_cy * h
            self.last_face_time = time.time()
            self.face_detected = True
        else:
            if time.time() - self.last_face_time > self.config.FACE_LOST_TIMEOUT:
                target_x = w / 2
                target_y = h / 2
                self.face_detected = False
            else:
                target_x = self.smooth_x.value if self.smooth_x.value else w / 2
                target_y = self.smooth_y.value if self.smooth_y.value else h / 2

        smooth_x = self.smooth_x.update(target_x)
        smooth_y = self.smooth_y.update(target_y)

        # Crop region (face in upper third for natural framing)
        crop_cy = smooth_y - (out_h * 0.1)
        x1 = int(max(0, min(smooth_x - out_w / 2, w - out_w)))
        y1 = int(max(0, min(crop_cy - out_h / 2, h - out_h)))
        x2 = x1 + out_w
        y2 = y1 + out_h

        cropped = frame[y1:y2, x1:x2]
        if cropped.shape[1] != out_w or cropped.shape[0] != out_h:
            cropped = cv2.resize(cropped, (out_w, out_h))

        return cropped

    def release(self):
        self.face_detector.close()


# =============================================================================
# FPS Counter
# =============================================================================

class FPSCounter:
    def __init__(self, window_size=30):
        self.timestamps = deque(maxlen=window_size)

    def tick(self):
        self.timestamps.append(time.time())

    @property
    def fps(self) -> float:
        if len(self.timestamps) < 2:
            return 0.0
        elapsed = self.timestamps[-1] - self.timestamps[0]
        return (len(self.timestamps) - 1) / elapsed if elapsed > 0 else 0.0


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description="Opal C1 Virtual Camera")
    parser.add_argument("--no-blur", action="store_true", help="Disable background blur")
    parser.add_argument("--no-autoframe", action="store_true", help="Disable auto-framing")
    parser.add_argument("--blur-strength", type=int, default=45, help="Blur kernel size (odd, 5-99)")
    parser.add_argument("--output-width", type=int, default=1920)
    parser.add_argument("--output-height", type=int, default=1080)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--show-preview", action="store_true", help="Show local preview")
    parser.add_argument("--smoothing", type=float, default=0.08, help="Auto-frame smoothing (0.01-0.2)")
    args = parser.parse_args()

    config = Config()
    config.BLUR_ENABLED = not args.no_blur
    config.AUTOFRAME_ENABLED = not args.no_autoframe
    config.BLUR_STRENGTH = args.blur_strength
    config.OUTPUT_WIDTH = args.output_width
    config.OUTPUT_HEIGHT = args.output_height
    config.FPS = args.fps
    config.SHOW_PREVIEW = args.show_preview
    config.AUTOFRAME_SMOOTHING = args.smoothing

    print("=" * 60)
    print("  Opal C1 Virtual Camera (MediaPipe Tasks API)")
    print("  Background Blur + Auto-Framing")
    print("=" * 60)
    print(f"  Capture:      {config.CAPTURE_WIDTH}x{config.CAPTURE_HEIGHT} @ {config.FPS}fps")
    print(f"  Output:       {config.OUTPUT_WIDTH}x{config.OUTPUT_HEIGHT}")
    print(f"  Blur:         {'ON (strength=' + str(config.BLUR_STRENGTH) + ')' if config.BLUR_ENABLED else 'OFF'}")
    print(f"  Auto-frame:   {'ON (smoothing=' + f'{config.AUTOFRAME_SMOOTHING:.2f}' + ')' if config.AUTOFRAME_ENABLED else 'OFF'}")
    print(f"  Preview:      {'ON' if config.SHOW_PREVIEW else 'OFF'}")
    print("=" * 60)
    print()

    # Initialize processors
    blur_processor = BackgroundBlur(config)
    autoframer = AutoFramer(config)
    fps_counter = FPSCounter()

    print("[INFO] Connecting to Opal C1...")
    pipeline = create_depthai_pipeline(config)

    try:
        with dai.Device(pipeline) as device:
            print(f"[INFO] Connected to: {device.getMxId()}")
            q_rgb = device.getOutputQueue(name="rgb", maxSize=1, blocking=False)

            print("[INFO] Starting virtual camera...")
            with pyvirtualcam.Camera(
                width=config.OUTPUT_WIDTH,
                height=config.OUTPUT_HEIGHT,
                fps=config.FPS,
                fmt=pyvirtualcam.PixelFormat.BGR,
            ) as vcam:
                print(f"[INFO] Virtual camera: {vcam.device}")
                print()
                print("[CONTROLS] q=quit  b=blur  a=autoframe  +/-=blur strength  [/]=smoothing")
                print()

                while True:
                    in_rgb = q_rgb.tryGet()
                    if in_rgb is None:
                        continue

                    frame = in_rgb.getCvFrame()
                    fps_counter.tick()

                    # Auto-frame then blur
                    framed = autoframer.process(frame)
                    output = blur_processor.process(framed)

                    vcam.send(output)
                    vcam.sleep_until_next_frame()

                    if config.SHOW_PREVIEW:
                        preview = output.copy()
                        status = f"FPS: {fps_counter.fps:.1f}"
                        if config.BLUR_ENABLED:
                            status += f" | Blur: {config.BLUR_STRENGTH}"
                        if config.AUTOFRAME_ENABLED:
                            face_st = "tracking" if autoframer.face_detected else "searching"
                            status += f" | Frame: {face_st}"
                        cv2.putText(preview, status, (10, 30),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                        cv2.imshow("Opal C1 Virtual Camera", preview)

                    key = cv2.waitKey(1) & 0xFF
                    if key == ord('q'):
                        print("\n[INFO] Shutting down...")
                        break
                    elif key == ord('b'):
                        config.BLUR_ENABLED = not config.BLUR_ENABLED
                        print(f"[INFO] Blur: {'ON' if config.BLUR_ENABLED else 'OFF'}")
                    elif key == ord('a'):
                        config.AUTOFRAME_ENABLED = not config.AUTOFRAME_ENABLED
                        print(f"[INFO] Auto-frame: {'ON' if config.AUTOFRAME_ENABLED else 'OFF'}")
                    elif key in (ord('+'), ord('=')):
                        config.BLUR_STRENGTH = min(99, config.BLUR_STRENGTH + 4) | 1
                        print(f"[INFO] Blur strength: {config.BLUR_STRENGTH}")
                    elif key == ord('-'):
                        config.BLUR_STRENGTH = max(5, config.BLUR_STRENGTH - 4) | 1
                        print(f"[INFO] Blur strength: {config.BLUR_STRENGTH}")
                    elif key == ord('['):
                        config.AUTOFRAME_SMOOTHING = max(0.01, config.AUTOFRAME_SMOOTHING - 0.02)
                        autoframer.smooth_x.alpha = config.AUTOFRAME_SMOOTHING
                        autoframer.smooth_y.alpha = config.AUTOFRAME_SMOOTHING
                        print(f"[INFO] Smoothing: {config.AUTOFRAME_SMOOTHING:.2f}")
                    elif key == ord(']'):
                        config.AUTOFRAME_SMOOTHING = min(0.3, config.AUTOFRAME_SMOOTHING + 0.02)
                        autoframer.smooth_x.alpha = config.AUTOFRAME_SMOOTHING
                        autoframer.smooth_y.alpha = config.AUTOFRAME_SMOOTHING
                        print(f"[INFO] Smoothing: {config.AUTOFRAME_SMOOTHING:.2f}")

    except RuntimeError as e:
        if "No DepthAI device found" in str(e) or "XLINK" in str(e):
            print(f"\n[ERROR] Could not connect to Opal C1.")
            print("  Ensure camera is plugged in via USB-C and not used by another app.")
            print(f"  Error: {e}")
        else:
            raise
    finally:
        blur_processor.release()
        autoframer.release()
        cv2.destroyAllWindows()
        print("[INFO] Done.")


if __name__ == "__main__":
    main()
```
