"""Cuts a Kenney equirectangular skybox (assets/models-textures/kenney_skyboxes-space) into
the six faces a Roblox Sky takes (SkyboxBk/Dn/Ft/Lf/Rt/Up), 1024 px each.

    python tools/sky/cubemap.py day galaxy          # -> assets/sky/<name>/<name>_<Face>.png
    python tools/sky/cubemap.py day --studio        # also into Studio's content/textures
                                                    # (rbxasset://textures/rocket-sky/<name>/...)
    python tools/sky/cubemap.py --test --studio     # labelled faces, to check orientation

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
    args = parser.parse_args()
    jobs = {}
    if args.test:
        jobs["test"] = test_faces()
    for name in args.names:
        panorama = np.asarray(Image.open(os.path.join(SOURCE, f"skybox-space-{name}.png")).convert("RGB"))
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
