"""Stars purchase cue, synthesised from scratch (BRIGHT-PREVIEWS-AND-PURCHASE-SOUND-PLAN-2026-11-22).

Proposal audio for review: nothing here is uploaded or wired. Two candidates for the
`stars_bought` cue, built only from sine partials and shaped white noise in numpy, with the
same helpers as the hatch rarity stings (scripts/synth_hatch_rarity.py). No samples, no
recordings, no AI audio, no borrowed melody. Fixed seeds make every run byte-identical.

  stars_bought_a  "shower, then home"  1.20 s
      Five glass notes fall like Stars dropping into a jar (E7 C7 D7 A6 G6, each a little
      later than even, each with a faint glass tick), a warm C major chord lands under them
      at 0.42 s (C5 G5 E6 with a soft C4 body), and one high C7 glint answers at 0.64 s.
      Falls, lands, then lifts: the last thing heard goes up.
  stars_bought_b  "bounce up, ta-daa"  1.10 s
      Four glass notes climb and quicken (C6 E6 G6 C7), a thin cloud of glitter opens over
      them, and a two-step warm finish answers: G5+D6 at 0.36 s, then C5+C6+E6 at 0.50 s.

Both stay in C major pentatonic so they sit in the family of the rarity chimes and the
snack sparkle, with no pop (the pop belongs to hatching) and no fast even trill (that is
what makes a payout sound like a slot machine): six landings at most, unevenly spaced.

Run from the repository root:  python scripts/synth_stars_bought.py
Writes: artifacts/bright-previews-2026-11-22/stars_bought_a.wav, stars_bought_b.wav
        (44.1 kHz, 16-bit, mono) and stars_bought_report.json
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth_hatch_rarity as H  # shared helpers: tone, decay, band_noise, bell, harp, glitter, reverb, finish

OUT = os.path.join(H.ROOT, "artifacts", "bright-previews-2026-11-22")
SR = H.SR
NOTE = dict(H.NOTE)
NOTE["C4"] = NOTE["C5"] / 2
NOTE["G4"] = NOTE["G5"] / 2
SUGGESTED_VOLUME = 0.70   # Sound.Volume for BoardAudio:play("stars_bought", 1, .7)


def glass(freq, seconds, tau, sheen=1.0):
    """A struck-glass note: the house bell, plus a quick high partial for the 'tink' and a
    second voice a few cents away so the ring shimmers instead of sitting still."""
    out = H.bell(freq, seconds, tau, bright=1.1, detune=6)
    top = freq * 4.07
    if top < SR * 0.45:
        out += 0.07 * sheen * H.tone(top, seconds) * H.decay(seconds, tau * 0.10, 0.0008)
    return out


def tick(rng, gain=1.0):
    """The tiny dry contact of a Star landing: 5 ms of bright noise."""
    return gain * H.band_noise(rng, 0.005, 5000, 12000) * H.decay(0.005, 0.0012, 0.0002)


def warm(names, seconds, tau):
    """The finish: soft plucked strings with a round bell on top of each, no glint."""
    out = H.buf(seconds)
    for name, gain in names:
        f = NOTE[name]
        out += gain * (H.harp(f, seconds, tau) + 0.45 * H.bell(f, seconds, tau * 0.9, bright=0.25, detune=-5))
    return out


def candidate_a(rng):
    x = H.buf(1.20)
    # The shower: falling, a little uneven, getting softer as the jar fills.
    for name, at, gain, tau in (("E7", 0.000, 0.40, 0.10), ("C7", 0.082, 0.38, 0.11), ("D7", 0.158, 0.34, 0.11),
                                ("A6", 0.246, 0.36, 0.13), ("G6", 0.318, 0.38, 0.16)):
        H.add(x, glass(NOTE[name], 0.60, tau), at, gain)
        H.add(x, tick(rng), at, 0.05)
    # Home: a warm chord under the last landing, rolled upward over 24 ms.
    for i, (name, gain) in enumerate((("C4", 0.07), ("C5", 0.21), ("G5", 0.20), ("E6", 0.22))):
        H.add(x, warm([(name, 1.0)], 0.76, 0.30), 0.420 + i * 0.008, gain)
    # The answer: one glint above everything, so the cue ends looking up.
    H.add(x, glass(NOTE["C7"], 0.55, 0.20, sheen=0.6), 0.640, 0.26)
    H.add(x, H.glitter(rng, 0.30, 4), 0.66, 0.10)
    return H.finish(H.reverb(x, 0.14, 0.8, 0.72), peak_db=-3.0, release=0.25)


def candidate_b(rng):
    x = H.buf(1.10)
    # The bounce: up the chord, each step sooner than the last.
    for name, at, gain, tau in (("C6", 0.000, 0.36, 0.11), ("E6", 0.110, 0.36, 0.11), ("G6", 0.200, 0.38, 0.12),
                                ("C7", 0.270, 0.42, 0.18)):
        H.add(x, glass(NOTE[name], 0.60, tau), at, gain)
        H.add(x, tick(rng), at, 0.05)
    H.add(x, H.glitter(rng, 0.45, 6), 0.28, 0.13)
    # Ta-daa: a fifth hanging open, then home.
    H.add(x, warm([("G5", 0.20), ("D6", 0.18)], 0.40, 0.14), 0.360, 1.0)
    for i, (name, gain) in enumerate((("C4", 0.06), ("C5", 0.20), ("C6", 0.20), ("E6", 0.22))):
        H.add(x, warm([(name, 1.0)], 0.58, 0.26), 0.500 + i * 0.007, gain)
    return H.finish(H.reverb(x, 0.14, 0.8, 0.72), peak_db=-3.0, release=0.25)


def measure(x):
    """What a reviewer without ears needs: level, brightness, and proof of clean edges."""
    q = (np.clip(x, -1, 1) * 32767).round()
    d = H.describe(x)
    win = int(0.010 * SR)
    env = np.array([math.sqrt(float(np.mean(x[i:i + win] ** 2))) for i in range(0, len(x) - win, win)])
    return {
        "seconds": d["seconds"], "peak_dbfs": d["peak_dbfs"], "rms_dbfs": d["rms_dbfs"],
        "loudest_50ms_dbfs": d["loudest_50ms_dbfs"], "centroid_hz": d["centroid_hz"],
        "above_4khz_share": d["above_4khz_share"],
        "clipped_samples": int(np.sum(np.abs(q) >= 32767)),
        "first_sample_16bit": int(q[0]), "last_sample_16bit": int(q[-1]),
        "last_10ms_peak_dbfs": round(20 * math.log10(float(np.max(np.abs(x[-win:]))) + 1e-9), 1),
        "largest_sample_step": round(float(np.max(np.abs(np.diff(x)))), 4),
        "loudest_10ms_at_s": round(float(np.argmax(env)) * 0.010, 2),
        "at_suggested_volume": {"volume": SUGGESTED_VOLUME,
                                "peak_dbfs": round(d["peak_dbfs"] + 20 * math.log10(SUGGESTED_VOLUME), 2),
                                "rms_dbfs": round(d["rms_dbfs"] + 20 * math.log10(SUGGESTED_VOLUME), 2)},
    }


def main():
    os.makedirs(OUT, exist_ok=True)
    made = {"stars_bought_a": candidate_a(np.random.default_rng(2211)),
            "stars_bought_b": candidate_b(np.random.default_rng(2212))}
    report = {"sample_rate": SR, "bit_depth": 16, "channels": 1, "sounds": {}}
    for name, x in made.items():
        H.write_wav(os.path.join(OUT, name + ".wav"), x)
        report["sounds"][name] = measure(x)
    with open(os.path.join(OUT, "stars_bought_report.json"), "w", newline="\n") as fh:
        json.dump(report, fh, indent=1)
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
