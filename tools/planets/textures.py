"""Builds the textures the destination planets wear, from the SBS planet texture pack
(assets/models-textures/sbs_-_planet_texture_pack_-_1024x512, CC0) plus a few made here.

    python tools/planets/textures.py            # -> assets/planets/*.png
    python tools/planets/textures.py --preview  # also a contact sheet, assets/planets/preview.png
    python tools/planets/textures.py --studio   # also into Studio's content/textures
                                                # (rbxasset://textures/rocket-planets/<name>.png)

Outputs:
  earth.png          Earth for the Moon's sky (SBS Grassland) under a white cloud layer
                     that wraps round (the seam at u=0/1 matches), equirectangular 1024x512.
                     The clouds are baked in: MeshPart textures ignore alpha, so a separate
                     cloud shell would be an opaque white ball.
  moon_regolith.png  A seamless 512x512 overlay for the Moon's ground: pocked small craters
                     (shaded from the sun's side) and mottling, mostly transparent so the
                     part's Slate material shows through.
  moon_maria.png     A seamless 512x512 overlay of broad dark patches (lunar seas) for the
                     plain round the platform, tiled large so the ground isn't one grey.
                     Tinted (Texture.Color3), it also darkens Mars's plain in patches.
  mars_ground.png    A seamless 512x512 overlay for Mars's sand: wind ripples, pebbles, mottling.
  mars_strata.png    Opaque layered rock beds for the canyon walls (seamless).
  phobos.png         Phobos and Deimos (the pack's Barren map, greyed to dusty brown).
  mars_sky_<Face>.png  Mars's daytime sky, cut into the six faces a Roblox Sky takes.
  jupiter.png        Jupiter for Europa's sky (SBS Gaseous) with the Great Red Spot painted in.
  io.png             Io (SBS Arid) pushed to sulfur yellow, with dark volcanic spots.
  europa_ice.png     A seamless 512x512 overlay of reddish lineae and fine cracks for Europa's ice.

Upload each as an Image and put the ids in ServerScriptService/Services/Planets.luau
(TEXTURES). Planets.LocalPreview = true uses the --studio copies instead, for
looking at changes in Studio before an upload loads.
"""
import argparse
import glob
import os
import shutil
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sky"))
import cubemap  # noqa: E402  (tools/sky: the face projection the skies use)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACK = os.path.join(ROOT, "assets", "models-textures", "sbs_-_planet_texture_pack_-_1024x512", "Planet Textures 1024x512")
OUT = os.path.join(ROOT, "assets", "planets")


def periodic_noise(width, height, cells_x, cells_y, rng):
    """Smooth value noise that tiles in both directions (a grid of random values,
    wrapped, sampled with a smoothstep blend)."""
    grid = rng.random((cells_y, cells_x))
    ys = np.linspace(0, cells_y, height, endpoint=False)
    xs = np.linspace(0, cells_x, width, endpoint=False)
    y0, x0 = np.floor(ys).astype(int), np.floor(xs).astype(int)
    ty, tx = ys - y0, xs - x0
    ty, tx = ty * ty * (3 - 2 * ty), tx * tx * (3 - 2 * tx)
    y1, x1 = (y0 + 1) % cells_y, (x0 + 1) % cells_x
    a = grid[np.ix_(y0, x0)]
    b = grid[np.ix_(y0, x1)]
    c = grid[np.ix_(y1, x0)]
    d = grid[np.ix_(y1, x1)]
    top = a + (b - a) * tx[None, :]
    bottom = c + (d - c) * tx[None, :]
    return top + (bottom - top) * ty[:, None]


def fbm(width, height, base_x, base_y, octaves, rng, gain=0.5):
    total, amplitude, norm = np.zeros((height, width)), 1.0, 0.0
    for octave in range(octaves):
        scale = 2 ** octave
        total += amplitude * periodic_noise(width, height, base_x * scale, base_y * scale, rng)
        norm += amplitude
        amplitude *= gain
    return total / norm


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def earth():
    image = Image.open(os.path.join(PACK, "Grassland", "Grassland_02-1024x512.png")).convert("RGB")
    return image


def earth_clouds(rng):
    width, height = 1024, 512
    # Wraps in x only matters, but tiling both ways is harmless. Stretch cells wide near the
    # equator the way weather bands run.
    noise = fbm(width, height, 8, 4, 6, rng, gain=0.55)
    streak = fbm(width, height, 3, 12, 3, rng)
    value = noise * 0.75 + streak * 0.25
    alpha = smoothstep(0.50, 0.70, value) * 0.92
    # Thin out over the poles (the texture's own ice caps show there) and leave a clear
    # band here and there so continents read.
    lat = np.abs(np.linspace(-1, 1, height))[:, None]
    alpha *= 1 - smoothstep(0.82, 0.97, lat)
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    shade = 235 + 20 * smoothstep(0.55, 0.8, value)
    rgba[..., 0] = rgba[..., 1] = np.clip(shade, 0, 255)
    rgba[..., 2] = 255
    rgba[..., 3] = np.clip(alpha * 255, 0, 255)
    return Image.fromarray(rgba, "RGBA")


def wrapped_distance(size, cx, cy):
    ys, xs = np.mgrid[0:size, 0:size]
    dx = (xs - cx + size / 2) % size - size / 2
    dy = (ys - cy + size / 2) % size - size / 2
    return dx, dy


def moon_regolith(rng):
    size = 512
    # Darkness (0 = leave the material alone) and light, each 0..1, composed into an
    # overlay: black where darker, white where lighter.
    dark = np.zeros((size, size))
    light = np.zeros((size, size))
    mottle = fbm(size, size, 6, 6, 5, rng)
    dark += smoothstep(0.5, 0.75, mottle) * 0.25
    light += smoothstep(0.5, 0.25, mottle) * 0.12
    # Craters: a shaded bowl (dark on the side toward the sun, which comes from -x/-y,
    # lit on the far wall) and a bright raised rim with a soft ejecta halo.
    sun = np.array([-0.7, -0.7])
    for _ in range(46):
        radius = rng.choice([rng.uniform(4, 9), rng.uniform(9, 20), rng.uniform(20, 40)], p=[0.55, 0.35, 0.10])
        cx, cy = rng.uniform(0, size), rng.uniform(0, size)
        dx, dy = wrapped_distance(size, cx, cy)
        r = np.sqrt(dx * dx + dy * dy) / radius
        facing = (dx * sun[0] + dy * sun[1]) / (np.sqrt(dx * dx + dy * dy) + 1e-6)
        # The near wall (toward the sun) sits in shadow, the far wall catches light; both
        # fade into the floor so the bowl reads as a dip, not a ring.
        wall = smoothstep(0.15, 0.95, r) * (r < 1.05)
        dark += wall * 0.42 * np.clip(-facing * 0.8 + 0.2, 0, 1)
        light += wall * 0.22 * np.clip(facing * 0.8 + 0.1, 0, 1)
        dark += np.where(r < 1, 0.08 * (1 - r), 0)
        rim = np.exp(-((r - 1.08) / 0.2) ** 2)
        light += rim * 0.16 * (0.6 + 0.4 * np.clip(-facing, 0, 1))
        halo = np.where(r > 1, np.exp(-(r - 1) * 1.6), 0)
        light += halo * 0.07
    dark, light = np.clip(dark, 0, 1), np.clip(light, 0, 1)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    lighter = light > dark
    value = np.where(lighter, 255, 0)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = value
    rgba[..., 3] = np.clip(np.where(lighter, light - dark, dark - light) * 255, 0, 255)
    return Image.fromarray(rgba, "RGBA")


def moon_maria(rng):
    size = 512
    broad = fbm(size, size, 3, 3, 5, rng, gain=0.55)
    alpha = smoothstep(0.52, 0.66, broad) * 0.55 + smoothstep(0.4, 0.52, broad) * 0.08
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = 40, 40, 46
    rgba[..., 3] = np.clip(alpha * 255, 0, 255)
    return Image.fromarray(rgba, "RGBA")


def mars_ground(rng):
    """Seamless overlay for Mars's sand: wind ripples (bands bent by noise), scattered
    pebbles with a shadow on the side away from the sun, and soft mottling."""
    size = 512
    dark = np.zeros((size, size))
    light = np.zeros((size, size))
    ys, xs = np.mgrid[0:size, 0:size]
    warp = fbm(size, size, 4, 4, 4, rng)
    # Ripples: 16 crests across the tile (so it wraps), wavering with the noise.
    phase = (ys / size * 16 + (warp - 0.5) * 3.0) * 2 * np.pi
    ripple = np.sin(phase)
    light += np.clip(ripple, 0, 1) ** 3 * 0.14
    dark += np.clip(-ripple, 0, 1) ** 3 * 0.12
    mottle = fbm(size, size, 5, 5, 5, rng)
    dark += smoothstep(0.55, 0.8, mottle) * 0.22
    light += smoothstep(0.45, 0.2, mottle) * 0.10
    for _ in range(260):
        radius = rng.choice([rng.uniform(1.2, 2.5), rng.uniform(2.5, 5)], p=[0.8, 0.2])
        cx, cy = rng.uniform(0, size), rng.uniform(0, size)
        dx, dy = wrapped_distance(size, cx, cy)
        r = np.sqrt(dx * dx + dy * dy) / radius
        stone = smoothstep(1.0, 0.6, r)
        dark += stone * rng.uniform(0.35, 0.6)
        # A highlight on the sun side (-x, -y) and a shadow past the far side.
        light += stone * np.clip((-dx - dy) / (radius * 1.4), 0, 1) * 0.35
        sx, sy = wrapped_distance(size, cx + radius * 0.9, cy + radius * 0.9)
        dark += smoothstep(1.1, 0.5, np.sqrt(sx * sx + sy * sy) / radius) * 0.18
    dark, light = np.clip(dark, 0, 1), np.clip(light, 0, 1)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    lighter = light > dark
    rgba[..., 0] = np.where(lighter, 255, 40)
    rgba[..., 1] = np.where(lighter, 240, 14)
    rgba[..., 2] = np.where(lighter, 220, 6)
    rgba[..., 3] = np.clip(np.where(lighter, light - dark, dark - light) * 255, 0, 255)
    return Image.fromarray(rgba, "RGBA")


def mars_strata(rng):
    """Opaque layered rock for canyon walls: beds of rust, ochre, tan and dark basalt, each
    a little uneven, grainy, with thin pale partings between some. Tiles both ways. The
    beds run down the image (vertical stripes): on the plain's side faces (a cylinder on
    its side) Roblox lays a texture's U up the wall, so they come out level."""
    size = 512
    palette = np.array([(150, 70, 42), (182, 104, 62), (204, 142, 92), (120, 56, 38), (168, 88, 52), (96, 50, 38), (196, 124, 78)], float)
    beds, y = [], 0
    while y < size:
        thickness = int(rng.uniform(14, 60))
        beds.append((y, min(size, y + thickness), palette[rng.integers(len(palette))], rng.random() < 0.35))
        y += thickness
    ys = np.arange(size)
    wobble = (fbm(size, size, 6, 2, 3, rng) - 0.5) * 10
    grain = fbm(size, size, 32, 32, 3, rng) - 0.5
    streak = fbm(size, size, 24, 2, 2, rng) - 0.5
    rgb = np.zeros((size, size, 3))
    row = (ys[:, None] + wobble) % size
    for top, bottom, colour, parting in beds:
        inside = (row >= top) & (row < bottom)
        rgb[inside] = colour
        if parting:
            edge = (row >= bottom - 2.5) & (row < bottom)
            rgb[edge] = np.minimum(colour * 1.35, 255)
    rgb *= (1 + grain[..., None] * 0.35 + streak[..., None] * 0.25)
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").transpose(Image.Transpose.TRANSPOSE)


def phobos():
    """Mars's moons: the pack's cratered Barren map, greyed toward dark dusty brown."""
    image = np.asarray(Image.open(os.path.join(PACK, "Barren", "Barren_04-1024x512.png")).convert("RGB")).astype(float)
    grey = image.mean(axis=2, keepdims=True)
    tinted = grey * 0.75 * np.array([1.0, 0.86, 0.76]) + image * 0.25
    return Image.fromarray(np.clip(tinted * 0.85, 0, 255).astype(np.uint8), "RGB")


def mars_sky(rng):
    """An equirectangular daytime Mars sky: deep dusty rose overhead fading to butterscotch
    and a pale haze on the horizon, faint dust streaks, and below the horizon ground that
    matches the plain (Roblox shortens the draw distance at times; the sky then shows
    more ground, not sky). Cut into cube faces by tools/sky/cubemap.py's projection."""
    w, h = 2048, 1024
    lat = (0.5 - (np.arange(h) + 0.5) / h) * 180  # degrees, +90 up
    zenith, mid, horizon = np.array((128, 74, 60)), np.array((206, 146, 100)), np.array((232, 196, 156))
    # Below the horizon: the far plain as the haze leaves it, darkening further down.
    ground_near, ground_far = np.array((176, 96, 62)), np.array((214, 146, 104))
    rgb = np.zeros((h, w, 3))
    for i, a in enumerate(lat):
        if a >= 0:
            t = min(1, a / 70)
            colour = horizon * (1 - smoothstep(0, 0.25, t)) + mid * smoothstep(0, 0.25, t)
            colour = colour * (1 - smoothstep(0.25, 1, t)) + zenith * smoothstep(0.25, 1, t)
        else:
            colour = ground_far * (1 - smoothstep(0, 12, -a)) + ground_near * smoothstep(0, 12, -a)
        rgb[i] = colour
    streaks = fbm(w, h, 6, 24, 4, rng) - 0.5
    upper = (lat[:, None] > 0) * (1 - np.clip(lat[:, None] / 80, 0, 1))
    rgb *= 1 + streaks[..., None] * 0.12 * upper[..., None]
    return np.clip(rgb, 0, 255).astype(np.uint8)


def jupiter(rng):
    """Jupiter for Europa's sky: the pack's orange banded gas giant, its bands sharpened a
    little, with the Great Red Spot (a swirled oval with a pale rim) in the south."""
    image = np.asarray(Image.open(os.path.join(PACK, "Gaseous", "Gaseous_05-1024x512.png")).convert("RGB")).astype(float)
    h, w = image.shape[:2]
    mean = image.mean(axis=(0, 1))
    image = mean + (image - mean) * 1.15
    ys, xs = np.mgrid[0:h, 0:w]
    cx, cy, rx, ry = w * 0.62, h * 0.66, w * 0.055, h * 0.055
    dx, dy = (xs - cx) / rx, (ys - cy) / ry
    r = np.sqrt(dx * dx + dy * dy)
    swirl = np.sin(np.arctan2(dy, dx) * 3 + r * 6) * 0.5 + 0.5
    spot = np.array((196, 82, 52)) * (0.85 + 0.15 * swirl[..., None])
    inside = smoothstep(1.0, 0.75, r)[..., None]
    rim = (np.exp(-((r - 1.1) / 0.12) ** 2))[..., None]
    image = image * (1 - inside) + spot * inside
    image = image * (1 - rim * 0.5) + np.array((238, 214, 180)) * rim * 0.5
    return Image.fromarray(np.clip(image, 0, 255).astype(np.uint8), "RGB")


def io(rng):
    """Io: the pack's Arid map pushed to sulfur yellow and orange, freckled with dark
    volcanic spots ringed in red."""
    image = np.asarray(Image.open(os.path.join(PACK, "Arid", "Arid_03-1024x512.png")).convert("RGB")).astype(float)
    grey = image.mean(axis=2, keepdims=True) / 255
    base = np.array((222, 196, 92)) * (0.7 + 0.5 * grey) + (np.array((206, 120, 54)) - np.array((222, 196, 92))) * smoothstep(0.45, 0.25, grey)
    h, w = base.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    for _ in range(24):
        cx, cy, radius = rng.uniform(0, w), rng.uniform(h * 0.15, h * 0.85), rng.uniform(3, 10)
        dx = (xs - cx + w / 2) % w - w / 2
        r = np.sqrt(dx * dx + (ys - cy) ** 2) / radius
        base = base * (1 - smoothstep(1, 0.4, r)[..., None] * 0.85) + np.array((120, 44, 26)) * (np.exp(-((r - 1.5) / 0.4) ** 2) * 0.35)[..., None]
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")


def europa_ice(rng):
    """Seamless overlay for Europa's ice: long reddish-brown lineae (double bands, gently
    curving, crossing each other) and fine pale cracks."""
    size = 512
    dark = np.zeros((size, size))
    light = np.zeros((size, size))
    ys, xs = np.mgrid[0:size, 0:size]
    for _ in range(5):
        # A band along a line with a whole-number slope (so it wraps at the tile's edges),
        # bent by a slow sine so it curves.
        k = rng.integers(1, 3)
        tx, ty = rng.integers(-2, 3), rng.integers(1, 3)
        length = np.hypot(tx, ty)
        nx, ny = -ty / length, tx / length
        offset = rng.uniform(0, size)
        bend = np.sin((xs * tx + ys * ty) / size * 2 * np.pi * k) * rng.uniform(6, 18)
        d = ((xs * nx + ys * ny + offset + bend) % (size / length)) - size / length / 2
        width = rng.uniform(4, 8)
        band = np.exp(-((np.abs(d) - width) / (width * 0.6)) ** 2)
        dark += band * rng.uniform(0.25, 0.45)
        light += np.exp(-(d / (width * 0.4)) ** 2) * 0.15
    cracks = fbm(size, size, 24, 24, 3, rng)
    light += smoothstep(0.03, 0.0, np.abs(cracks - 0.5)) * 0.25
    mottle = fbm(size, size, 4, 4, 4, rng)
    dark += smoothstep(0.55, 0.8, mottle) * 0.12
    dark, light = np.clip(dark, 0, 1), np.clip(light, 0, 1)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    lighter = light > dark
    rgba[..., 0] = np.where(lighter, 240, 120)
    rgba[..., 1] = np.where(lighter, 250, 58)
    rgba[..., 2] = np.where(lighter, 255, 40)
    rgba[..., 3] = np.clip(np.where(lighter, light - dark, dark - light) * 255, 0, 255)
    return Image.fromarray(rgba, "RGBA")


def preview(images):
    tiles = []
    for name, image in images.items():
        backdrop = Image.new("RGBA", image.size, (150, 150, 156, 255))
        backdrop.alpha_composite(image.convert("RGBA"))
        if image.size[0] == image.size[1]:
            # Tiled 2x2 to show the seams match.
            tiled = Image.new("RGBA", (image.size[0] * 2, image.size[1] * 2))
            for ox in (0, image.size[0]):
                for oy in (0, image.size[1]):
                    tiled.paste(backdrop, (ox, oy))
            backdrop = tiled
        tiles.append(backdrop.resize((512, 256 if backdrop.size[0] != backdrop.size[1] else 512)))
    sheet = Image.new("RGBA", (512, sum(t.size[1] for t in tiles)), "white")
    y = 0
    for tile in tiles:
        sheet.paste(tile, (0, y))
        y += tile.size[1]
    return sheet


def studio_textures():
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")
    installs = [d for d in glob.glob(os.path.join(base, "*")) if os.path.isfile(os.path.join(d, "RobloxStudioBeta.exe"))]
    return os.path.join(max(installs, key=os.path.getmtime), "content", "textures") if installs else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--studio", action="store_true", help="also copy into Studio's content/textures/rocket-planets")
    args = parser.parse_args()
    studio = studio_textures() if args.studio else None
    if args.studio and not studio:
        sys.exit("No Roblox Studio install found under %LOCALAPPDATA%/Roblox/Versions")
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(7)
    clouds = earth_clouds(rng)
    surface = earth().convert("RGBA")
    surface.alpha_composite(clouds)
    images = {
        "earth": surface.convert("RGB"),
        "moon_regolith": moon_regolith(rng),
        "moon_maria": moon_maria(rng),
        # Mars: each from its own seed, so adding one never changes another.
        "mars_ground": mars_ground(np.random.default_rng(21)),
        "mars_strata": mars_strata(np.random.default_rng(22)),
        "phobos": phobos(),
        "jupiter": jupiter(np.random.default_rng(31)),
        "io": io(np.random.default_rng(32)),
        "europa_ice": europa_ice(np.random.default_rng(33)),
    }
    sky = mars_sky(np.random.default_rng(23))
    for key, axes in cubemap.FACES.items():
        images["mars_sky_" + key] = Image.fromarray(cubemap.face(sky, *axes))
    for name, image in images.items():
        image.save(os.path.join(OUT, name + ".png"))
        print("wrote", os.path.join(OUT, name + ".png"))
        if studio:
            os.makedirs(os.path.join(studio, "rocket-planets"), exist_ok=True)
            shutil.copy(os.path.join(OUT, name + ".png"), os.path.join(studio, "rocket-planets", name + ".png"))
    if args.preview:
        preview({k: v for k, v in images.items() if not k.startswith("mars_sky_")}).save(os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    main()
