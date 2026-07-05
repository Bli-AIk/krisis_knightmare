from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REFERENCE = Path("/home/aik/Desktop/mpv-shot0005.jpg")
OUT_DIR = ROOT / "debug" / "depth_compare"

CENTER_X = 628.09
CENTER_Y = 336.90
LOGICAL_DIAMETER = 114
ALPHA = 0.56
TEXTURE_SCALE_X = 1.8
TEXTURE_SCALE_Y = 1.75
TEXTURE_OFFSET_X = 13
TEXTURE_OFFSET_Y = 239


def load_rgb(path):
    return np.array(Image.open(path).convert("RGB"), dtype=np.float32)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    ref = load_rgb(REFERENCE)
    texture = load_rgb(ROOT / "assets" / "sprites" / "battle" / "backgrounds" / "kris_depth_hot.png")

    diameter = LOGICAL_DIAMETER
    radius = diameter / 2
    crop_x = int(round(CENTER_X - diameter))
    crop_y = int(round(CENTER_Y - diameter))
    ref_crop = ref[crop_y:crop_y + diameter * 2, crop_x:crop_x + diameter * 2]

    y, x = np.mgrid[0:diameter, 0:diameter]
    circle = ((x + 0.5 - radius) ** 2 + (y + 0.5 - radius) ** 2) <= radius ** 2

    src_x = (np.floor(x / TEXTURE_SCALE_X).astype(int) + TEXTURE_OFFSET_X) % texture.shape[1]
    src_y = (np.floor(y / TEXTURE_SCALE_Y).astype(int) + TEXTURE_OFFSET_Y) % texture.shape[0]
    logical = np.zeros((diameter, diameter, 3), dtype=np.float32)
    logical[circle] = texture[src_y, src_x][circle] * ALPHA
    candidate = np.repeat(np.repeat(logical, 2, axis=0), 2, axis=1)

    target = ref_crop.reshape(diameter, 2, diameter, 2, 3).mean(axis=(1, 3))
    r, g, b = target[:, :, 0], target[:, :, 1], target[:, :, 2]
    exclude = ((r > 170) & (g > 170) & (b > 170)) | ((r > 120) & (g < 60) & (b < 70)) | ((g > 120) & (r < 80) & (b < 80))
    valid = circle & ~exclude
    valid_screen = np.repeat(np.repeat(valid, 2, axis=0), 2, axis=1)
    diff = np.abs(candidate - ref_crop)
    mae = float(diff[valid_screen].mean())
    rmse = float(np.sqrt(((candidate - ref_crop)[valid_screen] ** 2).mean()))

    Image.fromarray(np.uint8(np.clip(ref_crop, 0, 255))).save(OUT_DIR / "ref_crop.png")
    Image.fromarray(np.uint8(np.clip(candidate, 0, 255))).save(OUT_DIR / "candidate_crop.png")
    Image.fromarray(np.uint8(np.clip(np.concatenate([ref_crop, candidate, diff * 2], axis=1), 0, 255))).save(OUT_DIR / "compare_strip.png")

    print(f"MAE={mae:.3f} RMSE={rmse:.3f}")
    print(OUT_DIR / "compare_strip.png")


if __name__ == "__main__":
    main()
