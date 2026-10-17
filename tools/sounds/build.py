"""Builds the game's sound files from the raw Kenney packs in Sounds/.

Each cue in MANIFEST is decoded, cut so its first audible sample is at t=0 (many
Kenney files open with 35-140 ms of silence, which you hear as lag after a
click), cut after its tail falls 60 dB under the peak, peak-normalised to -1 dBFS
and written as mono Ogg Vorbis to assets/sounds/<group>/<name>.ogg. Not MP3: MP3
encoders pad the start with up to ~50 ms of silence.

    python tools/sounds/build.py            # build every cue
    python tools/sounds/build.py --studio   # also copy them into Studio's content
                                            # folder for local playtests (see Sfx.luau)

Needs ffmpeg on PATH and numpy.
"""
import argparse
import os
import shutil
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "Sounds")
OUTPUT = os.path.join(ROOT, "assets", "sounds")
RATE = 48000

# group/name -> source file under Sounds/, or (file, "reverse"): played backwards, so a
# rising sweep falls, but keeping the original's loudness over time so it still hits
# at once and fades out (a plain reverse would swell in late). Volume, pitch and
# voices live in Sfx.luau.
MANIFEST = {
    "ui/click": "kenney_interface-sounds/Audio/drop_002.ogg",
    "ui/hover": "kenney_ui-audio/Audio/rollover5.ogg",
    "ui/open": "kenney_interface-sounds/Audio/maximize_009.ogg",
    "ui/close": ("kenney_interface-sounds/Audio/maximize_009.ogg", "reverse"),
    "ui/toggle": "kenney_interface-sounds/Audio/toggle_002.ogg",
    "ui/tick": "kenney_interface-sounds/Audio/tick_002.ogg",
    "ui/error": "kenney_interface-sounds/Audio/error_004.ogg",
    "ui/confirm": "kenney_interface-sounds/Audio/confirmation_001.ogg",
    "ui/notify": "kenney_interface-sounds/Audio/pluck_001.ogg",
    "ui/jingle": "kenney_music-jingles/Audio/Hit jingles/jingles_HIT04.ogg",
}

ONSET_DB = -40  # first sample this far under the peak counts as the start
TAIL_DB = -60   # the end is where the 5 ms envelope stays this far under the peak
LEAD = 24       # samples kept before the onset (0.5 ms), faded in
FADE_OUT = 0.02


def decode(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def reverse(x):
    """x backwards, rescaled sample by sample to x's own smoothed envelope."""
    window = np.hanning(RATE // 100)  # 10 ms
    window /= window.sum()
    env = np.sqrt(np.convolve(x.astype(np.float64) ** 2, window, mode="same"))
    floor = env.max() * 10 ** (-60 / 20)
    y = x[::-1] / np.maximum(env[::-1], floor) * env
    return (y * (np.abs(x).max() / np.abs(y).max())).astype(np.float32)


def process(x):
    peak = float(np.abs(x).max())
    if peak <= 0:
        raise ValueError("silent file")
    onset = int(np.argmax(np.abs(x) >= peak * 10 ** (ONSET_DB / 20)))
    start = max(0, onset - LEAD)
    hop = RATE // 200
    frames = len(x) // hop
    env = np.sqrt((x[: frames * hop].reshape(frames, hop) ** 2).mean(axis=1))
    loud = np.nonzero(env >= peak * 10 ** (TAIL_DB / 20))[0]
    end = min(len(x), (int(loud[-1]) + 1) * hop + int(FADE_OUT * RATE)) if len(loud) else len(x)
    y = x[start:end] * (10 ** (-1 / 20) / peak)
    lead = onset - start
    if lead:
        y[:lead] *= np.linspace(0, 1, lead, endpoint=False)
    fade = min(len(y), int(FADE_OUT * RATE))
    y[len(y) - fade:] *= np.linspace(1, 0, fade)
    return y, start / RATE, len(x) / RATE, len(y) / RATE


def encode(y, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "6", path],
        input=y.astype(np.float32).tobytes(), check=True,
    )


def studio_content():
    """The newest Roblox Studio install's content/sounds folder, or None."""
    versions = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")
    installs = [os.path.join(versions, d) for d in os.listdir(versions)] if os.path.isdir(versions) else []
    installs = [d for d in installs if os.path.isfile(os.path.join(d, "RobloxStudioBeta.exe"))]
    if not installs:
        return None
    return os.path.join(max(installs, key=os.path.getmtime), "content", "sounds")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--studio", action="store_true", help="copy the built files into Studio's content folder")
    args = parser.parse_args()
    for cue, source in MANIFEST.items():
        source, mode = source if isinstance(source, tuple) else (source, None)
        x = decode(os.path.join(SOURCE, source))
        y, cut, before, after = process(reverse(x) if mode == "reverse" else x)
        encode(y, os.path.join(OUTPUT, cue + ".ogg"))
        print(f"{cue:12s} {os.path.basename(source) + (' reversed' if mode else ''):24s} cut {cut * 1000:5.1f} ms of lead-in, {before:.2f}s -> {after:.2f}s")
    if args.studio:
        content = studio_content()
        if not content:
            sys.exit("No Roblox Studio install found under %LOCALAPPDATA%/Roblox/Versions")
        target = os.path.join(content, "rocket")
        shutil.rmtree(target, ignore_errors=True)
        shutil.copytree(OUTPUT, target)
        print("Copied to", target)


if __name__ == "__main__":
    main()
