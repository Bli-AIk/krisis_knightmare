#!/usr/bin/env python3
"""Compare Kristal screenshots with frames extracted from a reference video."""
from __future__ import annotations

import argparse
import csv
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

DEFAULT_TIMES = "2.550,4.730,7.910,10.670,14.230,18.370,22.610,27.940,31.420,33.770"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("video", type=Path, help="reference MP4")
    p.add_argument("screenshots", type=Path, help="directory containing frame_XXXXXX.png files")
    p.add_argument("times", nargs="?", default=DEFAULT_TIMES,
                   help="comma-separated seconds (default: %(default)s)")
    p.add_argument("-o", "--output", type=Path, default=Path("debug/project4_compare"),
                   help="output directory (default: %(default)s)")
    p.add_argument("--ffmpeg", default="ffmpeg", help="ffmpeg executable")
    return p.parse_args()


def ssim(a: np.ndarray, b: np.ndarray) -> float:
    """Mean RGB SSIM using the standard 11x11 Gaussian window."""
    try:
        import cv2
        vals = []
        for c in range(3):
            x, y = a[..., c], b[..., c]
            ux = cv2.GaussianBlur(x, (11, 11), 1.5)
            uy = cv2.GaussianBlur(y, (11, 11), 1.5)
            vx = cv2.GaussianBlur(x * x, (11, 11), 1.5) - ux * ux
            vy = cv2.GaussianBlur(y * y, (11, 11), 1.5) - uy * uy
            cov = cv2.GaussianBlur(x * y, (11, 11), 1.5) - ux * uy
            vals.append(np.mean((2 * ux * uy + 6.5025) * (2 * cov + 58.5225) /
                                ((ux * ux + uy * uy + 6.5025) * (vx + vy + 58.5225))))
        return float(np.mean(vals))
    except ImportError:
        x, y = a.mean(2), b.mean(2)
        mx, my = x.mean(), y.mean()
        vx, vy = x.var(), y.var()
        cov = ((x - mx) * (y - my)).mean()
        return float((2 * mx * my + 6.5025) * (2 * cov + 58.5225) /
                     ((mx * mx + my * my + 6.5025) * (vx + vy + 58.5225)))


def extract(video: Path, frame_no: int, destination: Path, ffmpeg: str) -> None:
    # Filtering at 60 fps makes the requested frame number deterministic.
    vf = f"fps=60,select=eq(n\\,{frame_no})"
    cmd = [ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(video),
           "-vf", vf, "-frames:v", "1", "-y", str(destination)]
    result = subprocess.run(cmd, text=True, capture_output=True)
    if result.returncode or not destination.exists():
        raise RuntimeError(result.stderr.strip() or "ffmpeg did not produce a frame")


def side_by_side(reference: Image.Image, capture: Image.Image, path: Path) -> None:
    out = Image.new("RGB", (reference.width * 2, reference.height))
    out.paste(reference, (0, 0)); out.paste(capture, (reference.width, 0)); out.save(path)


def main() -> int:
    args = parse_args()
    if shutil.which(args.ffmpeg) is None:
        print(f"error: ffmpeg executable not found: {args.ffmpeg}", file=sys.stderr); return 2
    if not args.video.is_file():
        print(f"error: video not found: {args.video}", file=sys.stderr); return 2
    if not args.screenshots.is_dir():
        print(f"error: screenshot directory not found: {args.screenshots}", file=sys.stderr); return 2
    try:
        times = [float(x.strip()) for x in args.times.split(",") if x.strip()]
        if not times or any(x < 0 for x in times): raise ValueError
    except ValueError:
        print("error: times must be a comma-separated list of non-negative seconds", file=sys.stderr); return 2
    args.output.mkdir(parents=True, exist_ok=True)
    rows, failures = [], 0
    for t in times:
        frame_no = int(math.floor(t * 60 + 0.5))
        # Kristal capture names encode milliseconds; the reference is sampled at 60 fps.
        stem = f"frame_{int(math.floor(t * 1000 + 0.5)):06d}"
        capture_path = args.screenshots / f"{stem}.png"
        try:
            capture = Image.open(capture_path).convert("RGB")
            ref_path = args.output / f"{stem}_reference.png"
            extract(args.video, frame_no, ref_path, args.ffmpeg)
            reference = Image.open(ref_path).convert("RGB")
            if reference.size != capture.size:
                raise ValueError(f"size mismatch: reference={reference.size}, capture={capture.size}")
            x = np.asarray(reference, dtype=np.float32); y = np.asarray(capture, dtype=np.float32)
            diff = np.abs(x - y); mae = float(diff.mean()); rmse = float(np.sqrt(np.mean((x-y)**2)))
            psnr = float("inf") if rmse == 0 else float(20 * math.log10(255 / rmse))
            diff_img = Image.fromarray(np.clip(diff, 0, 255).astype(np.uint8), "RGB")
            diff_img.save(args.output / f"{stem}_absolute_diff.png")
            side_by_side(reference, capture, args.output / f"{stem}_comparison.png")
            overlay = Image.blend(reference, capture, 0.5); overlay.save(args.output / f"{stem}_overlay.png")
            rows.append({"time_seconds": t, "frame": frame_no, "capture": str(capture_path),
                         "width": capture.width, "height": capture.height, "mae": mae,
                         "rmse": rmse, "psnr_db": psnr, "ssim": ssim(x, y)})
            print(f"{t:.3f}s {stem}: MAE={mae:.4f} RMSE={rmse:.4f} PSNR={psnr:.4f} SSIM={rows[-1]['ssim']:.6f}")
        except (OSError, ValueError, RuntimeError) as exc:
            failures += 1; print(f"error: {t:.3f}s ({stem}): {exc}", file=sys.stderr)
    with (args.output / "summary.json").open("w") as f: json.dump(rows, f, indent=2)
    with (args.output / "summary.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]) if rows else
                                ["time_seconds", "frame", "capture", "width", "height", "mae", "rmse", "psnr_db", "ssim"])
        writer.writeheader(); writer.writerows(rows)
    print(f"summary: {len(rows)} compared, {failures} failed; output={args.output}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
