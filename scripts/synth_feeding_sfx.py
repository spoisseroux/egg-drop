"""Feeding sounds for Stat Snacks, synthesised from scratch (V2-FEEDING-RUNES-ONBOARDING-2026-11-19).

Proposal audio for review: nothing here is uploaded or wired. Every sound is built only from
sine partials and shaped white noise in numpy, with the same helpers as the hatch rarity
stings (scripts/synth_hatch_rarity.py). No samples, no recordings, no AI audio. Fixed seeds
make every run byte-identical.

  sniff           two quick little inhales, the second higher                    0.40 s
  nom_a/b/c       one soft "nom": a small voiced syllable closing to "m",        0.22 s each
                  with a biscuit snap and a few crumb ticks (three variations)
  crunch_feast    the Feast's first bite: a thump, a dense crackle, a short nom  0.50 s
  gulp            a small swallow, down then up                                  0.16 s
  happy_squeak    a short rising squeak                                          0.20 s
  happy_coo       a two-part "oo-ooh" with a little vibrato                      0.50 s
  boost_sparkle   three rising bell notes and glitter, C major pentatonic so it  1.00 s
                  sits in the same family as the rarity chimes, but smaller
  refuse_hm       a questioning "hm?" for when the server says no                0.26 s

Then four audition mixes that lay the sounds on the eating timeline in the doc (section 3):
sequence-nibble, sequence-snack, sequence-feast, sequence-feast-favourite. They are offline
mixes, not Studio recordings.

Run from the repository root:  python scripts/synth_feeding_sfx.py
Writes: artifacts/v2-feeding-runes-2026-11-19/sfx/*.wav and *.mp3 (mp3 needs ffmpeg) and report.json
"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth_hatch_rarity as H  # shared helpers: tone, decay, band_noise, bell, glitter, reverb, finish

ROOT = H.ROOT
OUT = os.path.join(ROOT, "artifacts", "v2-feeding-runes-2026-11-19", "sfx")
SR = H.SR
# Suggested playback gains, also used for the audition mixes.
GAIN = {"sniff": 0.45, "nom_a": 0.70, "nom_b": 0.70, "nom_c": 0.70, "crunch_feast": 0.85, "gulp": 0.50,
        "happy_squeak": 0.60, "happy_coo": 0.65, "boost_sparkle": 0.70, "refuse_hm": 0.55}
# Seconds from the server's receipt (the offer's sniff plays before it, on the client alone).
TIMELINE = {
    "nibble": [("nom_a", 0.60), ("nom_b", 0.92), ("gulp", 1.25), ("happy_squeak", 1.40), ("boost_sparkle", 1.65)],
    "snack": [("nom_a", 0.60), ("nom_b", 0.92), ("nom_c", 1.24), ("gulp", 1.57), ("happy_coo", 1.72), ("boost_sparkle", 2.10)],
    "feast": [("crunch_feast", 0.60), ("nom_b", 1.08), ("nom_c", 1.40), ("nom_a", 1.72), ("gulp", 2.05), ("happy_coo", 2.20),
              ("happy_squeak", 2.66), ("boost_sparkle", 2.80)],
    "feast-favourite": [("crunch_feast", 0.60), ("nom_b", 1.08), ("nom_c", 1.40), ("nom_a", 1.72), ("gulp", 2.05), ("happy_coo", 2.20),
                        ("happy_squeak", 2.66), ("boost_sparkle", 2.80), ("happy_squeak", 3.05), ("happy_coo", 3.22), ("boost_sparkle", 3.45)],
}


def ramp(seconds):
    n = int(round(seconds * SR))
    return np.arange(n) / max(1, n - 1)


def voice(f0, formants, harmonics=14):
    """A tiny voiced sound: harmonics of a gliding pitch, each weighted by where it falls
    among moving formants. `f0` is per-sample Hz; `formants` is a list of (centre Hz
    per-sample, width Hz, gain)."""
    phase = 2 * np.pi * np.cumsum(f0) / SR
    out = np.zeros(len(f0))
    for k in range(1, harmonics + 1):
        fk = k * f0
        weight = sum(g * np.exp(-0.5 * ((fk - centre) / width) ** 2) for centre, width, g in formants)
        out += np.where(fk < SR * 0.45, weight, 0.0) * np.sin(k * phase)
    return out


def swell(seconds, attack, release):
    """Up over `attack`, flat, down over `release` (raised cosines: no clicks)."""
    n = int(round(seconds * SR))
    t = np.arange(n) / SR
    up = 0.5 - 0.5 * np.cos(np.pi * np.minimum(1, t / attack))
    down = 0.5 - 0.5 * np.cos(np.pi * np.minimum(1, (seconds - t) / release))
    return up * down


def crumbs(rng, seconds, count, lo=2200, hi=9000, front=1.8):
    """Dry little ticks: very short bursts of bright noise, most of them early."""
    out = H.buf(seconds + 0.03)
    for _ in range(count):
        length = rng.uniform(0.004, 0.011)
        grain = H.band_noise(rng, length, lo * rng.uniform(0.8, 1.3), hi * rng.uniform(0.7, 1.0)) * H.decay(length, rng.uniform(0.0012, 0.0035), 0.0002)
        H.add(out, grain, seconds * rng.random() ** front, rng.uniform(0.35, 1.0))
    return out


def sniff(rng):
    x = H.buf(0.40)
    for at, length, lift, gain in ((0.0, 0.13, 1.0, 0.85), (0.19, 0.11, 1.28, 1.0)):
        u = ramp(length)
        low = H.band_noise(rng, length, 700 * lift, 2100 * lift)
        high = H.band_noise(rng, length, 2100 * lift, 5600 * lift)
        breath = (low * (1 - u) + high * u) * np.sin(np.pi * u ** 0.6) ** 1.4   # rises in pitch as it draws in
        H.add(x, breath, at, gain)
    return H.finish(x, peak_db=-6.0, release=0.03)


def nom(rng, pitch=1.0, length=0.20, ticks=4):
    """"Nom": a nasal start, an open "o", then the mouth closes on "m". A biscuit snap at the front."""
    u = ramp(length)
    f0 = pitch * (430 - 120 * u + 26 * np.exp(-u / 0.06))
    close = np.clip((u - 0.42) / 0.5, 0, 1)               # 0 open, 1 closed
    f1 = 300 + 380 * np.sin(np.pi * np.minimum(1, u / 0.42) * 0.5) * (1 - close) + 20 * close
    f2 = 1050 - 300 * close
    body = voice(f0, [(f1, 130, 1.0), (f2, 190, 0.45 * (1 - 0.8 * close)), (np.full(len(u), 2500.0), 400, 0.06 * (1 - close))])
    body *= swell(length, 0.012, 0.085) * (1 - 0.45 * close)
    x = H.buf(length + 0.05)
    H.add(x, body / (np.max(np.abs(body)) + 1e-12), 0.006, 0.9)
    snap = H.band_noise(rng, 0.022, 1600, 7500) * H.decay(0.022, 0.0045, 0.0003)
    H.add(x, snap, 0.0, 0.60)
    H.add(x, crumbs(rng, 0.085, ticks), 0.012, 0.32)
    return H.finish(x, peak_db=-3.0, release=0.02)


def crunch_feast(rng):
    x = H.buf(0.50)
    t = np.arange(int(0.16 * SR)) / SR
    thump = H.tone(84 + 90 * np.exp(-t / 0.022), 0.16) * H.decay(0.16, 0.050, 0.002)
    H.add(x, thump, 0.0, 0.55)
    for at, gain in ((0.0, 0.60), (0.035, 0.42)):                       # the biscuit breaks twice
        crack = H.band_noise(rng, 0.030, 1200, 9500) * H.decay(0.030, 0.006, 0.0003)
        H.add(x, crack, at, gain)
    H.add(x, crumbs(rng, 0.20, 22, 1500, 10000, 1.5), 0.004, 0.50)
    tail = nom(rng, 0.92, 0.19, 3)
    H.add(x, tail, 0.20, 0.55)
    return H.finish(H.reverb(x, 0.04, 0.5, 0.5), peak_db=-2.0, release=0.03)


def gulp(rng):
    length = 0.15
    u = ramp(length)
    # Kept above 300 Hz so a phone speaker can play it.
    f = 560 - 220 * np.sin(np.pi * np.minimum(1, u / 0.55) * 0.5) + 420 * np.clip((u - 0.55) / 0.45, 0, 1) ** 1.6
    body = (H.tone(f, length) + 0.30 * H.tone(2 * f, length)) * swell(length, 0.012, 0.05)
    x = H.buf(0.16)
    H.add(x, body, 0.0, 1.0)
    return H.finish(x, peak_db=-6.0, release=0.02)


def happy_squeak(rng):
    length = 0.19
    u = ramp(length)
    f = 760 + 640 * u ** 0.55 - 110 * np.clip((u - 0.86) / 0.14, 0, 1)
    f *= 1 + 0.012 * np.sin(2 * np.pi * 24 * u * length)
    body = (H.tone(f, length) + 0.30 * H.tone(2 * f, length) + 0.09 * H.tone(3 * f, length)) * np.sin(np.pi * u ** 0.7) ** 1.2
    x = H.buf(0.22)
    H.add(x, body, 0.0, 1.0)
    return H.finish(H.reverb(x, 0.06, 0.5, 0.55), peak_db=-4.0, release=0.03)


def happy_coo(rng):
    length = 0.48
    u = ramp(length)
    t = u * length
    rise = np.minimum(1, u / 0.36)
    f0 = 520 + 150 * np.sin(np.pi * rise * 0.5) - 95 * np.clip((u - 0.36) / 0.64, 0, 1) ** 0.8
    f0 *= 1 + 0.017 * np.clip((u - 0.3) / 0.4, 0, 1) * np.sin(2 * np.pi * 6.5 * t)
    f1 = 360 + 120 * np.sin(np.pi * u)
    body = voice(f0, [(f1, 150, 1.0), (np.full(len(u), 880.0), 220, 0.5), (np.full(len(u), 2600.0), 500, 0.05)], harmonics=10)
    dip = 1 - 0.55 * np.exp(-0.5 * ((u - 0.34) / 0.045) ** 2)            # the gap between "oo" and "ooh"
    body *= swell(length, 0.030, 0.16) * dip
    x = H.buf(0.52)
    H.add(x, body / (np.max(np.abs(body)) + 1e-12), 0.0, 1.0)
    return H.finish(H.reverb(x, 0.07, 0.6, 0.6), peak_db=-4.0, release=0.05)


def boost_sparkle(rng):
    x = H.buf(1.00)
    for name, at, gain, tau in (("E6", 0.000, 0.36, 0.11), ("G6", 0.070, 0.40, 0.13), ("C7", 0.140, 0.46, 0.22)):
        H.add(x, H.bell(H.NOTE[name], 0.80, tau, bright=0.8, detune=5), at, gain)
    H.add(x, H.glitter(rng, 0.55, 9), 0.20, 0.20)
    return H.finish(H.reverb(x, 0.12, 0.8, 0.70), peak_db=-3.0, release=0.22)


def refuse_hm(rng):
    length = 0.24
    u = ramp(length)
    f0 = 380 + 180 * u ** 1.8
    body = voice(f0, [(np.full(len(u), 420.0), 150, 1.0), (np.full(len(u), 1100.0), 240, 0.30)], harmonics=8) * swell(length, 0.03, 0.07)
    x = H.buf(0.26)
    H.add(x, body / (np.max(np.abs(body)) + 1e-12), 0.0, 1.0)
    return H.finish(x, peak_db=-6.0, release=0.03)


def save(name, x):
    """Keep both: the wav master for review and an mp3 audition."""
    wav = os.path.join(OUT, name + ".wav")
    H.write_wav(wav, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-codec:a", "libmp3lame", "-b:a", "192k",
                    os.path.join(OUT, name + ".mp3")], check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    made = {
        "sniff": sniff(np.random.default_rng(101)),
        "nom_a": nom(np.random.default_rng(102), 1.00, 0.20, 4),
        "nom_b": nom(np.random.default_rng(103), 1.09, 0.18, 3),
        "nom_c": nom(np.random.default_rng(104), 0.93, 0.21, 5),
        "crunch_feast": crunch_feast(np.random.default_rng(105)),
        "gulp": gulp(np.random.default_rng(106)),
        "happy_squeak": happy_squeak(np.random.default_rng(107)),
        "happy_coo": happy_coo(np.random.default_rng(108)),
        "boost_sparkle": boost_sparkle(np.random.default_rng(109)),
        "refuse_hm": refuse_hm(np.random.default_rng(110)),
    }
    report = {"sample_rate": SR, "suggested_gain": GAIN, "timeline_seconds_from_receipt": TIMELINE, "sounds": {}}
    for name, x in made.items():
        save(name, x)
        report["sounds"][name] = H.describe(x * GAIN[name])
    lead = 0.50                                                          # the offer: sniff, then the wait for the server
    for size, events in TIMELINE.items():
        mix = H.buf(lead + max(at for _, at in events) + 1.3)
        H.add(mix, made["sniff"], 0.0, GAIN["sniff"])
        for name, at in events:
            H.add(mix, made[name], lead + at - 0.60, GAIN[name])         # audition: the 0.6 s walk to the mouth is trimmed
        save("sequence-" + size, np.clip(mix, -1, 1))
    with open(os.path.join(OUT, "report.json"), "w", newline="\n") as fh:
        json.dump(report, fh, indent=1)
    print(json.dumps(report["sounds"], indent=1))


if __name__ == "__main__":
    main()
