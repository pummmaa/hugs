---
title: "logitech-brio-cross-platform-blur-auto-frame"
date: 2026-08-16T00:17:33Z
lastmod: 2026-08-16T00:17:33Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Webcam Background Blur + Auto-Framing — Cross-Platform (Windows / Linux / macOS)

> One Python script (`blur_cam.py`) that adds real-time background blur (bokeh) and auto-framing to the **Logitech Brio**, on **Windows, Linux, and macOS**. Uses MediaPipe (Tasks API) for segmentation/face-tracking and outputs a **virtual camera** usable in Zoom, Teams, Meet, etc.
> 

> **Why the Brio:** it's a standard **UVC / MJPG** webcam, so it behaves consistently across all three OSes — no vendor driver app required (unlike the Opal C1). The script auto-detects it by name (`--camera-name brio`).
> 

---

## 1. Install per platform

### Common: Python 3.11/3.12 + Python packages

MediaPipe supports Python 3.9–3.12 (not 3.13). Create a venv and install:

```bash
python -m venv .venv
# Linux/macOS:
source .venv/bin/activate
# Windows (PowerShell):
#   .venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install mediapipe opencv-python numpy pyvirtualcam
```

### Linux (Arch example)

```bash
sudo pacman -S v4l-utils linux-headers base-devel git ffmpeg
# virtual camera kernel module:
yay -S v4l2loopback-dkms
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="Virtual_Blur_Cam" exclusive_caps=1
```

(Debian/Ubuntu: `sudo apt install v4l-utils v4l2loopback-dkms ffmpeg`.)

### macOS (Apple Silicon or Intel)

```bash
brew install python@3.12 ffmpeg
brew install --cask obs        # provides the OBS Virtual Camera
```

Launch **OBS once → Start Virtual Camera → Stop → quit OBS** (registers the system extension;
approve it in System Settings → Privacy & Security). Grant **Camera** permission to your terminal.

### Windows

1. Install **Python 3.12** (python.org) and **ffmpeg** (e.g. `winget install Gyan.FFmpeg`; ensure `ffmpeg` is on PATH).
2. Install **OBS Studio** (`winget install OBSProject.OBSStudio`). Launch OBS once → **Start Virtual Camera** → **Stop** → quit. This installs the "OBS Virtual Camera" that `pyvirtualcam` targets.

---

## 2. Virtual camera per platform (what pyvirtualcam uses)

| OS | Virtual camera backend | One-time setup |
| --- | --- | --- |
| Linux | `v4l2loopback` | `modprobe` (see above); persist via `/etc/modules-load.d` |
| macOS | OBS Virtual Camera | install OBS, register once |
| Windows | OBS Virtual Camera | install OBS, register once |

The script calls `pyvirtualcam.Camera(...)`, which automatically targets the right one for the OS.

---

## 3. Download the MediaPipe models

```bash
# Linux/macOS
curl -L -o selfie_segmenter.tflite https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite
curl -L -o blaze_face_short_range.tflite https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite
```

On Windows PowerShell use `curl.exe -L -o ...` (or `Invoke-WebRequest`), keeping the two files in the same folder as `blur_cam.py`.

---

## 4. The script — `blur_cam.py`

```python
#!/usr/bin/env python3
"""
Cross-platform real-time background blur (bokeh) + auto-framing virtual camera.
Targets the Logitech Brio, works on Windows, Linux, and macOS.

Capture:  OpenCV (default) or ffmpeg, with the right backend per OS
          (V4L2 / AVFoundation / DirectShow).
Output:   virtual camera via pyvirtualcam
          (v4l2loopback on Linux, OBS Virtual Camera on macOS/Windows).
ML:       MediaPipe Tasks API (ImageSegmenter + FaceDetector).

Requires Python 3.11/3.12 and model files in the working dir:
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
import glob
import subprocess

IS_WIN = sys.platform.startswith("win")
IS_MAC = sys.platform == "darwin"
IS_LINUX = sys.platform.startswith("linux")


def parse_args():
    p = argparse.ArgumentParser(description="Webcam Blur + Auto-Frame (Windows/Linux/macOS, Logitech Brio)")
    # Device
    p.add_argument("--input", "-i", type=int, default=0, help="Camera index (default 0)")
    p.add_argument("--auto-detect", action="store_true", help="Find the camera by name (overrides --input)")
    p.add_argument("--camera-name", type=str, default="brio", help="Model substring to match (default: brio)")
    p.add_argument("--device-name", type=str, default=None,
                   help="Exact device name for the ffmpeg backend on Windows (DirectShow). "
                        "Auto-filled by --auto-detect.")
    p.add_argument("--list-devices", action="store_true", help="List cameras for this OS, then exit")
    p.add_argument("--width", "-W", type=int, default=1280, help="Capture width")
    p.add_argument("--height", "-H", type=int, default=720, help="Capture height")
    p.add_argument("--fps", "-f", type=int, default=30, help="Target FPS")
    p.add_argument("--res", choices=["720p", "1080p", "1440p", "4k"], default=None,
                   help="Resolution preset (overrides --width/--height). Brio 4K supports all four.")
    p.add_argument("--backend", type=str, default="opencv", choices=["opencv", "ffmpeg"],
                   help="Capture backend (default opencv; ffmpeg is a robust fallback)")
    p.add_argument("--mjpg", action="store_true", default=True,
                   help="Request MJPG from the camera (Brio supports it; saves USB bandwidth)")
    # Blur
    p.add_argument("--blur-strength", "-b", type=int, default=21, help="Blur kernel (odd)")
    p.add_argument("--edge-blur", "-e", type=int, default=7, help="Edge feather kernel (odd)")
    p.add_argument("--threshold", "-t", type=float, default=0.6, help="Foreground threshold 0-1")
    p.add_argument("--proc-width", type=int, default=640, help="Segment at this width for speed (0=full)")
    p.add_argument("--invert-mask", action="store_true", help="Flip mask if person/bg swapped")
    p.add_argument("--no-blur", action="store_true", help="Disable blur (auto-frame only)")
    # Auto-frame
    p.add_argument("--auto-frame", action="store_true", help="Face-tracking crop")
    p.add_argument("--out-width", type=int, default=None, help="Output width after framing")
    p.add_argument("--out-height", type=int, default=None, help="Output height after framing")
    p.add_argument("--zoom", "-z", type=float, default=0.75, help="Crop zoom (lower=tighter)")
    p.add_argument("--smoothing", "-s", type=float, default=0.08, help="Pan smoothing (lower=smoother)")
    p.add_argument("--face-confidence", type=float, default=0.7, help="Min face confidence")
    # Misc
    p.add_argument("--preview", "-p", action="store_true", help="Local preview window")
    return p.parse_args()


# ---------------- Cross-platform camera discovery ----------------

def _run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True)
    except Exception:
        return None


def list_cameras():
    """Return a list of (id, name) for this OS. id is an int index (opencv) or,
    on Windows, the DirectShow device name is also carried in `name`."""
    cams = []
    if IS_LINUX:
        for node in sorted(glob.glob("/dev/video*"), key=lambda p: int(re.sub(r"\D", "", p) or "-1")):
            r = _run(["udevadm", "info", "-q", "property", "--name", node])
            props = {}
            if r and r.returncode == 0:
                for line in r.stdout.splitlines():
                    if "=" in line:
                        k, v = line.split("=", 1); props[k] = v
            if ":capture:" in props.get("ID_V4L_CAPABILITIES", ""):
                name = props.get("ID_V4L_PRODUCT") or props.get("ID_MODEL", node)
                idx = int(re.search(r"(\d+)$", node).group(1))
                cams.append((idx, name))
    elif IS_MAC:
        r = _run(["ffmpeg", "-hide_banner", "-f", "avfoundation", "-list_devices", "true", "-i", ""])
        txt = r.stderr if r else ""
        in_video = False
        for line in txt.splitlines():
            if "AVFoundation video devices" in line: in_video = True; continue
            if "AVFoundation audio devices" in line: in_video = False; continue
            m = re.search(r"\[(\d+)\]\s+(.*)$", line)
            if in_video and m:
                cams.append((int(m.group(1)), m.group(2).strip()))
    elif IS_WIN:
        r = _run(["ffmpeg", "-hide_banner", "-f", "dshow", "-list_devices", "true", "-i", "dummy"])
        txt = r.stderr if r else ""
        idx = 0
        for line in txt.splitlines():
            if "(audio)" in line: continue
            m = re.search(r'"([^"]+)"', line)
            if m and "(video)" in line:
                cams.append((idx, m.group(1))); idx += 1
    return cams


def detect_camera(name_substr):
    """Return (index, name) of the first camera whose name matches, else (None, None)."""
    want = name_substr.lower()
    for idx, name in list_cameras():
        if want in (name or "").lower():
            return idx, name
    return None, None


# ---------------- ffmpeg capture backend (per-OS input) ----------------

class FFmpegCapture:
    def __init__(self, args, name=None):
        self.width, self.height, self.fps = args.width, args.height, args.fps
        self._nbytes = args.width * args.height * 3
        wh = f"{args.width}x{args.height}"
        cmd = ["ffmpeg", "-loglevel", "error"]
        if IS_LINUX:
            cmd += ["-f", "v4l2", "-input_format", "mjpeg", "-video_size", wh,
                    "-framerate", str(args.fps), "-i", f"/dev/video{args.input}"]
        elif IS_MAC:
            cmd += ["-f", "avfoundation", "-framerate", str(args.fps),
                    "-video_size", wh, "-i", f"{args.input}:none"]
        elif IS_WIN:
            dev = args.device_name or name
            if not dev:
                raise RuntimeError("Windows ffmpeg backend needs --device-name or --auto-detect")
            cmd += ["-f", "dshow", "-vcodec", "mjpeg", "-video_size", wh,
                    "-framerate", str(args.fps), "-i", f"video={dev}"]
        cmd += ["-pix_fmt", "bgr24", "-f", "rawvideo", "-"]
        self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def _read_exact(self, n):
        chunks, got = [], 0
        while got < n:
            c = self.proc.stdout.read(n - got)
            if not c: return None
            chunks.append(c); got += len(c)
        return b"".join(chunks)

    def read(self):
        buf = self._read_exact(self._nbytes)
        if buf is None: return False, None
        return True, np.frombuffer(buf, np.uint8).reshape(self.height, self.width, 3)

    def stderr_text(self):
        try: return self.proc.stderr.read().decode(errors="ignore")
        except Exception: return ""

    def release(self):
        try: self.proc.terminate(); self.proc.wait(timeout=2)
        except Exception:
            try: self.proc.kill()
            except Exception: pass


def _cv_backend():
    if IS_LINUX: return cv2.CAP_V4L2
    if IS_MAC: return cv2.CAP_AVFOUNDATION
    if IS_WIN: return cv2.CAP_DSHOW
    return cv2.CAP_ANY


def open_capture(args, name=None):
    """Return (cap, w, h, fps) or (None, 0, 0, 0)."""
    if args.backend == "ffmpeg":
        cap = FFmpegCapture(args, name)
        return cap, cap.width, cap.height, cap.fps
    cap = cv2.VideoCapture(args.input, _cv_backend())
    if args.mjpg:
        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
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


# ---------------- Processing helpers ----------------

def fast_blur(frame, strength):
    """Fast bokeh: downscale -> small blur -> upscale (cheaper than full-res GaussianBlur)."""
    h, w = frame.shape[:2]
    ds = 4
    small = cv2.resize(frame, (max(1, w // ds), max(1, h // ds)), interpolation=cv2.INTER_LINEAR)
    k = max(3, (strength // ds) | 1)
    small = cv2.GaussianBlur(small, (k, k), 0)
    return cv2.resize(small, (w, h), interpolation=cv2.INTER_LINEAR)


class SmoothPosition:
    def __init__(self, smoothing=0.08):
        self.smoothing = smoothing; self.cx = None; self.cy = None
    def update(self, cx, cy):
        if self.cx is None: self.cx, self.cy = cx, cy
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
    crop_h = int(h * zoom); crop_w = int(crop_h * aspect)
    if crop_w > w: crop_w = w; crop_h = int(crop_w / aspect)
    x1 = max(0, min(scx - crop_w // 2, w - crop_w))
    y1 = max(0, min(scy - crop_h // 2, h - crop_h))
    return cv2.resize(frame[y1:y1+crop_h, x1:x1+crop_w], (out_w, out_h), interpolation=cv2.INTER_LINEAR)


def main():
    args = parse_args()
    _RES = {"720p": (1280, 720), "1080p": (1920, 1080), "1440p": (2560, 1440), "4k": (3840, 2160)}
    if args.res:
        args.width, args.height = _RES[args.res]

    if args.list_devices:
        cams = list_cameras()
        if not cams:
            print("No cameras found (need ffmpeg on macOS/Windows, v4l-utils on Linux).")
        else:
            print(f"Cameras ({sys.platform}):")
            for idx, name in cams:
                print(f"  [{idx}] {name}")
        sys.exit(0)

    if args.auto_detect:
        idx, name = detect_camera(args.camera_name)
        if idx is not None:
            args.input = idx
            if IS_WIN and not args.device_name:
                args.device_name = name
            print(f"Auto-detected '{args.camera_name}' -> index {idx} ({name})")
        else:
            print(f"WARNING: no '{args.camera_name}' camera found; using --input {args.input}.")

    out_w = args.out_width or args.width
    out_h = args.out_height or args.height
    blur = args.blur_strength | 1
    edge = args.edge_blur | 1

    need = ([("selfie_segmenter.tflite")] if not args.no_blur else []) + \
           (["blaze_face_short_range.tflite"] if args.auto_frame else [])
    for path in need:
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

    cap, aw, ah, afps = open_capture(args, args.device_name)
    if cap is None:
        print(f"ERROR: cannot open camera index {args.input}"); sys.exit(1)
    if (aw, ah) != (args.width, args.height):
        print(f"NOTE: requested {args.width}x{args.height} but camera delivered {aw}x{ah} "
              f"(unsupported at this fps, or the driver clamped it).")
    print(f"[{sys.platform}] input {aw}x{ah}@{afps} idx {args.input} | output {out_w}x{out_h}")
    print(f"Blur={'off' if args.no_blur else blur} | AutoFrame={'on' if args.auto_frame else 'off'} | Ctrl+C to stop\n")

    running = True
    def stop(*_):
        nonlocal running; running = False
    signal.signal(signal.SIGINT, stop)
    try: signal.signal(signal.SIGTERM, stop)
    except Exception: pass

    with pyvirtualcam.Camera(width=out_w, height=out_h, fps=afps, fmt=pyvirtualcam.PixelFormat.BGR) as vcam:
        print(f"Virtual camera active: {vcam.device}\n")
        n = 0; fail = 0; t0 = time.time()
        while running:
            ok, frame = cap.read()
            if not ok:
                fail += 1
                if fail > 30:
                    print("ERROR: no frames. Check --list-devices / --backend / permissions.")
                    if isinstance(cap, FFmpegCapture):
                        e = cap.stderr_text()
                        if e: print("ffmpeg said:\n" + e)
                    break
                continue
            fail = 0
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            H, W = frame.shape[:2]

            if segmenter is not None:
                if args.proc_width and args.proc_width < W:
                    sw = args.proc_width; sh = max(1, int(H * sw / W))
                    seg_rgb = np.ascontiguousarray(cv2.resize(rgb, (sw, sh)))
                else:
                    seg_rgb = rgb
                fg = segmenter.segment(mp.Image(image_format=mp.ImageFormat.SRGB, data=seg_rgb)).confidence_masks[0].numpy_view()
                if args.invert_mask: fg = 1.0 - fg
                mask = (fg > args.threshold).astype(np.float32)
                if mask.shape[:2] != (H, W):
                    mask = cv2.resize(mask, (W, H), interpolation=cv2.INTER_LINEAR)
                mask = cv2.GaussianBlur(mask, (edge, edge), 0)
                mask3 = np.dstack([mask] * 3)
                out = (frame * mask3 + fast_blur(frame, blur) * (1.0 - mask3)).astype(np.uint8)
            else:
                out = frame

            if detector is not None:
                res = detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
                if res.detections:
                    bb = res.detections[0].bounding_box
                    out = auto_frame_crop(out, bb.origin_x + bb.width // 2, bb.origin_y + bb.height // 2,
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
                if cv2.waitKey(1) & 0xFF == ord('q'): break
            n += 1
            if n % 100 == 0:
                dt = time.time() - t0; print(f"[{n}] {100/dt:.1f} fps"); t0 = time.time()

    cap.release()
    if args.preview: cv2.destroyAllWindows()
    if segmenter: segmenter.close()
    if detector: detector.close()
    print("\nStopped.")


if __name__ == "__main__":
    main()
```

---

## 5. Usage (identical flags on every OS)

```bash
# See cameras + indices (per-OS enumeration)
python blur_cam.py --list-devices

# Auto-detect the Brio + blur + auto-frame (recommended)
python blur_cam.py --auto-detect --width 1280 --height 720 --fps 30 --auto-frame

# Explicit index instead of auto-detect
python blur_cam.py -i 1 --width 1920 --height 1080 --auto-frame

# Resolution presets (Brio 4K supports all four)
python blur_cam.py --auto-detect --res 720p  --fps 30 --auto-frame
python blur_cam.py --auto-detect --res 1080p --fps 30 --auto-frame
python blur_cam.py --auto-detect --res 1440p --fps 30 --auto-frame
python blur_cam.py --auto-detect --res 4k    --fps 30 --auto-frame   # heavy; consider --out-width 1920 --out-height 1080

# Blur only / auto-frame only
python blur_cam.py --auto-detect
python blur_cam.py --auto-detect --no-blur --auto-frame

# ffmpeg backend (robust fallback). On Windows it needs the device name:
python blur_cam.py --auto-detect --backend ffmpeg
python blur_cam.py --backend ffmpeg --device-name "Logitech BRIO"   # Windows, explicit
```

Then select the virtual camera in your app: **"Virtual_Blur_Cam"** (Linux) or **"OBS Virtual Camera"** (macOS/Windows).

### CLI reference

| Flag | Default | Description |
| --- | --- | --- |
| `--input`/`-i` | `0` | Camera index |
| `--auto-detect` | off | Find camera by `--camera-name` (default `brio`) |
| `--camera-name` | `brio` | Name substring to match |
| `--device-name` | — | Exact DirectShow name (Windows ffmpeg backend) |
| `--list-devices` | off | List cameras, then exit |
| `--width`/`--height` | `1280`/`720` | Capture resolution |
| `--fps`/`-f` | `30` | Target FPS |
| `--res` | — | Preset: `720p` / `1080p` / `1440p` / `4k` (overrides width/height) |
| `--backend` | `opencv` | `opencv` or `ffmpeg` |
| `--blur-strength`/`-b` | `21` | Bokeh strength (cheap via fast_blur) |
| `--edge-blur`/`-e` | `7` | Mask edge feather |
| `--threshold`/`-t` | `0.6` | Foreground cutoff |
| `--proc-width` | `640` | Segment at this width for speed |
| `--invert-mask` | off | Flip if person/bg swapped |
| `--no-blur` | off | Disable blur |
| `--auto-frame` | off | Face-tracking crop |
| `--out-width`/`--out-height` | = capture | Output size |
| `--zoom`/`-z` | `0.75` | Crop zoom (lower=tighter) |
| `--smoothing`/`-s` | `0.08` | Pan smoothing |
| `--preview`/`-p` | off | Local preview window |

---

## Resolutions — what the Brio 4K supports

This script does **not** hard-code a resolution — pass `--res` (or `--width/--height`) and it
requests that mode from the camera (over **MJPG**, so high resolutions fit on USB). The **Brio 4K**
(model V-U0040, USB `046d:085e`) exposes **720p, 1080p, 1440p, and 4K (3840x2160) at 30 fps**
(720p/1080p also at higher frame rates).

```bash
python blur_cam.py --auto-detect --res 720p    # 1280x720
python blur_cam.py --auto-detect --res 1080p   # 1920x1080
python blur_cam.py --auto-detect --res 1440p   # 2560x1440
python blur_cam.py --auto-detect --res 4k      # 3840x2160 (30fps)
```

**Notes & caveats:**

- If you request a mode the camera can't do at that fps, the script prints a `NOTE:` line showing
the resolution it actually got (the driver clamps it — it won't crash).
- **4K/1440p need USB 3.0** and are supported on the **Brio 4K family** (Brio 4K / 4K Pro / Stream,
MX Brio). The **Brio 500 / 100 / 300** are 1080p-max, so `--res 1440p/4k` will fall back there.
- **Real-time blur at 4K is CPU-heavy** — expect low FPS. Best practice: capture high but output
lighter, e.g. `--res 4k --out-width 1920 --out-height 1080`, or just use `--res 1080p`.
- `--proc-width` keeps segmentation cheap regardless of capture resolution (the foreground stays
full-res sharp).

---

## 6. Run at startup (per platform)

**Linux — systemd user service** `~/.config/systemd/user/webcam-blur.service`:

```ini
[Unit]
Description=Webcam Blur (Brio)
After=graphical-session.target
[Service]
WorkingDirectory=%h/webcam-blur
ExecStartPre=/bin/sh -c 'until [ -e /dev/video10 ]; do sleep 1; done'
ExecStart=%h/webcam-blur/.venv/bin/python %h/webcam-blur/blur_cam.py --auto-detect --auto-frame
Restart=on-failure
[Install]
WantedBy=default.target
```

`systemctl --user enable --now webcam-blur.service`

**macOS — launchd LaunchAgent** `~/Library/LaunchAgents/com.user.webcam-blur.plist` with
`ProgramArguments` = `[.venv/bin/python, blur_cam.py, --auto-detect, --auto-frame]`, `RunAtLoad=true`,
`KeepAlive=true`. Load with `launchctl bootstrap gui/$(id -u) <plist>`.

**Windows — Task Scheduler**: create a task, "Run whether user is logged on", trigger *At log on*,
action = `...\.venv\Scripts\pythonw.exe ...\blur_cam.py --auto-detect --auto-frame`. (Or use NSSM to
run it as a service.) OBS Virtual Camera must be registered first.

---

## 7. Troubleshooting (cross-platform)

| Issue | Fix |
| --- | --- |
| No virtual camera in Zoom/Meet | Linux: `modprobe v4l2loopback`. macOS/Windows: install OBS + register its Virtual Camera once. |
| Camera won't open | Grant camera permission (macOS: Privacy & Security; Windows: Settings → Privacy → Camera). Close other apps using it. |
| `--list-devices` empty on mac/Windows | Install `ffmpeg` and put it on PATH. |
| Wrong camera picked | Use `-i <index>` from `--list-devices`, or refine `--camera-name`. |
| Low FPS | Use 720p, keep `--preview` off, lower `--proc-width` (e.g. 480), or `--no-blur`. |
| Green/frozen frames | Prefer `--backend opencv` with `--mjpg` (Brio supports MJPG); or try `--backend ffmpeg`. |
| `mediapipe` won't install | Use Python 3.12 (no 3.13 wheels). |
| Windows ffmpeg backend error | Pass the exact `--device-name "Logitech BRIO"` (from `--list-devices`). |

---

## 8. How cross-platform capture works

| Concern | Linux | macOS | Windows |
| --- | --- | --- | --- |
| OpenCV backend | `CAP_V4L2` | `CAP_AVFOUNDATION` | `CAP_DSHOW` |
| ffmpeg input | `-f v4l2 /dev/videoN` | `-f avfoundation -i "idx:none"` | `-f dshow -i video="Name"` |
| Device detect | udev (`ID_V4L_PRODUCT`) | `ffmpeg -list_devices` | `ffmpeg -f dshow -list_devices` |
| Virtual camera | v4l2loopback | OBS Virtual Camera | OBS Virtual Camera |

The Brio exposes **MJPG**, so bandwidth is a non-issue and behavior is consistent everywhere.

---

## 9. Dependency summary

**Python (all OSes):** `mediapipe opencv-python numpy pyvirtualcam` (in a 3.12 venv)
**Linux:** `v4l-utils`, `v4l2loopback-dkms`, `ffmpeg`
**macOS:** `ffmpeg` + OBS (cask) for the virtual camera
**Windows:** `ffmpeg` on PATH + OBS Studio for the virtual camera
**Models:** `selfie_segmenter.tflite`, `blaze_face_short_range.tflite`

*Provided as-is under MIT license. MediaPipe is Apache 2.0.*
