"""Render Egg Drop's original mono synth cues with the Python standard library."""

import argparse
import math
from pathlib import Path
import random
import struct
import wave

RATE = 24_000
ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def note(frequency, duration, *, end=None, voice="tri", volume=0.4):
    return frequency, end or frequency, duration, voice, volume


CUES = {
    "aim": [(0, note(560, 0.065, end=630, volume=0.24))],
    "drop": [(0, note(460, 0.105, end=285, volume=0.4)),
             (0.013, note(780, 0.045, end=530, voice="pulse", volume=0.12))],
    "land": [(0, note(176, 0.15, end=68, volume=0.64)),
             (0.013, note(340, 0.085, end=186, volume=0.2)),
             (0, note(95, 0.048, voice="noise", volume=0.11))],
    "bank": [(0, note(310, 0.11, end=158, volume=0.47)),
             (0.022, note(570, 0.08, end=370, voice="pulse", volume=0.16))],
    "merge_bubble": [(0, note(660, 0.045, end=310, voice="sine", volume=0.24)),
                     (0, note(250, 0.095, end=140, voice="sine", volume=0.45)),
                     (0.025, note(980, 0.043, end=510, voice="sine", volume=0.18)),
                     (0.054, note(610, 0.086, end=432, volume=0.19)),
                     (0.087, note(485, 0.052, end=315, voice="sine", volume=0.12))],
    "merge_jelly": [(0, note(191, 0.153, end=85, voice="sine", volume=0.55)),
                    (0.012, note(335, 0.1, end=160, voice="sine", volume=0.24)),
                    (0.034, note(220, 0.078, voice="noise", volume=0.15)),
                    (0.062, note(590, 0.038, end=320, voice="sine", volume=0.16)),
                    (0.096, note(476, 0.057, end=263, voice="sine", volume=0.17)),
                    (0.128, note(330, 0.115, end=204, volume=0.17))],
    "merge_chain": [(0.028, note(430, 0.11, end=570, voice="sine", volume=0.18)),
                    (0.073, note(580, 0.13, end=740, voice="sine", volume=0.19)),
                    (0.125, note(720, 0.084, end=620, voice="sine", volume=0.11))],
    "charge": [(0, note(880, 0.08, end=990, voice="pulse", volume=0.22))],
    "hatch_rise": [(0, note(300, 0.18, end=510, volume=0.24)),
                   (0.14, note(520, 0.21, end=770, volume=0.21))],
    "hatch": [(0, note(240, 0.13, end=96, volume=0.48)),
              (0, note(180, 0.052, voice="noise", volume=0.2)),
              (0.035, note(523.25, 0.25, volume=0.32)),
              (0.09, note(659.25, 0.28, voice="pulse", volume=0.22)),
              (0.145, note(783.99, 0.34, volume=0.27)),
              (0.20, note(1046.50, 0.32, volume=0.22))],
    "pet": [(0, note(660, 0.14, end=910, volume=0.43)),
            (0.12, note(845, 0.17, end=710, volume=0.35))],
    "puddle": [(0, note(185, 0.15, end=410, volume=0.43)),
               (0.096, note(520, 0.08, end=380, voice="pulse", volume=0.17)),
               (0.168, note(245, 0.20, end=126, volume=0.34))],
    "overflow": [(0, note(523.25, 0.16, voice="pulse", volume=0.23)),
                 (0.12, note(392, 0.18, voice="pulse", volume=0.25)),
                 (0.24, note(261.63, 0.25, volume=0.35))],
    "retry": [(0, note(392, 0.11, volume=0.23)),
              (0.075, note(523.25, 0.15, volume=0.31))],
    "menu": [(0, note(698.46, 0.075, end=783.99, volume=0.22))],
}


def synth(events, attack_seconds=0.006, decay=1.45):
    size = math.ceil(max(at + event[2] for at, event in events) * RATE)
    samples = [0.0] * size
    noise = random.Random(742)
    for at, (start, end, duration, voice, volume) in events:
        offset = round(at * RATE)
        count = min(round(duration * RATE), size - offset)
        phase, filtered = 0.0, 0.0
        for index in range(count):
            t = index / count
            phase = (phase + (start * (end / start) ** t) / RATE) % 1
            triangle = 1 - 4 * abs(phase - 0.5)
            if voice == "pulse":
                raw = (0.66 if phase < 0.34 else -0.34) * 0.75 + triangle * 0.25
            elif voice == "noise":
                raw = noise.uniform(-1, 1)
            elif voice == "sine":
                raw = math.sin(phase * math.tau)
            else:
                raw = triangle
            filtered += (raw - filtered) * (0.23 if voice == "noise" else 0.62)
            attack = min(1, index / (attack_seconds * RATE))
            tail = min(1, (count - index - 1) / (0.014 * RATE))
            envelope = attack * tail * (1 - t) ** decay
            samples[offset + index] += filtered * envelope * volume
    return samples


def write_wav(path, samples):
    with wave.open(str(path), "wb") as handle:
        handle.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        pcm = [round(32767 * max(-1, min(1, sample))) for sample in samples]
        handle.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, help="Optional combined audition WAV")
    args = parser.parse_args()
    ROOT.mkdir(parents=True, exist_ok=True)
    preview = []
    for name, events in CUES.items():
        samples = synth(events)
        write_wav(ROOT / f"egg_drop_{name}.wav", samples)
        if args.preview:
            preview.extend(samples)
            preview.extend([0.0] * round(RATE * 0.36))
    if args.preview:
        write_wav(args.preview, preview)


if __name__ == "__main__":
    main()
