"""Cuts the loading-screen art into two halves for upload.

Roblox shrinks any uploaded image to fit 1024 px on its longer side, so the 1672x941
art would arrive at ~1024x576. Two halves of 838x941 each (they share the 4 px either
side of the middle, so no seam shows) stay under the limit and keep every pixel. The
loading screen (src/ReplicatedFirst/LoadingScreen.client.luau) lays them side by side.

    python tools/loading/split_art.py [art.png]

writes <art>-left.png and <art>-right.png next to the art (default:
"assets/Loading Screen/newloadingscreen.png"). Upload both as Images, put their ids in
ART_TILES, and for Studio previews copy them into Studio's
content/textures/rocket-loading/.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OVERLAP = 2  # px past the middle on each side


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "Loading Screen", "newloadingscreen.png")
    art = Image.open(path).convert("RGB")
    width, height = art.size
    middle = width // 2
    base = os.path.splitext(path)[0]
    for name, box in (("left", (0, 0, middle + OVERLAP, height)), ("right", (middle - OVERLAP, 0, width, height))):
        tile = art.crop(box)
        assert max(tile.size) <= 1024, f"{name} half is {tile.size}: still over 1024 px"
        tile.save(f"{base}-{name}.png")
        print(name, box, tile.size)


if __name__ == "__main__":
    main()
