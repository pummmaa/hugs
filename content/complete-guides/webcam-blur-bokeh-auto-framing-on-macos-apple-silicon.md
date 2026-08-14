---
title: "webcam-blur-bokeh-auto-framing-on-macos-apple-silicon"
date: 2026-08-14T17:37:42Z
lastmod: 2026-08-14T17:37:42Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Webcam Background Blur (Bokeh) + Auto-Framing on macOS (Apple Silicon)

> Real-time background blur **and** auto-framing virtual camera for **macOS on Apple Silicon (M1/M2/M3/M4)**, using Python, MediaPipe **Tasks API**, AVFoundation capture, and the **OBS Virtual Camera**. Designed for the **Opal C1** but works with any macOS camera.
> 

> **macOS vs Linux — what's different:**
> 
> - Capture uses **AVFoundation** (via `ffmpeg -f avfoundation` or OpenCV's AVFoundation backend), not V4L2.
> - The virtual camera is the **OBS Virtual Camera** (what `pyvirtualcam` targets on macOS), not `v4l2loopback`.
> - Dependencies come from **Homebrew**; there is no `v4l2-ctl`/udev.
> - Auto-start uses a **launchd LaunchAgent**, not systemd.
> - **The Opal C1 is native on macOS** (through the Opal app), so the Linux-only 720p ceiling does **not** apply — 1080p and 4K work here.
> 

---

## 1. Prerequisites & Homebrew packages

Install [Homebrew](https://brew.sh/) if you don't have it, then:

```bash
# Python 3.12 (MediaPipe supports 3.9–3.12, not 3.13) and ffmpeg
brew install python@3.12 ffmpeg

# OBS provides the macOS Virtual Camera that pyvirtualcam outputs to
brew install --cask obs
```

### One-time OBS Virtual Camera setup (required)

`pyvirtualcam` on macOS sends frames to the **OBS Virtual Camera** system extension:

1. Launch **OBS** once.
2. Click **Start Virtual Camera** (bottom-right), then **Stop Virtual Camera**. This registers
the camera's system extension.
3. Approve the extension if prompted: **System Settings → Privacy & Security → allow the OBS
system software**, then reboot if macOS asks.

You do **not** need to keep OBS open afterward — `pyvirtualcam` starts the virtual camera itself.

### Grant camera permission to your terminal

macOS gates camera access per-app. Grant it to whichever terminal you run the script from:

- **System Settings → Privacy & Security → Camera →** enable **Terminal** (or **iTerm**).
- If you later run it via `launchd`, the first run will prompt for camera access — approve it.

### The Opal C1 on macOS

The Opal C1 needs the **Opal app** (from ultra.me) running for the camera to appear. Once it's
running, the camera shows up in AVFoundation as **"Opal C1"** (or similar). Because macOS is the
Opal's native platform, it delivers clean 1080p/4K here — unlike Linux.

---

## 2. Python environment (must be 3.11 or 3.12)

```bash
mkdir -p ~/webcam-blur && cd ~/webcam-blur

# Create the venv with Homebrew's Python 3.12
/opt/homebrew/bin/python3.12 -m venv .venv
source .venv/bin/activate
python --version                      # -> 3.12.x

pip install --upgrade pip
pip install mediapipe opencv-python numpy pyvirtualcam
```

| Package | Purpose |
| --- | --- |
| `mediapipe` | Tasks API: ImageSegmenter (blur) + FaceDetector (auto-frame). Has arm64 wheels. |
| `opencv-python` | Image processing + optional preview + AVFoundation capture backend |
| `numpy` | Array math |
| `pyvirtualcam` | Sends frames to the OBS Virtual Camera on macOS |

> `/opt/homebrew` is the Apple-Silicon Homebrew prefix. If `python3.12` isn't found there, run
> `brew --prefix python@3.12` to locate it.
> 

---

## 3. Download the MediaPipe model files

```bash
cd ~/webcam-blur
curl -L -o selfie_segmenter.tflite \
  https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite
curl -L -o blaze_face_short_range.tflite \
  https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite
```

---

## 4. The Script — `blur_cam_mac.py`

```python
#!/usr/bin/env python3
"""
Real-time background blur (bokeh) + auto-framing virtual camera for macOS (Apple Silicon).
Capture: AVFoundation (ffmpeg or OpenCV). Output: OBS Virtual Camera via pyvirtualcam.
ML: MediaPipe Tasks API (ImageSegmenter + FaceDetector).
Requires Python 3.11/3.12 and model files:
  selfie_segmenter.tflite, blaze_face_short_range.tflite
"""

import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision
import pyvirtualcam
import argparse
import signal
import sys
import time
import os
import re
import subprocess


def parse_args():
    p = argparse.ArgumentParser(description="Webcam Blur + Auto-Frame (macOS / Apple Silicon)")
    # Camera / device
    p.add_argument("--input", "-i", type=int, default=0,
                   help="AVFoundation video device index (see --list-devices). Default 0.")
    p.add_argument("--auto-detect", "-a2", action="store_true",
                   help="Auto-find the camera by name (overrides --input).")
    p.add_argument("--camera-name", type=str, default="opal",
                   help="Model substring to match when --auto-detect is set (default: opal).")
    p.add_argument("--list-devices", action="store_true",
                   help="List AVFoundation video devices (index + name), then exit.")
    p.add_argument("--width", "-W", type=int, default=1920, help="Capture width (default 1920)")
    p.add_argument("--height", "-H", type=int, default=1080, help="Capture height (default 1080)")
    p.add_argument("--fps", "-f", type=int, default=30, help="Target FPS")
    p.add_argument("--backend", type=str, default="ffmpeg", choices=["ffmpeg", "opencv"],
                   help="Capture backend: 'ffmpeg' (default, robust) or 'opencv' (AVFoundation).")
    # Blur
    p.add_argument("--blur-strength", "-b", type=int, default=21, help="Blur kernel (odd)")
    p.add_argument("--edge-blur", "-e", type=int, default=7, help="Edge feather kernel (odd)")
    p.add_argument("--threshold", "-t", type=float, default=0.6, help="Foreground threshold 0-1")
    p.add_argument("--invert-mask", action="store_true", help="Flip mask if person/bg are swapped")
    p.add_argument("--no-blur", action="store_true", help="Disable blur (auto-frame only)")
    # Auto-frame
    p.add_argument("--auto-frame", action="store_true", help="Enable face-tracking crop")
    p.add_argument("--out-width", type=int, default=None, help="Output width after framing")
    p.add_argument("--out-height", type=int, default=None, help="Output height after framing")
    p.add_argument("--zoom", "-z", type=float, default=0.75, help="Crop zoom 0.1-1.0 (lower=tighter)")
    p.add_argument("--smoothing", "-s", type=float, default=0.08, help="Pan smoothing (lower=smoother)")
    p.add_argument("--face-confidence", type=float, default=0.7, help="Min face confidence")
    # Misc
    p.add_argument("--preview", "-p", action="store_true", help="Show a local preview window")
    return p.parse_args()


# ---------------- AVFoundation device discovery (macOS) ----------------

def list_avf_devices():
    """Return {index: name} for AVFoundation *video* devices, parsed from ffmpeg's stderr."""
    try:
        out = subprocess.run(
            ["ffmpeg", "-hide_banner", "-f", "avfoundation",
             "-list_devices", "true", "-i", ""],
            capture_output=True, text=True).stderr
    except Exception:
        return {}
    devices, in_video = {}, False
    for line in out.splitlines():
        if "AVFoundation video devices" in line:
            in_video = True; continue
        if "AVFoundation audio devices" in line:
            in_video = False; continue
        if in_video:
            m = re.search(r"\[(\d+)\]\s+(.*)$", line)   # "... [1] Opal C1"
            if m:
                devices[int(m.group(1))] = m.group(2).strip()
    return devices


def find_camera_index(name_substr="opal"):
    """Return the AVFoundation index of the first device whose name matches (case-insensitive)."""
    want = name_substr.lower()
    for idx, name in sorted(list_avf_devices().items()):
        if want in name.lower():
            return idx
    return None


# ---------------- ffmpeg capture backend (macOS / AVFoundation) ----------------

class FFmpegCapture:
    """Capture via ffmpeg's avfoundation input, delivering raw BGR24 frames."""
    def __init__(self, index, w, h, fps):
        self.width, self.height, self.fps = w, h, fps
        self._nbytes = w * h * 3
        cmd = ["ffmpeg", "-loglevel", "error", "-f", "avfoundation",
               "-framerate", str(fps), "-video_size", f"{w}x{h}",
               "-i", f"{index}:none", "-pix_fmt", "bgr24", "-f", "rawvideo", "-"]
        self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def _read_exact(self, n):
        chunks, got = [], 0
        while got < n:
            c = self.proc.stdout.read(n - got)
            if not c:
                return None
            chunks.append(c); got += len(c)
        return b"".join(chunks)

    def read(self):
        buf = self._read_exact(self._nbytes)
        if buf is None:
            return False, None
        return True, np.frombuffer(buf, np.uint8).reshape(self.height, self.width, 3)

    def stderr_text(self):
        try:
            return self.proc.stderr.read().decode(errors="ignore")
        except Exception:
            return ""

    def release(self):
        try:
            self.proc.terminate(); self.proc.wait(timeout=2)
        except Exception:
            try: self.proc.kill()
            except Exception: pass


def open_capture(args):
    """Return (cap, width, height, fps). cap exposes .read()/.release(). None on failure."""
    if args.backend == "ffmpeg":
        cap = FFmpegCapture(args.input, args.width, args.height, args.fps)
        return cap, cap.width, cap.height, cap.fps
    # OpenCV AVFoundation backend
    cap = cv2.VideoCapture(args.input, cv2.CAP_AVFOUNDATION)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, args.width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)
    cap.set(cv2.CAP_PROP_FPS, args.fps)
    if not cap.isOpened():
        return None, 0, 0, 0
    aw = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    ah = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    afps = int(cap.get(cv2.CAP_PROP_FPS)) or args.fps
    return cap, aw, ah, afps


class SmoothPosition:
    """Exponential moving average for smooth auto-frame panning."""
    def __init__(self, smoothing=0.08):
        self.smoothing = smoothing
        self.cx = None; self.cy = None
    def update(self, cx, cy):
        if self.cx is None:
            self.cx, self.cy = cx, cy
        else:
            self.cx += self.smoothing * (cx - self.cx)
            self.cy += self.smoothing * (cy - self.cy)
        return int(self.cx), int(self.cy)
    def get(self):
        return (int(self.cx), int(self.cy)) if self.cx is not None else (None, None)


def auto_frame_crop(frame, fcx, fcy, zoom, out_w, out_h, smooth):
    h, w = frame.shape[:2]
    scx, scy = smooth.update(fcx, fcy)
    aspect = out_w / out_h
    crop_h = int(h * zoom)
    crop_w = int(crop_h * aspect)
    if crop_w > w:
        crop_w = w; crop_h = int(crop_w / aspect)
    x1 = max(0, min(scx - crop_w // 2, w - crop_w))
    y1 = max(0, min(scy - crop_h // 2, h - crop_h))
    return cv2.resize(frame[y1:y1 + crop_h, x1:x1 + crop_w], (out_w, out_h),
                      interpolation=cv2.INTER_LINEAR)


def main():
    args = parse_args()

    if args.list_devices:
        devs = list_avf_devices()
        if not devs:
            print("No AVFoundation devices found (is ffmpeg installed and camera permission granted?).")
        else:
            print("AVFoundation video devices:")
            for idx, name in sorted(devs.items()):
                print(f"  [{idx}] {name}")
        sys.exit(0)

    if args.auto_detect:
        idx = find_camera_index(args.camera_name)
        if idx is not None:
            args.input = idx
            print(f"Auto-detected '{args.camera_name}' camera at AVFoundation index {idx}")
        else:
            print(f"WARNING: no '{args.camera_name}' camera found; using --input {args.input}.")

    out_w = args.out_width or args.width
    out_h = args.out_height or args.height
    blur = args.blur_strength | 1
    edge = args.edge_blur | 1

    for path in ([("selfie_segmenter.tflite")] if not args.no_blur else []) + \
                (["blaze_face_short_range.tflite"] if args.auto_frame else []):
        if not os.path.exists(path):
            print(f"ERROR: model file not found: {path}"); sys.exit(1)

    segmenter = None
    if not args.no_blur:
        segmenter = vision.ImageSegmenter.create_from_options(vision.ImageSegmenterOptions(
            base_options=mp_python.BaseOptions(model_asset_path="selfie_segmenter.tflite"),
            running_mode=vision.RunningMode.IMAGE, output_confidence_masks=True))

    detector = None; smooth = None
    if args.auto_frame:
        detector = vision.FaceDetector.create_from_options(vision.FaceDetectorOptions(
            base_options=mp_python.BaseOptions(model_asset_path="blaze_face_short_range.tflite"),
            running_mode=vision.RunningMode.IMAGE, min_detection_confidence=args.face_confidence))
        smooth = SmoothPosition(args.smoothing)

    cap, aw, ah, afps = open_capture(args)
    if cap is None:
        print(f"ERROR: cannot open camera index {args.input}"); sys.exit(1)
    print(f"Input idx {args.input} {aw}x{ah}@{afps} | Output {out_w}x{out_h} -> OBS Virtual Camera")
    print(f"Blur={'off' if args.no_blur else blur} | AutoFrame={'on' if args.auto_frame else 'off'}")
    print("Ctrl+C to stop.\n")

    running = True
    def stop(*_):
        nonlocal running; running = False
    signal.signal(signal.SIGINT, stop); signal.signal(signal.SIGTERM, stop)

    # On macOS pyvirtualcam automatically targets the OBS Virtual Camera (no device path).
    with pyvirtualcam.Camera(width=out_w, height=out_h, fps=afps,
                             fmt=pyvirtualcam.PixelFormat.BGR) as vcam:
        print(f"Virtual camera active: {vcam.device}\n")
        n = 0; fail = 0; t0 = time.time()
        while running:
            ok, frame = cap.read()
            if not ok:
                fail += 1
                if fail > 30:
                    print("ERROR: no frames. Check --backend/--list-devices/camera permission.")
                    if isinstance(cap, FFmpegCapture):
                        err = cap.stderr_text()
                        if err: print("ffmpeg said:\n" + err)
                    break
                continue
            fail = 0
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

            if segmenter is not None:
                fg = segmenter.segment(mp_img).confidence_masks[0].numpy_view()
                if args.invert_mask:
                    fg = 1.0 - fg
                mask = cv2.GaussianBlur((fg > args.threshold).astype(np.float32), (edge, edge), 0)
                mask3 = np.dstack([mask] * 3)
                bg = cv2.GaussianBlur(frame, (blur, blur), 0)
                out = (frame * mask3 + bg * (1.0 - mask3)).astype(np.uint8)
            else:
                out = frame

            if detector is not None:
                res = detector.detect(mp_img)
                if res.detections:
                    bb = res.detections[0].bounding_box
                    out = auto_frame_crop(out, bb.origin_x + bb.width // 2,
                                          bb.origin_y + bb.height // 2,
                                          args.zoom, out_w, out_h, smooth)
                else:
                    lcx, lcy = smooth.get()
                    if lcx is None: lcx, lcy = aw // 2, ah // 2
                    out = auto_frame_crop(out, lcx, lcy, args.zoom, out_w, out_h, smooth)
            elif (out_w, out_h) != (aw, ah):
                out = cv2.resize(out, (out_w, out_h))

            vcam.send(out)
            vcam.sleep_until_next_frame()

            if args.preview:
                cv2.imshow("Blur + Auto-Frame (q quits)", out)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break

            n += 1
            if n % 100 == 0:
                dt = time.time() - t0
                print(f"[{n}] {100/dt:.1f} fps"); t0 = time.time()

    cap.release()
    if args.preview: cv2.destroyAllWindows()
    if segmenter: segmenter.close()
    if detector: detector.close()
    print("\nStopped.")


if __name__ == "__main__":
    main()
```

---

## 5. Usage

```bash
cd ~/webcam-blur && source .venv/bin/activate

# See available cameras and their indices
python blur_cam_mac.py --list-devices
#   AVFoundation video devices:
#     [0] FaceTime HD Camera
#     [1] Opal C1

# Auto-detect the Opal + blur + auto-frame at 1080p (recommended)
python blur_cam_mac.py --auto-detect --width 1920 --height 1080 --fps 30 --auto-frame

# Explicit device index instead of auto-detect
python blur_cam_mac.py -i 1 --width 1920 --height 1080 --fps 30 --auto-frame

# Blur only, no crop
python blur_cam_mac.py --auto-detect --width 1920 --height 1080

# 4K (Opal is native on macOS — heavy but works; expect lower FPS)
python blur_cam_mac.py --auto-detect --width 3840 --height 2160 --fps 30 --out-width 1920 --out-height 1080

# If the person gets blurred instead of the background
python blur_cam_mac.py --auto-detect --invert-mask
```

Then in Zoom/Meet/Teams pick **"OBS Virtual Camera"** as the camera.

---

## 6. CLI Reference

| Flag | Short | Default | Description |
| --- | --- | --- | --- |
| `--input` | `-i` | `0` | AVFoundation device index (see `--list-devices`) |
| `--auto-detect` |  | off | Auto-find the camera by name (overrides `--input`) |
| `--camera-name` |  | `opal` | Model substring to match when `--auto-detect` is set |
| `--list-devices` |  | off | List AVFoundation video devices, then exit |
| `--width`/`--height` | `-W`/`-H` | `1920`/`1080` | Capture resolution |
| `--fps` | `-f` | `30` | Target FPS |
| `--backend` |  | `ffmpeg` | `ffmpeg` (robust) or `opencv` (AVFoundation) |
| `--blur-strength` | `-b` | `21` | Blur kernel (odd) |
| `--edge-blur` | `-e` | `7` | Edge feather (odd) |
| `--threshold` | `-t` | `0.6` | Foreground cutoff 0-1 |
| `--invert-mask` |  | off | Flip if person/bg swapped |
| `--no-blur` |  | off | Disable blur |
| `--auto-frame` |  | off | Face-tracking crop |
| `--out-width`/`--out-height` |  | = capture | Output resolution |
| `--zoom` | `-z` | `0.75` | Crop zoom (lower = tighter) |
| `--smoothing` | `-s` | `0.08` | Pan smoothing (lower = smoother) |
| `--face-confidence` |  | `0.7` | Min face confidence |
| `--preview` | `-p` | off | Local preview window |

---

## 7. Run at login with launchd (macOS service)

macOS uses **launchd** instead of systemd. Create a **LaunchAgent** (runs in your GUI session,
so it has camera + virtual-camera access).

Create `~/Library/LaunchAgents/com.user.webcam-blur.plist` (replace `YOU` with your username):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.webcam-blur</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOU/webcam-blur/.venv/bin/python</string>
        <string>/Users/YOU/webcam-blur/blur_cam_mac.py</string>
        <string>--auto-detect</string>
        <string>--camera-name</string><string>opal</string>
        <string>--width</string><string>1920</string>
        <string>--height</string><string>1080</string>
        <string>--fps</string><string>30</string>
        <string>--auto-frame</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/YOU/webcam-blur</string>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>/tmp/webcam-blur.log</string>
    <key>StandardErrorPath</key><string>/tmp/webcam-blur.err</string>
</dict>
</plist>
```

Load / manage it:

```bash
# Load (modern syntax)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.webcam-blur.plist
# (older macOS: launchctl load ~/Library/LaunchAgents/com.user.webcam-blur.plist)

launchctl kickstart -k gui/$(id -u)/com.user.webcam-blur    # (re)start now
tail -f /tmp/webcam-blur.err                                 # watch logs

# Unload / stop
launchctl bootout gui/$(id -u)/com.user.webcam-blur
```

> **Camera permission caveat:** the **first** launchd run will trigger a macOS camera-permission
> prompt attributed to `python`. Approve it (**System Settings → Privacy & Security → Camera**).
> If it never prompts, run the script once manually from Terminal first to grant access, then
> load the agent. The **Opal app must also be running** for the Opal C1 to appear.
> 

---

## 8. Troubleshooting

| Issue | Fix |
| --- | --- |
| `--list-devices` shows nothing | Install `ffmpeg` (`brew install ffmpeg`) and grant Terminal camera access. |
| No "OBS Virtual Camera" in Zoom/Meet | Launch OBS once, click Start→Stop Virtual Camera, approve the system extension, reboot. |
| `pyvirtualcam` error: virtual camera not installed | OBS (26.1+) must be installed and its virtual camera registered once. |
| Opal C1 not in `--list-devices` | Start the **Opal app** — the camera only appears while it's running. |
| Camera opens but frames are black | Grant camera permission to your terminal / to `python`; check the Opal app isn't exclusively using it. |
| Green/distorted colors | Use the default `--backend ffmpeg` (outputs clean BGR). |
| Low FPS at 4K | Expected — use 1080p, or `--out-width/--out-height` to downscale output, or `--no-blur`. |
| `mediapipe` install fails | Use Python 3.12 (`brew install python@3.12`); MediaPipe has no 3.13 wheels. |
| launchd job won't start | `launchctl print gui/$(id -u)/com.user.webcam-blur` and check `/tmp/webcam-blur.err`. |

---

## 9. Dependency Summary

**Homebrew:** `python@3.12 ffmpeg` + `--cask obs`
**pip (in a 3.12 venv):** `mediapipe opencv-python numpy pyvirtualcam`
**Model files:** `selfie_segmenter.tflite`, `blaze_face_short_range.tflite`
**Virtual camera:** OBS Virtual Camera (registered once via OBS)
**Permissions:** Camera access for your terminal / `python`; approve OBS system extension

---

## Key differences from the Linux version

| Concern | Linux | macOS (Apple Silicon) |
| --- | --- | --- |
| Capture API | V4L2 (`/dev/videoN`) | AVFoundation (device index) |
| Virtual camera | `v4l2loopback` | OBS Virtual Camera |
| Packages | pacman | Homebrew |
| Device detect | udev | AVFoundation device list |
| Service | systemd | launchd LaunchAgent |
| Opal C1 ceiling | 720p only | Full 1080p/4K (native) |

*Provided as-is under MIT license. MediaPipe is Apache 2.0.*
