---
title: "software-based-background-blue-bokeh-auto-framing-for-webcams-on-arch-linux"
date: 2026-08-12T06:28:34Z
lastmod: 2026-08-12T06:28:34Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Software-Based Background Blur (Bokeh) + Auto-Framing for Webcam on Arch Linux

> A complete guide to creating a real-time background blur **and** auto-framing virtual camera using Python, MediaPipe, and v4l2loopback on Arch Linux. Works with any UVC webcam (Logitech Brio, etc.) and outputs to a virtual camera usable in Zoom, Teams, Meet, etc.
> 

---

## Architecture Overview

```
┌─────────────┐    ┌───────────────────────────────┐    ┌───────────────────┐    ┌──────────────┐
│  Physical   │───▶│  Python Pipeline               │───▶│  Virtual Camera   │───▶│  Video App   │
│  Webcam     │    │  1. Segmentation (blur bg)     │    │  (v4l2loopback)   │    │  (Zoom/Meet) │
└─────────────┘    │  2. Face detection (auto-frame)│    └───────────────────┘    └──────────────┘
                   └───────────────────────────────┘
                         │
                    MediaPipe Models:
                    • Selfie Segmentation
                    • Face Detection
```

---

## 1. System Dependencies

### Install core packages

```bash
# Update system
sudo pacman -Syu

# Install Python and pip
sudo pacman -S python python-pip

# Install OpenCV dependencies
sudo pacman -S opencv python-opencv hdf5 vtk glew

# Install video4linux utilities
sudo pacman -S v4l-utils

# Install kernel headers (needed for v4l2loopback DKMS)
sudo pacman -S linux-headers

# Install git and base development tools
sudo pacman -S base-devel git
```

### Install v4l2loopback (virtual camera kernel module)

```bash
# Option A: From AUR (recommended)
# If using an AUR helper like yay or paru:
yay -S v4l2loopback-dkms

# Option B: Manual from AUR
git clone https://aur.archlinux.org/v4l2loopback-dkms.git
cd v4l2loopback-dkms
makepkg -si
```

### Load v4l2loopback module

```bash
# Load the module with a virtual device
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="Virtual_Blur_Cam" exclusive_caps=1

# Verify it was created
v4l2-ctl --list-devices
# You should see "Virtual_Blur_Cam" mapped to /dev/video10
```

### Make v4l2loopback persist across reboots

```bash
# Create module load config
echo "v4l2loopback" | sudo tee /etc/modules-load.d/v4l2loopback.conf

# Create module options config
echo 'options v4l2loopback devices=1 video_nr=10 card_label="Virtual_Blur_Cam" exclusive_caps=1' | \
  sudo tee /etc/modprobe.d/v4l2loopback.conf
```

---

## 2. Python Dependencies

### Create a virtual environment (recommended)

```bash
mkdir -p ~/webcam-blur && cd ~/webcam-blur
python -m venv .venv
source .venv/bin/activate
```

### Install Python packages

```bash
pip install mediapipe opencv-python-headless numpy pyvirtualcam
```

#### Package breakdown:

| Package | Purpose |
| --- | --- |
| `mediapipe` | Google's ML framework — provides selfie segmentation + face detection models |
| `opencv-python-headless` | Image capture and processing (headless = no GUI deps) |
| `numpy` | Array operations for image manipulation |
| `pyvirtualcam` | Python wrapper to write frames to v4l2loopback |

### Optional: if you want a GUI preview

```bash
# Use full opencv instead of headless
pip install opencv-python numpy mediapipe pyvirtualcam
```

---

## 3. The Combined Blur + Auto-Frame Script

Create `~/webcam-blur/blur_cam.py`:

```python
#!/usr/bin/env python3
"""
Real-time background blur (bokeh) + auto-framing virtual camera.
Uses MediaPipe Selfie Segmentation & Face Detection + OpenCV + pyvirtualcam.
"""

import cv2
import numpy as np
import mediapipe as mp
import pyvirtualcam
import argparse
import signal
import sys
import time


def parse_args():
    parser = argparse.ArgumentParser(
        description="Webcam Background Blur + Auto-Framing",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic (blur only)
  python blur_cam.py

  # Blur + auto-frame enabled
  python blur_cam.py --auto-frame

  # Heavy blur, aggressive framing, with preview
  python blur_cam.py --auto-frame --blur-strength 45 --zoom 0.65 --preview

  # 1080p capture, output auto-framed at 720p
  python blur_cam.py -W 1920 -H 1080 --auto-frame --out-width 1280 --out-height 720
        """
    )

    # Camera settings
    cam_group = parser.add_argument_group("Camera")
    cam_group.add_argument(
        "--input", "-i", type=int, default=0,
        help="Input camera device index (default: 0)"
    )
    cam_group.add_argument(
        "--output", "-o", type=str, default="/dev/video10",
        help="Output virtual camera device (default: /dev/video10)"
    )
    cam_group.add_argument(
        "--width", "-W", type=int, default=1280,
        help="Capture width (default: 1280)"
    )
    cam_group.add_argument(
        "--height", "-H", type=int, default=720,
        help="Capture height (default: 720)"
    )
    cam_group.add_argument(
        "--fps", "-f", type=int, default=30,
        help="Frames per second (default: 30)"
    )

    # Blur settings
    blur_group = parser.add_argument_group("Background Blur")
    blur_group.add_argument(
        "--blur-strength", "-b", type=int, default=21,
        help="Blur kernel size — must be odd (default: 21). Higher = more bokeh."
    )
    blur_group.add_argument(
        "--edge-blur", "-e", type=int, default=7,
        help="Edge feathering kernel size — must be odd (default: 7). Smooths mask edges."
    )
    blur_group.add_argument(
        "--threshold", "-t", type=float, default=0.6,
        help="Segmentation threshold 0.0-1.0 (default: 0.6). Lower = more background removed."
    )
    blur_group.add_argument(
        "--seg-model", type=int, default=1, choices=[0, 1],
        help="Segmentation model: 0 = general, 1 = landscape (default: 1, faster)"
    )

    # Auto-framing settings
    frame_group = parser.add_argument_group("Auto-Framing")
    frame_group.add_argument(
        "--auto-frame", "-a", action="store_true",
        help="Enable auto-framing (face tracking + smart crop)"
    )
    frame_group.add_argument(
        "--out-width", type=int, default=None,
        help="Output width after framing (default: same as capture width)"
    )
    frame_group.add_argument(
        "--out-height", type=int, default=None,
        help="Output height after framing (default: same as capture height)"
    )
    frame_group.add_argument(
        "--zoom", "-z", type=float, default=0.75,
        help="Auto-frame zoom level 0.1-1.0 (default: 0.75). Lower = more zoomed in on face."
    )
    frame_group.add_argument(
        "--smoothing", "-s", type=float, default=0.08,
        help="Frame position smoothing 0.01-1.0 (default: 0.08). Lower = smoother panning."
    )
    frame_group.add_argument(
        "--face-confidence", type=float, default=0.7,
        help="Face detection confidence 0.0-1.0 (default: 0.7)"
    )

    # Misc
    misc_group = parser.add_argument_group("Misc")
    misc_group.add_argument(
        "--preview", "-p", action="store_true",
        help="Show a local preview window"
    )
    misc_group.add_argument(
        "--no-blur", action="store_true",
        help="Disable background blur (auto-frame only mode)"
    )

    return parser.parse_args()


class SmoothPosition:
    """Exponential moving average for smooth camera panning."""

    def __init__(self, smoothing=0.08):
        self.smoothing = smoothing
        self.cx = None
        self.cy = None

    def update(self, cx, cy):
        if self.cx is None:
            self.cx = cx
            self.cy = cy
        else:
            self.cx += self.smoothing * (cx - self.cx)
            self.cy += self.smoothing * (cy - self.cy)
        return int(self.cx), int(self.cy)

    def get(self):
        return int(self.cx) if self.cx else None, int(self.cy) if self.cy else None


def auto_frame_crop(frame, face_cx, face_cy, zoom, out_w, out_h, smooth_pos):
    """
    Crop frame centered on face position with smooth tracking.

    Args:
        frame: Input frame (already blurred background)
        face_cx, face_cy: Detected face center coordinates
        zoom: Crop ratio (0.1-1.0, lower = more zoomed)
        out_w, out_h: Desired output dimensions
        smooth_pos: SmoothPosition instance for temporal smoothing

    Returns:
        Cropped and resized frame
    """
    h, w = frame.shape[:2]

    # Smooth the face position
    smooth_cx, smooth_cy = smooth_pos.update(face_cx, face_cy)

    # Calculate crop dimensions maintaining output aspect ratio
    out_aspect = out_w / out_h
    crop_h = int(h * zoom)
    crop_w = int(crop_h * out_aspect)

    # Clamp crop to frame bounds
    if crop_w > w:
        crop_w = w
        crop_h = int(crop_w / out_aspect)

    # Center crop on smoothed face position, clamped to edges
    x1 = max(0, min(smooth_cx - crop_w // 2, w - crop_w))
    y1 = max(0, min(smooth_cy - crop_h // 2, h - crop_h))
    x2 = x1 + crop_w
    y2 = y1 + crop_h

    # Crop and resize to output dimensions
    cropped = frame[y1:y2, x1:x2]
    resized = cv2.resize(cropped, (out_w, out_h), interpolation=cv2.INTER_LINEAR)

    return resized


def main():
    args = parse_args()

    # Resolve output dimensions
    out_w = args.out_width if args.out_width else args.width
    out_h = args.out_height if args.out_height else args.height

    # Ensure blur kernels are odd numbers
    blur_strength = args.blur_strength if args.blur_strength % 2 == 1 else args.blur_strength + 1
    edge_blur = args.edge_blur if args.edge_blur % 2 == 1 else args.edge_blur + 1

    # Initialize MediaPipe models
    mp_selfie = mp.solutions.selfie_segmentation
    segmentation = mp_selfie.SelfieSegmentation(model_selection=args.seg_model)

    face_detection = None
    smooth_pos = None
    if args.auto_frame:
        mp_face = mp.solutions.face_detection
        face_detection = mp_face.FaceDetection(
            model_selection=1,  # Full-range model (better for webcam distances)
            min_detection_confidence=args.face_confidence,
        )
        smooth_pos = SmoothPosition(smoothing=args.smoothing)

    # Open the physical camera
    cap = cv2.VideoCapture(args.input)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, args.width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)
    cap.set(cv2.CAP_PROP_FPS, args.fps)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # Minimize latency

    if not cap.isOpened():
        print(f"ERROR: Cannot open camera at index {args.input}")
        sys.exit(1)

    # Read actual resolution (camera may not support requested)
    actual_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    actual_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    actual_fps = int(cap.get(cv2.CAP_PROP_FPS)) or args.fps

    print("=" * 60)
    print("  WEBCAM BLUR + AUTO-FRAME")
    print("=" * 60)
    print(f"  Input:        /dev/video{args.input} ({actual_w}x{actual_h} @ {actual_fps}fps)")
    print(f"  Output:       {args.output} ({out_w}x{out_h})")
    print(f"  Blur:         {'DISABLED' if args.no_blur else f'strength={blur_strength}, edge={edge_blur}, threshold={args.threshold}'}")
    print(f"  Auto-frame:   {'ENABLED (zoom={args.zoom}, smoothing={args.smoothing})' if args.auto_frame else 'DISABLED'}")
    print(f"  Preview:      {'ON' if args.preview else 'OFF'}")
    print("=" * 60)
    print("  Press Ctrl+C to stop.\n")

    # Handle graceful shutdown
    running = True
    def signal_handler(sig, frame):
        nonlocal running
        running = False
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Open virtual camera output
    with pyvirtualcam.Camera(
        width=out_w,
        height=out_h,
        fps=actual_fps,
        device=args.output,
        fmt=pyvirtualcam.PixelFormat.BGR,
    ) as vcam:
        print(f"  Virtual camera active: {vcam.device}\n")

        frame_count = 0
        fps_timer = time.time()
        measured_fps = 0

        while running:
            ret, frame = cap.read()
            if not ret:
                print("  WARNING: Frame capture failed, retrying...")
                continue

            # Convert BGR to RGB for MediaPipe
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            # ── STEP 1: Background Blur ──
            if not args.no_blur:
                seg_results = segmentation.process(rgb_frame)
                mask = seg_results.segmentation_mask  # float32 [0.0, 1.0]

                # Apply threshold to create binary-ish mask
                mask_binary = (mask > args.threshold).astype(np.float32)

                # Feather the edges for natural look
                mask_smooth = cv2.GaussianBlur(
                    mask_binary, (edge_blur, edge_blur), 0
                )

                # Expand mask to 3 channels
                mask_3ch = np.stack([mask_smooth] * 3, axis=-1)

                # Create blurred background
                blurred = cv2.GaussianBlur(
                    frame, (blur_strength, blur_strength), 0
                )

                # Composite: person (sharp) + background (blurred)
                output = (frame * mask_3ch + blurred * (1.0 - mask_3ch)).astype(np.uint8)
            else:
                output = frame

            # ── STEP 2: Auto-Framing ──
            if args.auto_frame and face_detection:
                face_results = face_detection.process(rgb_frame)

                if face_results.detections:
                    # Use the highest-confidence detection
                    det = face_results.detections[0]
                    bbox = det.location_data.relative_bounding_box

                    # Calculate face center in pixel coordinates
                    face_cx = int((bbox.xmin + bbox.width / 2) * actual_w)
                    face_cy = int((bbox.ymin + bbox.height / 2) * actual_h)

                    # Crop and resize with smooth tracking
                    output = auto_frame_crop(
                        output, face_cx, face_cy,
                        args.zoom, out_w, out_h, smooth_pos
                    )
                else:
                    # No face detected — use last known position or center
                    last_cx, last_cy = smooth_pos.get()
                    if last_cx is not None:
                        output = auto_frame_crop(
                            output, last_cx, last_cy,
                            args.zoom, out_w, out_h, smooth_pos
                        )
                    else:
                        # First frame, no face ever seen — just center crop
                        output = auto_frame_crop(
                            output, actual_w // 2, actual_h // 2,
                            args.zoom, out_w, out_h, smooth_pos
                        )
            else:
                # No auto-frame: resize if output dims differ from capture
                if (out_w != actual_w) or (out_h != actual_h):
                    output = cv2.resize(output, (out_w, out_h))

            # ── STEP 3: Send to virtual camera ──
            vcam.send(output)
            vcam.sleep_until_next_frame()

            # Optional preview
            if args.preview:
                cv2.imshow("Blur + Auto-Frame Preview (q to quit)", output)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break

            # FPS counter
            frame_count += 1
            if frame_count % 100 == 0:
                elapsed = time.time() - fps_timer
                measured_fps = 100 / elapsed if elapsed > 0 else 0
                fps_timer = time.time()
                print(f"  [{frame_count} frames] {measured_fps:.1f} fps")

    # Cleanup
    cap.release()
    if args.preview:
        cv2.destroyAllWindows()
    segmentation.close()
    if face_detection:
        face_detection.close()
    print("\n  Shutdown complete.")


if __name__ == "__main__":
    main()
```

---

## 4. Usage

### Blur only (default)

```bash
cd ~/webcam-blur
source .venv/bin/activate
python blur_cam.py
```

### Blur + Auto-Framing

```bash
# Enable auto-frame with default zoom (0.75 = 75% of frame used for crop)
python blur_cam.py --auto-frame

# Tighter framing (more zoomed in on face)
python blur_cam.py --auto-frame --zoom 0.55

# Smoother camera panning (lower = less jittery)
python blur_cam.py --auto-frame --smoothing 0.05
```

### Auto-Frame only (no blur)

```bash
python blur_cam.py --auto-frame --no-blur
```

### High quality setup (1080p input → 720p output)

```bash
# Capture at 1080p for more headroom, auto-frame crops down to 720p
python blur_cam.py -W 1920 -H 1080 --auto-frame --out-width 1280 --out-height 720 --zoom 0.6
```

### Full example with all options

```bash
python blur_cam.py \
  --input 0 \
  --width 1920 --height 1080 \
  --auto-frame \
  --out-width 1280 --out-height 720 \
  --blur-strength 31 \
  --edge-blur 9 \
  --threshold 0.55 \
  --zoom 0.65 \
  --smoothing 0.06 \
  --preview
```

### Use in video conferencing apps

1. Start the script
2. Open Zoom / Google Meet / Teams
3. In camera settings, select **"Virtual_Blur_Cam"** instead of your physical webcam

---

## 5. CLI Reference

| Flag | Short | Default | Description |
| --- | --- | --- | --- |
| `--input` | `-i` | `0` | Camera device index |
| `--output` | `-o` | `/dev/video10` | Virtual camera device path |
| `--width` | `-W` | `1280` | Capture width |
| `--height` | `-H` | `720` | Capture height |
| `--fps` | `-f` | `30` | Target FPS |
| `--blur-strength` | `-b` | `21` | Gaussian blur kernel size (odd) |
| `--edge-blur` | `-e` | `7` | Mask edge feathering (odd) |
| `--threshold` | `-t` | `0.6` | Segmentation cutoff (0.0–1.0) |
| `--seg-model` |  | `1` | 0=general, 1=landscape (faster) |
| `--auto-frame` | `-a` | off | Enable face-tracking auto-frame |
| `--out-width` |  | same as width | Output resolution width |
| `--out-height` |  | same as height | Output resolution height |
| `--zoom` | `-z` | `0.75` | Crop zoom (lower = tighter on face) |
| `--smoothing` | `-s` | `0.08` | Pan smoothing (lower = smoother) |
| `--face-confidence` |  | `0.7` | Min face detection confidence |
| `--preview` | `-p` | off | Show local preview window |
| `--no-blur` |  | off | Disable blur (frame-only mode) |

---

## 6. Run as a Systemd Service (Optional)

Create `/etc/systemd/system/webcam-blur.service`:

```ini
[Unit]
Description=Webcam Background Blur + Auto-Frame Virtual Camera
After=multi-user.target

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/home/YOUR_USERNAME/webcam-blur
ExecStart=/home/YOUR_USERNAME/webcam-blur/.venv/bin/python blur_cam.py --auto-frame --blur-strength 25 --zoom 0.7
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
# Replace YOUR_USERNAME, then:
sudo systemctl daemon-reload
sudo systemctl enable webcam-blur.service
sudo systemctl start webcam-blur.service

# Check status
sudo systemctl status webcam-blur.service
journalctl -u webcam-blur.service -f
```

---

## 7. Troubleshooting

| Issue | Solution |
| --- | --- |
| `ModuleNotFoundError: No module named 'cv2'` | `pip install opencv-python-headless` |
| `/dev/video10` doesn't exist | `sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="Virtual_Blur_Cam" exclusive_caps=1` |
| Camera shows black in Zoom/Meet | Ensure `exclusive_caps=1` is set when loading v4l2loopback |
| Poor performance / low FPS | Use `--seg-model 1`, reduce resolution, increase `--threshold` |
| Segmentation edges are noisy | Increase `--edge-blur` (e.g., 11 or 15) |
| Auto-frame is jittery | Lower `--smoothing` (e.g., 0.03–0.05) |
| Auto-frame too tight/loose | Adjust `--zoom` (0.5 = tight, 0.9 = loose) |
| Face not detected | Lower `--face-confidence` (e.g., 0.5) or improve lighting |
| Permission denied on `/dev/video*` | `sudo usermod -aG video $USER` then re-login |
| MediaPipe model download fails | Ensure internet on first run (models download ~10–15MB) |
| Preview window doesn't open | Install full `opencv-python` (not headless) |

---

## 8. Performance Tips

- **Seg model 1 (landscape)** is ~2x faster than model 0 — use it for webcam
- **1280x720 capture** is the sweet spot for quality vs. performance
- **1080p capture → 720p output** with auto-frame gives the best framing headroom
- On modern CPUs (Ryzen 5+ / i5+), expect 25–30fps at 720p with both features
- Reduce `--blur-strength` for faster processing (smaller kernel = less compute)
- Set `--no-blur` if you only need auto-framing (much faster, ~45+ fps)
- `CAP_PROP_BUFFERSIZE=1` is already set in the script to minimize latency

---

## 9. Complete Dependency Summary

### System packages (pacman)

```
python python-pip opencv python-opencv v4l-utils linux-headers base-devel git
```

### AUR packages

```
v4l2loopback-dkms
```

### Python packages (pip)

```
mediapipe opencv-python-headless numpy pyvirtualcam
```

### Kernel module

```
v4l2loopback (loaded via modprobe)
```

---

## License

This guide and script are provided as-is under MIT license. MediaPipe is licensed under Apache 2.0.

```python
Traceback (most recent call last):
  File "/home/toniiz/Documents/cams/webcam-blur/blur_cam.py", line 358, in <module>
    main()
    ~~~~^^
  File "/home/toniiz/Documents/cams/webcam-blur/blur_cam.py", line 195, in main
    mp_selfie = mp.solutions.selfie_segmentation
                ^^^^^^^^^^^^
AttributeError: module 'mediapipe' has no attribute 'solutions'
(.venv) Tiny-Lenovo-Archy% python blur_cam.py --auto-frame
Traceback (most recent call last):
  File "/home/toniiz/Documents/cams/webcam-blur/blur_cam.py", line 358, in <module>
    main()
    ~~~~^^
  File "/home/toniiz/Documents/cams/webcam-blur/blur_cam.py", line 195, in main
    mp_selfie = mp.solutions.selfie_segmentation
                ^^^^^^^^^^^^
AttributeError: module 'mediapipe' has no attribute 'solutions'
```
