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
Captures the 4K stream from an Opal C1 camera (via DepthAI),
applies real-time background blur and face-based auto-framing,
and outputs the result to a virtual camera for use in video calls.

Requirements:
    pip install depthai opencv-python mediapipe pyvirtualcam numpy

Virtual camera setup:
    - Windows: Install OBS (includes virtual camera)
    - macOS:   Install OBS (includes virtual camera)
    - Linux:   sudo apt install v4l2loopback-dkms
               sudo modprobe v4l2loopback devices=1 video_nr=20 exclusive_caps=1

Usage:
    python opal_c1_virtual_camera.py [options]

    Options:
        --no-blur         Disable background blur
        --no-autoframe    Disable auto-framing
        --blur-strength   Blur kernel size (default: 45)
        --output-width    Output resolution width (default: 1920)
        --output-height   Output resolution height (default: 1080)
        --fps             Target FPS (default: 30)
        --show-preview    Show a local OpenCV preview window
"""

import argparse
import time
import sys
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
except ImportError:
    print("ERROR: mediapipe not installed. Run: pip install mediapipe")
    sys.exit(1)

try:
    import pyvirtualcam
except ImportError:
    print("ERROR: pyvirtualcam not installed. Run: pip install pyvirtualcam")
    sys.exit(1)


# =============================================================================
# Configuration
# =============================================================================

class Config:
    """Configuration for the virtual camera pipeline."""
    
    # Camera capture (Opal C1 native 4K)
    CAPTURE_WIDTH = 3840
    CAPTURE_HEIGHT = 2160
    
    # Output resolution (what the virtual camera outputs)
    OUTPUT_WIDTH = 1920
    OUTPUT_HEIGHT = 1080
    
    # Target FPS
    FPS = 30
    
    # Background blur
    BLUR_ENABLED = True
    BLUR_STRENGTH = 45          # Gaussian kernel size (must be odd)
    BLUR_EDGE_SMOOTH = 7       # Edge smoothing for segmentation mask
    SEGMENTATION_MODEL = 1      # 0 = general, 1 = landscape (faster)
    SEGMENTATION_THRESHOLD = 0.6  # Confidence threshold for person mask
    
    # Auto-framing
    AUTOFRAME_ENABLED = True
    AUTOFRAME_SMOOTHING = 0.08   # Lower = smoother but slower to follow (0.01-0.2)
    AUTOFRAME_PADDING = 0.3      # Extra padding around face (fraction of frame)
    AUTOFRAME_MIN_FACE_CONF = 0.5  # Minimum face detection confidence
    FACE_LOST_TIMEOUT = 2.0      # Seconds before reverting to center when face lost
    
    # Preview
    SHOW_PREVIEW = False


# =============================================================================
# Smoothing Filter for Auto-Framing
# =============================================================================

class ExponentialMovingAverage:
    """Smooth position tracking to avoid jittery auto-framing."""
    
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
    """Create a DepthAI pipeline to capture from the Opal C1."""
    pipeline = dai.Pipeline()
    
    # Color camera node
    cam_rgb = pipeline.create(dai.node.ColorCamera)
    cam_rgb.setResolution(dai.ColorCameraProperties.SensorResolution.THE_4_K)
    cam_rgb.setInterleaved(False)
    cam_rgb.setColorOrder(dai.ColorCameraProperties.ColorOrder.BGR)
    cam_rgb.setFps(config.FPS)
    
    # Set ISP output for full 4K
    cam_rgb.setIspScale(1, 1)  # No downscaling — full 4K
    
    # Output node
    xout_rgb = pipeline.create(dai.node.XLinkOut)
    xout_rgb.setStreamName("rgb")
    xout_rgb.input.setBlocking(False)
    xout_rgb.input.setQueueSize(1)  # Only keep latest frame
    
    cam_rgb.isp.link(xout_rgb.input)
    
    return pipeline


# =============================================================================
# Background Blur Processor
# =============================================================================

class BackgroundBlur:
    """Applies background blur using MediaPipe Selfie Segmentation."""
    
    def __init__(self, config: Config):
        self.config = config
        self.mp_selfie = mp.solutions.selfie_segmentation
        self.segmenter = self.mp_selfie.SelfieSegmentation(
            model_selection=config.SEGMENTATION_MODEL
        )
    
    def process(self, frame: np.ndarray) -> np.ndarray:
        """Apply background blur to a BGR frame."""
        if not self.config.BLUR_ENABLED:
            return frame
        
        # MediaPipe expects RGB
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.segmenter.process(rgb_frame)
        
        if results.segmentation_mask is None:
            return frame
        
        # Create mask (person = 1, background = 0)
        mask = results.segmentation_mask
        mask = (mask > self.config.SEGMENTATION_THRESHOLD).astype(np.float32)
        
        # Smooth mask edges to avoid harsh cutouts
        if self.config.BLUR_EDGE_SMOOTH > 0:
            kernel_size = self.config.BLUR_EDGE_SMOOTH * 2 + 1
            mask = cv2.GaussianBlur(mask, (kernel_size, kernel_size), 0)
        
        # Expand mask to 3 channels
        mask_3ch = np.stack([mask] * 3, axis=-1)
        
        # Create blurred background
        blur_size = self.config.BLUR_STRENGTH
        if blur_size % 2 == 0:
            blur_size += 1  # Must be odd
        blurred = cv2.GaussianBlur(frame, (blur_size, blur_size), 0)
        
        # Composite: person (sharp) over background (blurred)
        output = (frame * mask_3ch + blurred * (1 - mask_3ch)).astype(np.uint8)
        
        return output
    
    def release(self):
        self.segmenter.close()


# =============================================================================
# Auto-Framing Processor
# =============================================================================

class AutoFramer:
    """
    Auto-framing by detecting face and cropping a 1080p region from 4K.
    
    The idea: The Opal C1 captures at 4K (3840x2160). We detect the face,
    then crop a 1920x1080 region centered on the face. This gives us 2x
    digital zoom headroom to pan/follow the subject smoothly.
    """
    
    def __init__(self, config: Config):
        self.config = config
        self.mp_face = mp.solutions.face_detection
        self.face_detector = self.mp_face.FaceDetection(
            model_selection=1,  # 1 = full range (better for farther faces)
            min_detection_confidence=config.AUTOFRAME_MIN_FACE_CONF
        )
        
        # Smoothing filters for crop center position
        self.smooth_x = ExponentialMovingAverage(alpha=config.AUTOFRAME_SMOOTHING)
        self.smooth_y = ExponentialMovingAverage(alpha=config.AUTOFRAME_SMOOTHING)
        
        # Track when face was last seen
        self.last_face_time = time.time()
        self.face_detected = False
    
    def process(self, frame: np.ndarray) -> np.ndarray:
        """
        Detect face and return a cropped/framed region.
        
        Input: Full 4K frame (3840x2160)
        Output: Cropped frame at OUTPUT_WIDTH x OUTPUT_HEIGHT
        """
        if not self.config.AUTOFRAME_ENABLED:
            # Just resize to output resolution
            return cv2.resize(frame, (self.config.OUTPUT_WIDTH, self.config.OUTPUT_HEIGHT))
        
        h, w = frame.shape[:2]
        out_w = self.config.OUTPUT_WIDTH
        out_h = self.config.OUTPUT_HEIGHT
        
        # Detect face on a downscaled frame for performance
        scale = 0.25
        small_frame = cv2.resize(frame, (int(w * scale), int(h * scale)))
        rgb_small = cv2.cvtColor(small_frame, cv2.COLOR_BGR2RGB)
        results = self.face_detector.process(rgb_small)
        
        # Determine target center
        if results.detections:
            # Use the largest/most confident face
            best_detection = max(results.detections, key=lambda d: d.score[0])
            bbox = best_detection.location_data.relative_bounding_box
            
            # Face center in normalized coordinates
            face_cx = bbox.xmin + bbox.width / 2
            face_cy = bbox.ymin + bbox.height / 2
            
            # Convert to pixel coordinates in full frame
            target_x = face_cx * w
            target_y = face_cy * h
            
            self.last_face_time = time.time()
            self.face_detected = True
        else:
            # If face lost for too long, drift back to center
            if time.time() - self.last_face_time > self.config.FACE_LOST_TIMEOUT:
                target_x = w / 2
                target_y = h / 2
                self.face_detected = False
            else:
                # Keep last known position
                target_x = self.smooth_x.value if self.smooth_x.value else w / 2
                target_y = self.smooth_y.value if self.smooth_y.value else h / 2
        
        # Apply smoothing
        smooth_x = self.smooth_x.update(target_x)
        smooth_y = self.smooth_y.update(target_y)
        
        # Calculate crop region (ensure it stays within frame bounds)
        # Add slight upward offset so face isn't dead center (more natural framing)
        crop_center_y = smooth_y - (out_h * 0.1)  # Shift up 10% — face in upper third
        
        x1 = int(max(0, min(smooth_x - out_w / 2, w - out_w)))
        y1 = int(max(0, min(crop_center_y - out_h / 2, h - out_h)))
        x2 = x1 + out_w
        y2 = y1 + out_h
        
        # Crop
        cropped = frame[y1:y2, x1:x2]
        
        # Safety check: resize if crop dimensions don't match (edge cases)
        if cropped.shape[1] != out_w or cropped.shape[0] != out_h:
            cropped = cv2.resize(cropped, (out_w, out_h))
        
        return cropped
    
    def release(self):
        self.face_detector.close()


# =============================================================================
# FPS Counter
# =============================================================================

class FPSCounter:
    """Simple FPS counter using a sliding window."""
    
    def __init__(self, window_size=30):
        self.timestamps = deque(maxlen=window_size)
    
    def tick(self):
        self.timestamps.append(time.time())
    
    @property
    def fps(self) -> float:
        if len(self.timestamps) < 2:
            return 0.0
        elapsed = self.timestamps[-1] - self.timestamps[0]
        if elapsed == 0:
            return 0.0
        return (len(self.timestamps) - 1) / elapsed


# =============================================================================
# Main Pipeline
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description="Opal C1 Virtual Camera with Blur + Auto-Framing")
    parser.add_argument("--no-blur", action="store_true", help="Disable background blur")
    parser.add_argument("--no-autoframe", action="store_true", help="Disable auto-framing")
    parser.add_argument("--blur-strength", type=int, default=45, help="Blur kernel size (odd number)")
    parser.add_argument("--output-width", type=int, default=1920, help="Output width")
    parser.add_argument("--output-height", type=int, default=1080, help="Output height")
    parser.add_argument("--fps", type=int, default=30, help="Target FPS")
    parser.add_argument("--show-preview", action="store_true", help="Show local preview window")
    parser.add_argument("--smoothing", type=float, default=0.08, help="Auto-frame smoothing (0.01-0.2)")
    args = parser.parse_args()
    
    # Apply config
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
    print("  Opal C1 Virtual Camera")
    print("  Background Blur + Auto-Framing")
    print("=" * 60)
    print(f"  Capture:      {config.CAPTURE_WIDTH}x{config.CAPTURE_HEIGHT} @ {config.FPS}fps")
    print(f"  Output:       {config.OUTPUT_WIDTH}x{config.OUTPUT_HEIGHT}")
    print(f"  Blur:         {'ON (strength={})'.format(config.BLUR_STRENGTH) if config.BLUR_ENABLED else 'OFF'}")
    print(f"  Auto-frame:   {'ON (smoothing={:.2f})'.format(config.AUTOFRAME_SMOOTHING) if config.AUTOFRAME_ENABLED else 'OFF'}")
    print(f"  Preview:      {'ON' if config.SHOW_PREVIEW else 'OFF'}")
    print("=" * 60)
    print()
    
    # Initialize processors
    blur_processor = BackgroundBlur(config)
    autoframer = AutoFramer(config)
    fps_counter = FPSCounter()
    
    # Create DepthAI pipeline
    print("[INFO] Connecting to Opal C1...")
    pipeline = create_depthai_pipeline(config)
    
    try:
        with dai.Device(pipeline) as device:
            print(f"[INFO] Connected to: {device.getMxId()}")
            print("[INFO] Starting capture...")
            
            q_rgb = device.getOutputQueue(name="rgb", maxSize=1, blocking=False)
            
            # Start virtual camera
            print("[INFO] Starting virtual camera...")
            with pyvirtualcam.Camera(
                width=config.OUTPUT_WIDTH,
                height=config.OUTPUT_HEIGHT,
                fps=config.FPS,
                fmt=pyvirtualcam.PixelFormat.BGR,
            ) as vcam:
                print(f"[INFO] Virtual camera started: {vcam.device}")
                print()
                print("[CONTROLS]")
                print("  q       — Quit")
                print("  b       — Toggle background blur")
                print("  a       — Toggle auto-framing")
                print("  +/-     — Increase/decrease blur strength")
                print("  [/]     — Decrease/increase smoothing")
                print()
                
                while True:
                    # Get frame from Opal C1
                    in_rgb = q_rgb.tryGet()
                    if in_rgb is None:
                        continue
                    
                    frame = in_rgb.getCvFrame()
                    fps_counter.tick()
                    
                    # Step 1: Auto-framing (crop from 4K to 1080p)
                    framed = autoframer.process(frame)
                    
                    # Step 2: Background blur (on the cropped frame)
                    output = blur_processor.process(framed)
                    
                    # Send to virtual camera
                    vcam.send(output)
                    vcam.sleep_until_next_frame()
                    
                    # Show preview if enabled
                    if config.SHOW_PREVIEW:
                        # Add status overlay
                        preview = output.copy()
                        status = f"FPS: {fps_counter.fps:.1f}"
                        if config.BLUR_ENABLED:
                            status += f" | Blur: {config.BLUR_STRENGTH}"
                        if config.AUTOFRAME_ENABLED:
                            face_status = "tracking" if autoframer.face_detected else "searching"
                            status += f" | Frame: {face_status}"
                        
                        cv2.putText(preview, status, (10, 30),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                        
                        cv2.imshow("Opal C1 Virtual Camera", preview)
                    
                    # Handle keyboard input
                    key = cv2.waitKey(1) & 0xFF
                    if key == ord('q'):
                        print("\n[INFO] Shutting down...")
                        break
                    elif key == ord('b'):
                        config.BLUR_ENABLED = not config.BLUR_ENABLED
                        print(f"[INFO] Background blur: {'ON' if config.BLUR_ENABLED else 'OFF'}")
                    elif key == ord('a'):
                        config.AUTOFRAME_ENABLED = not config.AUTOFRAME_ENABLED
                        print(f"[INFO] Auto-framing: {'ON' if config.AUTOFRAME_ENABLED else 'OFF'}")
                    elif key == ord('+') or key == ord('='):
                        config.BLUR_STRENGTH = min(99, config.BLUR_STRENGTH + 4)
                        if config.BLUR_STRENGTH % 2 == 0:
                            config.BLUR_STRENGTH += 1
                        print(f"[INFO] Blur strength: {config.BLUR_STRENGTH}")
                    elif key == ord('-'):
                        config.BLUR_STRENGTH = max(5, config.BLUR_STRENGTH - 4)
                        if config.BLUR_STRENGTH % 2 == 0:
                            config.BLUR_STRENGTH += 1
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
            print("  Make sure the camera is plugged in via USB-C")
            print("  and no other application is using it.")
            print(f"\n  Technical error: {e}")
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
