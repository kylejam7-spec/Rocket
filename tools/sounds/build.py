"""Builds the game's sound files from the raw Kenney packs in Sounds/.

Each cue in MANIFEST is decoded, cut so its first audible sample is at t=0 (many
Kenney files open with 35-140 ms of silence, which you hear as lag after a
click), cut after its tail falls 60 dB under the peak, peak-normalised to -1 dBFS
and written as mono Ogg Vorbis to assets/sounds/<group>/<name>.ogg. Not MP3: MP3
encoders pad the start with up to ~50 ms of silence.

    python tools/sounds/build.py            # build every cue
    python tools/sounds/build.py --studio   # also copy them into Studio's content
                                            # folder for local playtests (see Sfx.luau)

Built files whose cue is no longer in MANIFEST are deleted.
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
NASA = "590189main_ringtone_131_launchNats.mp3"
PICKUP = "833635__nomagician__pickup-notification-videogame-ui-sound.mp3"

# group/name -> one of
#   "file under Sounds/"
#   ("file", "reverse"): played backwards, so a rising sweep falls, but keeping the
#       original's loudness over time so it still hits at once and fades out (a plain
#       reverse would swell in late);
#   {"layers": [...], "mode": "loop"?}: layers mixed together. A layer is {"file": ...}
#       with optional clip ([start, end] seconds of the file), fadein / fadeout
#       (seconds), gain (its peak), delay (seconds after the first layer starts), pitch
#       (a speed-up, like PlaybackSpeed), lowpass / highpass (Hz). Each layer is first
#       cut to its own first audible sample, so delays are exact. "loop" keeps the mix
#       whole with its end crossfaded into its start, so it repeats without a click.
# Volume, voices and in-game pitch live in Sfx.luau.
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
    # Short wooden knocks (~20 ms decay, 200-450 Hz): a soft thock, no metallic ring.
    # Fuel plays them lower in Sfx.
    "game/pickup": {"layers": [{"file": "kenney_impact-sounds/Audio/impactWood_light_000.ogg", "lowpass": 2500}]},
    "game/place": {"layers": [{"file": "kenney_impact-sounds/Audio/impactWood_medium_000.ogg", "lowpass": 2000}]},
    "game/full": "kenney_interface-sounds/Audio/bong_001.ogg",
    "game/drop": "kenney_impact-sounds/Audio/impactSoft_heavy_000.ogg",
    # Mixkit's coin jingle builds for ~200 ms; start at its first strong clink (90 ms)
    # so it lands with the coin.
    "game/coin": {"layers": [{"file": "mixkit-coins-sound-2003.wav", "clip": [0.085, 0.6], "fadein": 0.003}]},
    "game/gain": "kenney_interface-sounds/Audio/select_001.ogg",
    # A 0.31 s arpeggio that stops dead; the fade softens its end.
    "game/levelup": {"layers": [{"file": "609335__kenneth_cooney__levelup.wav", "fadeout": 0.03}]},
    "game/countdown": "kenney_digital-audio/Audio/tone1.ogg",
    # NASA's liftoff recording (public domain): 19 s of steady roar, nearly all under
    # 400 Hz. A steady 10 s of it loops, with a high-passed copy of itself on top so
    # its crackle carries on small speakers. Ignition is its first seconds swelling in
    # over a low thump.
    "game/engine": {"layers": [
        {"file": NASA, "clip": [5, 15], "highpass": 30},
        {"file": NASA, "clip": [5, 15], "highpass": 700, "gain": 0.35},
    ], "mode": "loop"},
    "game/ignition": {"layers": [
        {"file": NASA, "clip": [0, 2.4], "fadein": 0.05, "fadeout": 1.2, "highpass": 30},
        {"file": "kenney_sci-fi-sounds/Audio/lowFrequency_explosion_001.ogg", "gain": 0.7},
    ]},
    "game/liftoff": {"layers": [
        {"file": "kenney_sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg"},
        {"file": "kenney_sci-fi-sounds/Audio/explosionCrunch_000.ogg", "pitch": 0.55, "lowpass": 900, "gain": 0.6},
    ]},
    # UFO pet delivery (Kenney sci-fi). The UFO swoops in on a rising sweep; its tractor
    # beam powers up (forceField_002 climbs ~750 -> 1,150 Hz) over a soft warbling hum;
    # the pet pops out with a retro zap on a low thump; the UFO zooms off on a falling
    # laser played backwards (so it rises away).
    "pet/arrive": {"layers": [
        {"file": "kenney_sci-fi-sounds/Audio/laserSmall_003.ogg", "pitch": 0.7, "lowpass": 5000},
        {"file": "kenney_sci-fi-sounds/Audio/forceField_001.ogg", "gain": 0.35, "delay": 0.12},
    ]},
    "pet/beam": {"layers": [
        {"file": "kenney_sci-fi-sounds/Audio/forceField_002.ogg"},
        {"file": "kenney_sci-fi-sounds/Audio/engineCircular_002.ogg", "clip": [0, 1.6], "fadein": 0.25, "fadeout": 0.7,
         "lowpass": 2500, "gain": 0.3},
    ]},
    "pet/pop": {"layers": [
        {"file": "kenney_sci-fi-sounds/Audio/laserRetro_001.ogg", "pitch": 1.25},
        {"file": "kenney_sci-fi-sounds/Audio/lowFrequency_explosion_001.ogg", "gain": 0.55},
        {"file": "kenney_sci-fi-sounds/Audio/slime_000.ogg", "gain": 0.25, "delay": 0.04, "highpass": 400},
    ]},
    "pet/zip": ("kenney_sci-fi-sounds/Audio/laserSmall_002.ogg", "reverse"),
    # Rarity fanfares after the pop: nomagician's pickup notification (freesound 833635,
    # CC0, supplied by the user; a bright two-note chime around 1-2 kHz), climbing with rarity. Uncommon
    # plays it as is; Rare a whole tone up with a fifth above it; Epic a major third up
    # with its fifth; Legendary three entries rising (root, third, fifth) over a deep
    # boom. Common has none.
    "pet/fanfare2": {"layers": [{"file": PICKUP}]},
    "pet/fanfare3": {"layers": [
        {"file": PICKUP, "pitch": 1.122},
        {"file": PICKUP, "pitch": 1.682, "gain": 0.45, "delay": 0.12},
    ]},
    "pet/fanfare4": {"layers": [
        {"file": PICKUP, "pitch": 1.26},
        {"file": PICKUP, "pitch": 1.888, "gain": 0.5, "delay": 0.13},
    ]},
    "pet/fanfare5": {"layers": [
        {"file": PICKUP},
        {"file": PICKUP, "pitch": 1.26, "gain": 0.8, "delay": 0.16},
        {"file": PICKUP, "pitch": 1.498, "gain": 0.85, "delay": 0.32},
        {"file": "kenney_sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg", "gain": 0.5},
    ]},
}

ONSET_DB = -40  # first sample this far under the peak counts as the start
TAIL_DB = -60   # the end is where the 5 ms envelope stays this far under the peak
LEAD = 24       # samples kept before the onset (0.5 ms), faded in
FADE_OUT = 0.02
CROSSFADE = 0.3  # seconds of a loop's end blended into its start


def decode(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def normalize(x, peak=1.0):
    return x * (peak / np.abs(x).max())


def filtered(x, lowpass=None, highpass=None, order=2):
    """Zero-phase Butterworth-shaped low/high pass (applied in the frequency domain)."""
    if not lowpass and not highpass:
        return x
    n = len(x) + 8192  # padding, so the filter's tails don't wrap around
    spectrum = np.fft.rfft(x, n)
    f = np.fft.rfftfreq(n, 1 / RATE)
    gain = np.ones_like(f)
    if lowpass:
        gain /= np.sqrt(1 + (f / lowpass) ** (2 * order))
    if highpass:
        gain /= np.sqrt(1 + (highpass / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(spectrum * gain, n)[: len(x)]


def onset(x):
    return x[int(np.argmax(np.abs(x) >= np.abs(x).max() * 10 ** (ONSET_DB / 20))):]


def layered(layers):
    """The layers mixed."""
    parts = []
    for layer in layers:
        x = decode(os.path.join(SOURCE, layer["file"])).astype(np.float64)
        if layer.get("clip"):
            x = x[int(layer["clip"][0] * RATE): int(layer["clip"][1] * RATE)]
        x = onset(x)
        if layer.get("fadein"):
            n = min(len(x), int(layer["fadein"] * RATE))
            x[:n] *= np.linspace(0, 1, n)
        if layer.get("fadeout"):
            n = min(len(x), int(layer["fadeout"] * RATE))
            x[len(x) - n:] *= np.linspace(1, 0, n)
        if layer.get("pitch"):
            x = np.interp(np.arange(0, len(x) - 1, layer["pitch"]), np.arange(len(x)), x)
        x = filtered(x, layer.get("lowpass"), layer.get("highpass"))
        parts.append((int(layer.get("delay", 0) * RATE), normalize(x, layer.get("gain", 1.0))))
    y = np.zeros(max(at + len(x) for at, x in parts))
    for at, x in parts:
        y[at: at + len(x)] += x
    return y.astype(np.float32)


def loop(x):
    """x shortened by CROSSFADE, its last CROSSFADE blended over its start (equal power,
    for uncorrelated noise like an engine), so the end runs straight into the start."""
    n = int(CROSSFADE * RATE)
    t = np.linspace(0, np.pi / 2, n, endpoint=False)
    y = x[: len(x) - n].copy()
    y[:n] = x[:n] * np.sin(t) + x[len(x) - n:] * np.cos(t)
    return y * (10 ** (-1 / 20) / np.abs(y).max())


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
    # bitexact: a fixed stream serial and no encoder version, so an unchanged sound
    # rebuilds byte for byte and upload.py doesn't send it again.
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "6", "-fflags", "+bitexact", "-flags:a", "+bitexact", path],
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


def build(cue, source):
    """The finished samples for one cue and a line describing them."""
    if isinstance(source, dict):
        layers = source["layers"]
        name = " + ".join(os.path.basename(layer["file"]) for layer in layers)
        x = layered(layers)
        if source.get("mode") == "loop":
            y = loop(x)
            return y, f"{name} loop, {len(y) / RATE:.2f}s"
        y, _, _, after = process(x)
        return y, f"{name}, {after:.2f}s"
    source, mode = source if isinstance(source, tuple) else (source, None)
    x = decode(os.path.join(SOURCE, source))
    y, cut, before, after = process(reverse(x) if mode == "reverse" else x)
    name = os.path.basename(source) + (" reversed" if mode else "")
    return y, f"{name}, cut {cut * 1000:.1f} ms of lead-in, {before:.2f}s -> {after:.2f}s"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--studio", action="store_true", help="copy the built files into Studio's content folder")
    args = parser.parse_args()
    for cue, source in MANIFEST.items():
        y, line = build(cue, source)
        encode(y, os.path.join(OUTPUT, cue + ".ogg"))
        print(f"{cue:16s} {line}")
    for folder, _, files in os.walk(OUTPUT):
        for name in files:
            cue = os.path.relpath(os.path.join(folder, name), OUTPUT)[:-4].replace(os.sep, "/")
            if name.endswith(".ogg") and cue not in MANIFEST:
                os.remove(os.path.join(folder, name))
                print("removed", cue)
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
