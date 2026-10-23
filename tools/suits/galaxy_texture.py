"""The Galaxy Astronaut's star field (SkinService scrolls it across the suit).

    blender -b --factory-startup -P tools/suits/galaxy_texture.py

Writes assets/models-textures/Suits/Galaxy.png: 512 x 512 and seamless both ways (every
noise layer wraps), deep indigo with violet and blue nebula clouds, a dusting of faint
stars, brighter ones with a soft glow and a few four-point sparkles. Run inside Blender
for its numpy; the image is written with Blender's own image API.
"""
import os

import bpy
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIZE = 512
rng = np.random.default_rng(7)


def wrapped_noise(cells):
    """Smooth value noise on a `cells` x `cells` grid that tiles."""
    grid = rng.random((cells, cells))
    t = np.arange(SIZE) / SIZE * cells
    i0 = np.floor(t).astype(int)
    f = t - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    i0 = i0 % cells
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fy, fx = f[:, None], f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(base, octaves=5):
    total, amp, norm = np.zeros((SIZE, SIZE)), 1.0, 0.0
    for o in range(octaves):
        total += wrapped_noise(base * 2 ** o) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def blur_wrap(img, radius):
    """A cheap wrapped box blur (three passes ~ gaussian)."""
    for _ in range(3):
        acc = np.zeros_like(img)
        for d in range(-radius, radius + 1):
            acc += np.roll(img, d, axis=0)
        img = acc / (2 * radius + 1)
        acc = np.zeros_like(img)
        for d in range(-radius, radius + 1):
            acc += np.roll(img, d, axis=1)
        img = acc / (2 * radius + 1)
    return img


deep = np.array([0.03, 0.01, 0.10])
violet = np.array([0.55, 0.18, 0.85])
blue = np.array([0.15, 0.35, 0.95])
pink = np.array([0.95, 0.35, 0.80])

clouds = fbm(4)
wisps = fbm(8)
mask_v = np.clip((clouds - 0.45) * 2.6, 0, 1) ** 1.6
mask_b = np.clip((wisps - 0.5) * 2.4, 0, 1) ** 1.8
mask_p = np.clip((fbm(3) - 0.6) * 3.0, 0, 1) ** 2
img = deep[None, None, :] * (0.7 + 0.6 * fbm(16)[:, :, None])
img = img + violet * mask_v[:, :, None] * 0.75 + blue * mask_b[:, :, None] * 0.55 + pink * mask_p[:, :, None] * 0.35

# Stars: faint dust, then brighter stars with a glow, then a few sparkles.
stars = np.zeros((SIZE, SIZE))
n = 2600
ys, xs = rng.integers(0, SIZE, n), rng.integers(0, SIZE, n)
stars[ys, xs] = rng.random(n) ** 3 * 0.9
bright = np.zeros((SIZE, SIZE))
m = 90
ys, xs = rng.integers(0, SIZE, m), rng.integers(0, SIZE, m)
bright[ys, xs] = 0.6 + 0.4 * rng.random(m)
glow = blur_wrap(bright, 2) * 6
sparkle = np.zeros((SIZE, SIZE))
for _ in range(14):
    y, x = rng.integers(0, SIZE, 2)
    length = rng.integers(6, 14)
    for d in range(-length, length + 1):
        k = (1 - abs(d) / (length + 1)) ** 2
        sparkle[(y + d) % SIZE, x] = max(sparkle[(y + d) % SIZE, x], k)
        sparkle[y, (x + d) % SIZE] = max(sparkle[y, (x + d) % SIZE], k)
star_light = np.clip(stars + bright + glow + sparkle, 0, 1.5)
tint = np.array([0.9, 0.92, 1.0])
img = img + star_light[:, :, None] * tint
img = np.clip(img, 0, 1)

# Check it tiles: the wrap is built in, so the seam rows differ no more than neighbours.
seam = np.abs(img[0] - img[-1]).mean()
inner = np.abs(img[1] - img[0]).mean()
print("seam %.4f vs neighbour %.4f" % (seam, inner))

out = os.path.join(ROOT, "assets", "models-textures", "Suits", "Galaxy.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
image = bpy.data.images.new("Galaxy", SIZE, SIZE, alpha=False)
rgba = np.concatenate([img, np.ones((SIZE, SIZE, 1))], axis=2)
image.pixels.foreach_set(rgba[::-1].astype(np.float32).ravel())
image.filepath_raw = out
image.file_format = "PNG"
image.save()
print("wrote", out)
