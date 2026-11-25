#!/usr/bin/env python3
"""Generate the demo's synthetic, MIT-licensed image and ICC assets.

The output is deterministic for a fixed Pillow/numpy build: no timestamps,
no random source other than a fixed seed. The ICC profiles are copied from
the CMYK component's own MIT-licensed test fixtures (a Little CMS generated
sRGB profile and a synthetic CMYK device), so the demo carries no
third-party press profile or photograph.

Usage:
    python3 scripts/generate_assets.py --root .
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

WIDTH, HEIGHT = 1200, 800
DPI = (144, 144)

# 5 rows x 6 columns of reference patches: primaries, secondaries, process
# inks, skin-ish tones, neutrals, and a few high-chroma RGB-only colours that
# a CMYK press cannot reproduce. Deliberately simple rectangles so the demo
# preview is legible at a glance.
PATCHES = [
    (255, 0, 0), (0, 255, 0), (0, 0, 255), (0, 255, 255), (255, 0, 255), (255, 255, 0),
    (255, 128, 0), (128, 255, 0), (0, 255, 128), (0, 128, 255), (128, 0, 255), (255, 0, 128),
    (255, 255, 255), (204, 204, 204), (153, 153, 153), (102, 102, 102), (51, 51, 51), (0, 0, 0),
    (245, 222, 179), (222, 184, 135), (210, 150, 110), (160, 100, 70), (120, 70, 50), (80, 45, 30),
    (250, 240, 230), (235, 210, 190), (200, 170, 140), (150, 190, 210), (120, 160, 140), (90, 110, 130),
]


def chart() -> Image.Image:
    canvas = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)

    # 1. Hue sweep across the top band.
    top_h = 210
    x = np.linspace(0.0, 1.0, WIDTH, dtype=np.float32)
    hue = np.stack(
        [
            np.clip(np.abs(x * 6.0 - 3.0) - 1.0, 0.0, 1.0),
            np.clip(2.0 - np.abs(x * 6.0 - 2.0), 0.0, 1.0),
            np.clip(2.0 - np.abs(x * 6.0 - 4.0), 0.0, 1.0),
        ],
        axis=1,
    )
    canvas[0:top_h, :, :] = (hue[None, :, :] * 255.0).astype(np.uint8)

    # 2. Patch grid in the middle, with a light gutter.
    rows, cols = 5, 6
    gutter = 12
    grid_top, grid_bottom = top_h + 24, HEIGHT - 190
    cell_w = (WIDTH - gutter * (cols + 1)) / cols
    cell_h = (grid_bottom - grid_top - gutter * (rows - 1)) / rows
    canvas[grid_top:grid_bottom, :, :] = 245
    for r in range(rows):
        for c in range(cols):
            left = int(gutter + c * (cell_w + gutter))
            top = int(grid_top + r * (cell_h + gutter))
            right = int(left + cell_w)
            bottom = int(top + cell_h)
            canvas[top:bottom, left:right, :] = PATCHES[r * cols + c]

    # 3. Smooth vertical ramp at the bottom (banding/quantisation visible).
    ramp = np.linspace(0, 255, HEIGHT - grid_bottom, dtype=np.uint8)[:, None, None]
    canvas[grid_bottom:, :, :] = np.repeat(ramp, WIDTH, axis=1)

    # 4. A soft diagonal highlight so the image is not purely flat.
    yy, xx = np.mgrid[0:HEIGHT, 0:WIDTH].astype(np.float32)
    glow = np.clip(1.0 - np.sqrt((xx - WIDTH * 0.72) ** 2 + (yy - HEIGHT * 0.32) ** 2) / 420.0, 0.0, 1.0)
    canvas = np.clip(canvas.astype(np.float32) + glow[..., None] * 26.0, 0, 255).astype(np.uint8)

    return Image.fromarray(canvas, "RGB")


def untagged() -> Image.Image:
    w, h = 480, 320
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.clip(255.0 * xx / w, 0, 255)
    g = np.clip(255.0 * yy / h, 0, 255)
    b = np.clip(255.0 * (1.0 - xx / w), 0, 255)
    return Image.fromarray(np.dstack([r, g, b]).astype(np.uint8), "RGB")


def alpha() -> Image.Image:
    w, h = 400, 260
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    rgb = np.dstack(
        [
            np.clip(255.0 * xx / w, 0, 255),
            np.clip(255.0 * yy / h, 0, 255),
            np.full_like(xx, 140.0),
        ]
    ).astype(np.uint8)
    a = np.clip(255.0 * (1.0 - np.sqrt((xx - w / 2) ** 2 + (yy - h / 2) ** 2) / (w * 0.65)), 0, 255)
    return Image.fromarray(np.dstack([rgb, a.astype(np.uint8)]), "RGBA")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--fixtures", type=Path, required=True,
                        help="CMYK repository tests/fixtures directory (ICC profiles)")
    args = parser.parse_args()

    root = args.root.resolve()
    out = root / "Resources" / "Lab"
    profiles = out / "profiles"
    profiles.mkdir(parents=True, exist_ok=True)

    srgb = (args.fixtures / "source.icc").read_bytes()
    cmyk = (args.fixtures / "destination.icc").read_bytes()
    (profiles / "srgb.icc").write_bytes(srgb)
    (profiles / "destination.icc").write_bytes(cmyk)

    chart_img = chart()
    chart_img.save(out / "chart-srgb.png", icc_profile=srgb, optimize=False)
    chart_img.save(out / "chart-srgb.jpg", icc_profile=srgb, quality=92, subsampling=0, dpi=DPI)
    # A transparent 4x4 PNG so the Lab form can hold a real (empty) Picture
    # property before the first conversion instead of an unassigned one.
    Image.new("RGBA", (4, 4), (0, 0, 0, 0)).save(out / "placeholder.png", optimize=False)
    untagged().save(out / "untagged.png", optimize=False)
    alpha().save(out / "alpha.png", optimize=False)

    for path in sorted(out.rglob("*")):
        if path.is_file():
            print(f"{path.relative_to(root)} {path.stat().st_size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
