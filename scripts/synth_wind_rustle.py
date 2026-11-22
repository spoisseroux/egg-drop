"""Leaf rustle loop for the wind (ALIVE-BRIEF-2026-11-22 section 3, row D1).

Synthesised from scratch with numpy: shaped white noise only. No samples, no recordings,
no AI audio. A fixed seed makes every run byte-identical.

What it is: many small leaf ticks (short band-passed noise grains, each with its own pitch,
length and loudness, arriving in loose flurries) over a quiet band-limited bed. It is meant
to read as leaves touching, not as air moving: the energy sits around 1 to 4 kHz, there is
nothing strong above 7 kHz (that is where "hiss" and "surf" live) and nothing below 400 Hz
(no rumble). The game fades Sound.Volume 0 to .10 with the gust, so the file itself holds a
steady, gently breathing texture with no gust shape of its own.

Seamless by construction: the whole buffer is built on a circle. The bed and every filter
are made in the frequency domain of the full loop (so they are periodic in the loop length),
the density curve is a sum of whole-number cycles per loop, and ticks that run past the end
wrap to the start. There is no crossfade and no seam to hide.

Run from the repository root:  python -I scripts/synth_wind_rustle.py
Writes: assets/audio/custom/egg_drop_wind_rustle.wav  (44.1 kHz, 16-bit, mono, 14 s)
        artifacts/alive-2026-11-22/wind_rustle_report.json
"""
import json
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAV = os.path.join(ROOT, "assets", "audio", "custom", "egg_drop_wind_rustle.wav")
REPORT = os.path.join(ROOT, "artifacts", "alive-2026-11-22", "wind_rustle_report.json")

SR = 44100
SECONDS = 14.0
N = int(SR * SECONDS)
SEED = 20261122
PEAK_DBFS = -6.0
SUGGESTED_VOLUME = 0.10      # Sound.Volume at gust peak (row D1); 0 at rest

BED_SHARE = 0.30             # bed RMS as a share of tick RMS: the ticks lead, the bed fills
TICKS_PER_SECOND = 230       # mean; the density curve moves it between about 0.45x and 1.7x
LOW_CUT, HIGH_CUT = 450.0, 6200.0   # final loop-wide band edges (raised-cosine skirts)


def db(x):
    return 20.0 * np.log10(max(float(x), 1e-12))


def band_gain(freqs, lo, hi, lo_width, hi_width):
    """Raised-cosine band-pass gain: 0 below lo-lo_width, 1 from lo to hi, 0 above hi+hi_width."""
    g = np.ones_like(freqs)
    rise = np.clip((freqs - (lo - lo_width)) / lo_width, 0.0, 1.0)
    fall = np.clip(((hi + hi_width) - freqs) / hi_width, 0.0, 1.0)
    return g * (0.5 - 0.5 * np.cos(np.pi * rise)) * (0.5 - 0.5 * np.cos(np.pi * fall))


def loop_curve(rng, harmonics, depth):
    """A smooth positive curve that repeats exactly once per loop: whole cycles only."""
    t = np.arange(N) / N
    c = np.zeros(N)
    for k in harmonics:
        c += rng.uniform(0.5, 1.0) / np.sqrt(k) * np.sin(2 * np.pi * (k * t + rng.uniform()))
    c /= np.max(np.abs(c))
    return 1.0 + depth * c


def make_bed(rng):
    """Quiet airy fill: noise shaped in the loop's own frequency domain, tilted down so the
    weight is at 1 to 2 kHz, then breathed by a slow curve. Periodic in N by construction."""
    spec = np.fft.rfft(rng.standard_normal(N))
    f = np.fft.rfftfreq(N, 1.0 / SR)
    shape = band_gain(f, 700.0, 3800.0, 300.0, 2400.0)
    shape *= (np.maximum(f, 200.0) / 1500.0) ** -0.5          # about -3 dB per octave
    bed = np.fft.irfft(spec * shape, N)
    return bed * loop_curve(rng, (1, 2, 3, 5, 8, 13), 0.30)


def make_ticks(rng):
    """Leaf contacts. Each is a few to a few tens of milliseconds of noise, band-passed
    around its own centre (900 Hz to 5.2 kHz, more of them low than high), with a soft
    attack so none of them clicks. Arrival follows a loop-periodic density curve with
    slow swells and faster flurries, so the rustle thickens and thins like real foliage."""
    density = loop_curve(rng, (1, 2, 3), 0.38) * loop_curve(rng, (7, 11, 17, 23, 31), 0.30)
    density = np.clip(density, 0.25, None)
    density /= density.mean()

    count = int(TICKS_PER_SECOND * SECONDS)
    # Inverse-CDF draw of start samples from the density curve.
    cdf = np.cumsum(density)
    starts = np.searchsorted(cdf, rng.uniform(0, cdf[-1], count))

    out = np.zeros(N)
    for start in starts:
        centre = 900.0 * (5200.0 / 900.0) ** (rng.uniform() ** 1.15)  # skewed toward the low end
        # Lower leaves are longer and softer-edged; high ones are quick.
        seconds = rng.uniform(0.006, 0.020) * (2600.0 / centre) ** 0.5 * rng.choice((1.0, 1.0, 2.2))
        n = max(96, int(seconds * SR))
        width = centre * rng.uniform(0.35, 0.75)                      # wide: papery, not pitched
        grain = rng.standard_normal(n)
        f = np.fft.rfftfreq(n, 1.0 / SR)
        g = np.exp(-0.5 * ((f - centre) / (width * 0.5)) ** 2)
        grain = np.fft.irfft(np.fft.rfft(grain) * g, n)
        attack = rng.uniform(0.12, 0.35)
        x = np.arange(n) / n
        env = np.where(x < attack, 0.5 - 0.5 * np.cos(np.pi * x / attack),
                       np.exp(-(x - attack) / (1.0 - attack) * rng.uniform(3.0, 5.5)))
        env *= 0.5 + 0.5 * np.cos(np.pi * np.clip((x - 0.8) / 0.2, 0.0, 1.0))   # close to zero at the end
        grain *= env
        grain /= np.sqrt(np.mean(grain ** 2)) + 1e-12
        # Most ticks are small; a few stand out. High ticks are held back a little (less hiss).
        gain = rng.lognormal(mean=0.0, sigma=0.40) * (2600.0 / max(centre, 2600.0)) ** 0.6
        idx = (start + np.arange(n)) % N                               # wrap around the loop
        np.add.at(out, idx, gain * np.sqrt(n / SR) * grain)
    return out


def loop_filter(signal):
    """Final band limit, applied on the loop's circle so it cannot open a seam."""
    f = np.fft.rfftfreq(N, 1.0 / SR)
    g = band_gain(f, LOW_CUT, HIGH_CUT, 200.0, 1100.0)
    return np.fft.irfft(np.fft.rfft(signal) * g, N)


def synth():
    rng = np.random.default_rng(SEED)
    bed = make_bed(rng)
    ticks = make_ticks(rng)
    bed *= BED_SHARE * np.sqrt(np.mean(ticks ** 2)) / np.sqrt(np.mean(bed ** 2))
    mix = ticks + bed
    # Round off the rare tick that lands on top of others, so no single leaf snaps and the
    # body of the sound is not held 20 dB under one peak. Pointwise, so the loop stays whole.
    knee = 4.5 * np.sqrt(np.mean(mix ** 2))
    mix = loop_filter(knee * np.tanh(mix / knee))
    mix -= mix.mean()
    mix *= 10 ** (PEAK_DBFS / 20.0) / np.max(np.abs(mix))
    return mix


def band_share(power, f, lo, hi):
    return float(power[(f >= lo) & (f < hi)].sum() / power.sum())


def third_octave(x):
    """Smoothed spectrum in dB at third-octave centres 500 Hz to 8 kHz."""
    p = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    centres = 500.0 * 2 ** (np.arange(13) / 3.0)
    return centres, np.array([10 * np.log10(p[(f >= c / 2 ** (1 / 6)) & (f < c * 2 ** (1 / 6))].mean() + 1e-20)
                              for c in centres])


def measure(pcm):
    x = pcm.astype(np.float64) / 32768.0
    power = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    steps = np.abs(np.diff(x))
    seam = abs(float(x[0] - x[-1]))

    win = SR // 2
    hop = SR // 20
    looped = np.concatenate([x, x[:win]])                    # windows wrap, as playback does
    rms_windows = np.array([np.sqrt(np.mean(looped[i:i + win] ** 2)) for i in range(0, len(x), hop)])

    # Spectrum either side of the wrap, set against how much any two half-seconds differ.
    _, tail = third_octave(x[-win:])
    _, head = third_octave(x[:win])
    wrap_diff = float(np.mean(np.abs(tail - head)))
    blocks = [third_octave(x[i:i + win])[1] for i in range(0, len(x) - win + 1, win)]
    neighbour = [float(np.mean(np.abs(a - b))) for a, b in zip(blocks[:-1], blocks[1:])]

    rms = float(np.sqrt(np.mean(x ** 2)))
    peak = float(np.max(np.abs(x)))
    return {
        "seconds": round(len(x) / SR, 3),
        "sample_rate": SR, "channels": 1, "bits": 16, "samples": int(len(x)),
        "peak_dbfs": round(db(peak), 2),
        "clipped_samples": int(np.sum(np.abs(pcm.astype(np.int32)) >= 32767)),
        "rms_dbfs": round(db(rms), 2),
        "crest_db": round(db(peak) - db(rms), 2),
        "dc_offset": round(float(x.mean()), 6),
        "spectral_centroid_hz": round(float((f * power).sum() / power.sum()), 1),
        "energy_share": {
            "below_300_hz": round(band_share(power, f, 0, 300), 6),
            "300_to_600_hz": round(band_share(power, f, 300, 600), 4),
            "600_to_5000_hz": round(band_share(power, f, 600, 5000), 4),
            "5000_to_7000_hz": round(band_share(power, f, 5000, 7000), 4),
            "above_7000_hz": round(band_share(power, f, 7000, SR), 6),
        },
        "loop_seam": {
            "step_last_to_first": round(seam, 6),
            "median_sample_step": round(float(np.median(steps)), 6),
            "p95_sample_step": round(float(np.percentile(steps, 95)), 6),
            "max_sample_step": round(float(steps.max()), 6),
            "seam_over_median": round(seam / float(np.median(steps)), 2),
            "third_octave_diff_db_across_wrap": round(wrap_diff, 2),
            "third_octave_diff_db_neighbouring_half_seconds_mean": round(float(np.mean(neighbour)), 2),
            "third_octave_diff_db_neighbouring_half_seconds_max": round(float(np.max(neighbour)), 2),
            "rms_dbfs_last_100_ms": round(db(np.sqrt(np.mean(x[-SR // 10:] ** 2))), 2),
            "rms_dbfs_first_100_ms": round(db(np.sqrt(np.mean(x[:SR // 10] ** 2))), 2),
        },
        "half_second_windows": {
            "loudest_rms_dbfs": round(db(rms_windows.max()), 2),
            "loudest_at_s": round(float(np.argmax(rms_windows) * hop / SR), 2),
            "quietest_rms_dbfs": round(db(rms_windows.min()), 2),
            "quietest_at_s": round(float(np.argmin(rms_windows) * hop / SR), 2),
            "spread_db": round(db(rms_windows.max()) - db(rms_windows.min()), 2),
        },
    }


def main():
    mix = synth()
    pcm = np.round(mix * 32767.0).astype(np.int16)
    os.makedirs(os.path.dirname(WAV), exist_ok=True)
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with wave.open(WAV, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())

    report = {
        "file": os.path.relpath(WAV, ROOT).replace("\\", "/"),
        "brief": "ALIVE-BRIEF-2026-11-22 section 3, row D1",
        "method": "numpy shaped noise only, seed %d; built on a circle, so the loop has no crossfade" % SEED,
        "judged_by": "numbers only; nobody has listened to this file yet",
        "suggested_volume_at_gust_peak": SUGGESTED_VOLUME,
        "ticks": int(TICKS_PER_SECOND * SECONDS),
        "measurements": measure(pcm),
    }
    with open(REPORT, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)
        fh.write("\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
