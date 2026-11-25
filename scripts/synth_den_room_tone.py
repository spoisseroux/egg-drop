"""The Play Den's room tone (WORLD-FINISH-LOOK section 5, "Sound zones": "a soft room tone"; slice F).

Synthesised from scratch with numpy: shaped noise and a few damped sines. No samples, no recordings, no AI audio. A
fixed seed makes every run byte-identical.

What it is: the air of a small earth-stone room, heard from inside, under the garden. Three layers over one loop:
  A. room air: noise 45 to 380 Hz, a broad lump near 110 Hz (the room's size), very slowly breathing (8 percent, 2
     cycles a loop);
  B. a breath of high air: noise 1.8 to 5 kHz, 26 dB under A, so the tone is not a dull hum on a phone speaker;
  C. drips: five far water drips a loop (a 900 to 1,500 Hz sine falling 6 percent in 40 ms, a 2 ms tick before it),
     spaced unevenly, each 18 to 24 dB under A's peak.
No pitch of its own, no swell, no fade. Quiet by design: AmbientAudio plays it at RoomToneVolume .08 inside the den
only, eased over .6 s with the rest of the zone's mix.

Seamless by construction: every filter is applied in the frequency domain of the whole loop (periodic in its length),
the slow curve has whole cycles a loop, and a drip that would run past the end wraps to the start.

Run from the repository root:  python -I scripts/synth_den_room_tone.py
Writes: assets/audio/custom/egg_drop_den_room_tone.wav    (44.1 kHz, 16-bit, mono, 24 s)
        artifacts/qa-2026-11-26-beta21/slice-f/den_room_tone_report.json
Spencer's ears decide; these numbers only keep a bad file from reaching him.
"""
import hashlib
import json
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAV = os.path.join(ROOT, "assets", "audio", "custom", "egg_drop_den_room_tone.wav")
REPORT = os.path.join(ROOT, "artifacts", "qa-2026-11-26-beta21", "slice-f", "den_room_tone_report.json")

SR = 44100
SECONDS = 24.0
N = int(SR * SECONDS)
SEED = 20261126
PEAK_DBFS = -6.0
RMS_TARGET_DBFS = -24.0

F = np.fft.rfftfreq(N, 1.0 / SR)
T = np.arange(N) / SR


def ramp(f, a, b):
    k = np.clip((f - a) / (b - a), 0, 1)
    return .5 - .5 * np.cos(np.pi * k)


def loop_filter(x, gain):
    return np.fft.irfft(np.fft.rfft(x) * gain, len(x))


def band_noise(rng, lo, hi, lo_w, hi_w):
    g = ramp(F, lo - lo_w, lo) * (1 - ramp(F, hi, hi + hi_w))
    return loop_filter(rng.standard_normal(N), g)


def rms(x):
    return float(np.sqrt(np.mean(np.square(x))))


def db(x):
    return 20 * np.log10(max(float(x), 1e-12))


def room_air(rng):
    air = band_noise(rng, 45, 380, 20, 160)
    lump = np.exp(-.5 * (np.log2(np.maximum(F, 1) / 110) / 1.1) ** 2)
    air = loop_filter(air, lump)
    breathe = 1 + .08 * np.sin(2 * np.pi * 2 * T / SECONDS + rng.uniform(0, 2 * np.pi))
    return air / rms(air) * breathe


def high_air(rng):
    x = band_noise(rng, 1800, 5000, 600, 2000)
    return x / rms(x)


def drips(rng):
    out = np.zeros(N)
    starts = np.sort(rng.uniform(0, SECONDS, 5))
    for at in starts:
        f0 = rng.uniform(900, 1500)
        length = int(.09 * SR)
        t = np.arange(length) / SR
        freq = f0 * (1 - .06 * np.minimum(t / .04, 1))
        phase = 2 * np.pi * np.cumsum(freq) / SR
        tone = np.sin(phase) * np.exp(-t / .018) * np.minimum(1, t / .0015)
        tick_len = int(.002 * SR)
        tick = rng.standard_normal(tick_len) * np.hanning(tick_len) * .35
        sound = np.concatenate([tick, tone]) * 10 ** (-rng.uniform(18, 24) / 20)
        i = int(at * SR)
        idx = (np.arange(len(sound)) + i) % N
        out[idx] += sound
    return out


def main():
    rng = np.random.default_rng(SEED)
    a = room_air(rng)
    b = high_air(rng) * 10 ** (-26 / 20)
    c = drips(rng) * np.max(np.abs(a))
    x = a + b + c
    x -= np.mean(x)
    x *= 10 ** (RMS_TARGET_DBFS / 20) / rms(x)
    peak = np.max(np.abs(x))
    if peak > 10 ** (PEAK_DBFS / 20):
        x *= 10 ** (PEAK_DBFS / 20) / peak
    pcm = np.round(np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(os.path.dirname(WAV), exist_ok=True)
    with wave.open(WAV, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    y = pcm.astype(float) / 32767
    seam = abs(float(y[0] - y[-1]))
    step = float(np.max(np.abs(np.diff(y))))
    report = {"seconds": SECONDS, "sample_rate": SR, "peak_dbfs": round(db(np.max(np.abs(y))), 2),
              "rms_dbfs": round(db(rms(y)), 2), "seam_step": round(seam, 5), "largest_step": round(step, 5),
              "sha256": hashlib.sha256(open(WAV, "rb").read()).hexdigest()}
    assert report["peak_dbfs"] <= PEAK_DBFS + .01, report
    assert seam <= step + 1e-9, report  # the loop's join is no bigger than any step inside it
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
