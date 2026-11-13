"""Build Egg Drop's PLACEHOLDER sound effects (numpy synthesis, deterministic).

These are stand-ins so every cue has sound now. Spencer makes the final audio;
replace any file in assets/audio/placeholder/ with a real take of the same name.

Output: assets/audio/placeholder/egg_drop_<cue>.wav (44.1 kHz, mono, 16-bit),
an .ogg encode of each (ffmpeg, if found), manifest.json, and a printed
duration / peak / RMS summary. Re-running gives byte-identical WAVs.

    python scripts/build_placeholder_audio.py [--no-ogg]
"""

import argparse
import json
import math
import shutil
import subprocess
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 44_100
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "placeholder"

# Loudness targets, matched to the existing assets/audio/egg_drop_*.wav set
# (one-shots sit around -15..-25 dBFS RMS with peaks -4..-15 dBFS).
LEVELS = {  # name: (target RMS dBFS, peak ceiling dBFS)
    "tick": (-25.0, -9.0),
    "ui": (-21.0, -5.0),
    "fx": (-19.0, -3.0),
    "jingle": (-18.0, -2.0),
    "loop": (-31.0, -12.0),
}


# ---------------------------------------------------------------- primitives
def n_of(seconds):
    return max(1, int(round(seconds * SR)))


def t_of(seconds):
    return np.arange(n_of(seconds)) / SR


def rng_for(name):
    return np.random.default_rng(zlib.crc32(name.encode()))


def env(seconds, attack=0.004, decay=None, hold=0.0, curve=4.0):
    """Attack, optional hold, then exponential decay to ~0 at the end."""
    n = n_of(seconds)
    t = np.arange(n) / SR
    e = np.ones(n)
    a = max(attack, 1 / SR)
    e = np.where(t < a, t / a, e)
    start = a + hold
    span = max(seconds - start, 1 / SR)
    if decay is None:
        rest = np.clip((t - start) / span, 0, 1)
        e = np.where(t >= start, np.exp(-curve * rest) * (1 - rest), e)
    else:
        e = np.where(t >= start, np.exp(-(t - start) / decay), e)
    return e


def sweep_phase(f0, f1, seconds, shape="exp"):
    n = n_of(seconds)
    if shape == "exp" and f0 > 0 and f1 > 0:
        f = f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
    else:
        f = np.linspace(f0, f1, n)
    return 2 * np.pi * np.cumsum(f) / SR, f


def osc(f0, seconds, f1=None, wave_="sine", vib=0.0, vib_rate=6.0):
    phase, _ = sweep_phase(f0, f1 if f1 else f0, seconds)
    if vib:
        t = t_of(seconds)
        phase = phase + vib * np.sin(2 * np.pi * vib_rate * t)
    if wave_ == "sine":
        return np.sin(phase)
    if wave_ == "tri":
        return (2 / np.pi) * np.arcsin(np.sin(phase))
    if wave_ == "soft_square":  # rounded chiptune pulse: few odd harmonics
        return (np.sin(phase) + np.sin(3 * phase) / 3 * 0.6 + np.sin(5 * phase) / 5 * 0.3)
    raise ValueError(wave_)


def bell(freq, seconds, detune=0.0, bright=1.0, decay=None):
    """Soft bell/glass: sine fundamental plus gentle inharmonic partials."""
    t = t_of(seconds)
    decay = decay or seconds * 0.35
    out = np.zeros_like(t)
    partials = [(1.0, 1.0, 1.0), (2.0, 0.28 * bright, 0.55), (2.76, 0.18 * bright, 0.4),
                (5.4, 0.06 * bright, 0.22)]
    for ratio, amp, dk in partials:
        f = freq * ratio
        if f > SR * 0.45:
            continue
        out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / (decay * dk))
        if detune:
            out += amp * 0.6 * np.sin(2 * np.pi * f * (1 + detune) * t) * np.exp(-t / (decay * dk))
    attack = np.clip(t / 0.002, 0, 1)
    return out * attack


def onepole_lp(x, cutoff):
    """One-pole low-pass; cutoff may be an array (time-varying)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s = (1 - a[i]) * x[i] + a[i] * s
        y[i] = s
    return y


def lp(x, cutoff, order=2):
    for _ in range(order):
        x = onepole_lp(x, cutoff)
    return x


def hp(x, cutoff, order=1):
    return x - lp(x, cutoff, order)


def bandpass(x, center, q=2.0):
    """State-variable band-pass; center may vary over time."""
    center = np.broadcast_to(np.asarray(center, dtype=float), x.shape)
    f = 2 * np.sin(np.pi * np.clip(center, 20, SR / 6) / SR)
    damp = 1.0 / q
    low = band = 0.0
    y = np.empty_like(x)
    for i in range(len(x)):
        high = x[i] - low - damp * band
        band += f[i] * high
        low += f[i] * band
        y[i] = band
    return y


def noise(name_or_rng, seconds):
    rng = rng_for(name_or_rng) if isinstance(name_or_rng, str) else name_or_rng
    return rng.uniform(-1, 1, n_of(seconds))


def mix(total, *parts):
    """parts: (offset_seconds, signal, gain)."""
    out = np.zeros(n_of(total))
    for offset, sig, gain in parts:
        i = n_of(offset) if offset > 0 else 0
        j = min(len(out), i + len(sig))
        out[i:j] += gain * sig[: j - i]
    return out


def plus(*signals):
    """Sum signals of different lengths (zero-padded to the longest)."""
    out = np.zeros(max(len(x) for x in signals))
    for x in signals:
        out[: len(x)] += x
    return out


def note_hz(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7,
             "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def chip_note(freq, seconds, wave_="tri", vib=0.0, attack=0.004, decay=None, f1=None):
    return osc(freq, seconds, f1=f1, wave_=wave_, vib=vib) * env(seconds, attack, decay)


def sparkle(rng, seconds, count, lo=2600, hi=6200, start=0.0, gain=0.25):
    out = np.zeros(n_of(seconds))
    for _ in range(count):
        at = rng.uniform(start, seconds * 0.8)
        f = rng.uniform(lo, hi)
        dur = rng.uniform(0.05, 0.14)
        ping = np.sin(2 * np.pi * f * t_of(dur)) * np.exp(-t_of(dur) / (dur * 0.25))
        out = out + mix(seconds, (at, ping, gain * rng.uniform(0.4, 1.0)))
    return out


# ---------------------------------------------------------------- cue designs
def c_bear_boop(name):
    s = 0.18
    t = t_of(s)
    f = 760 + 420 * np.sin(np.pi * np.clip(t / 0.11, 0, 1)) ** 1.5 - 120 * (t / s)
    phase = 2 * np.pi * np.cumsum(f) / SR + 0.25 * np.sin(2 * np.pi * 28 * t)
    body = (np.sin(phase) + 0.25 * np.sin(2 * phase)) * env(s, 0.006, hold=0.05, curve=3)
    return lp(body, 3500)


def c_deck_boot(name):
    rng = rng_for(name)
    s = 1.3
    a = chip_note(note_hz("E5"), 0.16, "soft_square", decay=0.09)
    b = chip_note(note_hz("B5"), 0.16, "soft_square", decay=0.09)
    c = plus(bell(note_hz("E6"), 1.0, detune=0.003, decay=0.35), 0.5 * bell(note_hz("B6"), 0.9, decay=0.25))
    pad = osc(note_hz("E4"), 1.0, wave_="tri") * env(1.0, 0.02, curve=3) * 0.35
    return mix(s, (0, a, 0.5), (0.11, b, 0.5), (0.24, c, 0.6), (0.24, pad, 1.0),
               (0.26, sparkle(rng, 1.0, 6), 1.0))


def c_quest_complete(name):
    rng = rng_for(name)
    s = 0.8
    notes = ["G5", "C6", "E6"]
    parts = [(i * 0.085, chip_note(note_hz(n), 0.12, "soft_square", decay=0.06), 0.45)
             for i, n in enumerate(notes)]
    parts.append((0.255, bell(note_hz("G6"), 0.55, detune=0.004, decay=0.2), 0.6))
    parts.append((0.255, chip_note(note_hz("C5"), 0.45, "tri", decay=0.18), 0.35))
    parts.append((0.26, sparkle(rng, 0.5, 4), 1.0))
    return mix(s, *parts)


def c_danger_enter(name):
    s = 0.42
    a = chip_note(note_hz("E4"), 0.17, "tri", attack=0.01, decay=0.12, vib=0.15)
    b = chip_note(note_hz("C4"), 0.24, "tri", attack=0.01, decay=0.12, f1=note_hz("C4") * 0.97, vib=0.15)
    sub = osc(note_hz("C3"), 0.4) * env(0.4, 0.02, curve=3) * 0.25
    return lp(mix(s, (0, a, 0.7), (0.15, b, 0.75), (0, sub, 1.0)), 2200)


def c_danger_tick(name):
    s = 0.06
    body = osc(1250, s, f1=1050) * env(s, 0.0015, decay=0.012)
    knock = osc(520, s) * env(s, 0.001, decay=0.008) * 0.6
    return body + knock


def c_danger_clear(name):
    rng = rng_for(name)
    s = 0.6
    parts = [(i * 0.07, bell(note_hz(n), 0.45, detune=0.003, decay=0.16), 0.5)
             for i, n in enumerate(["G5", "C6", "E6"])]
    parts.append((0.14, sparkle(rng, 0.4, 3, lo=3000, hi=5500), 0.8))
    return mix(s, *parts)


def c_reveal_hush(name):
    s = 0.22
    t = t_of(s)
    cutoff = 5200 * (380 / 5200) ** (t / s)
    shaped = np.minimum(1, t / 0.03) * np.exp(-3.5 * t / s) * (1 - t / s)
    return lp(noise(name, s), cutoff) * shaped


def c_spot_on(name):
    s = 0.48
    thunk = osc(130, 0.09, f1=70) * env(0.09, 0.001, decay=0.025)
    click = lp(noise(name, 0.02), 2500) * env(0.02, 0.0005, decay=0.004)
    t = t_of(0.42)
    swell = np.sin(np.pi * np.clip(t / 0.42, 0, 1)) ** 1.4
    hum = (osc(220, 0.42) + 0.6 * osc(330, 0.42) + 0.25 * osc(440.8, 0.42)) * swell
    return mix(s, (0, thunk, 0.9), (0, click, 0.4), (0.04, lp(hum, 1800, 1), 0.28))


def c_streak_whoosh(name):
    s = 0.34
    t = t_of(s)
    center = 700 * (5600 / 700) ** (t / s)
    body = bandpass(noise(name, s), center, q=1.6)
    shaped = np.sin(np.pi * t / s) ** 1.6
    return body * shaped


def c_reveal_shimmer(name):
    rng = rng_for(name)
    s = 1.5
    notes = ["C6", "E6", "G6", "C7", "E7"]
    parts = [(i * 0.055, bell(note_hz(n), 1.2 - i * 0.1, detune=0.0045, decay=0.42), 0.42 - i * 0.03)
             for i, n in enumerate(notes)]
    parts.append((0, bell(note_hz("C5"), 1.3, detune=0.002, decay=0.5, bright=0.5), 0.3))
    air = hp(noise(rng, s), 5000) * env(s, 0.08, curve=4)
    parts.append((0, air, 0.05))
    parts.append((0.1, sparkle(rng, 1.3, 16, lo=3200, hi=7500), 0.9))
    return mix(s, *parts)


def c_tag_slam(name):
    s = 0.15
    thwack = lp(noise(name, s), 2200) * env(s, 0.0008, decay=0.022)
    wood = osc(240, s, f1=150) * env(s, 0.001, decay=0.035)
    knock = osc(720, s) * env(s, 0.001, decay=0.012)
    return 0.8 * thwack + 0.9 * wood + 0.35 * knock


def c_name_slam(name):
    rng = rng_for(name)
    s = 0.34
    thump = osc(110, 0.22, f1=48) * env(0.22, 0.001, decay=0.06)
    smack = lp(noise(rng, 0.06), 1600) * env(0.06, 0.0008, decay=0.012)
    chime = plus(bell(note_hz("G6"), 0.3, detune=0.004, decay=0.1), 0.6 * bell(note_hz("D7"), 0.25, decay=0.07))
    return mix(s, (0, thump, 1.0), (0, smack, 0.5), (0.012, chime, 0.32),
               (0.03, sparkle(rng, 0.28, 3, lo=4000, hi=7000), 0.6))


def c_desc_tick(name):
    s = 0.05
    return (osc(1900, s) * env(s, 0.0006, decay=0.006) +
            0.7 * osc(880, s) * env(s, 0.0008, decay=0.01) +
            0.25 * hp(noise(name, s), 3000) * env(s, 0.0003, decay=0.002))


def c_spin_whoosh(name):
    s = 0.26
    t = t_of(s)
    body = bandpass(noise(name, s), 900 + 700 * np.sin(np.pi * t / s), q=1.2)
    flutter = 0.65 + 0.35 * np.sin(2 * np.pi * 22 * t)
    return lp(body * flutter, 3000, 1) * np.sin(np.pi * t / s) ** 1.3


def c_shimmer_loop(name):
    """Seamless 3.2 s twinkle bed: notes wrap around the loop end."""
    rng = rng_for(name)
    s = 3.2
    n = n_of(s)
    out = np.zeros(n)
    pent = ["C6", "D6", "E6", "G6", "A6", "C7", "D7", "E7"]
    for k in range(14):
        at = int(k * n / 14 + rng.integers(0, n // 28))
        dur = rng.uniform(0.5, 0.9)
        tone = bell(note_hz(pent[rng.integers(0, len(pent))]), dur, detune=0.003,
                    decay=dur * 0.3) * rng.uniform(0.5, 1.0)
        idx = (at + np.arange(len(tone))) % n
        np.add.at(out, idx, tone)
    # Periodic airy bed: random-phase spectrum, so it is circular by construction.
    spec = np.zeros(n // 2 + 1, dtype=complex)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    band = (freqs > 4000) & (freqs < 9000)
    spec[band] = np.exp(1j * rng.uniform(0, 2 * np.pi, band.sum()))
    air = np.fft.irfft(spec, n)
    air /= np.max(np.abs(air))
    return out + 0.04 * air


def c_reveal_out(name):
    s = 0.26
    t = t_of(s)
    f = 330 * (190 / 330) ** (t / s)
    phase = 2 * np.pi * np.cumsum(f) / SR
    hum = (np.sin(phase) + 0.5 * np.sin(1.5 * phase)) * (1 - t / s) ** 1.5
    tail = osc(90, 0.06, f1=60) * env(0.06, 0.001, decay=0.015)
    return mix(s, (0, lp(hum, 1600, 1), 0.6), (0.19, tail, 0.5))


def c_goal_tick(name):
    s = 0.08
    return (osc(note_hz("C7"), s) * env(s, 0.0008, decay=0.018) +
            0.35 * osc(note_hz("G7"), s) * env(s, 0.0008, decay=0.01))


def c_row_flip(name):
    rng = rng_for(name)
    s = 0.11
    flick = bandpass(noise(rng, 0.04), 2400, q=1.5) * env(0.04, 0.001, decay=0.008)
    flap = bandpass(noise(rng, 0.06), 1500, q=1.3) * env(0.06, 0.002, decay=0.012)
    return mix(s, (0, flick, 0.8), (0.035, flap, 1.0))


def c_star_land(name):
    rng = rng_for(name)
    s = 0.42
    t = t_of(0.34)
    f = 260 * (1 + 0.35 * np.exp(-t / 0.05) * np.cos(2 * np.pi * 14 * t))
    boing = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(0.34, 0.002, decay=0.09)
    clink = bell(note_hz("E7"), 0.35, detune=0.006, decay=0.09, bright=1.3)
    return mix(s, (0, boing, 0.7), (0.004, clink, 0.35), (0.02, sparkle(rng, 0.3, 3, lo=4500, hi=7500), 0.5))


def c_stars_total(name):
    rng = rng_for(name)
    s = 1.15
    cymbal = hp(noise(rng, s), 6000, 2) * env(s, 0.06, curve=5)
    ta = (chip_note(note_hz("G5"), 0.14, "soft_square", decay=0.07) +
          0.6 * chip_note(note_hz("B4"), 0.14, "tri", decay=0.07))
    da_t = 0.95
    da = (chip_note(note_hz("C6"), da_t, "soft_square", decay=0.3, vib=0.08) +
          0.7 * chip_note(note_hz("E5"), da_t, "tri", decay=0.3) +
          0.5 * chip_note(note_hz("G5"), da_t, "tri", decay=0.3))
    return mix(s, (0, ta, 0.4), (0.15, lp(da, 5000, 1), 0.35), (0.15, cymbal, 0.12),
               (0.15, bell(note_hz("C7"), 0.9, detune=0.004, decay=0.3), 0.18),
               (0.18, sparkle(rng, 0.9, 10), 0.8))


def c_new_best(name):
    rng = rng_for(name)
    s = 0.55
    parts = [(i * 0.075, chip_note(note_hz(n), 0.11 if i < 2 else 0.36, "soft_square",
                                   decay=0.05 if i < 2 else 0.14), 0.45)
             for i, n in enumerate(["E6", "G6", "C7"])]
    parts.append((0.15, bell(note_hz("C7"), 0.38, detune=0.004, decay=0.12), 0.35))
    parts.append((0.17, sparkle(rng, 0.35, 3, lo=4500, hi=7000), 0.6))
    return mix(s, *parts)


def c_egg_ready(name):
    rng = rng_for(name)
    s = 0.55

    def knock(seed_rng):
        k = osc(520, 0.09, f1=470) * env(0.09, 0.001, decay=0.018)
        hollow = bandpass(noise(seed_rng, 0.09), 900, q=6) * env(0.09, 0.001, decay=0.025)
        return k + 2.5 * hollow

    return mix(s, (0, knock(rng), 0.8), (0.13, knock(rng), 0.7),
               (0.26, bell(note_hz("A6"), 0.28, detune=0.005, decay=0.09), 0.35),
               (0.3, bell(note_hz("E7"), 0.24, decay=0.07), 0.2))


def c_meter_fill(name):
    s = 0.26
    parts = []
    for i in range(8):
        f = 620 * (1500 / 620) ** (i / 7)
        parts.append((i * 0.028, chip_note(f, 0.045, "tri", attack=0.002, decay=0.014), 0.5))
    return mix(s, *parts)


def c_win(name):
    rng = rng_for(name)
    s = 1.25
    parts = [(i * 0.13, chip_note(note_hz(n), 0.17, "soft_square", decay=0.09), 0.42)
             for i, n in enumerate(["C6", "E6", "G6"])]
    hold = 0.85
    chord = (chip_note(note_hz("C7"), hold, "soft_square", decay=0.28, vib=0.1) +
             0.6 * chip_note(note_hz("G5"), hold, "tri", decay=0.28) +
             0.6 * chip_note(note_hz("E5"), hold, "tri", decay=0.28))
    parts.append((0.39, lp(chord, 6000, 1), 0.32))
    parts.append((0.39, bell(note_hz("C7"), 0.8, detune=0.004, decay=0.25), 0.2))
    parts.append((0.42, sparkle(rng, 0.75, 8), 0.8))
    return mix(s, *parts)


def c_lose(name):
    s = 0.95
    a = chip_note(note_hz("E5"), 0.32, "tri", attack=0.015, decay=0.2, vib=0.12)
    b_t = 0.6
    t = t_of(b_t)
    f = note_hz("C5") * (1 - 0.03 * (t / b_t))
    phase = 2 * np.pi * np.cumsum(f) / SR + 0.18 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.2, 0, 1)
    b = (2 / np.pi) * np.arcsin(np.sin(phase)) * env(b_t, 0.02, curve=3)
    under = osc(note_hz("A3"), 0.8) * env(0.8, 0.03, curve=3) * 0.3
    return lp(mix(s, (0, a, 0.6), (0.3, b, 0.65), (0, under, 1.0)), 2400)


def c_egg_wobble(name):
    s = 0.36
    t = t_of(0.3)
    f = 300 * (1 + 0.12 * np.sin(2 * np.pi * 9 * t))
    wob = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(0.3, 0.01, curve=3)
    tok = lambda fr: osc(fr, 0.05) * env(0.05, 0.001, decay=0.01)  # noqa: E731
    return mix(s, (0, tok(620), 0.6), (0.12, tok(560), 0.5), (0.24, tok(600), 0.4), (0.0, lp(wob, 1500, 1), 0.45))


def c_egg_crack_glint(name):
    rng = rng_for(name)
    s = 0.38
    crack = bandpass(noise(rng, 0.03), 3200, q=2) * env(0.03, 0.0005, decay=0.005)
    crack2 = bandpass(noise(rng, 0.025), 2200, q=2) * env(0.025, 0.0005, decay=0.004)
    glint = bell(note_hz("B6"), 0.32, detune=0.006, decay=0.09, bright=1.4)
    return mix(s, (0, crack, 1.0), (0.02, crack2, 0.8), (0.05, glint, 0.35),
               (0.06, sparkle(rng, 0.3, 2, lo=5000, hi=7500), 0.5))


def c_egg_select(name):
    s = 0.15
    pop = osc(420, 0.12, f1=780) * env(0.12, 0.002, decay=0.035)
    top = osc(note_hz("E6"), 0.1) * env(0.1, 0.002, decay=0.03)
    return mix(s, (0, pop, 0.7), (0.025, top, 0.3))


# Extras: AUDIO-HANDOFF "none" cues that are cheap to stand in (not wired yet).
def c_clear_v(name):
    rng = rng_for(name)
    s = 0.95
    t = t_of(0.6)
    whoosh = lp(noise(rng, 0.6), 6000 * (500 / 6000) ** (t / 0.6)) * np.sin(np.pi * t / 0.6)
    parts = [(i * 0.05, bell(note_hz(n), 0.75, detune=0.005, decay=0.25, bright=1.3), 0.35)
             for i, n in enumerate(["G6", "D7", "B6"])]
    parts += [(0.05, whoosh, 0.25), (0.05, sparkle(rng, 0.8, 10, lo=4000, hi=8000), 0.8)]
    return mix(s, *parts)


def c_purchase(name):
    rng = rng_for(name)
    s = 0.6
    cha = bandpass(noise(rng, 0.08), 3500, q=1.2) * env(0.08, 0.001, decay=0.02)
    ching = bell(note_hz("E7"), 0.5, detune=0.008, decay=0.15, bright=1.4) + \
        0.7 * bell(note_hz("B6"), 0.5, detune=0.006, decay=0.14)
    return mix(s, (0, cha, 0.6), (0.07, ching, 0.35), (0.09, sparkle(rng, 0.45, 4, lo=4500, hi=7500), 0.6))


def c_deny(name):
    s = 0.22
    buzz = osc(165, s, wave_="soft_square", vib=0.4, vib_rate=28) * env(s, 0.006, hold=0.1, curve=3)
    return lp(buzz, 900)


def c_deck_button(name):
    s = 0.05
    return (lp(noise(name, s), 4000) * env(s, 0.0004, decay=0.004) +
            0.8 * osc(1400, s, f1=1100) * env(s, 0.0006, decay=0.008))


def c_deck_move(name):
    s = 0.04
    return osc(2100, s, f1=1900) * env(s, 0.0005, decay=0.006)


def c_deck_back(name):
    s = 0.13
    return mix(s, (0, chip_note(note_hz("A5"), 0.06, "tri", decay=0.02), 0.6),
               (0.055, chip_note(note_hz("E5"), 0.075, "tri", decay=0.025), 0.6))


# cue: (builder, level class, loop, where it plays, description)
CUES = {
    # Played in src/ today but with no asset id
    "danger_enter": (c_danger_enter, "ui", False, "BoardDanger: stack goes over the fill line (once)", "soft low two-tone \"uh-oh\""),
    "danger_clear": (c_danger_clear, "ui", False, "BoardDanger: stack drops back under the line", "relieved rising three-bell chime"),
    "deck_boot": (c_deck_boot, "jingle", False, "DeckBoot: Pocket Deck power-on (810 ms in)", "two chip blips into a bright bell bloom"),
    "quest_complete": (c_quest_complete, "jingle", False, "Quest finished / results", "small rising fanfare, smaller than win"),
    "bear_boop": (c_bear_boop, "fx", False, "RevealStage: tapping the pet on the reveal", "plush squeak, up-and-down pitch"),
    "reveal_hush": (c_reveal_hush, "fx", False, "RevealStage t=0: room goes quiet", "short downward suck of air (closing low-pass noise)"),
    "spot_on": (c_spot_on, "fx", False, "RevealStage t=0.12: stage light", "soft thunk with a warm hum swell"),
    "streak_whoosh": (c_streak_whoosh, "fx", False, "RevealStage t=0.30: streak", "airy rising band-pass noise swipe"),
    "reveal_shimmer": (c_reveal_shimmer, "jingle", False, "RevealStage t=0.42: the main reveal (pitched +3 st for rare)", "detuned bell arpeggio C-E-G-C-E with glitter"),
    "tag_slam": (c_tag_slam, "fx", False, "RevealStage t=0.48: rarity tag", "paper-and-wood thwack"),
    "name_slam": (c_name_slam, "fx", False, "RevealStage t=0.60: pet name", "low thump with a chime on top"),
    "desc_tick": (c_desc_tick, "tick", False, "RevealStage t=0.84: description", "light wooden tick"),
    "spin_whoosh": (c_spin_whoosh, "fx", False, "RevealStage: drag-spin the pet (repitched by speed)", "soft cloth whirl"),
    "shimmer_loop": (c_shimmer_loop, "loop", True, "Reveal idle bed (very quiet)", "seamless pentatonic twinkle bed + air"),
    "reveal_out": (c_reveal_out, "fx", False, "RevealStage exit", "hum closing down, tiny thud"),
    "goal_tick": (c_goal_tick, "tick", False, "DeckResults: each goal checked (repitched up)", "bright check \"tik\""),
    "row_flip": (c_row_flip, "tick", False, "DeckResults: result rows flip in", "soft card flip"),
    "star_land": (c_star_land, "fx", False, "DeckResults: Stars land", "boing + metal clink"),
    "stars_total": (c_stars_total, "jingle", False, "DeckResults: Stars total payoff", "two-note ta-da over a soft cymbal bloom"),
    "new_best": (c_new_best, "jingle", False, "DeckResults: new best score", "rising three-note flourish"),
    "egg_ready": (c_egg_ready, "fx", False, "DeckResults finale: can hatch an egg", "hollow knock-knock with a twinkle"),
    "meter_fill": (c_meter_fill, "ui", False, "DeckResults: meter fills (also on loss, quiet)", "eight rising blips"),
    "win": (c_win, "jingle", False, "DeckResults: round won", "3-note rising jingle into a held chord"),
    "lose": (c_lose, "jingle", False, "DeckResults: round lost", "gentle 2-note descending \"aww\" (never harsh)"),
    # Spec'd, not wired yet
    "danger_tick": (c_danger_tick, "tick", False, "Danger state: quiet tick per second (doubles in last second); spec 6.3", "soft wooden tick"),
    "egg_wobble": (c_egg_wobble, "fx", False, "Hatch preview: egg wobbles", "three little toks over a wobbling hum"),
    "egg_crack_glint": (c_egg_crack_glint, "fx", False, "Hatch preview: crack glint", "tiny crack + high glint bell"),
    "egg_select": (c_egg_select, "ui", False, "Hatch preview: egg chosen", "soft rising pop"),
    # AUDIO-HANDOFF cues with no sound at all (optional upload)
    "clear_v": (c_clear_v, "jingle", False, "Top tier (V) clears (handoff; not wired)", "glass bells with a downward whoosh"),
    "purchase": (c_purchase, "fx", False, "Buying an egg (handoff; not wired)", "noise \"cha\" + coin \"ching\""),
    "deny": (c_deny, "ui", False, "Unusable/unaffordable button (handoff; not wired)", "dull soft low buzz"),
    "deck_button": (c_deck_button, "tick", False, "Deck A/B/screen button (handoff; uses menu now)", "crisp plastic click"),
    "deck_move": (c_deck_move, "tick", False, "Deck D-pad move (handoff; uses aim now)", "tiny soft tick"),
    "deck_back": (c_deck_back, "ui", False, "Deck back arrow (handoff; uses menu now)", "descending two-note blip"),
}


# ---------------------------------------------------------------- finishing
def finish(x, level, loop):
    x = np.asarray(x, dtype=float)
    x = x - np.mean(x) if loop else x
    if not loop:
        # Trim leading near-silence, then 1.5 ms fade-in and 12 ms fade-out.
        nz = np.flatnonzero(np.abs(x) > 1e-4 * np.max(np.abs(x)))
        x = x[nz[0]:] if len(nz) else x
        fi, fo = n_of(0.0015), n_of(0.012)
        x[:fi] *= np.linspace(0, 1, fi)
        x[-fo:] *= np.linspace(1, 0, fo) ** 2
    rms_db, peak_db = LEVELS[level]
    rms = np.sqrt(np.mean(x ** 2))
    x = x * (10 ** (rms_db / 20) / rms)
    peak = np.max(np.abs(x))
    ceiling = 10 ** (peak_db / 20)
    if peak > ceiling:
        x = x * (ceiling / peak)
    return x


def write_wav(path, x):
    pcm = np.round(np.clip(x, -1, 32767 / 32768) * 32768).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return pcm.astype(float) / 32768


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-ogg", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    ffmpeg = None if args.no_ogg else shutil.which("ffmpeg")
    manifest = []
    print(f"{'cue':16s} {'sec':>6s} {'peak':>7s} {'rms':>7s} {'seam':>7s}  ogg")
    for cue, (build, level, loop, where, desc) in CUES.items():
        x = finish(build(cue), level, loop)
        wav = OUT / f"egg_drop_{cue}.wav"
        y = write_wav(wav, x)
        peak = float(np.max(np.abs(y)))
        rms = float(np.sqrt(np.mean(y ** 2)))
        seam = float(abs(y[0] - y[-1])) if loop else None
        assert peak < 1.0 and not np.any(np.abs(y) >= 32767 / 32768), f"{cue} clips"
        ogg_name = None
        if ffmpeg:
            ogg = wav.with_suffix(".ogg")
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis",
                            "-q:a", "6", "-map_metadata", "-1", str(ogg)], check=True)
            ogg_name = ogg.name
        seconds = round(len(y) / SR, 3)
        manifest.append({"cue": cue, "file": wav.name, "ogg": ogg_name, "seconds": seconds, "loop": loop,
                         "peak_dbfs": round(20 * math.log10(peak), 1),
                         "rms_dbfs": round(20 * math.log10(rms), 1),
                         "where": where, "description": desc, "placeholder": True})
        seam_s = f"{seam:.4f}" if seam is not None else "-"
        print(f"{cue:16s} {seconds:6.3f} {20*math.log10(peak):7.1f} {20*math.log10(rms):7.1f} {seam_s:>7s}  "
              f"{'yes' if ogg_name else 'no'}")
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"\n{len(manifest)} placeholder cues -> {OUT}")


if __name__ == "__main__":
    main()
