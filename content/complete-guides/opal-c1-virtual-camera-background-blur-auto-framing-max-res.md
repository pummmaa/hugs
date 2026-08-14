---
title: "opal-c1-virtual-camera-background-blur-auto-framing-max-res"
date: 2026-08-13T17:48:05Z
lastmod: 2026-08-13T17:48:05Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Webcam Background Blur (Bokeh) + Auto-Framing on Arch Linux

> Real-time background blur **and** auto-framing virtual camera using Python, MediaPipe **Tasks API**, and v4l2loopback. Works with any UVC webcam (Logitech Brio, Opal C1, etc.) and outputs a virtual camera usable in Zoom, Teams, Meet, etc.
> 

> **IMPORTANT (read first):** The legacy `mediapipe.solutions.*` API (e.g. `mp.solutions.selfie_segmentation`) has been **removed/broken in recent MediaPipe builds**, and MediaPipe has **no wheels for Python 3.13** (Arch's default). This guide uses the current, supported **Tasks API** and requires **Python 3.11 or 3.12**.
> 

---

> **⚠️ Honest bottom line — Opal C1 on Linux:** The Opal C1 reliably streams **only 720p (NV12)**
> over raw Linux UVC. Requesting 1080p/1440p/4K distorts the image or makes the camera
> **disconnect/reset**, because its high-resolution pipeline depends on Opal's own macOS/Windows
> app. **On Linux, run everything at 1280x720.** If you need higher resolution, use a native
> MJPG/H.264 webcam such as the **Logitech Brio**. See *"Opal C1 — every option that works"* and
> *"Opal C1 keeps disconnecting"* below.
> 

## 0. Fix for `AttributeError: module 'mediapipe' has no attribute 'solutions'`

This happens because either (a) you're on Python 3.13 (no MediaPipe wheel -> broken install), or (b) your MediaPipe version dropped the legacy `solutions` API. The robust fix is to use **Python 3.12 + the Tasks API script below**.

```bash
# Confirm your Python version
python --version        # if 3.13.x -> that's the problem
```

---

## 1. System Dependencies

```bash
sudo pacman -Syu
sudo pacman -S v4l-utils linux-headers base-devel git ffmpeg

# Python 3.12 (MediaPipe does NOT support 3.13 yet).
# Arch ships 3.13 as default `python`, so install 3.12 from AUR:
yay -S python312          # provides the `python3.12` binary
# (alternatively use pyenv or uv to get a 3.12 interpreter)

# v4l2loopback kernel module (virtual camera)
yay -S v4l2loopback-dkms
```

### Load v4l2loopback

```bash
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="Virtual_Blur_Cam" exclusive_caps=1
v4l2-ctl --list-devices     # confirm /dev/video10 = Virtual_Blur_Cam
```

### Persist across reboots

```bash
echo "v4l2loopback" | sudo tee /etc/modules-load.d/v4l2loopback.conf
echo 'options v4l2loopback devices=1 video_nr=10 card_label="Virtual_Blur_Cam" exclusive_caps=1' | \
  sudo tee /etc/modprobe.d/v4l2loopback.conf
```

---

## 2. Python Environment (must be 3.11 or 3.12)

```bash
mkdir -p ~/webcam-blur && cd ~/webcam-blur

# Create venv with Python 3.12 explicitly
python3.12 -m venv .venv
source .venv/bin/activate

python --version          # should now say 3.12.x

pip install --upgrade pip
pip install mediapipe opencv-python-headless numpy pyvirtualcam
```

| Package | Purpose |
| --- | --- |
| `mediapipe` | Tasks API: ImageSegmenter (blur) + FaceDetector (auto-frame) |
| `opencv-python-headless` | Capture + image processing |
| `numpy` | Array math |
| `pyvirtualcam` | Writes frames to v4l2loopback |

> For a live preview window use `opencv-python` instead of `-headless`.
> 

---

## 3. Download the Model Files (required by Tasks API)

Unlike the old `solutions` API, the Tasks API needs explicit `.tflite` models:

```bash
cd ~/webcam-blur

# Selfie segmentation model (background blur)
wget -O selfie_segmenter.tflite \
  https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite

# Face detector model (auto-framing) - BlazeFace short-range, good for webcam distances
wget -O blaze_face_short_range.tflite \
  https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite
```

---

## What Caused the `AttributeError: module 'mediapipe' has no attribute 'solutions'`

The legacy MediaPipe **Solutions API** is gone in your install. Two things converge:

1. **Python 3.13** — Arch's default `python` is 3.13, and MediaPipe has **no wheels for 3.13 yet**, so `pip install mediapipe` produces a broken/partial install where submodules like `solutions` never load.
2. **API deprecation** — even on supported Python, recent MediaPipe builds **removed** `mp.solutions.selfie_segmentation` and `mp.solutions.face_detection` in favor of the newer **Tasks API** (`mediapipe.tasks.python.vision`).

The fix on both counts: use **Python 3.12** + the **Tasks API** script in this guide. (Pinning an older MediaPipe that still has `solutions` also requires Python <=3.12, so switching interpreters is unavoidable either way — the Tasks API is the future-proof path.)

---

## Quick Recovery Steps (TL;DR)

```bash
# 1. Get Python 3.12 (MediaPipe does NOT support 3.13)
yay -S python312

# 2. Recreate the venv with 3.12
cd ~/webcam-blur
rm -rf .venv
python3.12 -m venv .venv
source .venv/bin/activate
python --version                 # should say 3.12.x
pip install --upgrade pip
pip install mediapipe opencv-python-headless numpy pyvirtualcam

# 3. Download the Tasks API model files
wget -O selfie_segmenter.tflite \
  https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite
wget -O blaze_face_short_range.tflite \
  https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite

# 4. Use the Tasks-API blur_cam.py from section 4 below, then run:
python blur_cam.py --auto-frame
```

---

## 4. The Combined Script (Tasks API) — `blur_cam.py`

```python
#!/usr/bin/env python3
"""
Real-time background blur (bokeh) + auto-framing virtual camera.
Uses MediaPipe TASKS API (ImageSegmenter + FaceDetector) + OpenCV + pyvirtualcam.
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
import glob


def parse_args():
    p = argparse.ArgumentParser(description="Webcam Background Blur + Auto-Framing (Tasks API)")
    # Camera
    p.add_argument("--input", "-i", type=int, default=0, help="Input camera index (default 0)")
    p.add_argument("--output", "-o", type=str, default="/dev/video10", help="Virtual cam device")
    p.add_argument("--width", "-W", type=int, default=1280, help="Capture width")
    p.add_argument("--height", "-H", type=int, default=720, help="Capture height")
    p.add_argument("--fps", "-f", type=int, default=30, help="Target FPS")
    p.add_argument("--fourcc", type=str, default="MJPG",
                   help="Capture pixel format: MJPG (default, Brio), YUYV/NV12 (uncompressed cams like the Opal C1), AUTO (pick the camera's best-supported format), or NONE (driver default). If the requested format is not supported, the script auto-falls back to one that is.")
    p.add_argument("--max-res", action="store_true",
                   help="Auto-detect and use the camera's MAX resolution for the chosen --fourcc (needs v4l-utils). Overrides --width/--height.")
    p.add_argument("--list-formats", action="store_true",
                   help="List the camera's supported formats + resolutions, then exit.")
    p.add_argument("--backend", type=str, default="ffmpeg", choices=["ffmpeg", "opencv"],
                   help="Capture backend. 'ffmpeg' (default) handles NV12/YUYV stride reliably at all resolutions; 'opencv' uses cv2.VideoCapture (fine for MJPG cams like Brio).")
    # Models
    p.add_argument("--seg-model", type=str, default="selfie_segmenter.tflite", help="Segmenter .tflite")
    p.add_argument("--face-model", type=str, default="blaze_face_short_range.tflite", help="Face .tflite")
    # Blur
    p.add_argument("--blur-strength", "-b", type=int, default=21, help="Blur kernel (odd)")
    p.add_argument("--edge-blur", "-e", type=int, default=7, help="Edge feather kernel (odd)")
    p.add_argument("--threshold", "-t", type=float, default=0.6, help="Foreground threshold 0-1")
    p.add_argument("--invert-mask", action="store_true", help="Flip mask if person/bg are swapped")
    p.add_argument("--no-blur", action="store_true", help="Disable blur (auto-frame only)")
    # Auto-frame
    p.add_argument("--auto-frame", "-a", action="store_true", help="Enable face-tracking crop")
    p.add_argument("--out-width", type=int, default=None, help="Output width after framing")
    p.add_argument("--out-height", type=int, default=None, help="Output height after framing")
    p.add_argument("--zoom", "-z", type=float, default=0.75, help="Crop zoom 0.1-1.0 (lower=tighter)")
    p.add_argument("--smoothing", "-s", type=float, default=0.08, help="Pan smoothing (lower=smoother)")
    p.add_argument("--face-confidence", type=float, default=0.7, help="Min face confidence")
    # Misc
    p.add_argument("--preview", "-p", action="store_true", help="Show local preview window")
    p.add_argument("--auto-detect", action="store_true",
                   help="Auto-find the camera capture node by name (overrides --input). "
                        "Robust against the /dev/videoN number changing between reboots.")
    p.add_argument("--camera-name", type=str, default="opal",
                   help="Model substring to match when --auto-detect is set (default: opal).")
    return p.parse_args()


class SmoothPosition:
    """Exponential moving average for smooth panning."""
    def __init__(self, smoothing=0.08):
        self.smoothing = smoothing
        self.cx = None
        self.cy = None
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
        crop_w = w
        crop_h = int(crop_w / aspect)
    x1 = max(0, min(scx - crop_w // 2, w - crop_w))
    y1 = max(0, min(scy - crop_h // 2, h - crop_h))
    cropped = frame[y1:y1 + crop_h, x1:x1 + crop_w]
    return cv2.resize(cropped, (out_w, out_h), interpolation=cv2.INTER_LINEAR)


def list_v4l2_formats(device_path):
    """Parse `v4l2-ctl --list-formats-ext` -> {FOURCC: sorted[(w, h)]}. Empty dict if unavailable."""
    try:
        out = subprocess.check_output(
            ["v4l2-ctl", "-d", device_path, "--list-formats-ext"],
            stderr=subprocess.DEVNULL, text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return {}
    formats, current = {}, None
    for line in out.splitlines():
        mf = re.search(r"\]:\s*'(\w+)'", line)      # e.g. "[0]: 'YUYV' (YUYV 4:2:2)"
        if mf:
            current = mf.group(1)
            formats.setdefault(current, set())
            continue
        ms = re.search(r"(\d+)x(\d+)", line)         # e.g. "Size: Discrete 1920x1080"
        if ms and current and "Size" in line:
            formats[current].add((int(ms.group(1)), int(ms.group(2))))
    return {k: sorted(v, key=lambda wh: wh[0] * wh[1]) for k, v in formats.items()}


def detect_max_resolution(device_path, fourcc):
    """Return the largest (w, h) supported for `fourcc` (or overall if NONE). None if unknown."""
    fmts = list_v4l2_formats(device_path)
    if not fmts:
        return None
    key = fourcc.upper()
    if key == "NONE":
        sizes = [wh for lst in fmts.values() for wh in lst]
    else:
        sizes = fmts.get(key, [])
    return max(sizes, key=lambda wh: wh[0] * wh[1]) if sizes else None


def print_formats(device_path):
    fmts = list_v4l2_formats(device_path)
    if not fmts:
        print("Could not enumerate formats. Install v4l-utils:  sudo pacman -S v4l-utils")
        return
    print(f"Supported formats for {device_path}:")
    for fcc, sizes in fmts.items():
        print(f"  {fcc}: " + ", ".join(f"{w}x{h}" for w, h in sizes))


def normalize_bgr(frame, w, h):
    """Guarantee a 3-channel BGR frame. Safety net for the case where OpenCV still returns
    a raw NV12/YUYV buffer (single channel, or height = h*3/2) instead of a converted image."""
    if frame is None or (frame.ndim == 3 and frame.shape[2] == 3):
        return frame
    if frame.ndim == 2:
        if h and frame.shape[0] == (h * 3) // 2:            # raw NV12 (Y plane + interleaved UV)
            return cv2.cvtColor(frame, cv2.COLOR_YUV2BGR_NV12)
        if h and w and frame.size == h * w * 2:             # packed YUYV as (h, w*2)
            return cv2.cvtColor(frame.reshape(h, w, 2), cv2.COLOR_YUV2BGR_YUYV)
    if frame.ndim == 3 and frame.shape[2] == 2:             # YUYV as 2-channel
        return cv2.cvtColor(frame, cv2.COLOR_YUV2BGR_YUYV)
    return frame


class FFmpegCapture:
    """Capture frames via an ffmpeg subprocess that outputs raw BGR24. This bypasses
    OpenCV's V4L2 path, which mishandles NV12 stride at higher resolutions (green/distorted/
    zoomed image). ffmpeg negotiates the format and hands us clean, correctly-sized frames."""
    IFMT = {"NV12": "nv12", "YUYV": "yuyv422", "YUY2": "yuyv422", "MJPG": "mjpeg"}

    def __init__(self, device, w, h, fps, fourcc):
        self.width, self.height, self.fps = w, h, fps
        self._nbytes = w * h * 3
        cmd = ["ffmpeg", "-loglevel", "error", "-f", "v4l2"]
        ifmt = self.IFMT.get(fourcc.upper())
        if ifmt:
            cmd += ["-input_format", ifmt]
        cmd += ["-video_size", f"{w}x{h}", "-framerate", str(fps),
                "-i", device, "-pix_fmt", "bgr24", "-f", "rawvideo", "-"]
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
            self.proc.terminate()
            self.proc.wait(timeout=2)
        except Exception:
            try:
                self.proc.kill()
            except Exception:
                pass


def open_capture(args, device_path):
    """Return (cap, width, height, fps). cap exposes .read()/.release(). None on failure."""
    fourcc = args.fourcc.upper()
    if args.backend == "ffmpeg":
        cap = FFmpegCapture(device_path, args.width, args.height, args.fps, fourcc)
        return cap, cap.width, cap.height, cap.fps
    # OpenCV backend
    cap = cv2.VideoCapture(args.input)
    if fourcc == "MJPG":                      # only force MJPG (compressed) to cut USB bandwidth
        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
    cap.set(cv2.CAP_PROP_CONVERT_RGB, 1.0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, args.width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)
    cap.set(cv2.CAP_PROP_FPS, args.fps)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    if not cap.isOpened():
        return None, 0, 0, 0
    aw = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    ah = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    afps = int(cap.get(cv2.CAP_PROP_FPS)) or args.fps
    return cap, aw, ah, afps


def _udev_properties(node):
    try:
        out = subprocess.check_output(
            ["udevadm", "info", "-q", "property", "--name", node],
            stderr=subprocess.DEVNULL, text=True)
    except Exception:
        return {}
    props = {}
    for line in out.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            props[k] = v
    return props


def find_camera_node(name_substr="opal"):
    """Return the /dev/videoN index of the first CAPTURE node whose model matches
    name_substr (case-insensitive). None if not found. Uses udev so it survives the
    /dev/videoN number changing between reboots/replugs."""
    want = name_substr.lower()
    nodes = sorted(glob.glob("/dev/video*"),
                   key=lambda p: int(re.sub(r"\D", "", p) or "-1"))
    for node in nodes:
        props = _udev_properties(node)
        name = " ".join([
            props.get("ID_V4L_PRODUCT", ""),
            props.get("ID_MODEL", ""),
            props.get("ID_MODEL_ENC", ""),
            props.get("ID_MODEL_FROM_DATABASE", ""),
        ]).lower()
        caps = props.get("ID_V4L_CAPABILITIES", "")
        if want in name and ":capture:" in caps:
            m = re.search(r"(\d+)$", node)
            if m:
                return int(m.group(1))
    return None


def main():
    args = parse_args()
    if args.auto_detect:
        idx = find_camera_node(args.camera_name)
        if idx is not None:
            args.input = idx
            print(f"Auto-detected '{args.camera_name}' camera at /dev/video{idx}")
        else:
            print(f"WARNING: no '{args.camera_name}' camera found; using --input {args.input}.")
    device_path = f"/dev/video{args.input}"

    # Just list formats and exit
    if args.list_formats:
        print_formats(device_path)
        sys.exit(0)

    # Enumerate what the camera actually supports, then pick a usable capture format.
    # This fixes the common case where the default MJPG isn't offered (e.g. the Opal C1
    # only exposes NV12) — we auto-fall back to a supported format instead of silently
    # ignoring the request and dropping to a low default resolution.
    fmts = list_v4l2_formats(device_path)            # {FOURCC: [(w, h), ...]}
    req = args.fourcc.upper()
    chosen = req
    if fmts:
        best_fmt = max(fmts, key=lambda f: max((w * h for w, h in fmts[f]), default=0))
        if req == "AUTO":
            chosen = best_fmt
            print(f"Auto-selected capture format: {chosen}")
        elif req not in ("NONE",) and req not in fmts:
            print(f"WARNING: camera does not support '{req}'. "
                  f"Available: {', '.join(fmts)}. Falling back to '{best_fmt}'.")
            chosen = best_fmt
    elif req == "AUTO":
        chosen = "NONE"                              # can't enumerate; let the driver decide
    args.fourcc = chosen

    # Auto-detect the camera's MAX resolution for the chosen format
    if args.max_res:
        sizes = fmts.get(chosen, []) if fmts else []
        if not sizes and fmts:                       # NONE/unknown -> overall max across formats
            sizes = [wh for lst in fmts.values() for wh in lst]
        if sizes:
            args.width, args.height = max(sizes, key=lambda wh: wh[0] * wh[1])
            print(f"Max resolution for {chosen}: {args.width}x{args.height}")
        else:
            print("WARNING: could not auto-detect max resolution (is v4l-utils installed?); "
                  "using --width/--height.")

    # Performance guard for very high resolutions
    if args.width * args.height >= 3840 * 2160:
        print("NOTE: 4K capture is very heavy for real-time blur/segmentation. Expect low FPS; "
              "use --fps 15, --no-blur, or a smaller --out-width/--out-height if it stutters.")

    out_w = args.out_width or args.width
    out_h = args.out_height or args.height
    blur = args.blur_strength | 1          # force odd
    edge = args.edge_blur | 1              # force odd

    for path in ([args.seg_model] if not args.no_blur else []) + \
                ([args.face_model] if args.auto_frame else []):
        if not os.path.exists(path):
            print(f"ERROR: model file not found: {path}")
            sys.exit(1)

    # --- Build Tasks API segmenter (confidence masks) ---
    segmenter = None
    if not args.no_blur:
        seg_opts = vision.ImageSegmenterOptions(
            base_options=mp_python.BaseOptions(model_asset_path=args.seg_model),
            running_mode=vision.RunningMode.IMAGE,
            output_confidence_masks=True,
            output_category_mask=False,
        )
        segmenter = vision.ImageSegmenter.create_from_options(seg_opts)

    # --- Build Tasks API face detector ---
    detector = None
    smooth = None
    if args.auto_frame:
        det_opts = vision.FaceDetectorOptions(
            base_options=mp_python.BaseOptions(model_asset_path=args.face_model),
            running_mode=vision.RunningMode.IMAGE,
            min_detection_confidence=args.face_confidence,
        )
        detector = vision.FaceDetector.create_from_options(det_opts)
        smooth = SmoothPosition(args.smoothing)

    cap, aw, ah, afps = open_capture(args, device_path)
    if cap is None:
        print(f"ERROR: cannot open camera {args.input}")
        sys.exit(1)
    if (aw, ah) != (args.width, args.height):
        print(f"WARNING: requested {args.width}x{args.height} but got {aw}x{ah} "
              f"(driver/backend may have clamped it).")
    print(f"Input {aw}x{ah}@{afps} | Output {out_w}x{out_h} -> {args.output}")
    print(f"Blur={'off' if args.no_blur else blur} | AutoFrame={'on' if args.auto_frame else 'off'}")
    print("Ctrl+C to stop.\n")

    running = True
    def stop(*_):
        nonlocal running
        running = False
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    with pyvirtualcam.Camera(width=out_w, height=out_h, fps=afps,
                             device=args.output,
                             fmt=pyvirtualcam.PixelFormat.BGR) as vcam:
        print(f"Virtual camera active: {vcam.device}\n")
        n = 0
        fail = 0
        t0 = time.time()
        while running:
            ok, frame = cap.read()
            if not ok:
                fail += 1
                if fail > 30:
                    print("ERROR: no frames from camera. Check --backend/--fourcc/resolution.")
                    if isinstance(cap, FFmpegCapture):
                        err = cap.stderr_text()
                        if err:
                            print("ffmpeg said:\n" + err)
                    break
                continue
            fail = 0
            frame = normalize_bgr(frame, aw, ah)
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

            # STEP 1: background blur
            if segmenter is not None:
                res = segmenter.segment(mp_img)
                fg = res.confidence_masks[0].numpy_view()   # float32 HxW, person prob
                if args.invert_mask:
                    fg = 1.0 - fg
                mask = (fg > args.threshold).astype(np.float32)
                mask = cv2.GaussianBlur(mask, (edge, edge), 0)
                mask3 = np.dstack([mask] * 3)
                bg = cv2.GaussianBlur(frame, (blur, blur), 0)
                out = (frame * mask3 + bg * (1.0 - mask3)).astype(np.uint8)
            else:
                out = frame

            # STEP 2: auto-frame
            if detector is not None:
                fres = detector.detect(mp_img)
                if fres.detections:
                    bb = fres.detections[0].bounding_box
                    fcx = bb.origin_x + bb.width // 2
                    fcy = bb.origin_y + bb.height // 2
                    out = auto_frame_crop(out, fcx, fcy, args.zoom, out_w, out_h, smooth)
                else:
                    lcx, lcy = smooth.get()
                    if lcx is None:
                        lcx, lcy = aw // 2, ah // 2
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
                print(f"[{n}] {100/dt:.1f} fps")
                t0 = time.time()

    cap.release()
    if args.preview:
        cv2.destroyAllWindows()
    if segmenter:
        segmenter.close()
    if detector:
        detector.close()
    print("\nStopped.")


if __name__ == "__main__":
    main()
```

---

## Fixing `Killed` (process terminated by the OS)

`Killed` = the process received **SIGKILL (signal 9)**. On Linux this is almost always the **OOM (out-of-memory) killer**, occasionally a corrupt model file.

### Step 1 — Diagnose

```bash
# Was it the OOM killer? (look for 'Out of memory' / 'oom-kill' / 'Killed process')
sudo dmesg -T | grep -iE 'oom|killed process|out of memory' | tail

# How much RAM/swap is available?
free -h

# Verify model files are real (not tiny HTML error pages from a failed wget)
ls -lh selfie_segmenter.tflite blaze_face_short_range.tflite
#   selfie_segmenter.tflite       ~1.2 MB
#   blaze_face_short_range.tflite ~230 KB
file selfie_segmenter.tflite      # must NOT say 'HTML document'
```

If `dmesg` shows an OOM line -> it's memory. If the `.tflite` files are a few KB or `file` says HTML -> re-download them (section 3).

### Step 2 — Reduce memory use

```bash
# Lower capture resolution (biggest single win)
python blur_cam.py --width 640 --height 480 --auto-frame

# Cap the ML thread count so TFLite/XNNPACK doesn't spike RAM & CPU
export OMP_NUM_THREADS=2
export MEDIAPIPE_DISABLE_GPU=1     # force CPU, avoid GL buffer allocations
python blur_cam.py --width 640 --height 480

# Blur is the heaviest stage — run auto-frame only to test
python blur_cam.py --auto-frame --no-blur
```

### Step 3 — Add swap if you have low RAM (< 8 GB)

A quick temporary 4 GB swap file:

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
free -h                     # confirm swap is now listed
# To make permanent, add to /etc/fstab:
echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
```

### Step 4 — Re-download models if corrupt

```bash
rm -f selfie_segmenter.tflite blaze_face_short_range.tflite
wget -O selfie_segmenter.tflite \
  https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite
wget -O blaze_face_short_range.tflite \
  https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite
```

> Tip: close memory-hungry apps (browsers especially) while testing. Once it runs at 640x480, step resolution back up (960x540, then 1280x720) to find your machine's ceiling.
> 

---

## Fixing `not enough bandwidth for new device state` (USB error)

This kernel/USB error means the webcam requested a video stream whose bandwidth **exceeds what the USB controller can allocate**. It is the #1 issue with 4K cams like the Logitech Brio, because uncompressed video is huge:

| Format @ 1280x720 @ 30fps | Approx. bandwidth |
| --- | --- |
| Uncompressed (YUY2) | ~660 Mbps |
| **MJPG (compressed)** | **~60-80 Mbps** |

### Fix 1 — Force MJPG in the script (already applied above)

```python
# Must be set BEFORE width/height:
cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
```

Verify the camera actually supports MJPG at your resolution:

```bash
v4l2-ctl -d /dev/video0 --list-formats-ext
# Look for a 'MJPG' / 'Motion-JPEG' block with your resolution + framerate
```

### Fix 2 — Check the USB connection speed

The Brio needs a **USB 3.0** link (5 Gbps). If it negotiated USB 2.0 (480 Mbps) you'll starve for bandwidth:

```bash
lsusb -t
# Find the Brio. It should show 5000M (USB 3.0).
# If it shows 480M -> it's on a USB 2.0 link.
```

- Plug **directly** into a **blue USB 3.0 / USB-C** port on the machine — **not** a hub, keyboard passthrough, or front-panel splitter.
- Try a different port; front-panel ports often share one controller.
- Use the cable that came with the Brio (some cheap cables are USB 2.0 only).

### Fix 3 — Lower resolution / FPS to fit the available bandwidth

```bash
python blur_cam.py --width 640 --height 480 --fps 30
# or drop framerate
python blur_cam.py --width 1280 --height 720 --fps 24
```

### Signature: only 720p works, everything higher is green/distorted/zoomed

If **720p looks fine but every higher resolution is corrupt**, the camera is almost certainly
on a **USB 2.0 link (480 Mbps)** — uncompressed NV12 only fits at 720p. NV12 @ 30fps needs:

| Resolution | Bandwidth | Fits USB 2.0? |
| --- | --- | --- |
| 1280x720 | ~332 Mbps | ✅ yes |
| 1920x1080 | ~746 Mbps | ❌ no |
| 2560x1440 | ~1.3 Gbps | ❌ no |
| 3840x2160 | ~3 Gbps | ❌ no (USB 3.0 only) |

Confirm and fix:

```bash
lsusb -t                       # Opal shows 480M (USB 2.0 = problem) vs 5000M (USB 3.0)
sudo dmesg -T | grep -iE 'bandwidth|no space' | tail
```

- Plug **directly** into a blue USB 3.0 / USB-C port with a USB 3.0 cable (no hub/splitter),
then 1080p/1440p/4K have the bandwidth they need.
- **Stuck on USB 2.0?** Trade FPS for resolution — 1080p fits at ~15fps:
```bash
python blur_cam.py -i 4 --fourcc auto --width 1920 --height 1080 --fps 15 --auto-frame
```
1440p/4K won't fit USB 2.0 at any usable framerate.

### Fix 4 — Remove other devices sharing the bus

Other cameras, capture cards, external drives, or audio interfaces on the **same USB controller** compete for bandwidth. Unplug them or move the Brio to a different physical controller. `lsusb -t` shows which devices share a bus.

### Quick test outside Python

Confirm the camera streams at all with MJPG (rules out the script):

```bash
# ffplay from ffmpeg package
ffplay -f v4l2 -input_format mjpeg -video_size 1280x720 /dev/video0
```

If this works but the script still errors, the FOURCC line isn't taking effect — make sure it's set before width/height.

---

---

## Opal C1 keeps disconnecting / OBS shows no video

If the camera **disconnects and reconnects**, or apps like **OBS can't see any video**, the
Opal C1's firmware has **reset** — usually triggered by repeatedly requesting a resolution it
can't cleanly deliver over Linux UVC (1080p/1440p/4K). This is a **camera/driver-level** issue,
not the blur script.

### Recover the camera to a working state

```bash
# 1. Stop everything using the camera (blur script, OBS, browsers, Zoom, ffplay)
fuser -v /dev/video*                 # see who holds it
# if something is stuck:  sudo fuser -k /dev/video4

# 2. Check the kernel log for reset/error messages
sudo dmesg -T | tail -30             # look for 'reset', 'disconnect', 'usb', 'uvcvideo'

# 3. Reload the UVC driver (after closing all camera apps)
sudo modprobe -r uvcvideo && sudo modprobe uvcvideo

# 4. If still bad: physically unplug the Opal, wait ~10s, replug into a USB 3.0/USB-C port
#    (directly, no hub). Reboot as a last resort.
```

### Verify it works again at the known-good mode (720p)

```bash
ffplay -f v4l2 -input_format nv12 -video_size 1280x720 -framerate 30 /dev/video4
```

### The Linux reality for the Opal C1

On Linux the Opal C1 reliably streams **only 720p (NV12)**; 1080p/1440p/4K tend to distort or
reset the device because its high-res pipeline depends on Opal's own macOS/Windows app. For a
stable Linux setup, run the blur tool at 720p:

```bash
python blur_cam.py -i 4 --fourcc auto --width 1280 --height 720 --fps 30 --auto-frame
```

If you need higher resolution on Linux, a **native MJPG/H.264 webcam** (e.g. Logitech Brio,
which does MJPG at 1080p+) will behave far better than the Opal C1.

---

## Opal C1 — every option that works (720p on Linux)

On Linux the Opal C1 is stable **only at 1280x720 / NV12**. Within that mode, all of the
script's blur and auto-framing options work normally. Use `-i 4` (adjust to your capture node).

### Recommended commands

```bash
# Auto-detect the Opal's node (no -i needed) + blur + auto-frame — best for a fixed setup
python blur_cam.py --auto-detect --fourcc auto --width 1280 --height 720 --fps 30 --auto-frame

# Blur + auto-frame with an explicit node
python blur_cam.py -i 4 --fourcc auto --width 1280 --height 720 --fps 30 --auto-frame

# Blur only (no crop, full 720p field of view)
python blur_cam.py -i 4 --fourcc auto --width 1280 --height 720 --fps 30

# Auto-frame only, no blur (lightest / highest FPS)
python blur_cam.py -i 4 --fourcc auto --width 1280 --height 720 --no-blur --auto-frame

# Stronger bokeh + wider auto-frame + local preview
python blur_cam.py -i 4 --fourcc auto --width 1280 --height 720 --blur-strength 35 --zoom 0.9 --preview

# If the person gets blurred instead of the background
python blur_cam.py -i 4 --fourcc auto --width 1280 --height 720 --invert-mask
```

### Flags that are SAFE with the Opal C1

| Flag | Notes |
| --- | --- |
| `--auto-detect` (`--camera-name opal`) | Finds the Opal's capture node automatically — best for the systemd service |
| `-i/--input 4` | The Opal's capture node (verify with `--list-formats` / udev) |
| `--fourcc auto` or `--fourcc NV12` | NV12 is the only format the Opal exposes on Linux |
| `--width 1280 --height 720` | The only reliably-working resolution |
| `--fps 30` | Works at 720p |
| `--backend ffmpeg` (default) | Clean frames; `--backend opencv` also works at 720p |
| `--auto-frame`, `--zoom`, `--smoothing`, `--face-confidence` | Face-tracking crop |
| `--blur-strength`, `--edge-blur`, `--threshold`, `--invert-mask` | Background blur controls |
| `--no-blur` | Disable blur (auto-frame only) |
| `--out-width`, `--out-height` | Downscale the output (e.g. 960x540) — fine |
| `--preview` | Local preview window |
| `--list-formats` | Inspect the camera's formats |

### Flags/values to AVOID with the Opal C1

| Avoid | Why |
| --- | --- |
| `--max-res` | Selects 3840x2160 -> distorts / **resets the camera** |
| `--width/--height` above 1280x720 | 1080p/1440p/4K distort or disconnect the device |
| Upscaling output beyond 720p | No quality gain (source is capped at 720p) |

---

## Using an Opal C1 (and other non-MJPG cameras)

Different webcams expose different pixel formats over UVC on Linux. The **Opal C1** does **not** offer MJPG at all — depending on firmware/kernel it exposes **NV12** (often up to 4K: `1280x720, 1920x1080, 2560x1440, 3840x2160`) or YUYV. Forcing MJPG on it fails with:

```
cannot find proper format for codec mjpeg
```

### Step 1 — See what your camera actually supports

```bash
python blur_cam.py --list-formats -i 4     # use the Opal's capture node index
# Example (Opal C1):
#   Supported formats for /dev/video4:
#     NV12: 1280x720, 1920x1080, 2560x1440, 3840x2160
```

### Step 2 — Let the script pick a supported format automatically

The script auto-falls back to a format the camera supports, so you don't have to hard-code it. Two easy options:

```bash
# AUTO: pick the camera's best-supported format, and grab its MAX resolution
python blur_cam.py -i 4 --fourcc auto --max-res --auto-frame

# Or name the format explicitly (from --list-formats) + max resolution
python blur_cam.py -i 4 --fourcc NV12 --max-res --auto-frame
```

- If you pass the default `--fourcc MJPG` but the camera lacks MJPG, the script prints a
warning and **automatically switches** to a supported format (e.g. NV12) instead of
silently dropping to a low default resolution.
- `--max-res` enumerates the supported sizes for the chosen format and picks the largest by
pixel area. For the Opal C1 that is typically **3840x2160 (NV12)**.

### Step 3 — Mind the performance & bandwidth at 4K

4K is **very** demanding for real-time segmentation + blur and for the USB bus:

- Expect low FPS at 3840x2160 with blur on. The script prints a NOTE when you select 4K.
- Keep the heavy ML output but lighten the pipeline by downscaling the **output**:
```bash
# Capture at 4K, output a lighter 1080p (still uses the full-res sensor feed)
python blur_cam.py -i 4 --fourcc NV12 --max-res --auto-frame --out-width 1920 --out-height 1080
```
- If you hit `not enough bandwidth for new device state`, lower FPS (`--fps 15`) or step down
a resolution, and plug the camera **directly** into a USB 3.0 / USB-C port (see the USB
bandwidth section above).
- If a resolution won't apply, the script warns `requested WxH but camera delivered ...` so
you can see the driver clamped it.

> If `--list-formats` prints nothing, install `v4l-utils` (`sudo pacman -S v4l-utils`) — the
> auto-detection and `--max-res` features rely on `v4l2-ctl`.
> 

> **Colors greenish or image mis-scaled/zoomed?** That's the raw-YUV pitfall: the script no longer forces the FOURCC for NV12/YUYV (only for MJPG) and calls `cv2.CAP_PROP_CONVERT_RGB` plus a `normalize_bgr()` safety net, so grab the latest `blur_cam.py`. If it still looks too tight, that's the `--auto-frame` crop — raise `--zoom` (e.g. `--zoom 0.9`) or run without `--auto-frame`.
> 

> **Still green/distorted only at higher resolutions on a USB 3.0 link?** OpenCV's V4L2 path mishandles NV12 stride above 720p. Use the default `--backend ffmpeg`, which captures via an `ffmpeg` subprocess and delivers clean BGR frames at any resolution (`sudo pacman -S ffmpeg`).
> 

---

## 5. Usage

```bash
cd ~/webcam-blur && source .venv/bin/activate

# Blur only
python blur_cam.py

# Blur + auto-frame
python blur_cam.py --auto-frame

# Tighter framing + smoother panning + preview
python blur_cam.py --auto-frame --zoom 0.6 --smoothing 0.05 --preview

# Auto-frame only (no blur, fastest)
python blur_cam.py --auto-frame --no-blur

# 1080p capture -> 720p auto-framed output
python blur_cam.py -W 1920 -H 1080 --auto-frame --out-width 1280 --out-height 720 --zoom 0.6

# If the PERSON gets blurred instead of the background, flip the mask:
python blur_cam.py --invert-mask
```

Then in Zoom/Meet/Teams pick **"Virtual_Blur_Cam"** as the camera.

---

## 6. CLI Reference

| Flag | Short | Default | Description |
| --- | --- | --- | --- |
| `--input` | `-i` | `0` | Camera index |
| `--output` | `-o` | `/dev/video10` | Virtual cam device |
| `--width`/`--height` | `-W`/`-H` | `1280`/`720` | Capture resolution |
| `--fps` | `-f` | `30` | Target FPS |
| `--fourcc` |  | `MJPG` | Capture format: `MJPG` (Brio), `YUYV`/`NV12` (Opal C1), `AUTO`, or `NONE`. Auto-falls back if unsupported. |
| `--max-res` |  | off | Auto-detect & use the camera's max resolution for `--fourcc` (needs v4l-utils) |
| `--list-formats` |  | off | Print the camera's supported formats + resolutions, then exit |
| `--backend` |  | `ffmpeg` | Capture backend: `ffmpeg` (robust NV12/YUYV at all res) or `opencv` |
| `--auto-detect` |  | off | Auto-find the camera's capture node by name (overrides `--input`) |
| `--camera-name` |  | `opal` | Model substring to match when `--auto-detect` is set |
| `--seg-model` |  | `selfie_segmenter.tflite` | Segmenter model path |
| `--face-model` |  | `blaze_face_short_range.tflite` | Face model path |
| `--blur-strength` | `-b` | `21` | Blur kernel (auto-forced odd) |
| `--edge-blur` | `-e` | `7` | Edge feather (auto-forced odd) |
| `--threshold` | `-t` | `0.6` | Foreground cutoff 0-1 |
| `--invert-mask` |  | off | Flip if person/bg swapped |
| `--no-blur` |  | off | Disable blur |
| `--auto-frame` | `-a` | off | Enable face-tracking crop |
| `--out-width`/`--out-height` |  | = capture | Output resolution |
| `--zoom` | `-z` | `0.75` | Crop zoom (lower=tighter) |
| `--smoothing` | `-s` | `0.08` | Pan smoothing (lower=smoother) |
| `--face-confidence` |  | `0.7` | Min face confidence |
| `--preview` | `-p` | off | Local preview window |

---

## 7. Run as a systemd service (auto-start + auto-detect)

Run the blur cam automatically in the background as a **user service**. With `--auto-detect`
it finds the Opal C1's capture node on every start, so it keeps working even if the
`/dev/videoN` number changes after a reboot or replug.

**One-time prerequisites:**

```bash
sudo usermod -aG video "$USER"          # camera access (log out/in afterwards)
v4l2-ctl --list-devices | grep -i virtual   # confirm v4l2loopback loads at boot (section 1)
```

Create `~/.config/systemd/user/webcam-blur.service`:

```ini
[Unit]
Description=Webcam Background Blur + Auto-Frame (Opal C1, 720p)
After=graphical-session.target

[Service]
Type=simple
WorkingDirectory=%h/webcam-blur
# Wait for the v4l2loopback virtual camera to appear before starting
ExecStartPre=/bin/sh -c 'until [ -e /dev/video10 ]; do sleep 1; done'
ExecStart=%h/webcam-blur/.venv/bin/python %h/webcam-blur/blur_cam.py \
  --auto-detect --camera-name opal \
  --fourcc auto --width 1280 --height 720 --fps 30 --auto-frame
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

Enable, start, and inspect it:

```bash
mkdir -p ~/.config/systemd/user
# (save the unit file above, then:)
systemctl --user daemon-reload
systemctl --user enable --now webcam-blur.service

systemctl --user status webcam-blur.service
journalctl --user -u webcam-blur.service -f

# keep it running even when you're not logged in (headless):
loginctl enable-linger "$USER"
```

Manage it:

```bash
systemctl --user restart webcam-blur.service
systemctl --user stop webcam-blur.service
systemctl --user disable --now webcam-blur.service
```

> **System-wide alternative:** to run it as a root/system service, place the unit at
> `/etc/systemd/system/webcam-blur.service`, add `User=YOUR_USERNAME`, set
> `After=multi-user.target`, replace every `%h` with the absolute home path, and manage it with
> `sudo systemctl ...` (no `--user`). The **user service above is recommended** on a laptop —
> it inherits your `video`-group access and needs no root.
> 

## 8. Troubleshooting

| Issue | Fix |
| --- | --- |
| `module 'mediapipe' has no attribute 'solutions'` | You're using the old API. Use this Tasks-API script + Python 3.12. |
| `pip install mediapipe` fails / no matching distribution | You're on Python 3.13. Create venv with `python3.12`. |
| `model file not found` | Run the `wget` commands in section 3 (must be in the working dir). |
| Person is blurred, background sharp | Add `--invert-mask`. |
| `/dev/video10` missing | `sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="Virtual_Blur_Cam" exclusive_caps=1` |
| Black camera in Zoom/Meet | Ensure `exclusive_caps=1` when loading v4l2loopback. |
| Low FPS | Reduce resolution, raise `--threshold`, or `--no-blur`. |
| Jittery auto-frame | Lower `--smoothing` (e.g. 0.03-0.05). |
| Face not detected | Lower `--face-confidence` (e.g. 0.5) / improve lighting. |
| Permission denied `/dev/video*` | `sudo usermod -aG video $USER` then re-login. |
| Preview window won't open | Install `opencv-python` (not `-headless`). |
| `Killed` (SIGKILL) | OOM killer — see the "Fixing `Killed`" section: lower resolution, cap threads, add swap. |
| `cannot find proper format for codec mjpeg` | Camera has no MJPG (e.g. Opal C1). Use `--fourcc YUYV` (or `NONE`). See the Opal C1 section. |
| Greenish / distorted colors (NV12/YUYV cams) | Don't force the FOURCC on uncompressed cams — update to the latest script (only MJPG is forced; `CAP_PROP_CONVERT_RGB` + `normalize_bgr` handle the rest). |
| Image looks overly "zoomed in" | Two causes: (a) raw-YUV mis-scaling — fixed by the color fix above; (b) `--auto-frame` crop — raise `--zoom` (e.g. `0.9`) or drop `--auto-frame`. |
| Only 720p is clean; higher res green/corrupt | USB 2.0 bandwidth ceiling — NV12 only fits at 720p on USB 2.0. Use a USB 3.0 port/cable, or `--fps 15` at 1080p. See the USB bandwidth section. |
| Green/distorted at higher res **even on USB 3.0** | OpenCV mishandles NV12 stride. Use the default `--backend ffmpeg` (needs `ffmpeg` installed). |
| Opal C1 disconnects/resets, OBS shows nothing | Camera firmware reset from an unsupported high-res mode. Recover (reload `uvcvideo`, replug) and stay at **720p** on Linux. See "Opal C1 keeps disconnecting". |

---

## 9. Dependency Summary

**pacman:** `v4l-utils linux-headers base-devel git ffmpeg`
**AUR:** `python312` (or pyenv/uv for a 3.12 interpreter), `v4l2loopback-dkms`
**pip (in a Python 3.12 venv):** `mediapipe opencv-python-headless numpy pyvirtualcam`
**Model files:** `selfie_segmenter.tflite`, `blaze_face_short_range.tflite`
**Kernel module:** `v4l2loopback`

---

## Notes on the API change

- **Legacy** `mp.solutions.selfie_segmentation` / `mp.solutions.face_detection` are deprecated and absent in newer MediaPipe.
- **Current** approach = **Tasks API**: `mediapipe.tasks.python.vision.ImageSegmenter` and `FaceDetector`, which load explicit `.tflite` models.
- Tasks API face detection returns bounding boxes in **pixel** coordinates (no manual scaling needed).

---

*Provided as-is under MIT license. MediaPipe is Apache 2.0.*
