"""Build Egg Drop's PLACEHOLDER Pocket Deck round music (numpy synthesis, deterministic).

Spencer (2026-11-13): "the deck gets its own music". Until his track lands this
is a short, calm, loopable chip-lullaby: soft triangle bass, a warm two-voice
pad and a sparse pentatonic bell melody at 84 BPM, 8 bars (about 22.9 s).
Every note tail wraps around the loop end, so the file is circular.

Output: assets/audio/placeholder/egg_drop_deck_music.wav (44.1 kHz, mono,
16-bit) and an .ogg (ffmpeg, if found). It does NOT touch manifest.json or
PLACEHOLDER-AUDIO.md (their deck_music entries were added by hand; keep the
assetId when re-running). Never run build_placeholder_audio.py for this: it
rewrites the manifest from scratch.

    python scripts/build_deck_music_placeholder.py [--no-ogg]
"""

import argparse
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
CUE = "deck_music"
LEVEL = (-24.0, -9.0)  # file RMS / peak ceiling; the runtime voice volume keeps it under the SFX
BPM = 84
BEAT = 60 / BPM
BARS = 8
TOTAL = BARS * 4 * BEAT

# I - vi - IV - V style progression in C major pentatonic colours, two bars each half.
CHORDS = [("C3", "E4", "G4"), ("A2", "C4", "E4"), ("F2", "A3", "C4"), ("G2", "B3", "D4"),
          ("C3", "E4", "G4"), ("A2", "C4", "E4"), ("F2", "A3", "C4"), ("G2", "D4", "G4")]
# (beat offset inside the 32-beat loop, note, length in beats)
MELODY = [(0, "E5", 1.5), (2, "G5", 1), (3, "A5", 1), (4.5, "G5", 1.5), (6, "E5", 2),
          (8, "C5", 1.5), (10, "D5", 1), (11, "E5", 1), (12.5, "D5", 3),
          (16, "E5", 1.5), (18, "G5", 1), (19, "C6", 1), (20.5, "A5", 1.5), (22, "G5", 2),
          (24, "E5", 1), (25, "D5", 1), (26, "C5", 2), (28.5, "D5", 1), (29.5, "C5", 2.5)]


def add_wrapped(out, at_seconds, sig, gain=1.0):
    idx = (int(round(at_seconds * SR)) + np.arange(len(sig))) % len(out)
    np.add.at(out, idx, gain * sig)


def soft_env(seconds, attack, release):
    t = base.t_of(seconds)
    e = np.minimum(1, t / max(attack, 1 / SR))
    tail = np.clip((seconds - t) / max(release, 1 / SR), 0, 1)
    return e * tail


def build():
    n = base.n_of(TOTAL)
    out = np.zeros(n)
    for bar, (root, a, b) in enumerate(CHORDS):
        start = bar * 4 * BEAT
        # Bass: root on beat 1, fifth-ish octave on beat 3, soft triangle.
        for k, beat in enumerate((0, 2)):
            f = base.note_hz(root) * (1 if k == 0 else 2)
            dur = BEAT * 1.9
            sig = base.osc(f, dur, wave_="tri") * base.env(dur, attack=0.01, decay=0.6)
            add_wrapped(out, start + beat * BEAT, base.lp(sig, 900, 1), 0.55)
        # Pad: two sustained voices with slow swell, slightly detuned.
        dur = 4 * BEAT + 0.4
        for note in (a, b):
            f = base.note_hz(note)
            t = base.t_of(dur)
            sig = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.003 * t)
                   + 0.12 * np.sin(4 * np.pi * f * t))
            add_wrapped(out, start, sig * soft_env(dur, 0.5, 0.6), 0.16)
    for beat, note, length in MELODY:
        dur = length * BEAT + 0.6
        sig = base.bell(base.note_hz(note), dur, detune=0.0015, bright=0.45, decay=length * BEAT * 0.6)
        add_wrapped(out, beat * BEAT, sig, 0.32)
    # A tiny off-beat shaker keeps it moving without a drum kit.
    rng = base.rng_for(CUE)
    for i in range(BARS * 4):
        dur = 0.06
        hit = base.hp(rng.uniform(-1, 1, base.n_of(dur)), 5000) * np.exp(-base.t_of(dur) / 0.015)
        add_wrapped(out, (i + 0.5) * BEAT, hit, 0.05 if i % 2 else 0.035)
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-ogg", action="store_true")
    args = parser.parse_args()
    x = build()
    x = x - np.mean(x)
    rms_db, peak_db = LEVEL
    x *= 10 ** (rms_db / 20) / np.sqrt(np.mean(x ** 2))
    peak = np.max(np.abs(x))
    if peak > 10 ** (peak_db / 20):
        x *= 10 ** (peak_db / 20) / peak
    wav = OUT / f"egg_drop_{CUE}.wav"
    y = base.write_wav(wav, x)
    seam = abs(y[0] - y[-1])
    inside = float(np.max(np.abs(np.diff(y))))
    assert seam <= inside, f"loop seam clicks ({seam:.4f} > {inside:.4f})"
    peak = float(np.max(np.abs(y)))
    rms = float(np.sqrt(np.mean(y ** 2)))
    ffmpeg = None if args.no_ogg else shutil.which("ffmpeg")
    if ffmpeg:
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis",
                        "-q:a", "6", "-map_metadata", "-1", str(wav.with_suffix(".ogg"))], check=True)
    print(f"{CUE}: {len(y) / SR:.3f} s, peak {20 * math.log10(peak):.1f} dBFS, "
          f"rms {20 * math.log10(rms):.1f} dBFS, seam {seam:.4f} <= {inside:.4f}, ogg {'yes' if ffmpeg else 'no'}")


if __name__ == "__main__":
    main()
