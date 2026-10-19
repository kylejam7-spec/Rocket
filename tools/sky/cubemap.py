"""Cuts a Kenney equirectangular skybox (assets/models-textures/kenney_skyboxes-space) into
the six faces a Roblox Sky takes (SkyboxBk/Dn/Ft/Lf/Rt/Up), 1024 px each.

    python tools/sky/cubemap.py day galaxy          # -> assets/sky/<name>/<name>_<Face>.png
    python tools/sky/cubemap.py day --studio        # also into Studio's content/textures
                                                    # (rbxasset://textures/rocket-sky/<name>/...)
    python tools/sky/cubemap.py --test --studio     # labelled faces, to check orientation
    python tools/sky/cubemap.py day --land          # Earth: land below the horizon, far range

Earth's sky carries land of its own (--land): Roblox shortens the draw distance when the
frame rate dips (a launch, with its smoke and fire), and the far plain and mountains drop
out. Behind them the sky then shows more of the same ground and a faint far range instead
of the panorama's purple lower half.

Upload each face as an Image and put the ids in Shared/Skies.luau.
"""
import argparse
import glob
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "assets", "models-textures", "kenney_skyboxes-space", "Skyboxes")
OUT = os.path.join(ROOT, "assets", "sky")
SIZE = 1024

# Roblox world axes: +Y up; the default camera looks along -Z. For each face: the
# direction it covers, then the world directions of its image's right and down, as Studio
# draws them (checked with --test: Rt covers -X, and Up/Dn are turned a quarter).
FACES = {
    "Ft": ((0, 0, -1), (1, 0, 0), (0, -1, 0)),
    "Bk": ((0, 0, 1), (-1, 0, 0), (0, -1, 0)),
    "Rt": ((-1, 0, 0), (0, 0, -1), (0, -1, 0)),
    "Lf": ((1, 0, 0), (0, 0, 1), (0, -1, 0)),
    "Up": ((0, 1, 0), (0, 0, -1), (-1, 0, 0)),
    "Dn": ((0, -1, 0), (0, 0, -1), (1, 0, 0)),
}


def face(panorama, forward, right, down):
    h, w = panorama.shape[:2]
    t = (np.arange(SIZE) + 0.5) / SIZE * 2 - 1
    u, v = np.meshgrid(t, t)
    d = (np.array(forward)[None, None, :] + u[..., None] * np.array(right) + v[..., None] * np.array(down))
    d /= np.linalg.norm(d, axis=-1, keepdims=True)
    # Longitude 0 at -Z (the panorama's centre), growing toward +X; latitude up +Y.
    lon = np.arctan2(d[..., 0], -d[..., 2])
    lat = np.arcsin(np.clip(d[..., 1], -1, 1))
    x = ((lon / (2 * math.pi) + 0.5) * w).astype(int) % w
    y = np.clip(((0.5 - lat / math.pi) * h).astype(int), 0, h - 1)
    return panorama[y, x]


# The grass plain and mountain rock as they render on Earth (sampled in Studio).
LAND = (84, 94, 72)
ROCK = (92, 88, 94)


def land(panorama, seed=7):
    """Ground below the horizon (matching the grass plain), a soft haze line, and a low,
    faceted far mountain range with snow on its tallest peaks. Drawn at twice the
    resolution and scaled down, so slopes stay smooth on the cube faces."""
    random = np.random.default_rng(seed)
    h, w = panorama.shape[:2]
    horizon = h // 2
    deg = h / 180
    sky = panorama[horizon - 30:horizon - 6].reshape(-1, 3).mean(axis=0)
    def mix(a, b, t):
        return tuple(int(round(x * (1 - t) + y * t)) for x, y in zip(a, b))
    image = Image.fromarray(panorama)
    draw = ImageDraw.Draw(image)
    for y in range(horizon, h):
        down = (y - horizon) / deg
        colour = mix(mix(LAND, sky, 0.35), LAND, min(1, down / 1.5)) if down < 1.5 else mix(LAND, (60, 68, 50), min(1, (down - 1.5) / 40))
        draw.line([(0, y), (w, y)], fill=colour)
    # The range, on a strip twice the size: alternating peaks and saddles round the full
    # circle (the last meets the first), lit and shaded facets, snow caps.
    top, scale = int(horizon - 8 * deg), 2
    strip = Image.fromarray(np.asarray(image)[top:horizon + 2]).resize((w * scale, (horizon + 2 - top) * scale), Image.BICUBIC)
    pen = ImageDraw.Draw(strip)
    base_y = (horizon - top) * scale + scale
    rock = mix(ROCK, sky, 0.3)
    lit, shade, snow = mix(rock, (255, 255, 255), 0.1), mix(rock, (0, 0, 0), 0.12), mix((236, 236, 248), sky, 0.2)
    points, x = [], 0.0
    while x < w:
        peak = len(points) % 2 == 0
        tall = random.uniform(0.5, 1) * 4.5 if peak else random.uniform(0.05, 0.3) * 4.5
        points.append((x * scale, tall * deg * scale))
        x += random.uniform(140, 360) * (w / 4096)
    points.append((w * scale, points[0][1]))
    for shift in (-w * scale, 0, w * scale):
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            pen.polygon([(x0 + shift, base_y - y0), (x1 + shift, base_y - y1), (x1 + shift, base_y), (x0 + shift, base_y)], fill=lit if y1 > y0 else shade)
        for index in range(0, len(points) - 1, 2):
            px, py = points[index]
            if py > 3.4 * deg * scale:
                left = points[index - 1] if index > 0 else (points[-2][0] - w * scale, points[-2][1])
                right, cap = points[index + 1], 0.25
                pen.polygon([(px + (left[0] - px) * cap + shift, base_y - (py + (left[1] - py) * cap)), (px + shift, base_y - py),
                    (px + (right[0] - px) * cap + shift, base_y - (py + (right[1] - py) * cap))], fill=snow)
    image.paste(strip.resize((w, horizon + 2 - top), Image.LANCZOS), (0, top))
    return np.asarray(image)


def test_faces():
    colours = {"Ft": "red", "Bk": "blue", "Lf": "green", "Rt": "yellow", "Up": "white", "Dn": "gray"}
    faces = {}
    for name, colour in colours.items():
        image = Image.new("RGB", (SIZE, SIZE), colour)
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, SIZE - 1, 60), fill="black")  # marks the image's top edge
        draw.text((SIZE // 2 - 40, SIZE // 2 - 20), name, fill="black", font_size=160)
        faces[name] = image
    return faces


def studio_textures():
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")
    installs = [d for d in glob.glob(os.path.join(base, "*")) if os.path.isfile(os.path.join(d, "RobloxStudioBeta.exe"))]
    return os.path.join(max(installs, key=os.path.getmtime), "content", "textures") if installs else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("names", nargs="*", help="skybox names: band, dark, day, galaxy, nebula")
    parser.add_argument("--test", action="store_true", help="write labelled orientation faces as 'test'")
    parser.add_argument("--studio", action="store_true", help="also copy into Studio's content/textures/rocket-sky")
    parser.add_argument("--land", action="store_true", help="paint ground and a far range below/on the horizon (Earth)")
    args = parser.parse_args()
    jobs = {}
    if args.test:
        jobs["test"] = test_faces()
    for name in args.names:
        panorama = np.asarray(Image.open(os.path.join(SOURCE, f"skybox-space-{name}.png")).convert("RGB"))
        if args.land:
            panorama = land(panorama)
        jobs[name] = {key: Image.fromarray(face(panorama, *axes)) for key, axes in FACES.items()}
    if not jobs:
        parser.error("name a skybox or pass --test")
    studio = studio_textures() if args.studio else None
    if args.studio and not studio:
        sys.exit("No Roblox Studio install found under %LOCALAPPDATA%/Roblox/Versions")
    for name, faces in jobs.items():
        targets = [os.path.join(OUT, name)] + ([os.path.join(studio, "rocket-sky", name)] if studio else [])
        for target in targets:
            os.makedirs(target, exist_ok=True)
            for key, image in faces.items():
                image.save(os.path.join(target, f"{name}_{key}.png"))
        print("wrote", name, "->", ", ".join(os.path.relpath(t, ROOT) if t.startswith(ROOT) else t for t in targets))


if __name__ == "__main__":
    main()
