"""New-tip chime candidates, synthesised from scratch (beta 12 QA S2, TipChime.lua).

Proposal audio for Spencer to listen to: nothing here is uploaded or wired. Three candidates for the
`tip_chime` cue, each two soft mallet notes going up (DASH-DECK-UI-LOOK S2), built only from decaying
sine partials and a little shaped noise in numpy. No samples, no recordings, no AI audio. Fixed seed,
so every run is byte-identical.

  tip_chime_a_wood     wooden xylophone pair, G5 then C6: short, dry, round
  tip_chime_b_kalimba  kalimba pair, E5 then B5: soft thumb pluck, a little longer ring
  tip_chime_c_glock    felt-beater glockenspiel pair, C6 then G6, low-passed under 3 kHz: the airiest

The game plays it at volume .25 (under the Stars pickup), never more than once in 20 s, never in a round,
race or hatch, with +/- 3% pitch per play.

Run from the repository root:  python scripts/synth_tip_chime.py
Writes: assets/audio/drafts/tip_chime_{a_wood,b_kalimba,c_glock}.wav (44.1 kHz, 16-bit, mono)
"""
import math
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join("assets", "audio", "drafts")
RNG = np.random.default_rng(20261123)


def note_hz(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semis = names[name[0]] + 12 * (int(name[-1]) + 1)
    return 440.0 * 2 ** ((semis - 69) / 12)


def onepole_lowpass(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def mallet(freq, length, partials, attack, click=0.0, click_cut=4000.0):
    """partials: list of (ratio, gain, decay seconds)."""
    t = np.arange(int(SR * length)) / SR
    out = np.zeros_like(t)
    for ratio, gain, decay in partials:
        f = freq * ratio
        if f > SR / 2.2:
            continue
        out += gain * np.sin(2 * math.pi * f * t + RNG.uniform(0, 2 * math.pi)) * np.exp(-t / decay)
    env = np.minimum(1.0, t / attack)  # soft onset: no click
    out *= env
    if click > 0:
        n = int(SR * .012)
        burst = RNG.standard_normal(n) * np.exp(-np.arange(n) / (SR * .003))
        out[:n] += click * onepole_lowpass(burst, click_cut)
    return out


def pair(make, first, second, gap, length, second_gain=.9):
    total = np.zeros(int(SR * length))
    a = make(note_hz(first))
    b = make(note_hz(second)) * second_gain
    total[: len(a)] += a[: len(total)]
    start = int(SR * gap)
    end = min(len(total), start + len(b))
    total[start:end] += b[: end - start]
    return total


def finish(x, fade=.02, peak_db=-1.0):
    n = int(SR * fade)
    x[-n:] *= np.linspace(1, 0, n)
    x /= np.max(np.abs(x))
    return x * 10 ** (peak_db / 20)


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(path, f"{len(x) / SR:.2f} s")


def wood(f):
    # Tuned bar: fundamental, the 4th partial (bars are tuned to ~1:4), a faint 10th; short and dry.
    return mallet(f, .5, [(1, 1, .16), (3.98, .32, .05), (9.9, .06, .018)], attack=.0025, click=.08, click_cut=2500)


def kalimba(f):
    # Tine: strong fundamental with a long ring, an inharmonic upper mode that dies fast (the "pluck").
    return mallet(f, .9, [(1, 1, .42), (2.0, .08, .18), (5.92, .22, .045)], attack=.004, click=.04, click_cut=1800)


def glock(f):
    # Steel bar, felt beater: soft onset, bar modes 1 : 2.76 : 5.40, everything above 3 kHz rolled off.
    x = mallet(f, 1.0, [(1, 1, .55), (2.76, .25, .16), (5.40, .08, .06)], attack=.006)
    return onepole_lowpass(x, 3000)


def main():
    write("tip_chime_a_wood", finish(pair(wood, "G5", "C6", .11, .62)))
    write("tip_chime_b_kalimba", finish(pair(kalimba, "E5", "B5", .13, .95)))
    write("tip_chime_c_glock", finish(pair(glock, "C6", "G6", .12, 1.05)))


if __name__ == "__main__":
    main()
