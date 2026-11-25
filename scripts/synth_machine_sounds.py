"""The egg machine's capsule-shot cues (CAPSULE-AND-HUD-LOOK.md U5, EGG-CORNER-LOOK.md 2, ASMR-AND-SCALE-LOOK.md 1).

  crank_click_1..3  .075 s  a wooden pawl snapping over a plastic gear tooth: snap, grit, body, a tiny settle
  egg_tok_1..3      .12 s   two hollow plastic capsules knocking: glassy inharmonic shell modes, a soft click
  crank_clunk       .30 s   the dial stopping and springing back: a low wooden knock (180 Hz body), a crunch,
                            the pawl catching at 70 ms and the mechanism settling
  egg_roll          .40 s   a capsule rolling down the leaf chute (seam ticks speeding up, a hollow rumble, leaf
                            hiss) into the woven cup (a wicker crackle at the end; the thud itself is `land`)
  screen_tuck       .22 s   a soft paper slide downward, falling pitch, ending in a small pat
  screen_rise       .24 s   the same slide rising, ending in a light flick
  cup_shine         .60 s   one small glassy ting about 1.8 kHz; most of it gone by .25 s, the rest a faint shimmer

Crunchy, layered and tactile (Spencer: the hatch should feel cathartic and ASMR-ish), with no reverb: every cue is
built from a transient, a band of grit and a few damped modes, so it reads close and dry. Levels are not in the
files: every file peaks at -3 dBFS (true peak too) and EggMachineClient's Machine.Volume sets the level in the game
(click .1, clunk .16, roll .1, tok .05, tuck .08, rise .063, shine .08), well under the stings.

Additive synthesis and shaped noise in numpy only (audio_draft_kit). No samples, no generated audio. Fixed seeds:
every run is byte-identical.

Run from the repository root:  python scripts/synth_machine_sounds.py
Writes assets/audio/custom/egg_drop_<cue>.wav and artifacts/qa-2026-11-25-beta17/machine-sounds/report.json.
"""
import math
import os

import numpy as np

import audio_draft_kit as K

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio", "custom")
REPORT = os.path.join(ROOT, "artifacts", "qa-2026-11-25-beta17", "machine-sounds", "report.json")
SR = 44100
PEAK_DB = -3.0


def secs(n):
    return np.arange(int(round(n * SR))) / SR


def modes(t, table, rng):
    """Damped sines: (freq, gain, decay s). Random phase so variants differ in the attack too."""
    out = np.zeros_like(t)
    for f, g, d in table:
        if f < SR / 2.2:
            out += g * np.sin(2 * math.pi * f * t + rng.uniform(0, 2 * math.pi)) * np.exp(-t / d)
    return out


def burst(rng, t, low, high, decay, attack=.0004):
    """Band-limited noise with a fast rise and an exponential fall: the grit of a hard contact."""
    return K.band_noise(rng, len(t), SR, low, high) * np.minimum(1, t / attack) * np.exp(-t / decay)


def snap(rng, t, cut=1500, decay=.0008):
    """A 1 ms step through a high-pass: the first instant of plastic meeting plastic."""
    x = rng.standard_normal(len(t)) * np.exp(-t / decay)
    return x - K.onepole_lowpass(x, SR, cut)


def place(out, at, sound, gain):
    i = int(round(at * SR))
    n = min(len(sound), len(out) - i)
    if n > 0:
        out[i:i + n] += gain * sound[:n]


def sweep_band(rng, seconds, f0, f1, q):
    """White noise through a two-pole resonator whose centre glides f0 -> f1 (exponential)."""
    n = int(round(seconds * SR))
    x = rng.standard_normal(n)
    y = np.zeros(n)
    y1 = y2 = 0.0
    for i in range(n):
        f = f0 * (f1 / f0) ** (i / max(1, n - 1))
        w = 2 * math.pi * f / SR
        r = math.exp(-w / (2 * q))
        a1, a2 = 2 * r * math.cos(w), -r * r
        v = (1 - r) * x[i] + a1 * y1 + a2 * y2
        y2, y1 = y1, v
        y[i] = v
    return y / (np.max(np.abs(y)) + 1e-12)


def grains(rng, t, rate, length=(.006, .018), level=(.45, 1.0)):
    """A grain envelope (paper fibres, wicker): random short Hann bumps at about `rate` a second."""
    env = np.zeros_like(t)
    at = 0.0
    while at < t[-1]:
        at += rng.exponential(1 / rate)
        n = int(rng.uniform(*length) * SR)
        i = int(at * SR)
        if i + n >= len(t) or n < 4:
            continue
        env[i:i + n] += rng.uniform(*level) * np.hanning(n)
    return .35 + env   # a floor so the slide is continuous, the grains on top


# ---------------------------------------------------------------- the cues

CLICK = [  # pawl body (Hz), plastic ring (Hz), wood tick (Hz)
    (1350, 3150, 360),
    (1620, 3420, 410),
    (1880, 2900, 330),
]


def crank_click(index):
    rng = np.random.default_rng(1100 + index)
    body, ring, wood = CLICK[index - 1]
    t = secs(.075)
    x = np.zeros_like(t)
    x += .55 * snap(rng, t)
    x += .70 * burst(rng, t, 2200, 7500, .0035)                  # grit
    x += modes(t, [(body, .55, .010), (body * 1.53, .25, .006), (ring, .30, .007)], rng)  # the gear and the pawl
    x += modes(t, [(wood, .40, .006)], rng) * np.minimum(1, t / .0008)   # a little wood under it
    tail = secs(.03)
    settle = .9 * burst(rng, tail, 2500, 8000, .0018) + modes(tail, [(body * 1.08, .35, .005)], rng)
    place(x, .007 + .002 * index, settle, .28)                     # the pawl settling into the tooth
    return K.fade_edges(x, SR, .0005, .012)


TOK = [  # capsule shell modes: three inharmonic, glassy; a low hollow body
    ((1460, 2390, 3640), 540, None),
    ((1330, 2210, 3380), 500, .038),   # a little bounce 38 ms on
    ((1580, 2560, 3870), 590, None),
]


def egg_tok(index):
    rng = np.random.default_rng(1200 + index)
    shell, hollow, bounce = TOK[index - 1]
    t = secs(.12)

    def knock(gain, damp):
        x = .35 * K.onepole_lowpass(snap(rng, t, 900, .0006), SR, 6000)
        x += modes(t, [(shell[0], .60, .022 * damp), (shell[1], .38, .014 * damp), (shell[2], .22, .009 * damp)], rng)
        x += modes(t, [(hollow, .50, .018 * damp)], rng) * np.minimum(1, t / .0015)
        x += .18 * burst(rng, t, 3000, 9000, .002)
        return gain * x

    x = knock(1.0, 1.0)
    if bounce:
        place(x, bounce, knock(1.0, .7), .38)
    return K.fade_edges(x, SR, .0004, .03)


def crank_clunk():
    rng = np.random.default_rng(1301)
    t = secs(.30)
    x = np.zeros_like(t)
    # The knock: a 180 Hz wooden body that drops a little as it is damped, two wood modes, a short crunch.
    f = 180 * (1 - .22 * (1 - np.exp(-t / .03)))
    x += np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t / .06) * np.minimum(1, t / .0015)
    x += modes(t, [(415, .45, .032), (770, .26, .018), (1240, .14, .010)], rng)
    x += .55 * burst(rng, t, 900, 6000, .012)
    x += .35 * snap(rng, t, 1200, .001)
    # The spring-back: the pawl catches a tooth at 70 ms (a small click), then the mechanism settles.
    catch = secs(.05)
    place(x, .070, .7 * burst(rng, catch, 2000, 7000, .003) + modes(catch, [(1450, .5, .008), (330, .4, .010)], rng), .32)
    for at, g in ((.125, .16), (.165, .11), (.205, .07), (.24, .045)):
        g_t = secs(.02)
        place(x, at + rng.uniform(-.006, .006), burst(rng, g_t, 1800, 6500, .0025) + modes(g_t, [(rng.uniform(600, 900), .5, .006)], rng), g)
    return K.fade_tail(K.fade_edges(x, SR, .0004, .01), SR, .24, .30)


def egg_roll():
    rng = np.random.default_rng(1401)
    length = .40
    t = secs(length)
    x = np.zeros_like(t)
    # Seam ticks: the capsule's seam meets the leaf once a turn, the turn speeding up 13 -> 24 a second.
    rate = 13 + 11 * (t / length) ** 1.3
    phase = np.cumsum(rate) / SR
    ticks = np.flatnonzero(np.diff(np.floor(phase)) > 0)
    for n, i in enumerate(ticks):
        at = i / SR
        if at > .33:
            break
        tt = secs(.03)
        lift = 1 + .06 * at / length                              # rising slightly
        tick = modes(tt, [(1180 * lift, .5, .007), (1910 * lift, .3, .005), (520 * lift, .35, .009)], rng)
        tick += .5 * burst(rng, tt, 2500, 8000, .0015)
        place(x, at, tick, rng.uniform(.55, .85) * (.6 + .4 * min(1, at / .12)))
    # Hollow rumble and leaf hiss under the ticks, amplitude riding the rotation.
    wobble = .75 + .25 * np.sin(2 * math.pi * phase)
    rumble = K.band_noise(rng, len(t), SR, 180, 1100) * wobble
    hiss = K.band_noise(rng, len(t), SR, 2500, 7000) * (.6 + .4 * np.sin(2 * math.pi * 2 * phase + 1))
    bed = np.minimum(1, t / .05) * np.where(t < .34, 1.0, np.exp(-(t - .34) / .015))
    x += (.22 * rumble + .08 * hiss) * bed
    # Into the woven cup: a few dry wicker crackles as it settles (the landing thud is `land`).
    for k in range(7):
        at = .335 + k * .009 + rng.uniform(0, .006)
        g_t = secs(.012)
        place(x, at, burst(rng, g_t, 3000, 9000, .0018) + modes(g_t, [(rng.uniform(1100, 1700), .4, .003)], rng),
              .45 * .82 ** k)
    return K.fade_tail(K.fade_edges(x, SR, .002, .01), SR, .375, .40)


def paper_slide(seed, length, f0, f1, end):
    rng = np.random.default_rng(seed)
    t = secs(length)
    slide = sweep_band(rng, length, f0, f1, 1.6)
    fibre = grains(rng, t, 140)
    shape = np.minimum(1, t / .035) * np.exp(-np.maximum(0, t - .06) / (length * .45))
    x = .8 * slide * fibre * shape
    x += .18 * K.band_noise(rng, len(t), SR, 4000, 9000) * fibre * shape   # the paper's edge
    tt = secs(.04)
    if end == "pat":       # settling down: a small soft pat
        place(x, length - .06, modes(tt, [(240, .7, .012), (520, .3, .006)], rng) + .25 * burst(rng, tt, 800, 3000, .004), .45)
    else:                  # flicking up: a light dry flick
        place(x, length - .055, .6 * burst(rng, tt, 3500, 9500, .003) + modes(tt, [(2600, .3, .004)], rng), .4)
    return K.fade_tail(K.fade_edges(x, SR, .002, .01), SR, length - .02, length)


def cup_shine():
    rng = np.random.default_rng(1601)
    t = secs(.60)
    f = 1800.0
    x = modes(t, [(f, 1.0, .10), (f * 1.0021, .35, .16), (f * 2.76, .22, .035), (f * 5.40, .06, .015)], rng)
    x *= np.minimum(1, t / .002)
    x += .10 * K.onepole_lowpass(snap(rng, t, 2500, .0005), SR, 9000)     # the tap that starts it
    return K.fade_tail(K.fade_edges(x, SR, .0005, .01), SR, .45, .60)


def master(x):
    """Peak at PEAK_DB, sample and true peak, with nothing clipped."""
    x = x - np.mean(x) * np.hanning(len(x)) / np.mean(np.hanning(len(x)))   # no DC, edges untouched
    x = x * (K.db(PEAK_DB - .05) / K.true_peak(x))   # a hair under, so 16-bit rounding never lands over
    return x


def main():
    cues = {}
    for i in (1, 2, 3):
        cues[f"crank_click_{i}"] = crank_click(i)
        cues[f"egg_tok_{i}"] = egg_tok(i)
    cues["crank_clunk"] = crank_clunk()
    cues["egg_roll"] = egg_roll()
    cues["screen_tuck"] = paper_slide(1501, .22, 3200, 1150, "pat")
    cues["screen_rise"] = paper_slide(1502, .24, 1150, 3400, "flick")
    cues["cup_shine"] = cup_shine()
    report = {"sample_rate": SR, "peak_target_dbfs": PEAK_DB, "cues": {}}
    for name, x in cues.items():
        path = os.path.join(OUT, f"egg_drop_{name}.wav")
        written = K.write_wav(path, master(x), SR)
        stats = K.basic_stats(written, SR)
        stats["true_peak_dbtp"] = round(20 * math.log10(K.true_peak(written)), 2)
        stats["sha256"] = K.sha256(path)
        assert stats["sample_peak_dbfs"] <= PEAK_DB and stats["true_peak_dbtp"] <= PEAK_DB, (name, stats)
        assert stats["first_sample"] < .002 and stats["last_sample"] == 0, (name, stats)
        report["cues"][name] = stats
        print(f"{name:14s} {stats['seconds']:.3f} s  peak {stats['sample_peak_dbfs']:6.2f} dBFS  tp {stats['true_peak_dbtp']:6.2f}  rms {stats['rms_dbfs']:6.2f}")
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    K.save_report(REPORT, report)


if __name__ == "__main__":
    main()
