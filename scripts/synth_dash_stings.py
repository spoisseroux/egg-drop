"""Garden Dash finish cues (RACE-AND-MUSIC-LOOK.md sections 1.1, 2.3 to 2.5, Fable's scores).

  dash_win     2.6 s  win sting, C major 120 bpm; the big chord is 0.40 s in      48 kHz stereo
  dash_place   1.8 s  soft "you placed" sting, kalimba, no drums                   48 kHz stereo
  dash_line    0.6 s  over the line: woodblock double tap, wood G5 C6, air whoosh  44.1 kHz mono
  dash_best    0.9 s  new best: rising felt-glock run                              44.1 kHz mono
  star_land    0.22 s one felt-glock C6, pitched per Star by the code              44.1 kHz mono
  stars_total  0.7 s  wood C6 + glock G6 with a soft thump                         44.1 kHz mono

Additive synthesis only (voices from qa20261114_music.py, mallets from synth_tip_chime.py). No samples,
no generated audio. Fixed seed: every run is byte-identical.

Run from the repository root:  python scripts/synth_dash_stings.py
Writes artifacts/qa-2026-11-23-beta14/audio/stings/ (drafts for Spencer to hear; nothing uploaded).
"""
import math
import os

import numpy as np

import audio_draft_kit as K

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "artifacts", "qa-2026-11-23-beta14", "audio", "stings")
HZ = K.hz


def felt_glock(note, rng, sr, ring, cutoff, length=None, onset=.006):
    s = ring / .55   # shorten every mode with the fundamental
    return K.glock(HZ(note), rng, sr, length or ring * 5, ring, .16 * s, .06 * s, cutoff, onset)


def air(rng, sr, seconds, low, high, attack, tau):
    t = np.arange(int(round(seconds * sr))) / sr
    return K.band_noise(rng, len(t), sr, low, high) * np.minimum(1, t / attack) * np.exp(-np.maximum(0, t - attack) / tau) * K.envelope(t, seconds, .001, .05)


def sweep_noise(rng, sr, seconds, f0, f1, sweep, q=2.0):
    """Noise through a state-variable band-pass whose centre glides f0 -> f1 (exponential) over `sweep` s."""
    n = int(round(seconds * sr))
    x = rng.standard_normal(n)
    t = np.arange(n) / sr
    fc = f0 * (f1 / f0) ** np.clip(t / sweep, 0, 1)
    y = np.zeros(n)
    low = band = 0.0
    for i in range(n):
        f = 2 * math.sin(math.pi * fc[i] / sr)
        low += f * band
        high = x[i] - low - band / q
        band += f * high
        y[i] = band
    y /= np.max(np.abs(y))
    env = np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 1.5
    return y * env


# ---------------------------------------------------------------- dash_win (2.6 s, 48 kHz stereo)

def dash_win(rng):
    sr, lead = 48000, .23
    out = np.zeros((int(2.6 * sr) + sr, 2))
    add = lambda at, s, gain, pan=0.0: K.add(out, at, s, gain, sr, pan)
    # Pickup: wood + glock G5 C6 E6, 0.12 s each, rising 2 dB a note; brush roll under it.
    for i, (at, note) in enumerate(((0, "G5"), (.13, "C6"), (.26, "E6"))):
        gain = lead * K.db(-4 + 2 * i)
        add(at, K.voice(note, .12, "wood", sr), gain)
        add(at, felt_glock(note, rng, sr, .30, 4500), gain * K.db(-6), .05)
    for i in range(8):
        add(i * .05, K.brush(rng, sr), lead * K.db(-18 + 12 * i / 7))
    chord = lambda at, notes, dur, gain: [add(at, K.gated(K.voice(n, dur, "pluck", sr), sr, dur + .15), gain / math.sqrt(len(notes)), (-.12, 0, .12, .06)[k]) for k, n in enumerate(notes)]
    # 0.40 the hit (F), 0.90 (G).
    for at, notes, bass, top in ((.40, "F4 A4 C5", "F3", "C6"), (.90, "D4 G4 B4", "G3", "G6")):
        chord(at, notes.split(), .45, lead * K.db(-8))
        add(at, K.voice(bass, .45, "bass", sr), lead * K.db(-3))
        add(at, K.voice(top, .25, "wood", sr), lead)
        add(at, K.voice(top, .25, "bell", sr), lead * K.db(-8), .05)
        add(at, K.kick(sr), lead * K.db(-4))
        add(at, K.brush(rng, sr), lead * K.db(-9))
    add(.65, K.voice("F6", .25, "wood", sr), lead)
    add(.65, K.voice("F6", .25, "bell", sr), lead * K.db(-8), .05)
    for at, note in ((1.15, "D6"), (1.275, "G6")):
        add(at, K.voice(note, .125 * .9, "wood", sr), lead * K.db(-1))
        add(at, K.voice(note, .125 * .9, "bell", sr), lead * K.db(-9), .05)
    # 1.40 home: C with the added D5, bass C3 + C4, pad, C7 on top with E6 and G6 under it.
    chord(1.40, "C4 E4 G4 D5".split(), .9, lead * K.db(-7))
    add(1.40, K.voice("C3", .7, "bass", sr), lead * K.db(-3))
    add(1.40, K.voice("C4", .7, "bass", sr), lead * K.db(-8))
    for k, n in enumerate("C4 E4 G4".split()):
        add(1.40, K.voice(n, 1.0, "pad", sr), lead * K.db(-16), (-.12, 0, .12)[k])
    add(1.40, K.voice("C7", 1.0, "bell", sr), lead * K.db(-1))
    add(1.40, K.voice("C7", .4, "wood", sr), lead * K.db(-3))
    for k, n in enumerate(("E6", "G6")):
        add(1.40, K.voice(n, 1.0, "bell", sr), lead * K.db(-9), (-.08, .08)[k])
    add(1.40, K.kick(sr), lead * K.db(-3))
    add(1.40, air(rng, sr, .6, 3000, 6000, .03, .18), lead * K.db(-14))
    for i, (at, note) in enumerate(((1.40, "C6"), (1.46, "E6"), (1.52, "G6"), (1.58, "C7"))):
        add(at, felt_glock(note, rng, sr, .40, 4500), lead * K.db(-8), (-.1, -.03, .03, .1)[i])
    out = K.room(out, sr, .05, wrap=False)
    out = K.fade_tail(out, sr, 2.40, 2.60)[:int(2.6 * sr)]
    return K.fade_edges(out, sr, .001, .002), sr


# ---------------------------------------------------------------- dash_place (1.8 s, 48 kHz stereo)

def dash_place(rng):
    sr, lead = 48000, .23
    out = np.zeros((int(1.8 * sr) + sr, 2))
    add = lambda at, s, gain, pan=0.0: K.add(out, at, s, gain, sr, pan)
    kal = lambda n: K.kalimba(HZ(n), rng, sr)
    add(0.0, kal("E5"), lead * K.db(-2), -.05)
    add(.20, kal("G5"), lead * K.db(-1), .05)
    add(.40, kal("C6"), lead)
    for k, n in enumerate("C4 E4 A4 D5".split()):
        add(.40, K.voice(n, .6, "pluck", sr), lead * K.db(-8) / 2, (-.12, -.04, .04, .12)[k])
    add(.40, K.voice("C3", .6, "bass", sr), lead * K.db(-5))
    add(.90, K.gated(kal("D6"), sr, .15, .03), lead * K.db(-1), .05)
    add(1.05, kal("E6"), lead, -.03)
    out = K.room(out, sr, .05, wrap=False)
    out = K.fade_tail(out, sr, 1.60, 1.80)[:int(1.8 * sr)]
    return K.fade_edges(out, sr, .001, .002), sr


# ---------------------------------------------------------------- small cues (44.1 kHz mono)

def dash_line(rng):
    sr = 44100
    out = np.zeros(int(.6 * sr) + sr)
    add = lambda at, s, gain: K.add(out, at, s, gain, sr)
    add(0.0, K.woodblock(sr), .5)
    add(.07, K.woodblock(sr), .42)
    add(.05, K.voice("G5", .10, "wood", sr), .8)
    add(.17, K.voice("C6", .22, "wood", sr), .9)
    add(0.0, sweep_noise(rng, sr, .30, 800, 4000, .25), .9 * K.db(-12))
    out = K.fade_tail(out, sr, .50, .60)[:int(.6 * sr)]
    return K.fade_edges(out, sr, .001, .002), sr


def dash_best(rng):
    sr = 44100
    out = np.zeros(int(.9 * sr) + sr)
    add = lambda at, s, gain: K.add(out, at, s, gain, sr)
    for i, (at, note) in enumerate(((0, "G5"), (.06, "C6"), (.12, "E6"), (.18, "G6"))):
        add(at, felt_glock(note, rng, sr, .25, 4500), .7 * K.db(-3 + i))
    add(.30, felt_glock("G6", rng, sr, .25, 4500, length=.6), .8)
    add(.30, felt_glock("C7", rng, sr, .25, 4500, length=.6), .8)
    out = K.fade_tail(out, sr, .80, .90)[:int(.9 * sr)]
    return K.fade_edges(out, sr, .001, .002), sr


def star_land(rng):
    sr = 44100
    x = felt_glock("C6", rng, sr, .12, 4000, length=.22, onset=.002)
    x = K.fade_tail(x, sr, .17, .22)
    return K.fade_edges(x, sr, .0005, .002), sr


def stars_total(rng):
    sr = 44100
    out = np.zeros(int(round(.7 * sr)))
    add = lambda at, s, gain: K.add(out, at, s, gain, sr)
    add(0, K.wood_bar(HZ("C6"), rng, sr, length=.7, ring=.30), 1.0)
    add(0, felt_glock("G6", rng, sr, .30, 4000, length=.7), .8)
    t = np.arange(int(.08 * sr)) / sr
    add(0, np.sin(2 * np.pi * 90 * t) * K.envelope(t, .08, .004, .04), K.db(-10) * 1.6)
    out = K.fade_tail(out, sr, .55, .70)
    return K.fade_edges(out, sr, .0005, .002), sr


# Loudness targets (section 5): ("lufs", integrated target, true-peak ceiling) or ("peak", dBFS).
TARGETS = {
    "dash_win": ("lufs", -16.0, -4.5),
    "dash_place": ("lufs", -18.0, -6.0),
    "dash_line": ("lufs", -18.0, -6.0),
    "dash_best": ("lufs", -18.0, -6.0),
    "star_land": ("peak", -6.0),
    "stars_total": ("peak", -4.0),
}


def main():
    rng = np.random.default_rng(20261123)
    report = {}
    for name, make in (("dash_win", dash_win), ("dash_place", dash_place), ("dash_line", dash_line),
                       ("dash_best", dash_best), ("star_land", star_land), ("stars_total", stars_total)):
        x, sr = make(rng)
        target = TARGETS[name]
        gr = 0.0
        if target[0] == "lufs":
            x, gr = K.normalise(x, sr, target[1], target[2])
        else:
            x = x * K.db(target[1]) / np.max(np.abs(x))
        path = os.path.join(OUT, name + ".wav")
        pcm = K.write_wav(path, x, sr)
        meter = K.ebur128(path)
        report[name] = dict(file=name + ".wav", sha256=K.sha256(path), target=list(target), limiter_max_gain_reduction_db=round(gr, 2),
                            **meter, **K.basic_stats(pcm, sr))
        r = report[name]
        print(f"{name:12s} {r['seconds']:.3f}s {sr}Hz ch{r['channels']} I {r['integrated_lufs']} maxM {r['max_momentary_lufs']} "
              f"TP {r['true_peak_dbtp']} peak {r['sample_peak_dbfs']} first {r['first_sample']} last {r['last_sample']} GR {r['limiter_max_gain_reduction_db']}")
    K.save_report(os.path.join(OUT, "stings-report.json"), report)


if __name__ == "__main__":
    main()
