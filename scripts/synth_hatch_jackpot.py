"""Rare jackpot layer for the v2 hatch, synthesised from scratch (V2-HATCH-REDESIGN-2026-11-19, Revision 1).

Proposal audio for review: nothing here is uploaded or wired. One new layer that plays WITH the
approved Rare sting (assets/audio/custom/egg_drop_rarity_rare.wav, untouched) on the Rare jackpot
moment. Built only from sine partials and shaped white noise in numpy, with the helpers from
scripts/synth_hatch_rarity.py. No samples, no recordings, no AI audio. Fixed seeds make every
run byte-identical.

Inside the file (seconds; HIT is the impact, which the game lands on the Rare burst at 1.72 s):

  0.00 to 0.93  riser      two gliding voices (C5 to C7, a fifth apart), a pentatonic tick roll that
                           speeds from 10 to 34 ticks a second, and a breath of noise climbing in pitch
  0.93 to 1.05  the gap    the layer goes silent for 0.12 s (the slow-motion freeze); only the last
                           harp notes of the approved sting are heard
  1.05          impact     a low boom, the family pop with weight, a noise splash and a wide C chord
  1.05 to 3.30  shimmer    dense high pings and a soft airy tremolo, thinning out
  1.28, 1.40    cannons    two soft "poomf" puffs (the confetti cannons, left then right)
  1.27 to 1.63  fanfare    "da da-da DAAA": G5, C6, E6 pick-ups into a C major brass chord
  1.63          stamp      a short thud under the chord: the title stamp lands here (impact + 0.58)

Run from the repository root:  python scripts/synth_hatch_jackpot.py
Writes into artifacts/v2-hatch-redesign-2026-11-19/audio/ (wav and mp3; mp3 needs ffmpeg):
  rare-jackpot-layer            the new layer alone (44.1 kHz mono 16-bit, peak -1 dBFS)
  rare-jackpot-calm-layer       Reduced Motion version: no riser, no boom, no cannons, 6 dB quieter
  rare-jackpot-over-rare-cue    the layer mixed over the approved Rare sting, hits aligned
  rare-cue-alone-for-compare    the approved sting on the same timeline, for A/B
  report.json                   measurements, offsets and suggested gains
"""
import json
import math
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth_hatch_rarity as H  # shared helpers: tone, decay, band_noise, bell, pop, glitter, reverb, finish

ROOT = H.ROOT
SR = H.SR
NOTE = H.NOTE
OUT = os.path.join(ROOT, "artifacts", "v2-hatch-redesign-2026-11-19", "audio")
RARE_MASTER = os.path.join(H.MASTERS, "egg_drop_rarity_rare.wav")
HIT = 1.05            # the impact inside the jackpot layer
STAMP = 0.58          # impact to the title stamp (2.30 - 1.72 on the hatch clock)
BURST = 1.72          # Revision 1 Rare burst on the hatch clock
LENGTH = 3.45
GAIN = {"rare": 0.80, "jackpot": 0.72}   # suggested playback gains; their sum stays under full scale


def ramp(n):
    return np.arange(n) / max(1, n - 1)


def brass(freq, seconds, bright=1.0, vibrato=0.0):
    """A soft toy-brass note: ten harmonics, the upper ones swelling in a little after the attack
    (the 'blat'), all from sines. `vibrato` is depth in cents at 5.5 Hz, fading in."""
    n = int(round(seconds * SR))
    t = np.arange(n) / SR
    cents = vibrato * np.minimum(1, t / 0.25) * np.sin(2 * np.pi * 5.5 * t)
    phase = 2 * np.pi * np.cumsum(freq * 2 ** (cents / 1200)) / SR
    attack = np.minimum(1, t / 0.018)
    release = np.minimum(1, (seconds - t) / 0.06)
    out = np.zeros(n)
    for k in range(1, 11):
        if freq * k > SR * 0.45:
            break
        open_up = 1 - np.exp(-t / (0.012 + 0.006 * k))          # higher harmonics arrive later
        out += (bright ** (k - 1)) / k ** 1.15 * open_up * np.sin(k * phase + 0.3 * k)
    return out * attack * release


def riser(rng, seconds):
    """Everything that climbs into the gap. Ends on a fast fade so the freeze is really silent."""
    n = int(round(seconds * SR))
    u = ramp(n)
    out = np.zeros(n)
    # Two gliding voices a fifth apart, C5 to C7, with a tremolo that speeds up.
    glide = NOTE["C5"] * 4 ** (u ** 1.6)
    trem_rate = 7 + 21 * u ** 2
    trem = 0.72 + 0.28 * np.sin(2 * np.pi * np.cumsum(trem_rate) / SR)
    for ratio, amp in ((1.0, 1.0), (1.5, 0.55), (2.0, 0.22)):
        out += amp * H.tone(glide * ratio, seconds) * trem
    out *= 0.16 * u ** 1.5
    # A pentatonic tick roll, 10 to 34 ticks a second, climbing two octaves.
    scale = ["C6", "D6", "E6", "G6", "A6", "C7", "D7", "E7", "G7", "A7", "C8"]
    at, i = 0.02, 0
    while at < seconds - 0.03:
        w = at / seconds
        f = NOTE[scale[min(len(scale) - 1, int(w * len(scale)))]]
        tick = H.tone(f, 0.05) * H.decay(0.05, 0.012, 0.0008)
        tick += 0.25 * H.band_noise(rng, 0.05, 4000, 11000) * H.decay(0.05, 0.004, 0.0004)
        H.add(out, tick, at, 0.10 + 0.20 * w)
        at += 1 / (10 + 24 * w ** 1.5)
        i += 1
    # A breath of noise that climbs in pitch (three bands cross-faded, as in the Rare sting).
    low, mid, high = (H.band_noise(rng, seconds, a, b) for a, b in ((900, 2200), (2200, 5200), (5200, 12000)))
    breath = low * np.clip(1 - 2 * u, 0, 1) + mid * (1 - np.abs(2 * u - 1)) + high * np.clip(2 * u - 1, 0, 1)
    out += 0.20 * breath * u ** 2.2
    cut = int(0.025 * SR)
    out[-cut:] *= np.linspace(1, 0, cut) ** 2
    return out


def impact(rng):
    """The hit: a low boom that phones can still hear (a 55 Hz floor and a 150 Hz body), the family
    pop with weight, a bright splash and a wide C chord an octave under the sting's."""
    out = H.buf(1.9)
    t = np.arange(int(0.55 * SR)) / SR
    boom = H.tone(55 + 95 * np.exp(-t / 0.045), 0.55) * H.decay(0.55, 0.16, 0.004)
    body = H.tone(150 + 120 * np.exp(-t / 0.030), 0.55) * H.decay(0.55, 0.09, 0.003)
    H.add(out, boom, 0.0, 0.70)
    H.add(out, body, 0.0, 0.45)
    H.add(out, H.pop(rng, 0.80, weight=0.7), 0.0, 0.70)
    splash = H.band_noise(rng, 0.7, 2500, 13000) * H.decay(0.7, 0.16, 0.002)
    H.add(out, splash, 0.0, 0.30)
    for i, (name, octave, gain, tau) in enumerate((("C5", 0.5, 0.30, 0.75), ("G5", 0.5, 0.22, 0.70), ("C5", 1.0, 0.26, 0.70),
                                                   ("E5", 1.0, 0.22, 0.66), ("G5", 1.0, 0.20, 0.62), ("C6", 1.0, 0.16, 0.60))):
        H.add(out, H.bell(NOTE[name] * octave, 1.85, tau, bright=1.1, detune=7 if i % 2 else -7), 0.003 + i * 0.007, gain)
    return out


def shimmer(rng, seconds):
    """Sparkle: two waves of high pings and a soft airy band with a slow tremolo."""
    out = H.buf(seconds + 0.3)
    H.add(out, H.glitter(rng, seconds * 0.55, 46, lo="G6", hi="E8", lean=1.3), 0.03, 0.26)
    H.add(out, H.glitter(rng, seconds * 0.85, 40, lo="C7", hi="E8", lean=1.1), 0.30, 0.20)
    n = int(round(seconds * SR))
    t = np.arange(n) / SR
    air = H.band_noise(rng, seconds, 7000, 14000) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * np.exp(-t / 0.7) * np.minimum(1, t / 0.03)
    H.add(out, air, 0.0, 0.07)
    return out


def cannon(rng, pitch=1.0):
    """A soft confetti-cannon puff: an air thump and a short hiss. Not a bang."""
    out = H.buf(0.34)
    t = np.arange(int(0.16 * SR)) / SR
    thump = H.tone((120 + 260 * np.exp(-t / 0.018)) * pitch, 0.16) * H.decay(0.16, 0.045, 0.002)
    H.add(out, thump, 0.0, 0.8)
    hiss = H.band_noise(rng, 0.30, 1800 * pitch, 9000) * H.decay(0.30, 0.07, 0.006)
    H.add(out, hiss, 0.004, 0.38)
    return out


def fanfare():
    """'da da-da DAAA' in C major: three pick-up notes and a held chord. Returns (audio, chord_at)."""
    out = H.buf(1.6)
    chord_at = 0.36
    for name, at, length, gain in (("G5", 0.00, 0.11, 0.42), ("C6", 0.12, 0.10, 0.46), ("E6", 0.24, 0.10, 0.50)):
        H.add(out, brass(NOTE[name], length, bright=0.86), at, gain)
    for name, octave, gain in (("C5", 1.0, 0.34), ("G5", 1.0, 0.30), ("C6", 1.0, 0.40), ("E6", 1.0, 0.32), ("G6", 1.0, 0.36)):
        note = brass(NOTE[name] * octave, 1.05, bright=0.88, vibrato=9)
        n = len(note)
        note *= np.exp(-np.arange(n) / SR / 0.55)           # the chord rings down, it does not sit
        H.add(out, note, chord_at, gain)
    return out, chord_at


def stamp_thud(rng):
    """The title stamp landing: a rubber thud and a paper tick."""
    out = H.buf(0.22)
    t = np.arange(int(0.18 * SR)) / SR
    H.add(out, H.tone(110 + 150 * np.exp(-t / 0.014), 0.18) * H.decay(0.18, 0.045, 0.001), 0.0, 0.9)
    H.add(out, H.band_noise(rng, 0.03, 2500, 9000) * H.decay(0.03, 0.006, 0.0003), 0.0, 0.35)
    return out


def jackpot(rng, calm=False):
    x = H.buf(LENGTH)
    if not calm:
        H.add(x, riser(rng, HIT - 0.12), 0.0, 1.9)            # 0.12 s of silence before the hit
        H.add(x, impact(rng), HIT, 0.80)
        H.add(x, cannon(rng, 1.0), HIT + 0.23, 0.36)
        H.add(x, cannon(rng, 1.12), HIT + 0.35, 0.36)
    else:
        rng.standard_normal(4096)                             # keep the seed stream simple and fixed
        for i, (name, gain) in enumerate((("C5", 0.26), ("G5", 0.20), ("E6", 0.16))):
            H.add(x, H.bell(NOTE[name], 1.6, 0.6, bright=0.8, detune=5), HIT + i * 0.008, gain)
    H.add(x, shimmer(rng, 2.25), HIT + 0.02, 1.0 if calm else 1.9)
    fan, chord_at = fanfare()
    H.add(x, fan, HIT + STAMP - chord_at, 0.40 if calm else 0.62)
    if not calm:
        H.add(x, stamp_thud(rng), HIT + STAMP, 0.55)
    return H.finish(H.reverb(x, 0.16, 1.0, 0.78), peak_db=-7.0 if calm else -1.0, release=0.45)


def write_both(name, x):
    wav = os.path.join(OUT, name + ".wav")
    H.write_wav(wav, x)
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-codec:a", "libmp3lame", "-b:a", "192k",
                        os.path.join(OUT, name + ".mp3")], check=True)
    except (OSError, subprocess.CalledProcessError) as err:
        print("mp3 skipped for %s: %s" % (name, err))


def window_rms_db(x, start, end):
    part = x[int(start * SR):int(end * SR)]
    return round(20 * math.log10(math.sqrt(float(np.mean(part ** 2))) + 1e-9), 2)


def main():
    os.makedirs(OUT, exist_ok=True)
    layer = jackpot(np.random.default_rng(77))
    calm = jackpot(np.random.default_rng(78), calm=True)
    write_both("rare-jackpot-layer", layer)
    write_both("rare-jackpot-calm-layer", calm)
    report = {"sample_rate": SR, "hit_seconds_in_layer": HIT, "stamp_seconds_after_hit": STAMP, "burst_on_hatch_clock": BURST,
              "start_layer_at_hatch_clock": round(BURST - HIT, 3), "start_rare_sting_at_hatch_clock": round(BURST - H.HIT["rare"], 3),
              "suggested_gain": GAIN, "layer": H.describe(layer * GAIN["jackpot"]), "calm_layer": H.describe(calm * GAIN["jackpot"])}
    hit = int(HIT * SR)
    report["layer"]["hit_peak_at"] = round((hit + int(np.argmax(np.abs(layer[hit:hit + int(0.05 * SR)])))) / SR, 4)
    report["layer"]["gap_rms_dbfs_0.95_to_1.04"] = window_rms_db(layer, 0.95, 1.04)
    report["layer"]["riser_rms_dbfs_0.60_to_0.90"] = window_rms_db(layer, 0.60, 0.90)
    report["layer"]["impact_rms_dbfs_1.05_to_1.25"] = window_rms_db(layer, 1.05, 1.25)
    if os.path.exists(RARE_MASTER):
        rare = H.read_wav(RARE_MASTER)
        lead = HIT - H.HIT["rare"]                           # the sting starts this long after the layer
        total = max(LENGTH, lead + len(rare) / SR) + 0.05
        alone, mix = H.buf(total), H.buf(total)
        H.add(alone, rare, lead, GAIN["rare"])
        H.add(mix, rare, lead, GAIN["rare"])
        H.add(mix, layer, 0.0, GAIN["jackpot"])
        peak = float(np.max(np.abs(mix)))
        report["mix"] = {"rare_sting_offset_in_mix": round(lead, 3), "raw_sum_peak_dbfs": round(20 * math.log10(peak), 2),
                         "clips_at_suggested_gains": bool(peak > 1.0)}
        if peak > 10 ** (-1 / 20):                            # scale the audition, never clip it
            mix *= 10 ** (-1 / 20) / peak
            alone *= 10 ** (-1 / 20) / peak
            report["mix"]["audition_scaled_by_db"] = round(20 * math.log10(10 ** (-1 / 20) / peak), 2)
        report["mix"].update(H.describe(mix))
        write_both("rare-jackpot-over-rare-cue", mix)
        write_both("rare-cue-alone-for-compare", alone)
    else:
        report["mix"] = "skipped: %s not found" % os.path.relpath(RARE_MASTER, ROOT)
    with open(os.path.join(OUT, "report.json"), "w", newline="\n") as fh:
        json.dump(report, fh, indent=1)
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
