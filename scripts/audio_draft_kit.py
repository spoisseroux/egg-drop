"""Shared helpers for the beta 14 audio drafts (RACE-AND-MUSIC-LOOK.md).

Additive synthesis and DSP in numpy only: sine partials, shaped noise, FFT filters. No samples,
no generated audio. The voices are ports of `qa20261114_music.voice()` and the mallet recipes of
`synth_tip_chime.py`, with the sample rate passed in so the same voice renders at 44.1 or 48 kHz.

Loudness is measured with ffmpeg's `ebur128` filter (ITU-R BS.1770-4 K-weighting and gating,
true peak by 4x oversampling), the same meter the earlier music scripts used through `loudnorm`.
"""
import hashlib
import json
import math
import os
import re
import subprocess
import tempfile
import wave

import numpy as np

PITCH = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(note):
    m = re.fullmatch(r"([A-G])([b#]?)(\d)", note)
    assert m, note
    return 12 * (int(m[3]) + 1) + PITCH[m[1]] + {"b": -1, "#": 1, "": 0}[m[2]]


def hz(note):
    return 440.0 * 2 ** ((midi(note) - 69) / 12)


def octave(note, shift):
    return note[:-1] + str(int(note[-1]) + shift)


def parse(row):
    """'E5:.5 G5:.5 r:1' -> [(note, beats), ...]"""
    return [(n, float(d)) for token in row.split() for n, d in [token.split(":")]]


def db(x):
    return 10 ** (x / 20)


# ---------------------------------------------------------------- envelopes, filters, noise

def envelope(t, duration, attack=.008, release=.05):
    a = .5 - .5 * np.cos(np.pi * np.clip(t / attack, 0, 1))
    r = .5 - .5 * np.cos(np.pi * np.clip((duration - t) / release, 0, 1))
    return a * r


def fft_lowpass(x, sr, cutoff, order=4, circular=False):
    """Zero-phase Butterworth-magnitude low-pass in the frequency domain. `circular` keeps a loop
    a loop (the filter wraps); otherwise the signal is padded so tails do not wrap."""
    n = len(x)
    pad = 0 if circular else min(n, int(.25 * sr))
    y = np.concatenate([x, np.zeros((pad,) + x.shape[1:])]) if pad else x
    spec = np.fft.rfft(y, axis=0)
    f = np.fft.rfftfreq(len(y), 1 / sr)
    h = 1 / np.sqrt(1 + (f / cutoff) ** (2 * order))
    spec *= h[:, None] if spec.ndim == 2 else h
    return np.fft.irfft(spec, n=len(y), axis=0)[:n]


def onepole_lowpass(x, sr, cutoff):
    a = math.exp(-2 * math.pi * cutoff / sr)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def band_noise(rng, count, sr, low, high):
    """White noise with steep Butterworth-like edges at low/high, unit peak."""
    spec = np.fft.rfft(rng.standard_normal(count))
    f = np.fft.rfftfreq(count, 1 / sr)
    spec *= (1 - np.exp(-(f / max(1, low)) ** 4)) * np.exp(-(f / high) ** 4)
    out = np.fft.irfft(spec, n=count)
    return out / (np.max(np.abs(out)) + 1e-12)


def triangle(f, t):
    y = np.zeros_like(t)
    for k in range(min(18, int(5000 / f))):
        n = 2 * k + 1
        if n * f > 5000:
            break
        y += ((-1) ** k) * np.sin(2 * np.pi * n * f * t) / (n * n)
    return y * (8 / np.pi ** 2)


# ---------------------------------------------------------------- voices (qa20261114_music.voice)

def voice(note, duration, kind, sr):
    """Port of qa20261114_music.voice() for the kinds the race score uses."""
    f = hz(note)
    tail = .45 if kind in {"pluck", "bell", "wood"} else .10
    total = duration + tail
    t = np.arange(round(total * sr)) / sr
    if kind == "wood":
        decay = min(.30, max(.18, duration * .65))
        y = np.sin(2 * np.pi * f * t) + db(-14) * np.sin(4 * np.pi * f * t) + db(-22) * np.sin(6 * np.pi * f * t)
        spectrum = np.fft.rfft(y * np.exp(-t / decay) * envelope(t, total, .008, .06))
        spectrum *= np.exp(-(np.fft.rfftfreq(len(t), 1 / sr) / 4000) ** 8)
        return np.fft.irfft(spectrum, n=len(t))
    if kind in {"pluck", "bell"}:
        y = (np.sin(2 * np.pi * f * t) + .22 * np.sin(4 * np.pi * f * t) * np.exp(-t / .10) +
             .08 * np.sin(6 * np.pi * f * t) * np.exp(-t / .07))
        return y * np.exp(-t / (.42 if kind == "pluck" else .52)) * envelope(t, total, .008, .10)
    if kind == "bass":
        return (.72 * np.sin(2 * np.pi * f * t) + .28 * triangle(f, t)) * envelope(t, total, .012, .065) * np.exp(-t / .19)
    if kind == "pad":
        y = .66 * np.sin(2 * np.pi * f * t) + .22 * np.sin(2 * np.pi * f * 1.0014 * t) + .12 * np.sin(4 * np.pi * f * t)
        return y * envelope(t, total, .4, .45)
    raise ValueError(kind)


def gated(x, sr, seconds, release=.03):
    """Cut a ringing note at `seconds` with a raised-cosine release (no step)."""
    n = min(len(x), int(round(seconds * sr)))
    r = min(n, int(round(release * sr)))
    y = x[:n].copy()
    y[n - r:] *= .5 + .5 * np.cos(np.pi * np.arange(r) / r)
    return y


# ---------------------------------------------------------------- mallets (synth_tip_chime.py)

def mallet(freq, length, partials, attack, rng, sr, click=0.0, click_cut=4000.0):
    """partials: (ratio, gain, decay seconds). Soft linear onset; optional low-passed noise click."""
    t = np.arange(int(round(sr * length))) / sr
    out = np.zeros_like(t)
    for ratio, gain, decay in partials:
        f = freq * ratio
        if f > sr / 2.2:
            continue
        out += gain * np.sin(2 * math.pi * f * t + rng.uniform(0, 2 * math.pi)) * np.exp(-t / decay)
    out *= np.minimum(1.0, t / attack)
    if click > 0:
        n = int(sr * .012)
        burst = rng.standard_normal(n) * np.exp(-np.arange(n) / (sr * .003))
        out[:n] += click * onepole_lowpass(burst, sr, click_cut)
    return out


def wood_bar(f, rng, sr, length=.5, ring=.16):
    s = ring / .16
    return mallet(f, length, [(1, 1, ring), (3.98, .32, .05 * min(1, s)), (9.9, .06, .018)], .0025, rng, sr, .08, 2500)


def kalimba(f, rng, sr, length=.9, ring=.42, second=.18):
    return mallet(f, length, [(1, 1, ring), (2.0, .08, second), (5.92, .22, .045)], .004, rng, sr, .04, 1800)


def glock(f, rng, sr, length=1.0, ring=.55, mid=.16, top=.06, cutoff=3000, onset=.006):
    x = mallet(f, length, [(1, 1, ring), (2.76, .25, mid), (5.40, .08, top)], onset, rng, sr)
    return onepole_lowpass(x, sr, cutoff)


# ---------------------------------------------------------------- drums

def kick(sr, length=.25):
    t = np.arange(int(round(length * sr))) / sr
    f = np.where(t < .12, 50 * (110 / 50) ** (1 - t / .12), 50.0)
    return np.sin(2 * np.pi * np.cumsum(f) / sr) * envelope(t, length, .002, .04) * np.exp(-t / .09)


def brush(rng, sr, length=.09):
    t = np.arange(int(round(length * sr))) / sr
    noise = band_noise(rng, len(t), sr, 1800, 5800) * np.exp(-t / .025)
    body = db(-10) * np.sin(2 * np.pi * 190 * t) * np.exp(-t / .03)
    return (noise + body) * envelope(t, length, .003, .025)


def shaker(rng, sr, length=.04):
    t = np.arange(int(round(length * sr))) / sr
    return band_noise(rng, len(t), sr, 3000, 7000) * np.exp(-t / .012) * envelope(t, length, .002, .012)


def woodblock(sr, length=.105):
    t = np.arange(int(round(length * sr))) / sr
    return (np.sin(2 * np.pi * 620 * t) + .30 * np.sin(2 * np.pi * 970 * t)) * np.exp(-t / .022) * envelope(t, length, .002, .025)


# ---------------------------------------------------------------- mixing

def add(out, at_seconds, sound, gain, sr, pan=0.0, wrap=False):
    """Mix `sound` into `out` (mono 1-D or stereo N x 2). Equal-power pan, |pan| <= .2 so a phone's
    mono sum stays even. With `wrap` the tail runs past the end back into the start (a loop)."""
    assert -.2 <= pan <= .2
    n = len(out)
    at = int(round(at_seconds * sr))
    if wrap:
        at %= n
    sig = sound * gain
    if out.ndim == 2:
        g = (math.cos((pan + 1) * np.pi / 4), math.sin((pan + 1) * np.pi / 4))
        sig = np.stack([sig * g[0], sig * g[1]], axis=1) * math.sqrt(2)
    first = min(len(sig), n - at)
    if first > 0:
        out[at:at + first] += sig[:first]
    if wrap and first < len(sig):
        rest = sig[first:]
        assert len(rest) < n
        out[:len(rest)] += rest


ROOM_TAPS = (.031, .047, .073, .109, .149, .197, .257, .337, .431, .547, .677, .797)


def room(x, sr, ratio, wrap):
    """The music script's delay network: 12 taps, odd taps swap channels, decay exp(-d/.24).
    `wrap` rolls the taps around the loop; otherwise the input must already carry its own tail room."""
    stereo = x if x.ndim == 2 else x[:, None]
    wet = np.zeros_like(stereo)
    for k, delay in enumerate(ROOM_TAPS):
        d = round(delay * sr)
        if wrap:
            shifted = np.roll(stereo, d, axis=0)
        else:
            shifted = np.zeros_like(stereo)
            shifted[d:] = stereo[:-d]
        if k % 2 and stereo.shape[1] == 2:
            shifted = shifted[:, ::-1]
        wet += shifted * math.exp(-delay / .24)
    wet /= 3.8
    y = (1 - ratio) * stereo + ratio * wet
    return y if x.ndim == 2 else y[:, 0]


def fade_tail(x, sr, start, end):
    """Raised-cosine fade to exactly zero between `start` and `end` seconds; silent after."""
    a, b = int(round(start * sr)), min(len(x), int(round(end * sr)))
    w = np.ones(len(x))
    w[a:b] = .5 + .5 * np.cos(np.pi * np.arange(b - a) / (b - a))
    w[b:] = 0
    return x * (w[:, None] if x.ndim == 2 else w)


def fade_edges(x, sr, fade_in=.001, fade_out=.02):
    y = x.copy()
    a, b = max(1, int(round(fade_in * sr))), max(1, int(round(fade_out * sr)))
    win = lambda m: (.5 - .5 * np.cos(np.pi * np.arange(m) / m))
    wi, wo = win(a), win(b)[::-1]
    if y.ndim == 2:
        wi, wo = wi[:, None], wo[:, None]
    y[:a] *= wi
    y[-b:] *= wo   # the window's last value is 0, so the file ends on exactly zero
    return y


def true_peak(x, oversample=4):
    """Inter-sample peak estimate by FFT upsampling (circular)."""
    stereo = x if x.ndim == 2 else x[:, None]
    n = len(stereo)
    spec = np.fft.rfft(stereo, axis=0)
    up = np.fft.irfft(spec, n=n * oversample, axis=0) * oversample
    return float(np.max(np.abs(up)))


def limit(x, sr, ceiling_db, window=.008, circular=False):
    """Look-ahead brickwall gain: per-sample needed gain (from 4x-oversampled peaks), a sliding
    minimum over `window`, then a Hann smooth over the same window (so the gain is never above
    what each peak needs). Returns (signal, max gain reduction dB)."""
    stereo = x if x.ndim == 2 else x[:, None]
    n = len(stereo)
    ceiling = db(ceiling_db)
    spec = np.fft.rfft(stereo, axis=0)
    up = np.abs(np.fft.irfft(spec, n=n * 4, axis=0) * 4).max(axis=1).reshape(n, 4).max(axis=1)
    need = np.minimum(1.0, ceiling / np.maximum(up, 1e-12))
    if need.min() >= 1.0:
        return x, 0.0
    w = int(round(window * sr)) | 1
    h = w // 2
    if circular:
        padded = np.concatenate([need[-h:], need, need[:h]])
    else:
        padded = np.concatenate([np.ones(h), need, np.ones(h)])
    mins = np.lib.stride_tricks.sliding_window_view(padded, w).min(axis=1)
    hann = np.hanning(w + 2)[1:-1]
    hann /= hann.sum()
    if circular:
        mp = np.concatenate([mins[-h:], mins, mins[:h]])
    else:
        mp = np.concatenate([np.ones(h), mins, np.ones(h)])
    gain = np.convolve(mp, hann, mode="valid")
    assert len(gain) == n
    y = stereo * gain[:, None]
    return (y if x.ndim == 2 else y[:, 0]), float(-20 * math.log10(gain.min()))


# ---------------------------------------------------------------- files and meters

def write_wav(path, x, sr):
    assert np.isfinite(x).all()
    assert np.max(np.abs(x)) < 1, np.max(np.abs(x))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = np.rint(x * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1 if pcm.ndim == 1 else pcm.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    return pcm.astype(np.float64) / 32767


def read_wav(path):
    with wave.open(str(path), "rb") as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        assert w.getsampwidth() == 2
        x = np.frombuffer(w.readframes(n), "<i2").astype(np.float64) / 32767
    return (x.reshape(-1, ch) if ch > 1 else x), sr


def ebur128(path):
    """ffmpeg ebur128: integrated LUFS, loudness range, true peak, max momentary (400 ms) and
    max short-term (3 s). Files shorter than one 400 ms block report no integrated value."""
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-v", "verbose", "-i", str(path), "-af",
                        "ebur128=peak=true:framelog=verbose", "-f", "null", "-"],
                       capture_output=True, text=True, check=True)
    err = r.stderr
    summary = err[err.rfind("Summary:"):]
    get = lambda pat: float(re.search(pat, summary, re.S)[1])
    ms = [(float(a), float(b)) for a, b in re.findall(r"M:\s*(-?[\d.]+|-inf)\s+S:\s*(-?[\d.]+|-inf)", err.replace("-inf", "-120"))]
    return dict(integrated_lufs=get(r"I:\s*(-?[\d.]+) LUFS"), loudness_range_lu=get(r"LRA:\s*(-?[\d.]+) LU"),
                true_peak_dbtp=get(r"Peak:\s*(-?[\d.inf]+) dBFS"),
                max_momentary_lufs=max((m for m, _ in ms if m > -70), default=None),
                max_short_term_lufs=max((s for _, s in ms if s > -70), default=None))


def measure_array(x, sr):
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "m.wav")
        scale = 1.0
        peak = np.max(np.abs(x))
        if peak >= .999:   # meter a scaled copy, then put the level back
            scale = .9 / peak
        write_wav(p, x * scale, sr)
        m = ebur128(p)
    off = -20 * math.log10(scale)
    for k in ("integrated_lufs", "true_peak_dbtp", "max_momentary_lufs", "max_short_term_lufs"):
        if m[k] is not None and m[k] > -70:
            m[k] += off
    return m


def normalise(x, sr, target_lufs, ceiling_dbtp, key="integrated_lufs", circular=False, tries=4):
    """Gain to `target_lufs` (on `key`), then a look-ahead limiter if the true peak would pass the
    ceiling. Returns (signal, max limiter gain reduction dB)."""
    gr_total = 0.0
    for _ in range(tries):
        m = measure_array(x, sr)
        x = x * db(target_lufs - m[key])
        if true_peak(x) > db(ceiling_dbtp - .3):
            x, gr = limit(x, sr, ceiling_dbtp - .4, circular=circular)
            gr_total = max(gr_total, gr)
        m = measure_array(x, sr)
        if abs(m[key] - target_lufs) <= .1 and m["true_peak_dbtp"] <= ceiling_dbtp:
            break
    return x, gr_total


def basic_stats(x, sr):
    a = np.abs(x)
    mono = x.mean(axis=1) if x.ndim == 2 else x
    rms = float(np.sqrt(np.mean(x ** 2)))
    return dict(seconds=round(len(x) / sr, 6), frames=len(x), sample_rate=sr, channels=1 if x.ndim == 1 else x.shape[1],
                sample_peak_dbfs=round(20 * math.log10(float(a.max())), 2), rms_dbfs=round(20 * math.log10(rms), 2),
                mono_rms_minus_stereo_rms_db=round(20 * math.log10(float(np.sqrt(np.mean(mono ** 2))) / rms), 2) if x.ndim == 2 else 0.0,
                first_sample=round(float(np.max(np.abs(x[0]))), 5), last_sample=round(float(np.max(np.abs(x[-1]))), 5),
                dc=round(float(x.mean()), 7))


def join_check(before, after, sr, window=.05):
    """Click test at a join (a loop seam, or the lead-in into the loop). Compares the step across the
    join and the largest second difference (a click detector) within 2 ms of it against the same
    measures over the surrounding `window` on both sides. Ratios <= 1 mean the join is no rougher
    than the music around it."""
    w = int(window * sr)
    seg = np.concatenate([before[-w:], after[:w]])
    seg = seg if seg.ndim == 2 else seg[:, None]
    step = np.abs(np.diff(seg, axis=0)).max(axis=1)
    curv = np.abs(np.diff(seg, n=2, axis=0)).max(axis=1)
    j = w - 1   # step index across the join
    near = slice(j - int(.002 * sr), j + int(.002 * sr))
    away = np.r_[0:j - int(.002 * sr), j + int(.002 * sr):len(curv)]
    return dict(step_at_join=round(float(step[j]), 5), step_p999_around=round(float(np.percentile(step, 99.9)), 5),
                step_ratio=round(float(step[j] / max(1e-9, np.percentile(step, 99.9))), 3),
                curvature_near_join=round(float(curv[near].max()), 5), curvature_max_around=round(float(curv[away].max()), 5),
                curvature_ratio=round(float(curv[near].max() / max(1e-9, curv[away].max())), 3))


def sha256(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def save_report(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
