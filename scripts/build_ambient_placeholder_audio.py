"""Build Egg Drop's PLACEHOLDER ambient audio (numpy synthesis, deterministic).

The "feel alive" set (FEEL-ALIVE-DIRECTION-2026-11-13.md): a soft brook bed, a
fuller waterfall loop, six bird chirps, three pet coos and one machine attract
ping. Same primitives, format and loudness rules as build_placeholder_audio.py;
Spencer's own audio replaces every file.

Output: assets/audio/placeholder/egg_drop_<cue>.wav (44.1 kHz, mono, 16-bit),
an .ogg encode of each (ffmpeg, if found) and merged entries in manifest.json.
Entries of other cues (and every assetId) are left exactly as they are.
Re-running gives byte-identical WAVs.

    python scripts/build_ambient_placeholder_audio.py [--no-ogg]
"""

import argparse
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_placeholder_audio as base  # noqa: E402

SR = base.SR
OUT = base.OUT
n_of, t_of, rng_for, env, lp, hp, mix, bell = (base.n_of, base.t_of, base.rng_for, base.env,
                                               base.lp, base.hp, base.mix, base.bell)

# Ambient levels sit under the SFX set: beds are felt, not heard as a track.
LEVELS = dict(base.LEVELS)
LEVELS.update({
    "bed": (-31.0, -14.0),     # same RMS as shimmer_loop
    "falls": (-27.0, -10.0),   # positional source, attenuated by distance in game
    "bird": (-24.0, -8.0),
    "coo": (-22.0, -8.0),
})
base.LEVELS = LEVELS


# ---------------------------------------------------------------- loop helpers
def periodic_noise(rng, n, shape):
    """Circular noise: random phases under a spectral shape (freqs -> gain)."""
    freqs = np.fft.rfftfreq(n, 1 / SR)
    mag = shape(freqs)
    spec = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
    spec[0] = 0
    x = np.fft.irfft(spec, n)
    return x / np.max(np.abs(x))


def band_shape(lo, hi, tilt=0.0, soft=0.35):
    """Smooth band with log-domain skirts; tilt in dB per octave above lo."""
    def shape(f):
        f = np.maximum(f, 1.0)
        up = 1 / (1 + (lo / f) ** (2 / soft))
        down = 1 / (1 + (f / hi) ** (2 / soft))
        return up * down * 10 ** (tilt * np.log2(f / lo) / 20)
    return shape


def cyclic_lfo(rng, n, cycles, depth):
    """Sum of sines with whole cycles per loop, so modulation wraps cleanly."""
    t = np.arange(n) / n
    out = np.zeros(n)
    for c in cycles:
        out += np.sin(2 * np.pi * (c * t + rng.uniform()))
    return 1 + depth * out / len(cycles)


def add_wrapped(out, at, sig, gain=1.0):
    idx = (int(at) + np.arange(len(sig))) % len(out)
    np.add.at(out, idx, gain * sig)


def bubble(rng, f0=None, dur=None):
    """One water 'bloop': a short sine that glides up while it dies."""
    f0 = f0 or rng.uniform(420, 1500)
    dur = dur or rng.uniform(0.035, 0.11)
    t = t_of(dur)
    f = f0 * (1 + rng.uniform(0.25, 0.9) * (t / dur) ** 1.5)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.6 * np.exp(-t / (dur * 0.45))


def c_water_bed_loop(name):
    """Seamless 10 s brook: soft mid hiss, slow swells, scattered bloops."""
    rng = rng_for(name)
    n = n_of(10.0)
    hiss = periodic_noise(rng, n, band_shape(500, 3200, tilt=-4.5))
    hiss *= cyclic_lfo(rng, n, (1, 3, 7), 0.22)
    trickle = periodic_noise(rng, n, band_shape(1800, 5200, tilt=-6))
    trickle *= np.clip(cyclic_lfo(rng, n, (2, 5, 11, 23), 0.9) - 0.55, 0, None)
    low = periodic_noise(rng, n, band_shape(140, 420, tilt=-3))
    out = 0.75 * hiss + 0.35 * trickle + 0.3 * low
    blips = np.zeros(n)
    for _ in range(150):
        add_wrapped(blips, rng.integers(0, n), bubble(rng), rng.uniform(0.15, 0.6))
    for _ in range(18):  # a few rounder plops
        add_wrapped(blips, rng.integers(0, n), bubble(rng, rng.uniform(260, 520), rng.uniform(0.09, 0.16)),
                    rng.uniform(0.35, 0.7))
    return out + 0.33 * blips / np.max(np.abs(blips)) * np.max(np.abs(out))


def c_waterfall_loop(name):
    """Seamless 10 s falls: wide steady rush, low body, light spray flutter."""
    rng = rng_for(name)
    n = n_of(10.0)
    rush = periodic_noise(rng, n, band_shape(220, 6500, tilt=-3.2))
    rush *= cyclic_lfo(rng, n, (1, 2, 5), 0.08)
    body = periodic_noise(rng, n, band_shape(70, 300, tilt=-2))
    body *= cyclic_lfo(rng, n, (3, 4, 9), 0.25)
    spray = periodic_noise(rng, n, band_shape(3500, 9000, tilt=-5))
    spray *= cyclic_lfo(rng, n, (13, 17, 29), 0.5)
    out = rush + 0.55 * body + 0.22 * spray
    blips = np.zeros(n)
    for _ in range(90):
        add_wrapped(blips, rng.integers(0, n), bubble(rng, rng.uniform(300, 900)), rng.uniform(0.2, 0.5))
    return out + 0.1 * blips / np.max(np.abs(blips)) * np.max(np.abs(out))


# ---------------------------------------------------------------- birds
def whistle(freqs, seconds, vib=0.0, vib_rate=28.0, attack=0.008, breath=0.0, rng=None, h2=0.12):
    """A bird note: freqs is an array (Hz per sample) or (f0, f1)."""
    n = n_of(seconds)
    t = np.arange(n) / SR
    if isinstance(freqs, tuple):
        f = freqs[0] * (freqs[1] / freqs[0]) ** (t / max(seconds, 1e-6))
    else:
        f = np.asarray(freqs)[:n]
    if vib:
        f = f * (1 + vib * np.sin(2 * np.pi * vib_rate * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) + h2 * np.sin(2 * phase)
    shape = np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 0.7
    shape *= np.clip(t / attack, 0, 1)
    if breath and rng is not None:
        x = x + breath * hp(rng.uniform(-1, 1, n), 3000) * shape
    return x * shape


def c_bird_chirp_1(name):
    """Two-note 'tsee-wit': a high slide down, then a short flick up."""
    return mix(0.42, (0.0, whistle((3900, 3100), 0.15), 1.0), (0.21, whistle((2900, 4100), 0.11), 0.85))


def c_bird_chirp_2(name):
    """Fast trill: eight tiny rising pips that speed up and fade."""
    parts, at = [], 0.0
    for k in range(8):
        d = 0.045 - k * 0.002
        parts.append((at, whistle((4300 + k * 40, 5200 + k * 40), d, attack=0.003), 1.0 - k * 0.08))
        at += d + 0.022 - k * 0.0015
    return mix(at + 0.03, *parts)


def c_bird_chirp_3(name):
    """Single falling whistle 'peeeu' with a soft warble at the tail."""
    s = 0.46
    t = t_of(s)
    f = 3300 * (2300 / 3300) ** ((t / s) ** 0.7)
    f = f * (1 + 0.035 * np.sin(2 * np.pi * 22 * t) * np.clip((t - 0.2) / 0.2, 0, 1))
    return whistle(f, s, breath=0.03, rng=rng_for(name))


def c_bird_chirp_4(name):
    """Cheerful triple 'chip-chip-cheep': two pips and a longer rise."""
    return mix(0.52, (0.0, whistle((3400, 4000), 0.07, attack=0.004), 0.8),
               (0.12, whistle((3500, 4200), 0.07, attack=0.004), 0.9),
               (0.25, whistle((3300, 4700), 0.2), 1.0))


def c_bird_chirp_5(name):
    """Liquid warble: one long note with a deep, slowing wobble."""
    s = 0.6
    t = t_of(s)
    rate = 34 - 16 * (t / s)
    wob = np.sin(2 * np.pi * np.cumsum(rate) / SR)
    f = (2700 + 500 * (t / s)) * (1 + 0.11 * wob)
    return whistle(f, s, h2=0.08)


def c_bird_chirp_6(name):
    """Low sleepy 'hoo-hoo' for dusk and night: two round, breathy notes."""
    rng = rng_for(name)
    a = lp(whistle((760, 690), 0.26, attack=0.03, breath=0.05, rng=rng, h2=0.3), 2400)
    b = lp(whistle((720, 640), 0.34, attack=0.03, breath=0.05, rng=rng, h2=0.3), 2400)
    return mix(0.78, (0.0, a, 0.9), (0.4, b, 1.0))


# ---------------------------------------------------------------- pet coos
def voice(f, seconds, bright=0.3, attack=0.03, tail=0.5):
    """Soft vowel: a pitch curve with gentle harmonics and a rounded envelope."""
    n = n_of(seconds)
    t = np.arange(n) / SR
    f = np.asarray(f)[:n] * (1 + 0.012 * np.sin(2 * np.pi * 6.5 * t) * np.clip(t / 0.12, 0, 1))
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) + bright * np.sin(2 * phase) + bright * 0.4 * np.sin(3 * phase)
    u = t / seconds
    shape = np.clip(t / attack, 0, 1) * np.where(u < tail, 1.0, np.cos(np.clip((u - tail) / (1 - tail), 0, 1) * np.pi / 2) ** 1.5)
    return lp(x * shape, 2600)


def c_pet_coo_1(name):
    """Curious rising 'oo?': small scoop down, then up a fourth."""
    s = 0.34
    u = t_of(s) / s
    f = 560 - 40 * np.sin(np.pi * np.clip(u / 0.3, 0, 1)) + 210 * np.clip((u - 0.25) / 0.75, 0, 1) ** 1.3
    return voice(f, s, bright=0.28)


def c_pet_coo_2(name):
    """Happy two-syllable 'ah-oo': a short high note, then a lower rounder one."""
    a = t_of(0.14) / 0.14
    b = t_of(0.3) / 0.3
    first = voice(700 + 60 * np.sin(np.pi * a), 0.14, bright=0.4, attack=0.015, tail=0.55)
    second = voice(600 - 90 * b + 30 * np.sin(np.pi * b), 0.3, bright=0.22, tail=0.4)
    return mix(0.5, (0.0, first, 0.9), (0.17, second, 1.0))


def c_pet_coo_3(name):
    """Sleepy 'mmm-m': low, slow fall with a tiny hum bump at the end."""
    s = 0.52
    u = t_of(s) / s
    f = 470 - 95 * u ** 0.8 + 22 * np.sin(np.pi * np.clip((u - 0.62) / 0.3, 0, 1))
    return voice(f, s, bright=0.16, attack=0.05, tail=0.35)


# ---------------------------------------------------------------- machines
def c_machine_attract(name):
    """Gentle sparkle ping: two soft bells a fifth apart and a little glitter."""
    rng = rng_for(name)
    s = 0.9
    a = bell(base.note_hz("E6"), 0.7, detune=0.002, bright=0.7, decay=0.2)
    b = bell(base.note_hz("B6"), 0.6, detune=0.002, bright=0.6, decay=0.18)
    return mix(s, (0.0, a, 0.8), (0.09, b, 0.6)) + base.sparkle(rng, s, 6, lo=3800, hi=7000, start=0.1, gain=0.07)


CUES = {
    # cue: (builder, level, loop, where it plays, short description)
    "water_bed_loop": (c_water_bed_loop, "bed", True,
                       "Garden ambience: global brook bed, heard everywhere (not wired)",
                       "seamless 10 s soft brook: mid hiss, slow swells, scattered bloops"),
    "waterfall_loop": (c_waterfall_loop, "falls", True,
                       "Positional loop at Tumble Falls and Sky Falls (not wired)",
                       "seamless 10 s fuller rush with low body and light spray"),
    "bird_chirp_1": (c_bird_chirp_1, "bird", False, "Bird ambience from tree canopies, day (not wired)",
                     "two-note 'tsee-wit': slide down, flick up"),
    "bird_chirp_2": (c_bird_chirp_2, "bird", False, "Bird ambience, day (not wired)", "fast eight-pip trill"),
    "bird_chirp_3": (c_bird_chirp_3, "bird", False, "Bird ambience, day and dusk (not wired)",
                     "single falling whistle with a warbled tail"),
    "bird_chirp_4": (c_bird_chirp_4, "bird", False, "Bird ambience, day (not wired)",
                     "cheerful 'chip-chip-cheep'"),
    "bird_chirp_5": (c_bird_chirp_5, "bird", False, "Bird ambience, day (not wired)",
                     "liquid warble that slows down"),
    "bird_chirp_6": (c_bird_chirp_6, "bird", False, "Bird ambience, dusk and night only (not wired)",
                     "low sleepy 'hoo-hoo'"),
    "pet_coo_1": (c_pet_coo_1, "coo", False, "Pet coo: curious / look-around beat (not wired)",
                  "rising 'oo?'"),
    "pet_coo_2": (c_pet_coo_2, "coo", False, "Pet coo: happy / greeting / after petting (not wired)",
                  "two-syllable 'ah-oo'"),
    "pet_coo_3": (c_pet_coo_3, "coo", False, "Pet coo: sleepy / sit / yawn tail (not wired)",
                  "low falling 'mmm-m'"),
    "machine_attract": (c_machine_attract, "ui", False,
                        "Station attract: walking into range of an unused machine (not wired)",
                        "two soft bells a fifth apart with glitter"),
}


def crossfade_check(y):
    """Largest sample step across the loop seam, relative to the largest step inside."""
    seam = abs(y[0] - y[-1])
    inside = float(np.max(np.abs(np.diff(y))))
    return seam, inside


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-ogg", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    ffmpeg = None if args.no_ogg else shutil.which("ffmpeg")
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else []
    by_cue = {entry["cue"]: entry for entry in manifest}
    print(f"{'cue':16s} {'sec':>6s} {'peak':>7s} {'rms':>7s} {'seam':>7s}  ogg")
    for cue, (build, level, loop, where, desc) in CUES.items():
        x = base.finish(build(cue), level, loop)
        wav = OUT / f"egg_drop_{cue}.wav"
        y = base.write_wav(wav, x)
        peak = float(np.max(np.abs(y)))
        rms = float(np.sqrt(np.mean(y ** 2)))
        assert peak < 1.0, f"{cue} clips"
        seam_s = "-"
        if loop:
            seam, inside = crossfade_check(y)
            assert seam <= inside, f"{cue} loop seam clicks ({seam:.4f} > {inside:.4f})"
            seam_s = f"{seam:.4f}"
        ogg_name = None
        if ffmpeg:
            ogg = wav.with_suffix(".ogg")
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis",
                            "-q:a", "6", "-map_metadata", "-1", str(ogg)], check=True)
            ogg_name = ogg.name
        seconds = round(len(y) / SR, 3)
        entry = by_cue.get(cue)
        if entry is None:
            entry = {"cue": cue}
            manifest.append(entry)
            by_cue[cue] = entry
        # Update in place: an assetId added after upload survives a rebuild.
        entry.update({"file": wav.name, "ogg": ogg_name, "seconds": seconds, "loop": loop,
                      "peak_dbfs": round(20 * math.log10(peak), 1),
                      "rms_dbfs": round(20 * math.log10(rms), 1),
                      "where": where, "description": desc, "placeholder": True})
        print(f"{cue:16s} {seconds:6.3f} {20*math.log10(peak):7.1f} {20*math.log10(rms):7.1f} {seam_s:>7s}  "
              f"{'yes' if ogg_name else 'no'}")
    manifest_path.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    print(f"\n{len(CUES)} ambient placeholder cues -> {OUT} (manifest now {len(manifest)} entries)")


if __name__ == "__main__":
    main()
