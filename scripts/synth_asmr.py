"""The ASMR hatch's dry one-shots (ASMR-AND-SCALE-LOOK.md section 1, "The sounds, layer by layer").

  egg_set_a..c       .12 s   settle thud: a sine 110 -> 80 Hz, a 2 ms shell tick on top (an egg set on a tea towel)
  crack1_a..c        .16 s   crack 1: snap, bite (3-9 kHz noise), hollow body 420/610/880 Hz, 3 crumbs over 60-110 ms
  crack2_a..c        .24 s   crack 2: as crack 1, the body a third lower (300/440/640 Hz), a longer bite, 6 crumbs
  creak_a..c         .18 s   stick-slip creak: a 0.5 ms pulse train gliding 18 -> 45 a second through two resonators
  creak_long_a..b    .35 s   the same, longer, for a Rare's wind-up
  pop_a..c           .50 s   the open: thump 150 -> 70 Hz, a hollow "tok" chirp 520 -> 1100 Hz, crunch, 12-18 shards
  flake_a..e         .03 s   one shell crumb landing: a 3 ms grain and a 2.4-3.6 kHz blip
  exhale_a..b        .80 s   pink noise through a band sliding 1.8 kHz -> 700 Hz (no pitch, no voice)

Every variant is its own seed, not just a pitch change: the game picks one at random (never the same twice running) and
adds its own speed and gain jitter (HatchAsmr), so the hundredth hatch does not sound like the first.

No reverb, no music: close and dry. Levels are not in the files: each peaks at -3 dBFS (true peak too) and
HatchAsmr.Layers sets the level in the game, well under the tier sting. 44.1 kHz, 16-bit mono (the crunch lives at 4 to
10 kHz). Additive synthesis and shaped noise in numpy only (audio_draft_kit). No samples, no generated audio. Fixed
seeds: every run is byte-identical. Not heard by Spencer yet.

Run from the repository root:  python scripts/synth_asmr.py
Writes assets/audio/custom/egg_drop_asmr_<name>.wav and artifacts/asmr-hatch-2026-11-25/report.json.
"""
import math
import os

import numpy as np

import audio_draft_kit as K

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio", "custom")
REPORT = os.path.join(ROOT, "artifacts", "asmr-hatch-2026-11-25", "report.json")
SR = 44100
PEAK_DB = -3.0


def secs(n):
    return np.arange(int(round(n * SR))) / SR


def modes(t, table, rng):
    """Damped sines: (freq, gain, decay s), random phase."""
    out = np.zeros_like(t)
    for f, g, d in table:
        if f < SR / 2.2:
            out += g * np.sin(2 * math.pi * f * t + rng.uniform(0, 2 * math.pi)) * np.exp(-t / d)
    return out


def burst(rng, t, low, high, decay, attack=.0003):
    """Band-limited noise with a fast rise and an exponential fall."""
    return K.band_noise(rng, len(t), SR, low, high) * np.minimum(1, t / attack) * np.exp(-t / decay)


def snap(rng, t, cut=1500, decay=.0008):
    """A 1 ms step through a high-pass: the first instant of shell giving way."""
    x = rng.standard_normal(len(t)) * np.exp(-t / decay)
    return x - K.onepole_lowpass(x, SR, cut)


def place(out, at, sound, gain):
    i = int(round(at * SR))
    n = min(len(sound), len(out) - i)
    if n > 0:
        out[i:i + n] += gain * sound[:n]


def grain(rng, length, low=4000, high=10000):
    """One crumb: a few ms of bright noise in a Hann window."""
    n = max(8, int(round(length * SR)))
    return K.band_noise(rng, n + 64, SR, low, high)[32:32 + n] * np.hanning(n)


def chirp(t, f0, f1, glide, decay):
    """A sine whose pitch moves f0 -> f1 over `glide` s (exponential), damped."""
    k = np.minimum(1, t / glide)
    f = f0 * (f1 / f0) ** k
    return np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t / decay)


def resonator(x, f, q):
    """A two-pole band-pass ring at f (Q q)."""
    w = 2 * math.pi * f / SR
    r = math.exp(-w / (2 * q))
    a1, a2 = 2 * r * math.cos(w), -r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = (1 - r) * v + a1 * y1 + a2 * y2
        y2, y1 = y1, o
        y[i] = o
    return y


# ---------------------------------------------------------------- the layers

def egg_set(seed):
    rng = np.random.default_rng(seed)
    t = secs(.12)
    drop = rng.uniform(.96, 1.04)
    f = 110 * drop * (80 / 110) ** np.minimum(1, t / .05)
    x = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t / .07) * np.minimum(1, t / .002)
    x += K.db(-14) * 3 * snap(rng, t, 2000, .0006)                       # the shell touching down
    x += .12 * burst(rng, t, 300, 1400, .012)                            # the cloth under it
    return K.fade_tail(K.fade_edges(x, SR, .0004, .01), SR, .10, .12)


def crack(seed, body, bite, crumbs, spread, length):
    rng = np.random.default_rng(seed)
    t = secs(length)
    x = np.zeros_like(t)
    x += .6 * snap(rng, t, 1500, .0007)                                   # (a) snap
    x += 1.0 * burst(rng, t, 3000, 9000, bite)                           # (b) bite
    jitter = rng.uniform(.97, 1.03)
    x += K.db(-10) * 1.6 * modes(t, [(f * jitter, g, d) for f, g, d in body], rng) * np.minimum(1, t / .0006)  # (c) body
    # The crumbs: a few bright grains scattered after the crack, each quieter than the last.
    times = np.sort(rng.uniform(spread[0], spread[1], crumbs))
    for k, at in enumerate(times):
        place(x, at, grain(rng, rng.uniform(.002, .004)), .55 * K.db(-4 * k / max(1, crumbs / 3)))
    return K.fade_tail(K.fade_edges(x, SR, .0003, .01), SR, length - .02, length)


def creak(seed, length, rise_db=6.0):
    rng = np.random.default_rng(seed)
    t = secs(length)
    pulses = np.zeros_like(t)
    at = 0.0
    while at < length - .004:
        rate = 18 + (45 - 18) * (at / length)
        at += (1 / rate) * rng.uniform(.8, 1.2)                          # irregular stick-slip
        i = int(at * SR)
        if i + 22 < len(t):
            pulses[i:i + 22] += rng.uniform(.6, 1.0) * np.hanning(22)    # a 0.5 ms pulse
    f1 = rng.uniform(900, 1400)
    ring = resonator(pulses, f1, 12) + .7 * resonator(pulses, 2800 * rng.uniform(.96, 1.04), 8)
    ring += .25 * resonator(pulses, f1 * 2.1, 10)
    swell = K.db(-rise_db) * K.db(rise_db) ** (t / length)               # level rises 6 dB across it
    x = ring * swell * np.minimum(1, t / .01)
    return K.fade_tail(K.fade_edges(x, SR, .001, .006), SR, length - .015, length)


def pop(seed):
    rng = np.random.default_rng(seed)
    length = .5
    t = secs(length)
    x = np.zeros_like(t)
    lift = rng.uniform(.97, 1.03)
    x += 1.0 * chirp(t, 150 * lift, 70 * lift, .06, .09) * np.minimum(1, t / .0015)    # (a) thump
    x += .55 * chirp(t, 520 * lift, 1100 * lift, .025, .03) * np.minimum(1, t / .0006)   # (b) the hollow tok
    x += .55 * burst(rng, t, 1500, 12000, .035)                                        # (c) crunch
    x += .35 * snap(rng, t, 1200, .0009)
    n = int(rng.integers(12, 19))                                                      # (d) shard scatter, thinning
    times = np.sort(.03 + .32 * rng.uniform(0, 1, n) ** 1.7)
    for k, at in enumerate(times):
        level = K.db(-6 - 18 * k / max(1, n - 1))
        place(x, at, grain(rng, rng.uniform(.002, .005)), .9 * level)
    return K.fade_tail(K.fade_edges(x, SR, .0003, .01), SR, .44, length)


def flake(seed):
    rng = np.random.default_rng(seed)
    t = secs(.03)
    x = np.zeros_like(t)
    place(x, .0005, grain(rng, .003, 5000, 9000), .9)
    blip = rng.uniform(2400, 3600)
    x += .5 * np.sin(2 * math.pi * blip * t + rng.uniform(0, 6.28)) * np.exp(-t / .0025) * np.minimum(1, t / .0004)
    return K.fade_tail(K.fade_edges(x, SR, .0002, .004), SR, .024, .03)


def exhale(seed):
    rng = np.random.default_rng(seed)
    length = .8
    n = int(round(length * SR))
    # Pink noise (FFT shaped), then a two-pole band whose centre slides 1.8 kHz -> 700 Hz.
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    spec[1:] /= np.sqrt(f[1:])
    spec[0] = 0
    pink = np.fft.irfft(spec, n=n)
    pink /= np.max(np.abs(pink)) + 1e-12
    y = np.zeros(n)
    y1 = y2 = 0.0
    top = rng.uniform(1700, 1900)
    for i in range(n):
        fc = top * (700 / top) ** (i / (n - 1))
        w = 2 * math.pi * fc / SR
        r = math.exp(-w / (2 * 1.5))
        a1, a2 = 2 * r * math.cos(w), -r * r
        v = (1 - r) * pink[i] + a1 * y1 + a2 * y2
        y2, y1 = y1, v
        y[i] = v
    t = secs(length)
    env = np.minimum(1, t / .12) * np.exp(-np.maximum(0, t - .12) / .3)
    return K.fade_tail(K.fade_edges(y * env, SR, .002, .02), SR, .7, length)


CRACK1 = [(420, .7, .025), (610, .5, .025), (880, .35, .025)]
CRACK2 = [(300, .7, .035), (440, .5, .035), (640, .35, .035)]


def master(x):
    """Peak at PEAK_DB, sample and true peak, no DC."""
    x = x - np.mean(x) * np.hanning(len(x)) / np.mean(np.hanning(len(x)))
    return x * (K.db(PEAK_DB - .05) / K.true_peak(x))


def main():
    cues = {}
    for i, v in enumerate("abc"):
        cues[f"egg_set_{v}"] = egg_set(2100 + i)
        cues[f"crack1_{v}"] = crack(2200 + i, CRACK1, .012, 3, (.06, .11), .16)
        cues[f"crack2_{v}"] = crack(2300 + i, CRACK2, .018, 6, (.05, .15), .24)
        cues[f"creak_{v}"] = creak(2400 + i, .18)
        cues[f"pop_{v}"] = pop(2600 + i)
    for i, v in enumerate("ab"):
        cues[f"creak_long_{v}"] = creak(2500 + i, .35)
        cues[f"exhale_{v}"] = exhale(2800 + i)
    for i, v in enumerate("abcde"):
        cues[f"flake_{v}"] = flake(2700 + i)
    report = {"sample_rate": SR, "peak_target_dbfs": PEAK_DB, "cues": {}}
    for name, x in cues.items():
        path = os.path.join(OUT, f"egg_drop_asmr_{name}.wav")
        written = K.write_wav(path, master(x), SR)
        stats = K.basic_stats(written, SR)
        stats["true_peak_dbtp"] = round(20 * math.log10(K.true_peak(written)), 2)
        stats["sha256"] = K.sha256(path)
        assert stats["sample_peak_dbfs"] <= PEAK_DB and stats["true_peak_dbtp"] <= PEAK_DB, (name, stats)
        assert stats["first_sample"] < .002 and stats["last_sample"] == 0, (name, stats)
        report["cues"]["asmr_" + name] = stats
        print(f"asmr_{name:14s} {stats['seconds']:.3f} s  peak {stats['sample_peak_dbfs']:6.2f} dBFS  tp {stats['true_peak_dbtp']:6.2f}  rms {stats['rms_dbfs']:6.2f}")
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    K.save_report(REPORT, report)


if __name__ == "__main__":
    main()
