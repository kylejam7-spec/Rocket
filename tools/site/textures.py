"""Builds the surface textures for the Earth launch site: seamless 512x512 overlays laid
over the parts' own materials and colours (mostly transparent, so the material shows).

    python tools/site/textures.py            # -> assets/site/*.png
    python tools/site/textures.py --studio   # also into Studio's content/textures
                                             # (rbxasset://textures/rocket-planets/<name>.png,
                                             # where Planets.LocalPreview looks)

Outputs:
  site_dirt.png   packed construction dirt: gravel, damp and dusty patches (tyre ruts are parts)
  asphalt.png     road surface: grit, hairline cracks, oil stains
  concrete.png    apron slabs: a joint round every tile, mottling, stains, skid marks
  grass.png       the plain: darker and lighter clumps, blades, clover, little flowers
  gym_floor.png   rubber gym flooring: coloured flecks and tile seams

Upload each as an Image and put the ids in ServerScriptService/Services/Planets.luau
(TEXTURES), which lays them on (Planets.overlay).
"""
import argparse
import os
import shutil
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "planets"))
import textures as planet  # noqa: E402  (fbm, smoothstep, wrapped_distance, studio_textures)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "site")
SIZE = 512
fbm, smoothstep, wrapped = planet.fbm, planet.smoothstep, planet.wrapped_distance


def overlay(dark, light, dark_rgb=(20, 14, 8), light_rgb=(255, 248, 235)):
    """Darkening and lightening amounts (0..1) as one RGBA overlay."""
    dark, light = np.clip(dark, 0, 1), np.clip(light, 0, 1)
    lighter = light > dark
    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    for channel in range(3):
        rgba[..., channel] = np.where(lighter, light_rgb[channel], dark_rgb[channel])
    rgba[..., 3] = np.clip(np.where(lighter, light - dark, dark - light) * 255, 0, 255)
    return Image.fromarray(rgba, "RGBA")


def band(coordinate, centre, width):
    """Distance-based soft band across a wrapped coordinate (0..SIZE)."""
    d = np.abs(((coordinate - centre + SIZE / 2) % SIZE) - SIZE / 2)
    return smoothstep(width, width * 0.4, d)


def speckle(rng, density, size_range=(1, 2)):
    """Random dots (0..1), each a few pixels, wrapping."""
    out = np.zeros((SIZE, SIZE))
    count = int(density * SIZE * SIZE / 100)
    ys, xs = rng.integers(0, SIZE, count), rng.integers(0, SIZE, count)
    sizes = rng.integers(size_range[0], size_range[1] + 1, count)
    for y, x, s in zip(ys, xs, sizes):
        out[np.arange(y, y + s)[:, None] % SIZE, np.arange(x, x + s)[None, :] % SIZE] = rng.uniform(0.5, 1)
    return out


def site_dirt(rng):
    dark, light = np.zeros((SIZE, SIZE)), np.zeros((SIZE, SIZE))
    blotch = fbm(SIZE, SIZE, 4, 4, 5, rng)
    dark += smoothstep(0.55, 0.75, blotch) * 0.35  # damp patches
    light += smoothstep(0.42, 0.22, blotch) * 0.22  # dry dust
    dark += speckle(rng, 1.2, (1, 3)) * 0.35
    light += speckle(rng, 1.0, (1, 2)) * 0.4
    return overlay(dark, light)


def asphalt(rng):
    dark, light = np.zeros((SIZE, SIZE)), np.zeros((SIZE, SIZE))
    mottle = fbm(SIZE, SIZE, 6, 6, 4, rng)
    dark += smoothstep(0.55, 0.8, mottle) * 0.2
    light += smoothstep(0.45, 0.2, mottle) * 0.12
    dark += speckle(rng, 3, (1, 1)) * 0.3
    light += speckle(rng, 3, (1, 1)) * 0.35
    # Hairline cracks: random walks that wrap.
    for _ in range(6):
        y, x = rng.uniform(0, SIZE), rng.uniform(0, SIZE)
        angle = rng.uniform(0, 2 * np.pi)
        for _ in range(rng.integers(60, 160)):
            angle += rng.normal(0, 0.35)
            y, x = (y + np.sin(angle) * 1.5) % SIZE, (x + np.cos(angle) * 1.5) % SIZE
            dark[int(y), int(x)] = 0.7
    # Oil stains (repairs are separate parts: a patch in the tile repeats too plainly).
    for _ in range(3):
        cx, cy, r = rng.uniform(0, SIZE), rng.uniform(0, SIZE), rng.uniform(14, 34)
        dx, dy = wrapped(SIZE, cx, cy)
        dark += smoothstep(1, 0.3, np.sqrt(dx * dx + dy * dy) / r) * 0.35
    return overlay(dark, light, (8, 8, 10), (240, 240, 235))


def concrete(rng):
    ys, xs = np.mgrid[0:SIZE, 0:SIZE]
    dark, light = np.zeros((SIZE, SIZE)), np.zeros((SIZE, SIZE))
    mottle = fbm(SIZE, SIZE, 5, 5, 5, rng)
    dark += smoothstep(0.55, 0.8, mottle) * 0.18
    light += smoothstep(0.45, 0.2, mottle) * 0.14
    # One slab per tile: a joint round its edge, with a little lighter lip beside it.
    joint = np.minimum(np.minimum(xs, SIZE - 1 - xs), np.minimum(ys, SIZE - 1 - ys))
    dark += smoothstep(3, 0, joint) * 0.55
    light += smoothstep(3, 5, joint) * smoothstep(8, 5, joint) * 0.12
    dark += speckle(rng, 1.2, (1, 2)) * 0.2
    # Rust and water stains, and a pair of curving skid marks.
    for _ in range(4):
        cx, cy, r = rng.uniform(0, SIZE), rng.uniform(0, SIZE), rng.uniform(20, 60)
        dx, dy = wrapped(SIZE, cx, cy)
        dark += smoothstep(1, 0.2, np.sqrt(dx * dx + dy * dy) / r) * 0.12
    curve = np.sin(xs / SIZE * 2 * np.pi) * 40 + SIZE * 0.6
    for offset in (-12, 12):
        dark += band(ys, curve + offset, 4) * 0.22 * smoothstep(0.3, 0.6, fbm(SIZE, SIZE, 8, 2, 2, rng))
    return overlay(dark, light, (16, 16, 18), (250, 250, 245))


def grass(rng):
    dark, light = np.zeros((SIZE, SIZE)), np.zeros((SIZE, SIZE))
    clumps = fbm(SIZE, SIZE, 6, 6, 5, rng)
    dark += smoothstep(0.55, 0.78, clumps) * 0.3
    light += smoothstep(0.45, 0.22, clumps) * 0.2
    # Blades: short vertical strokes, dark and light.
    for amount, target in ((2.0, dark), (1.6, light)):
        count = int(amount * SIZE * SIZE / 100)
        ys, xs = rng.integers(0, SIZE, count), rng.integers(0, SIZE, count)
        for y, x in zip(ys, xs):
            target[np.arange(y, y + 4) % SIZE, x] = np.maximum(target[np.arange(y, y + 4) % SIZE, x], rng.uniform(0.2, 0.45))
    img = overlay(dark, light, (10, 30, 8), (215, 240, 160))
    rgba = np.array(img)
    # Clover patches and flowers, painted opaque-ish on top.
    for _ in range(60):
        cx, cy = rng.uniform(0, SIZE), rng.uniform(0, SIZE)
        colour = [(250, 250, 245), (250, 220, 60), (230, 120, 200), (170, 150, 250)][rng.integers(0, 4)]
        for _ in range(rng.integers(3, 8)):
            x, y = int(cx + rng.normal(0, 6)) % SIZE, int(cy + rng.normal(0, 6)) % SIZE
            rgba[y:y + 2, x:x + 2, :3] = colour
            rgba[y:y + 2, x:x + 2, 3] = 230
    return Image.fromarray(rgba, "RGBA")


def gym_floor(rng):
    ys, xs = np.mgrid[0:SIZE, 0:SIZE]
    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    # Seams: a 4 x 4 grid of rubber tiles per texture tile.
    seam = np.minimum(xs % 128, ys % 128)
    rgba[..., 3] = (smoothstep(2.5, 0, seam) * 150).astype(np.uint8)
    # Coloured flecks.
    count = int(2.2 * SIZE * SIZE / 100)
    fy, fx = rng.integers(0, SIZE, count), rng.integers(0, SIZE, count)
    palette = np.array([(235, 235, 235), (90, 170, 240), (240, 200, 60), (230, 80, 80), (120, 120, 130)])
    picks = palette[rng.integers(0, len(palette), count)]
    rgba[fy, fx, :3] = picks
    rgba[fy, fx, 3] = 200
    return Image.fromarray(rgba, "RGBA")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--studio", action="store_true")
    args = parser.parse_args()
    os.makedirs(OUT, exist_ok=True)
    studio = planet.studio_textures() if args.studio else None
    images = {
        "site_dirt": site_dirt(np.random.default_rng(61)),
        "asphalt": asphalt(np.random.default_rng(62)),
        "concrete": concrete(np.random.default_rng(63)),
        "grass": grass(np.random.default_rng(64)),
        "gym_floor": gym_floor(np.random.default_rng(65)),
    }
    for name, image in images.items():
        path = os.path.join(OUT, name + ".png")
        image.save(path)
        print("wrote", path)
        if studio:
            os.makedirs(os.path.join(studio, "rocket-planets"), exist_ok=True)
            shutil.copy(path, os.path.join(studio, "rocket-planets", name + ".png"))


if __name__ == "__main__":
    main()
