"""Garden fountain loop for the Aero stone fountain (LOOK-R3 section 3, Fable 2026-11-23).

Synthesised from scratch with numpy: shaped noise, short noise grains and short sine plinks. No samples, no
recordings, no AI audio. A fixed seed makes every run byte-identical.

What it is: small water falling into water, close by. Four layers over one loop-wide band limit:
  A. basin splash bed: noise 900 to 5,000 Hz (centred near 2.2 kHz), made lumpy by a 25-60 Hz flutter (35 percent);
  B. spill streams: eight unrelated narrow bands 1.4 to 3.6 kHz, each wandering 6 percent and fluttering 12-30 Hz;
  C. jet patter: short sine plinks starting 2.2 to 6.5 kHz, pitch RISING 10 to 25 percent, 6 to 22 ms, ~55 a second;
  D. ticks: 3 to 8 ms noise grains in 3 to 8 kHz, ~30 a second.
Only C and D's density and B's level move, each at most 15 percent, on 3, 4 and 5 cycles per loop. Layer A never
moves. Nothing below 500 Hz (40 dB down by 350), nothing above 9 kHz (30 dB down by 11 kHz), no falling pitch, no
swell, no fade: the "toilet flush" the wind rustle became was a noise wash that swelled and restarted.

Seamless by construction: every filter is applied in the frequency domain of the whole loop (periodic in its length),
every slow curve and pitch wander has a whole number of cycles per loop, and grains that run past the end wrap to the
start. There is no crossfade and no seam to hide.

Run from the repository root:  python -I scripts/synth_fountain_loop.py
Writes: assets/audio/custom/egg_drop_fountain_loop.wav    (44.1 kHz, 16-bit, mono, 32 s)
        artifacts/world-pass-2026-11-22/reexport/r5/fountain_loop_report.json
        artifacts/world-pass-2026-11-22/reexport/r5/fountain_loop_spectrogram.png
Spencer's ears decide; these numbers only keep a bad file from reaching him.
"""
import json
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAV = os.path.join(ROOT, "assets", "audio", "custom", "egg_drop_fountain_loop.wav")
OUT = os.path.join(ROOT, "artifacts", "world-pass-2026-11-22", "reexport", "r5")
REPORT = os.path.join(OUT, "fountain_loop_report.json")
SPECTRO = os.path.join(OUT, "fountain_loop_spectrogram.png")

SR = 44100
SECONDS = 32.0
N = int(SR * SECONDS)
SEED = 20261123
PEAK_DBFS = -6.0
RMS_TARGET_DBFS = -21.0

# Relative RMS levels (dB) of the layers, LOOK-R3 3.
LEVEL = {"A": 0.0, "B": -5.0, "C": -7.0, "D": -12.0}
VARY = 0.15  # the slow variation's ceiling (share)

F = np.fft.rfftfreq(N, 1.0 / SR)
T = np.arange(N) / SR


def db(x):
    return 20 * np.log10(max(float(x), 1e-12))


def rms(x):
    return float(np.sqrt(np.mean(np.square(x))))


def ramp(f, a, b):
    """0 at a, 1 at b (raised cosine), on a frequency axis."""
    k = np.clip((f - a) / (b - a), 0, 1)
    return .5 - .5 * np.cos(np.pi * k)


def loop_filter(x, gain):
    return np.fft.irfft(np.fft.rfft(x) * gain, len(x))


def band_noise(rng, lo, hi, lo_w, hi_w):
    """Periodic noise in lo..hi with raised-cosine skirts lo_w / hi_w wide."""
    g = ramp(F, lo - lo_w, lo) * (1 - ramp(F, hi, hi + hi_w))
    return loop_filter(rng.standard_normal(N), g)


def unit(x):
    return x / max(np.max(np.abs(x)), 1e-12)


def slow_curve(rng, cycles, depth):
    """1 + depth * a whole-cycle sine: periodic in the loop."""
    return 1 + depth * np.sin(2 * np.pi * cycles * T / SECONDS + rng.uniform(0, 2 * np.pi))


def make_bed(rng):
    bed = band_noise(rng, 900, 5000, 350, 1800)
    # Centre near 2.2 kHz: a broad log-Gaussian tilt, 1.4 octaves wide.
    tilt = np.exp(-.5 * (np.log2(np.maximum(F, 1) / 2200) / 1.4) ** 2)
    bed = loop_filter(bed, tilt)
    flutter = unit(band_noise(rng, 25, 60, 8, 10))
    return bed * (1 + .35 * flutter)


def analytic_baseband(rng, half_width):
    """Complex periodic lowpass noise (a narrow band moved to 0 Hz)."""
    full = np.fft.fftfreq(N, 1.0 / SR)
    spec = np.fft.fft(rng.standard_normal(N) + 1j * rng.standard_normal(N))
    spec *= 1 - ramp(np.abs(full), half_width, half_width * 1.6)
    return np.fft.ifft(spec)


def make_streams(rng):
    out = np.zeros(N)
    centres = np.exp(np.linspace(np.log(1400), np.log(3600), 8))
    for c in centres:
        c = round(c * SECONDS) / SECONDS * (1 + rng.uniform(-.03, .03))
        c = round(c * SECONDS) / SECONDS            # whole cycles per loop: the carrier closes on itself
        width = c * (2 ** .125 - 2 ** -.125)        # a quarter octave
        z = analytic_baseband(rng, width / 2)
        wander_hz = round(rng.uniform(.3, .8) * SECONDS) / SECONDS
        # f(t) = c (1 + .06 sin(2 pi w t + p)); its phase integral over whole wander cycles adds nothing.
        p = rng.uniform(0, 2 * np.pi)
        phase = 2 * np.pi * c * T - .06 * c / wander_hz * np.cos(2 * np.pi * wander_hz * T + p)
        stream = np.real(z * np.exp(1j * phase))
        flutter = unit(band_noise(rng, 12, 30, 4, 6))
        stream *= 1 + .5 * flutter
        out += unit(stream) * rng.uniform(.7, 1.0)
    return out * slow_curve(rng, 5, VARY * .8)


def place(out, grain, at):
    n = len(grain)
    end = at + n
    if end <= N:
        out[at:end] += grain
    else:
        k = N - at
        out[at:] += grain[:k]
        out[:end - N] += grain[k:]


def scatter_times(rng, mean_rate, cycles):
    """Random grain times whose density follows a whole-cycle curve (rejection sampling)."""
    curve = slow_curve(rng, cycles, VARY * .8)
    count = rng.poisson(mean_rate * SECONDS * (1 + VARY))
    times = rng.uniform(0, SECONDS, count)
    keep = rng.uniform(0, 1 + VARY, count) < curve[(times * SR).astype(int) % N]
    return np.sort(times[keep])


def make_patter(rng):
    out = np.zeros(N)
    for t in scatter_times(rng, 55, 3):
        dur = rng.uniform(.006, .022)
        n = int(dur * SR)
        tt = np.arange(n) / SR
        f0 = rng.uniform(2200, 6500)
        rise = rng.uniform(.10, .25)
        freq = f0 * (1 + rise * tt / dur)            # rising only
        ph = 2 * np.pi * np.cumsum(freq) / SR + rng.uniform(0, 2 * np.pi)
        env = np.minimum(tt / .001, 1) * np.exp(-tt / (dur / 4))
        loud = 10 ** ((-18 + 18 * rng.uniform(0, 1) ** 2.5) / 20)   # mostly quiet ones
        place(out, np.sin(ph) * env * loud, int(t * SR) % N)
    return out


def make_ticks(rng):
    out = np.zeros(N)
    for t in scatter_times(rng, 30, 4):
        n = int(rng.uniform(.003, .008) * SR)
        env = np.hanning(n)
        loud = 10 ** (rng.uniform(-12, 0) / 20)
        place(out, rng.standard_normal(n) * env * loud, int(t * SR) % N)
    # The ticks' band, loop-wide (circular, so it stays seamless).
    return loop_filter(out, ramp(F, 2400, 3000) * (1 - ramp(F, 8000, 9000)))


def synth():
    rng = np.random.default_rng(SEED)
    layers = {"A": make_bed(rng), "B": make_streams(rng), "C": make_patter(rng), "D": make_ticks(rng)}
    mix = np.zeros(N)
    for name, x in layers.items():
        mix += x / rms(x) * 10 ** (LEVEL[name] / 20)
    # The band limit for everything: 40 dB down by 350 Hz, 30 dB down by 11 kHz.
    mix = loop_filter(mix, ramp(F, 350, 540) * (1 - ramp(F, 8600, 10800)))
    mix *= 10 ** (RMS_TARGET_DBFS / 20) / rms(mix)
    # A sample-wise soft limit above the peak ceiling (memoryless, so the loop stays seamless).
    ceiling = 10 ** (PEAK_DBFS / 20)
    knee = ceiling * .7
    over = np.abs(mix) > knee
    mix[over] = np.sign(mix[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(mix[over]) - knee) / (ceiling - knee)))
    # The limiter's corners spray a little above 9 kHz: band-limit again, then pull the peak back to the ceiling.
    mix = loop_filter(mix, ramp(F, 350, 540) * (1 - ramp(F, 8600, 10800)))
    mix *= min(1.0, ceiling / np.max(np.abs(mix)))
    return mix, layers


def band_db(power, lo, hi):
    total = power.sum()
    part = power[(F >= lo) & (F < hi)].sum()
    return round(10 * np.log10(max(part / total, 1e-20)), 1)


def measure(x):
    power = np.abs(np.fft.rfft(x)) ** 2
    win = int(.5 * SR)
    windows = [db(rms(x[i:i + win])) for i in range(0, N - win + 1, win)]
    seam = np.concatenate([x[-win:], x[:win]])
    # Peak spectral density of each band against the strongest bin, smoothed over 50 Hz.
    k = max(1, int(50 * SECONDS))
    smooth = np.convolve(power, np.ones(k) / k, mode="same")
    top = smooth.max()
    def floor(lo, hi):
        sel = (F >= lo) & (F < hi)
        return round(10 * np.log10(max(smooth[sel].max() / top, 1e-20)), 1)
    return {
        "seconds": SECONDS, "sample_rate": SR, "seed": SEED,
        "peak_dbfs": round(db(np.max(np.abs(x))), 2), "rms_dbfs": round(db(rms(x)), 2),
        "rms_0_5s_spread_db": round(max(windows) - min(windows), 2),
        "rms_0_5s_min_max_dbfs": [round(min(windows), 2), round(max(windows), 2)],
        "seam_rms_vs_mean_db": round(db(rms(seam)) - db(rms(x)), 2),
        "seam_step": round(float(abs(x[0] - x[-1]) / max(np.max(np.abs(x)), 1e-9)), 4),
        "energy_share_db": {"below_350": band_db(power, 0, 350), "350_500": band_db(power, 350, 500),
                            "500_9000": band_db(power, 500, 9000), "9000_11000": band_db(power, 9000, 11000),
                            "above_11000": band_db(power, 11000, SR / 2)},
        "peak_density_vs_max_db": {"below_350": floor(20, 350), "at_400": floor(380, 420),
                                   "at_11000_up": floor(11000, 20000)},
    }


def spectrogram(x, path):
    from PIL import Image
    hop, size = 512, 2048
    frames = (len(x) - size) // hop
    win = np.hanning(size)
    cols = []
    for i in range(frames):
        cols.append(np.abs(np.fft.rfft(x[i * hop:i * hop + size] * win))[:size // 2])
    s = 20 * np.log10(np.array(cols).T + 1e-9)
    s = np.clip((s - (s.max() - 80)) / 80, 0, 1)
    img = (s[::-1] * 255).astype(np.uint8)  # low frequencies at the bottom
    Image.fromarray(img).resize((1400, 512)).save(path)


def main():
    x, _ = synth()
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype(np.int16)
    os.makedirs(os.path.dirname(WAV), exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(WAV, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    report = measure(pcm.astype(np.float64) / 32767)
    report["file"] = os.path.relpath(WAV, ROOT).replace("\\", "/")
    report["in_game"] = {"volume": .14, "speed": 1.0, "min": 5, "max": 26, "rolloff": "InverseTapered",
                         "start": "random TimePosition, never restarted while the garden is loaded"}
    with open(REPORT, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    spectrogram(pcm.astype(np.float64) / 32767, SPECTRO)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
