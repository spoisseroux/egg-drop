#!/usr/bin/env python3
"""Deterministic render of the garden day / night and Pocket Deck music from Spencer's stems.

Follows artifacts/qa-2026-11-28-music/MUSIC-BRIEF.md (Fable, 2026-11-28).

  python scripts/build_music.py                      # v4 (current): garden day + night without the pads
  python scripts/build_music.py --version deck-v4    # Pocket Deck v4 "Marimba Pop" (140 BPM) + its lite
  python scripts/build_music.py --version v3         # v3: garden beds with pads + the exciting Pocket Deck
  python scripts/build_music.py --version v2         # the first-pass v2 render
  python scripts/build_music.py --with boing,la-chop # v3 with the risky samples back on
  python scripts/build_music.py --no-encode          # WAV only, skip OGG/MP3

Inputs:  assets/audio/music-src/{main,deck}/*.mp3 (Spencer's stems, his own music)
         assets/audio/music/garden-loop.wav, pocket-deck-loop.wav (alignment + loudness reference)
Outputs: assets/audio/music/{garden-day-v2,garden-night-v2,pocket-deck-v2,pocket-deck-lite-v2}.{wav,ogg}
         assets/audio/music/samples/*.wav, assets/audio/music/manifest.json ("v2" block)
         artifacts/qa-2026-11-28-music/report.json, previews/*.mp3

Every sample-palette sound is synthesized here from an original recipe, or is a chop/resample of
Spencer's stems. No downloads, no generated audio. All randomness comes from fixed seeds, so two
runs give byte-identical files.

Loop safety: every filter is a zero-phase magnitude curve applied in the frequency domain over the
whole loop (so it is circular by construction); dynamics and reverb run over three copies of the
loop and keep the middle one, so tails and compressor state wrap across the seam.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import warnings
from dataclasses import dataclass, field

import numpy as np
import soundfile as sf
import pyloudnorm as pyln
import librosa
from scipy import signal
from scipy.ndimage import minimum_filter1d
from pedalboard import Pedalboard, Compressor, Reverb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_MAIN = os.path.join(ROOT, "assets", "audio", "music-src", "main")
SRC_DECK = os.path.join(ROOT, "assets", "audio", "music-src", "deck")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "music")
SAMPLE_DIR = os.path.join(OUT_DIR, "samples")
QA_DIR = os.path.join(ROOT, "artifacts", "qa-2026-11-28-music")
PREVIEW_DIR = os.path.join(QA_DIR, "previews")
REF_GARDEN = os.path.join(OUT_DIR, "garden-loop.wav")
REF_DECK = os.path.join(OUT_DIR, "pocket-deck-loop.wav")

SR = 44100
BPM = 117.0
BAR = 60.0 / BPM * 4 * SR          # 90461.538... frames
BEAT = BAR / 4
SEED = 20261128

N_DAY = int(round(64 * BAR))        # 5,789,538
N_DECK = int(round(32 * BAR))       # 2,894,769
N_LITE = int(round(16 * BAR))       # 1,447,385
# Not in the brief: bass + chords sit lower in A1 "wake" and the C1 breakdown, for the loudness range it asks for
C1_BED_DB = -4.5
A1_BED_DB = -2.5

PITCH_SET = (0, 2, 4, 7, 9)          # C D E G A, never F or F#
RISKY = ("boing", "eep", "la-chop")
ALL_SAMPLES = ("pip", "la-chop", "tok", "plip", "boing", "swell", "music-box", "shaker",
               "kalimba", "eep", "ribbit", "hoo")

# chords / bass / drums: which 8-bar source phrase plays in each 8-bar phrase of the 64-bar loop.
# Source phrase 3 (bars 25-32) carries the bass dropouts, so it only plays in C1 (bars 33-40).
PHRASE_SRC = [0, 1, 2, 1, 3, 0, 1, 2]


def db(x):
    return 10 ** (x / 20.0)


def todb(x):
    return 20 * np.log10(max(float(x), 1e-12))


def pos(bar, beat=1.0):
    """Frame of a 1-based bar and beat, on the 117.00 BPM grid."""
    return int(round(((bar - 1) + (beat - 1) / 4.0) * BAR))


def barf(bar0):
    """Frame of a 0-based (possibly fractional) bar index."""
    return int(round(bar0 * BAR))


# ----------------------------------------------------------------------------- zero-phase filters

def _rbj(kind, f0, gain_db, q):
    a = db(gain_db / 2.0)
    w0 = 2 * np.pi * f0 / SR
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2 * q)
    if kind == "peak":
        b = [1 + alpha * a, -2 * cw, 1 - alpha * a]
        den = [1 + alpha / a, -2 * cw, 1 - alpha / a]
    elif kind == "highshelf":
        sa = 2 * np.sqrt(a) * alpha
        b = [a * ((a + 1) + (a - 1) * cw + sa), -2 * a * ((a - 1) + (a + 1) * cw), a * ((a + 1) + (a - 1) * cw - sa)]
        den = [(a + 1) - (a - 1) * cw + sa, 2 * ((a - 1) - (a + 1) * cw), (a + 1) - (a - 1) * cw - sa]
    else:
        raise ValueError(kind)
    return np.array(b), np.array(den)


def mag_rbj(f, kind, f0, gain_db, q=0.707):
    b, a = _rbj(kind, f0, gain_db, q)
    z = np.exp(-1j * 2 * np.pi * f / SR)
    h = (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)
    return np.abs(h)


def mag_hp(f, fc, order=2):
    with np.errstate(divide="ignore"):
        r = np.where(f > 0, fc / np.maximum(f, 1e-9), np.inf)
    return 1.0 / np.sqrt(1.0 + r ** (2 * order))


def mag_lp(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def fft_filter(x, mag):
    """Zero-phase circular filter: multiply the loop's spectrum by a real magnitude curve.
    `mag` is a function of frequency (Hz) returning the linear magnitude."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    h = mag(f)
    spec = np.fft.rfft(x, axis=0)
    spec *= h[:, None] if x.ndim == 2 else h
    return np.fft.irfft(spec, n=n, axis=0)


def fft_filter_padded(x, mag, pad=4096):
    """Zero-phase filter for a one-shot (non-loop) sound: pad with zeros so nothing wraps."""
    z = np.concatenate([x, np.zeros((pad,) + x.shape[1:])])
    return fft_filter(z, mag)[: len(x)]


def ms_split(x):
    return (x[:, 0] + x[:, 1]) * 0.5, (x[:, 0] - x[:, 1]) * 0.5


def ms_join(m, s):
    return np.stack([m + s, m - s], axis=1)


def stereo(m):
    return np.stack([m, m], axis=1)


# ----------------------------------------------------------------------------- measurement

_METER = pyln.Meter(SR)


def lufs(x):
    return float(_METER.integrated_loudness(np.asarray(x, dtype=np.float64)))


def true_peak_db(x):
    pad = 64
    z = np.concatenate([x[-pad:], x, x[:pad]], axis=0)
    up = signal.resample_poly(z, 4, 1, axis=0)[4 * pad: -4 * pad]
    return todb(np.abs(up).max())


def k_weight(x):
    y = np.asarray(x, dtype=np.float64)
    for filt in _METER._filters.values():
        y = signal.lfilter(filt.b, filt.a, y, axis=0)
    return y


def loudness_range(x):
    """EBU R128 LRA on 3 s short-term windows (0.1 s hop), treated as a loop."""
    n = len(x)
    pre = int(3 * SR)
    kw = k_weight(np.concatenate([x[-pre:], x], axis=0))[pre:]   # settle the K filter on the wrap
    p = (kw ** 2).sum(axis=1)
    cs = np.concatenate([[0.0], np.cumsum(np.concatenate([p, p[:pre]]))])
    hop = int(0.1 * SR)
    starts = np.arange(0, n, hop)
    ms = (cs[starts + pre] - cs[starts]) / pre
    st = -0.691 + 10 * np.log10(np.maximum(ms, 1e-20))
    st = st[st > -70]
    if len(st) == 0:
        return 0.0
    rel = -0.691 + 10 * np.log10(np.mean(10 ** ((st + 0.691) / 10))) - 20
    st = st[st > rel]
    return float(np.percentile(st, 95) - np.percentile(st, 10))


def hf_share(x, fc=6000.0):
    spec = np.abs(np.fft.rfft(x, axis=0)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    tot = spec.sum()
    return float(spec[f >= fc].sum() / tot)


def mono_loss_db(x):
    m, _ = ms_split(x)
    st = np.sqrt(((x[:, 0] ** 2).mean() + (x[:, 1] ** 2).mean()) / 2)
    return todb(np.sqrt((m ** 2).mean()) / max(st, 1e-12))


def crest_db(x):
    return todb(np.abs(x).max()) - todb(np.sqrt((x ** 2).mean()))


def seam_stats(x, bar=None):
    """Loop seam check: the wrap (last sample -> first sample) against the track's own motion."""
    w = int(0.05 * SR)
    last, first = x[-w:], x[:w]
    d1 = np.abs(np.diff(x, axis=0))
    wrap1 = np.abs(x[0] - x[-1])
    d2 = np.abs(np.diff(x, n=2, axis=0))
    wrap2 = np.abs(x[1] - 2 * x[0] + x[-1])
    # HF (>8 kHz) energy in 20 ms around the seam vs the same window at every other bar line:
    # a click would make the seam stand out from the downbeats it should sound like
    hf = fft_filter(x, lambda f: mag_hp(f, 8000, 4))
    e = (hf ** 2).sum(axis=1)
    win = int(0.02 * SR)
    bl = bar or BAR
    nb = int(round(len(x) / bl))
    at = lambda c: e[(np.arange(c - win // 2, c + win // 2)) % len(e)].mean()
    seam_e = at(0)
    bars = [at(int(round(k * bl))) for k in range(1, nb)]
    lag = int(0.004 * SR)
    a = last[-lag:].mean(axis=1)
    b = first[:lag].mean(axis=1)
    return {
        "rms_last50_db": round(todb(np.sqrt((last ** 2).mean())), 2),
        "rms_first50_db": round(todb(np.sqrt((first ** 2).mean())), 2),
        "wrap_step": [int(round(v * 32767)) for v in wrap1],
        "p99_step": [int(round(v * 32767)) for v in np.percentile(d1, 99, axis=0)],
        "wrap_step_ratio_p99": round(float((wrap1 / np.maximum(np.percentile(d1, 99, axis=0), 1e-12)).max()), 3),
        "wrap_curvature_ratio_p99": round(float((wrap2 / np.maximum(np.percentile(d2, 99, axis=0), 1e-12)).max()), 3),
        "hf_seam_vs_median_barline_db": round(10 * np.log10(max(seam_e, 1e-20) / max(np.median(bars), 1e-20)), 2),
        "hf_seam_vs_loudest_barline_db": round(10 * np.log10(max(seam_e, 1e-20) / max(np.max(bars), 1e-20)), 2),
        "slope_last4ms_vs_first4ms": [round(float(np.mean(np.diff(a)) * 32767), 2), round(float(np.mean(np.diff(b)) * 32767), 2)],
    }


def measure(x, name, bar=None):
    m = {
        "file": name,
        "frames": int(len(x)),
        "seconds": round(len(x) / SR, 3),
        "integrated_lufs": round(lufs(x), 2),
        "true_peak_dbtp": round(true_peak_db(x), 2),
        "sample_peak_dbfs": round(todb(np.abs(x).max()), 2),
        "loudness_range_lu": round(loudness_range(x), 2),
        "mono_loss_db": round(mono_loss_db(x), 2),
        "share_above_6k": round(hf_share(x), 4),
        "seam": seam_stats(x, bar),
    }
    return m


# ----------------------------------------------------------------------------- dynamics / reverb

def tile3(fn, x):
    n = len(x)
    y = fn(np.concatenate([x, x, x], axis=0))
    return y[n: 2 * n]


def pb_run(board, x):
    y = board(np.ascontiguousarray(x.T, dtype=np.float32), SR)
    return y.T.astype(np.float64)


_REV_CAL = {}


def reverb_gain(room):
    """Freeverb's wet gain, measured on seeded noise, so a send of -14 dB returns 14 dB under."""
    if room not in _REV_CAL:
        rng = np.random.default_rng(7)
        n = np.ascontiguousarray(rng.standard_normal((2, 4 * SR)).astype(np.float32) * 0.1)
        out = Pedalboard([Reverb(room_size=room, damping=0.5, wet_level=1.0, dry_level=0.0, width=0.7)])(n, SR)
        _REV_CAL[room] = float(np.sqrt((n[:, 2 * SR:] ** 2).mean()) / np.sqrt((out[:, 2 * SR:] ** 2).mean()))
    return _REV_CAL[room]


def room(send, size):
    """Shared room: wet only, return HP 300 Hz / LP 6 kHz, three loops rendered, middle kept."""
    board = Pedalboard([Reverb(room_size=size, damping=0.5, wet_level=1.0, dry_level=0.0, width=0.7)])
    wet = tile3(lambda z: pb_run(board, z), send) * reverb_gain(size)
    return fft_filter(wet, lambda f: mag_hp(f, 300, 2) * mag_lp(f, 6000, 2))


def soft_clip(x, ceiling):
    return ceiling * np.tanh(x / ceiling)


def drum_chain(x, label, target_crest=12.5):
    """Garden drum treatment: -4 dB, high shelf -4 dB @ 6 kHz, mono below 150 Hz,
    soft clip then 4:1 / 5 ms / 80 ms compressor, clip depth searched for a 12-13 dB crest."""
    x = x * db(-4)
    x = fft_filter(x, lambda f: mag_rbj(f, "highshelf", 6000, -4, 0.707))
    m, s = ms_split(x)
    s = fft_filter(s, lambda f: mag_hp(f, 150, 2))
    x = ms_join(m, s)
    peak = np.abs(x).max()
    rms_db = todb(np.sqrt((x ** 2).mean()))
    comp = Pedalboard([Compressor(threshold_db=rms_db + 6, ratio=4, attack_ms=5, release_ms=80)])
    best = None
    for depth in np.arange(0.0, 18.01, 0.5):
        y = pb_run(comp, soft_clip(x, peak * db(-depth)))
        c = crest_db(y)
        if best is None or abs(c - target_crest) < abs(best[1] - target_crest):
            best = (depth, c)
        if c <= target_crest:
            break
    depth = best[0]
    y = tile3(lambda z: pb_run(comp, soft_clip(z, peak * db(-depth))), x)
    info = {"clip_depth_db": float(depth), "crest_before_db": round(crest_db(x), 2), "crest_after_db": round(crest_db(y), 2)}
    print(f"  drums[{label}]: crest {info['crest_before_db']} -> {info['crest_after_db']} dB (clip {depth} dB)")
    return y, info


def glue(x, target_gr=1.5):
    """2:1 bus glue; threshold searched so the loudness drops 1-2 dB."""
    l0 = lufs(x)
    chosen = None
    for thr in np.arange(-6.0, -40.01, -1.0):
        board = Pedalboard([Compressor(threshold_db=float(thr), ratio=2, attack_ms=15, release_ms=150)])
        gr = l0 - lufs(pb_run(board, x))
        chosen = (float(thr), gr)
        if gr >= target_gr:
            break
    board = Pedalboard([Compressor(threshold_db=chosen[0], ratio=2, attack_ms=15, release_ms=150)])
    y = tile3(lambda z: pb_run(board, z), x)
    return y, {"threshold_db": chosen[0], "loudness_reduction_db": round(l0 - lufs(y), 2)}


def tp_limit(x, ceiling_db, look_ms=3.0, release_ms=60.0):
    """Look-ahead true-peak limiter on a loop: gain = min over a window of ceiling/peak(4x), smoothed.
    The min window covers the smoothing kernel, so the smoothed gain never exceeds what each sample needs."""
    n = len(x)
    pad = 64
    z = np.concatenate([x[-pad:], x, x[:pad]], axis=0)
    up = np.abs(signal.resample_poly(z, 4, 1, axis=0))[4 * pad: -4 * pad].max(axis=1)
    pk = up.reshape(n, 4).max(axis=1)
    pk = np.maximum(pk, np.abs(x).max(axis=1))
    need = np.minimum(1.0, db(ceiling_db) / np.maximum(pk, 1e-12))
    if need.min() >= 1.0:
        return x.copy()
    la = int(look_ms * 1e-3 * SR)
    rel = int(release_ms * 1e-3 * SR)
    g = minimum_filter1d(need, size=2 * (la + rel) + 1, mode="wrap")
    ker = np.hanning(2 * rel + 1)
    ker /= ker.sum()
    gpad = np.concatenate([g[-rel:], g, g[:rel]])
    g = np.convolve(gpad, ker, mode="valid")
    g = np.minimum(g, 1.0)
    return x * g[:, None]


def finish(x, target_lufs, tp_max):
    """Loudness-normalize to target and limit to the true-peak ceiling (iterated)."""
    g = db(target_lufs - lufs(x))
    ceil = tp_max - 0.4
    y = x * g
    for _ in range(12):
        y = tp_limit(x * g, ceil)
        l, tp = lufs(y), true_peak_db(y)
        if abs(l - target_lufs) <= 0.05 and tp <= tp_max - 0.15:
            break
        g *= db(target_lufs - l)
        if tp > tp_max - 0.15:
            ceil -= (tp - (tp_max - 0.15)) + 0.05
    return y


def quantize16(x, seed):
    rng = np.random.default_rng(seed)
    d = (rng.random(x.shape) - rng.random(x.shape))
    q = np.round(x * 32767.0 + d)
    return np.clip(q, -32768, 32767).astype(np.int16)


# ----------------------------------------------------------------------------- stems

def load_mp3(path):
    x, sr = sf.read(path, dtype="float64", always_2d=True)
    assert sr == SR, path
    return x


def measure_offset(ref, stems):
    """Decoder offset of the MP3 stems: circular cross-correlation of the drum stem against the
    reference loop. Returns the stem frame that lines up with reference frame 0 (bar 1 beat 1)."""
    r = ref.mean(axis=1)
    out = {}
    for name, x in stems.items():
        m = x.mean(axis=1)
        n = len(r)
        rr = np.concatenate([r, r, r])
        c = signal.fftconvolve(rr, m[::-1], mode="valid")
        j = int(np.argmax(np.abs(c)))
        score = float(c[j] / np.sqrt((m ** 2).sum() * (r ** 2).sum()))
        off = (-j) % n
        # offsets are mod the bar grid of the reference (stems can sit at any bar of it)
        off_bar = off - int(round(off / BAR)) * BAR
        out[name] = (int(round(off_bar)) % int(round(BAR)), score)
    return out


def grid_stem(x, offset, nbars):
    """Cut a decoded stem to its bar grid. The MP3s end a few hundred frames short of the grid;
    the missing tail is filled from the same spot 8 bars (4 for 8-bar stems) earlier."""
    n = int(round(nbars * BAR))
    body = x[offset:]
    out = np.zeros((n, 2))
    k = min(len(body), n)
    out[:k] = body[:k]
    missing = n - k
    if missing > 0:
        back = int(round((8 if nbars >= 16 else 4) * BAR))
        x0 = 64
        fill = out[k - back - x0: n - back]
        ramp = 0.5 - 0.5 * np.cos(np.pi * (np.arange(x0) + 0.5) / x0)
        seg = fill.copy()
        out[k - x0:k] = out[k - x0:k] * (1 - ramp)[:, None] + seg[:x0] * ramp[:, None]
        out[k:n] = seg[x0:]
    return out, missing


@dataclass
class Note:
    slot: int      # 16th-note index from the stem's start
    midi: int
    dur: float     # in 16ths


def transcribe(x, nbars):
    """Onset + pitch transcription of a monophonic stem (pyin), quantized to 16ths."""
    m = x.mean(axis=1).astype(np.float32)
    b = int(round(BAR))
    m2 = np.concatenate([m[-b:], m])           # wrap so the bar-1 downbeat registers as an onset
    hop = 256
    f0, _, _ = librosa.pyin(m2, fmin=130, fmax=2100, sr=SR, frame_length=2048, hop_length=hop)
    on = librosa.onset.onset_detect(y=m2, sr=SR, hop_length=hop, units="samples")
    six = BAR / 16
    notes = []
    for i, o in enumerate(on):
        e = on[i + 1] if i + 1 < len(on) else len(m2)
        a = o // hop + 2
        seg = f0[a: min(e // hop, a + 20)]
        seg = seg[~np.isnan(seg)]
        if len(seg) < 2 or o < b - six / 2:
            continue
        midi = int(np.round(np.median(librosa.hz_to_midi(seg))))
        q = int(np.round((o - b) / six))
        if q >= nbars * 16:
            continue
        notes.append(Note(q, midi, (e - o) / six))
    # octave-error guard: fold notes more than 9 semitones from the bar's median
    for bar in range(nbars):
        inbar = [n for n in notes if n.slot // 16 == bar]
        if not inbar:
            continue
        med = np.median([n.midi for n in inbar])
        for n in inbar:
            while n.midi - med > 9:
                n.midi -= 12
            while med - n.midi > 9:
                n.midi += 12
    dedup = {}
    for n in notes:
        dedup.setdefault(n.slot, n)
    return [dedup[k] for k in sorted(dedup)]


def bar_chroma(x, nbars):
    m = x.mean(axis=1).astype(np.float32)
    out = []
    for i in range(nbars):
        seg = m[barf(i): barf(i + 1)]
        if np.abs(seg).max() < 1e-4:
            out.append(np.ones(12) / 12)
            continue
        c = librosa.feature.chroma_stft(y=seg, sr=SR, n_fft=8192, hop_length=2048, tuning=0.0).mean(axis=1)
        out.append(c / c.max())
    return np.array(out)


def pc_fit(chroma, midi):
    pc = midi % 12
    return chroma[pc] - 0.8 * max(chroma[(pc + 1) % 12], chroma[(pc - 1) % 12])


# ----------------------------------------------------------------------------- arrangement

@dataclass
class Block:
    src: np.ndarray
    s: float           # source bar (0-based)
    d: float           # destination bar (0-based)
    n: float           # length in bars
    g: float = 1.0


def assemble(n_out, blocks, h=64):
    """Copy bar blocks into a loop. Each block is tapered over 2h frames centred on its edges;
    neighbouring blocks overlap there, so continuous source material passes through unchanged."""
    out = np.zeros((n_out, 2))
    for bl in blocks:
        ns = len(bl.src)
        s0, d0 = barf(bl.s), barf(bl.d)
        length = barf(bl.d + bl.n) - d0
        idx = np.arange(-h, length + h)
        seg = bl.src[(s0 + idx) % ns]
        w = np.ones(len(idx))
        r = 0.5 - 0.5 * np.cos(np.pi * (np.arange(2 * h) + 0.5) / (2 * h))
        w[: 2 * h] = r
        w[-2 * h:] = r[::-1]
        di = (d0 + idx) % n_out
        out[di] += seg * (w * bl.g)[:, None]
    return out


def gate(x, regions, value=0.0, ramp=220):
    """Multiply frame regions [a, b) by `value`, with raised-cosine ramps centred on the edges."""
    n = len(x)
    g = np.ones(n)
    for a, b in regions:
        idx = np.arange(a - ramp // 2, b + ramp // 2)
        w = np.ones(len(idx)) * value
        r = 0.5 - 0.5 * np.cos(np.pi * (np.arange(ramp) + 0.5) / ramp)
        w[:ramp] = 1 + (value - 1) * r
        w[-ramp:] = value + (1 - value) * r
        g[idx % n] = np.minimum(g[idx % n], w) if value <= 1 else w
    return x * g[:, None]


def place(bus, snd, frame, gain=1.0, pan=0.0):
    """Circular add of a mono (constant-power pan) or stereo sound at `frame`."""
    n = len(bus)
    if snd.ndim == 1:
        th = (pan + 1) * np.pi / 4
        snd = np.stack([snd * np.cos(th), snd * np.sin(th)], axis=1)
    idx = (frame + np.arange(len(snd))) % n
    bus[idx] += snd * gain


def balance(x, p):
    th = (p + 1) * np.pi / 4
    return x * np.array([np.cos(th), np.sin(th)]) * np.sqrt(2)


# ----------------------------------------------------------------------------- synth palette

def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def env_ad(n, att, tau):
    t = np.arange(n) / SR
    e = np.exp(-t / tau)
    a = int(att * SR)
    if a > 0:
        e[:a] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(a) / a)
    tail = min(n, int(0.004 * SR))
    e[-tail:] *= np.linspace(1, 0, tail)
    return e


def osc(freq_curve):
    return np.cumsum(2 * np.pi * freq_curve / SR)


def s_pip(midi, scale, rng):
    n = int(0.070 * scale * SR)
    t = np.arange(n) / SR
    f1 = hz(midi)
    f = f1 * (0.6 + 0.4 * (1 - np.exp(-t / 0.012)))          # 900 -> 1500 shape, landing on the note
    f *= 1 + 0.012 * np.sin(2 * np.pi * 30 * t)               # 30 Hz vibrato
    ph = osc(f)
    y = np.sin(ph) + db(-12) * np.sin(2 * ph)
    return y * env_ad(n, 0.003, 0.03)


def s_tok(midi, scale, rng):
    n = int(0.16 * scale * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t / (0.090 * scale / 3))
         + 0.45 * np.sin(2 * np.pi * 3.9 * f * t) * np.exp(-t / 0.012)
         + 0.18 * np.sin(2 * np.pi * 9.2 * f * t) * np.exp(-t / 0.005))
    c = int(0.002 * SR)
    click = rng.standard_normal(c) * np.linspace(1, 0, c) * 0.35
    y[:c] += fft_filter_padded(click, lambda fr: mag_hp(fr, 2000, 2) * mag_lp(fr, 7000, 2))
    y[: int(0.0005 * SR)] *= np.linspace(0, 1, int(0.0005 * SR))
    return y * env_ad(n, 0.0, 10.0)


def s_plip(midi, scale, rng):
    n = int(0.055 * scale * SR)
    t = np.arange(n) / SR
    f1 = hz(midi)
    f0 = f1 / 3.5                                             # 400 -> 1400 Hz ratio
    k = np.minimum(t / (0.035 * scale), 1.0)
    f = f0 * (f1 / f0) ** k
    y = np.sin(osc(f)) * env_ad(n, 0.001, 0.02)
    tip = int(0.005 * SR)
    nz = fft_filter_padded(rng.standard_normal(tip), lambda fr: mag_hp(fr, 3000, 2) * mag_lp(fr, 7000, 2))
    y[:tip] += nz * np.linspace(0.25, 0, tip)
    return y


def s_boing(midi, scale, rng):
    n = int(0.25 * scale * SR)
    t = np.arange(n) / SR
    u = t / t[-1]
    f = hz(midi) * 2 ** ((5 / 12) * (u ** 0.6))              # bend up a 4th
    ph = osc(f)
    y = np.zeros(n)
    for k in range(1, 60):                                    # band-limited saw
        live = (k * f) < 7000
        y += live * np.sin(k * ph) / k
    # time-varying state-variable band-pass sweeping 400 -> 1800 -> 600 Hz
    fc = np.where(u < 0.4, 400 * (1800 / 400) ** (u / 0.4), 1800 * (600 / 1800) ** ((u - 0.4) / 0.6))
    q = 4.0
    lo = bp = 0.0
    out = np.zeros(n)
    for i in range(n):
        fcoef = 2 * np.sin(np.pi * fc[i] / SR)
        hi = y[i] - lo - bp / q
        bp += fcoef * hi
        lo += fcoef * bp
        out[i] = bp
    return out * env_ad(n, 0.004, 0.12)


def s_music_box(midi, scale, rng, dur=0.6):
    n = int(max(dur, 0.25) * SR * scale) + int(0.2 * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.18)
         + db(-14) * np.sin(2 * np.pi * 4.07 * f * t) * np.exp(-t / 0.06)
         + 0.3 * np.sin(2 * np.pi * 6.3 * f * t) * np.exp(-t / 0.004))
    y[: int(0.001 * SR)] *= np.linspace(0, 1, int(0.001 * SR))
    end = min(n, int(dur * scale * SR) + int(0.15 * SR))
    y = y[:end] * env_ad(end, 0.0, 10.0)
    return fft_filter_padded(y, lambda fr: mag_lp(fr, 5000, 2))


def s_kalimba(midi, scale, rng):
    n = int(0.7 * scale * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    y = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.22) + 0.3 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t / 0.025)
    th = int(0.003 * SR)
    y[:th] += fft_filter_padded(rng.standard_normal(th), lambda fr: mag_lp(fr, 2500, 2)) * np.linspace(0.3, 0, th)
    y[: int(0.0008 * SR)] *= np.linspace(0, 1, int(0.0008 * SR))
    return y * env_ad(n, 0.0, 10.0)


def s_eep(midi, scale, rng):
    n = int(0.09 * scale * SR)
    u = np.linspace(0, 1, n)
    peak = hz(midi)
    up, down = np.clip(u / 0.45, 0, 1), np.clip((u - 0.45) / 0.55, 0, 1)
    contour = np.where(u < 0.45, 1.2 + 0.6 * np.sin(np.pi / 2 * up), 1.8 - 0.7 * down ** 0.8) / 1.8   # 1.2-1.8-1.1 kHz
    f = peak * contour
    ph = osc(f)
    y = np.zeros(n)
    for k in range(1, 8):                                     # band-limited 25% pulse
        live = (k * f) < 6000
        y += live * (np.sin(np.pi * k * 0.25) / k) * np.cos(k * ph)
    return y * env_ad(n, 0.005, 0.05)


def s_ribbit(midi, scale, rng):
    n = int(0.18 * scale * SR)
    t = np.arange(n) / SR
    u = t / t[-1]
    f = hz(midi) * (hz(midi - 2) / hz(midi)) ** u             # A3 -> G3
    ph = osc(f)
    y = np.zeros(n)
    for k in (1, 3, 5, 7, 9, 11):                             # band-limited triangle
        y += ((-1) ** ((k - 1) // 2)) * np.sin(k * ph) / (k * k)
    am = 0.55 + 0.45 * np.sin(2 * np.pi * 28 * t - np.pi / 2)
    return y * am * env_ad(n, 0.01, 0.1)


def s_hoo(midi, scale, rng):
    one = int(0.34 * scale * SR)
    parts = []
    for m in (midi, midi - 2):                                # E4 -> D4
        t = np.arange(one) / SR
        f = hz(m) * (1 + 0.006 * np.sin(2 * np.pi * 5 * t))
        y = np.sin(osc(f))
        e = np.minimum(1, t / 0.07) * np.exp(-np.maximum(t - 0.12, 0) / 0.18)
        parts.append(y * e)
    y = np.concatenate(parts)
    br = fft_filter_padded(rng.standard_normal(len(y)), lambda fr: mag_hp(fr, 300, 2) * mag_lp(fr, 2200, 2))
    br *= np.concatenate([p != 0 for p in parts]).astype(float) * 0.05
    y = fft_filter_padded(y + br, lambda fr: mag_lp(fr, 2200, 2))
    return y * env_ad(len(y), 0.0, 10.0)


def s_shaker(accent, scale, rng):
    n = int(0.045 * scale * SR)
    nz = fft_filter_padded(rng.standard_normal(n), lambda fr: mag_hp(fr, 4000, 2) * mag_lp(fr, 8000, 2))
    return nz * env_ad(n, 0.004, 0.012) * accent


RECIPES = {"pip": s_pip, "tok": s_tok, "plip": s_plip, "boing": s_boing, "music-box": s_music_box,
           "kalimba": s_kalimba, "eep": s_eep, "ribbit": s_ribbit, "hoo": s_hoo}

# variant pitch pools (all in C D E G A; ribbit and hoo glide to the next set note down)
POOLS = {"pip": [79, 81, 84], "tok": [72, 74, 76, 79, 81], "plip": [81, 84, 88, 91, 93],
         "boing": [45], "music-box": [72, 76, 79], "kalimba": [76, 79, 81], "eep": [91, 93],
         "ribbit": [57], "hoo": [64]}


def body_rms(y):
    a = np.abs(y if y.ndim == 1 else y.mean(axis=1))
    k = max(1, int(0.005 * SR))
    sm = np.convolve(a, np.ones(k) / k, mode="same")
    mask = sm > 0.1 * sm.max()
    v = y[mask]
    return float(np.sqrt((v ** 2).mean()))


class Palette:
    def __init__(self, seed, disabled):
        self.rng = np.random.default_rng(seed)
        self.disabled = set(disabled)
        self.variants = {}
        self.cache = {}
        for name, pool in POOLS.items():
            r = np.random.default_rng(seed + sum(map(ord, name)))
            picks = list(r.choice(pool, size=3, replace=False)) if len(pool) >= 3 else [pool[i % len(pool)] for i in range(3)]
            if name == "pip":
                picks = [79, 81, 84]                         # the brief names G5 / A5 / C6
            if name == "kalimba":
                picks = [76, 79, 81]                         # E G A ostinato
            scales = list(1 + r.uniform(-0.04, 0.04, size=3))
            self.variants[name] = [(int(p), float(s), int(r.integers(1 << 30))) for p, s in zip(picks, scales)]

    def on(self, name):
        return name not in self.disabled

    def render(self, name, midi, scale, vseed, **kw):
        key = (name, midi, round(scale, 6), vseed, tuple(sorted(kw.items())))
        if key not in self.cache:
            y = RECIPES[name](midi, scale, np.random.default_rng(vseed), **kw)
            self.cache[key] = y / max(body_rms(y), 1e-9)       # unit body RMS
        return self.cache[key]

    def best(self, name, chroma, k=1, shift=0):
        vs = self.variants[name]
        order = sorted(range(len(vs)), key=lambda i: (-pc_fit(chroma, vs[i][0]), i))
        return [vs[i] for i in order[:k]]

    def note(self, name, midi, idx=0, **kw):
        _, scale, vseed = self.variants[name][idx % 3]
        return self.render(name, midi, scale, vseed, **kw)


def make_swell(chords_src, src_bar, size):
    """Swell: one bar of Spencer's chords stem, reversed, through the room, fading up to the downbeat."""
    seg = chords_src[barf(src_bar): barf(src_bar + 1)][::-1].copy()
    n = len(seg)
    pad = np.concatenate([np.zeros((int(0.5 * SR), 2)), seg, np.zeros((int(2 * SR), 2))])
    board = Pedalboard([Reverb(room_size=size, damping=0.5, wet_level=1.0, dry_level=0.0, width=0.7)])
    wet = pb_run(board, pad)[int(0.5 * SR): int(0.5 * SR) + n] * reverb_gain(size)
    y = 0.5 * seg + 0.8 * wet
    u = np.linspace(0, 1, n)
    y *= (u ** 2.2)[:, None]
    f = int(0.012 * SR)
    y[-f:] *= np.linspace(1, 0, f)[:, None]
    y = fft_filter_padded(y, lambda fr: mag_hp(fr, 150, 2) * mag_lp(fr, 6000, 2))
    return y / max(body_rms(y), 1e-9)


def make_lachop(melody_src, notes, seed):
    """la-chop: 240 ms of Spencer's melody at note onsets, resampled +12 (to 120 ms), through
    two parallel band-passes (700 / 1100 Hz, Q 4): a small 'la/da' syllable."""
    r = np.random.default_rng(seed)
    cand = [n for n in notes if n.midi % 12 in PITCH_SET and n.dur >= 1.5]
    picks = sorted(r.choice(len(cand), size=min(3, len(cand)), replace=False).tolist())
    out = []
    six = BAR / 16
    m = melody_src.mean(axis=1)
    for i in picks:
        nt = cand[i]
        scale = 1 + r.uniform(-0.04, 0.04)
        a = int(round(nt.slot * six))
        seg = m[a: a + int(0.240 * scale * SR)]
        seg = signal.resample_poly(seg, 1, 2)
        bp = lambda f, c: 1.0 / np.sqrt(1 + (4 * (f / c - c / np.maximum(f, 1e-9))) ** 2)
        y = fft_filter_padded(seg, lambda f: bp(f, 700) + 0.8 * bp(f, 1100))
        y *= env_ad(len(y), 0.004, 0.06)
        out.append((nt.midi + 12, y / max(body_rms(y), 1e-9)))
    return out


# ----------------------------------------------------------------------------- render helpers

@dataclass
class Mix:
    n: int
    dry: np.ndarray = None
    send: np.ndarray = None
    events: list = field(default_factory=list)

    def __post_init__(self):
        self.dry = np.zeros((self.n, 2))
        self.send = np.zeros((self.n, 2))
        self.fx = np.zeros((self.n, 2))      # sample-palette hits only, for the level check

    def add(self, x, send_db=None):
        self.dry += x
        if send_db is not None:
            self.send += x * db(send_db)

    def hit(self, name, snd, frame, gain, pan, send_db):
        place(self.dry, snd, frame, gain, pan)
        place(self.fx, snd, frame, gain, pan)
        place(self.send, snd, frame, gain * db(send_db), pan)
        mono = snd if snd.ndim == 1 else snd.mean(axis=1) * np.sqrt(2)
        own = fft_filter_padded(mono, lambda f: mag_hp(f, 200, 2)) ** 2
        k = min(len(own), int(0.1 * SR))                       # loudest 100 ms of the sound
        loud = np.sqrt(np.convolve(own, np.ones(k) / k, mode="valid").max())
        self.events.append({"sound": name, "frame": int(frame), "bar": round(frame / BAR + 1, 3),
                            "rms": float(gain * np.sqrt(0.5) * loud)})

    def fx_levels(self):
        """Median level of each palette sound (over its own length) against the rest of the mix over
        the bar around it, both high-passed at 200 Hz so the sub bass does not hide the comparison (dB)."""
        hp = lambda f: mag_hp(f, 200, 2)
        bed = fft_filter(self.dry - self.fx, hp)
        out = {}
        half = int(BAR / 2)
        for e in self.events:
            ctx = (e["frame"] + np.arange(-half, half)) % self.n
            a = e["rms"]
            b = np.sqrt((bed[ctx] ** 2).mean())
            out.setdefault(e["sound"], []).append(todb(a / max(b, 1e-9)))
        return {k: round(float(np.median(v)), 1) for k, v in sorted(out.items())}


def melody_line(notes, src_bar0, nbars, octave, keep=None, src_len_bars=16):
    """Notes of the transcription for source bars [src_bar0, src_bar0+nbars), as (rel16, midi, dur16)."""
    out = []
    for nt in notes:
        b = nt.slot // 16
        rel = (b - src_bar0) % src_len_bars
        if rel >= nbars:
            continue
        if keep is not None and (nt.slot % 16) not in keep:
            continue
        out.append((rel * 16 + nt.slot % 16, nt.midi + 12 * octave, nt.dur))
    out.sort()
    # duration: until the next kept note, max one beat and a half
    res = []
    for i, (s, m, d) in enumerate(out):
        nxt = out[i + 1][0] if i + 1 < len(out) else s + 8
        res.append((s, m, min(nxt - s, 6)))
    return res


def play_line(mix, pal, line, dst_bar0, gain, send_db, pan=0.0, name="music-box"):
    six = BAR / 16
    for i, (s, m, d) in enumerate(line):
        dur = d * six / SR
        snd = pal.render("music-box", m, 1.0, 11 + i % 3, dur=round(dur, 4))
        mix.hit(name, snd, barf(dst_bar0) + int(round(s * six)), gain, pan, send_db)


# ----------------------------------------------------------------------------- the build

def build(args):
    disabled = [s.strip() for s in (args.without or "").split(",") if s.strip()]
    bad = [s for s in disabled if s not in ALL_SAMPLES]
    if bad:
        sys.exit(f"unknown sample(s) for --without: {bad}; choose from {ALL_SAMPLES}")
    pal = Palette(args.seed, disabled)
    report = {"brief": "artifacts/qa-2026-11-28-music/MUSIC-BRIEF.md", "seed": args.seed, "bpm": BPM,
              "bar_frames": BAR, "disabled_samples": disabled, "notes": []}

    print("loading stems")
    main = {k: load_mp3(os.path.join(SRC_MAIN, f)) for k, f in [
        ("drums", "[stem]maindrumloop.mp3"), ("bass", "[stem]-mainbass.mp3"), ("chords", "[stem]mainchords.mp3"),
        ("melody", "[stem]-mainmelody.mp3"), ("lead2", "[stem]-mainlead2.mp3")]}
    deck = {k: load_mp3(os.path.join(SRC_DECK, f)) for k, f in [
        ("drums", "[stem]gameboydrums.mp3"), ("chords", "[stem]gameboychords.mp3"), ("lead", "[stem]gameboylead.mp3")]}
    ref_g, _ = sf.read(REF_GARDEN, dtype="float64", always_2d=True)
    ref_d, _ = sf.read(REF_DECK, dtype="float64", always_2d=True)

    offs = measure_offset(ref_g, {k: main[k] for k in ("drums", "chords", "melody")})
    offs.update({"deck_" + k: v for k, v in measure_offset(ref_d, deck).items()})
    off = offs["drums"][0]
    for k, (o, sc) in offs.items():
        print(f"  offset {k}: {o} frames (score {sc:.2f})")
        if sc > 0.15 and abs(o - off) > 48:
            sys.exit(f"stem {k} offset {o} disagrees with drums {off}; refusing to guess")
    report["stem_offset_frames"] = off
    nbars = {"drums": 32, "bass": 32, "chords": 32, "melody": 16, "lead2": 8}
    G = {}
    for k, x in main.items():
        G[k], miss = grid_stem(x, off, nbars[k])
        report["notes"].append(f"main {k}: cut at frame {off}, {miss} frames short of the grid, tail filled")
    D = {}
    for k, x in deck.items():
        D[k], miss = grid_stem(x, off, 8)
        report["notes"].append(f"deck {k}: cut at frame {off}, {miss} frames short of the grid, tail filled")

    print("transcribing melody and deck lead")
    mel_notes = transcribe(G["melody"], 16)
    deck_notes = transcribe(D["lead"], 8)
    chroma_main = bar_chroma(G["chords"], 32)
    chroma_deck = bar_chroma(D["chords"], 8)
    report["transcription"] = {
        "melody_bars_1_2": [(n.slot, librosa.midi_to_note(n.midi)) for n in mel_notes if n.slot < 32],
        "deck_lead_bars_1_2": [(n.slot, librosa.midi_to_note(n.midi)) for n in deck_notes if n.slot < 32]}

    print("processing stems")
    drums_full, dinfo = drum_chain(G["drums"], "garden")
    drums_tops = fft_filter(drums_full, lambda f: mag_hp(f, 250, 2)) * db(-6)
    bass_m = fft_filter(G["bass"].mean(axis=1), lambda f: mag_hp(f, 35, 2))
    pk = np.abs(bass_m).max()
    harm = fft_filter(np.tanh(4 * bass_m / pk), lambda f: mag_hp(f, 120, 2) * mag_lp(f, 500, 2))
    harm *= np.sqrt((bass_m ** 2).mean()) / np.sqrt((harm ** 2).mean()) * db(-10)
    bass_day = stereo(bass_m + harm)
    bass_night = stereo(bass_m) * db(-3)
    chords = fft_filter(G["chords"], lambda f: mag_hp(f, 110, 2)) * db(1)

    def lead_proc(x, gain_db):
        m, s = ms_split(x)
        y = ms_join(m, s * db(-8)) * db(gain_db)
        return fft_filter(y, lambda f: mag_lp(f, 7000, 2))

    melody = lead_proc(G["melody"], 2)
    lead2 = lead_proc(G["lead2"], 0)
    report["mono_loss_db"] = {
        "melody_before": round(mono_loss_db(G["melody"]), 2), "melody_after": round(mono_loss_db(melody), 2),
        "lead2_before": round(mono_loss_db(G["lead2"]), 2), "lead2_after": round(mono_loss_db(lead2), 2)}
    report["drums_garden"] = dinfo

    def active_rms(x):
        e = (x ** 2).mean(axis=1)
        k = int(0.1 * SR)
        blocks = e[: (len(e) // k) * k].reshape(-1, k).mean(axis=1)
        thr = blocks.max() * db(-30) ** 2
        return float(np.sqrt(blocks[blocks > thr].mean()))

    REF = active_rms(melody)
    rel = lambda d: REF * db(d) / np.sqrt(0.5)   # unit-body-RMS mono sound -> dB under the melody

    # ---------------------------------------------------------------- DAY
    print("arranging day")
    day = Mix(N_DAY)
    sp = lambda b: PHRASE_SRC[(b - 1) // 8] * 8 + (b - 1) % 8     # source bar (0-based) of loop bar b
    drum_mode = {}
    for b in range(1, 65):
        sec = (b - 1) // 8
        drum_mode[b] = ["tops", "full", "full", "full", "none", "tops", "full", "full"][sec]
    blocks = [Block(drums_tops if drum_mode[b] == "tops" else drums_full, sp(b), b - 1, 1)
              for b in range(1, 65) if drum_mode[b] != "none"]
    drums_day = assemble(N_DAY, blocks)
    mutes = [(pos(b, 4), pos(b + 1, 1)) for b in (8, 24, 56)] + [(pos(64, 3), N_DAY)]
    drums_day = gate(drums_day, mutes)
    day.add(drums_day, -24)

    bed = lambda p: db(C1_BED_DB) if p == 4 else db(A1_BED_DB) if p == 0 else 1.0
    bass_blocks = [Block(bass_day, PHRASE_SRC[p] * 8, p * 8, 8, bed(p)) for p in range(8)]
    day.add(assemble(N_DAY, bass_blocks))

    chords_arr = assemble(N_DAY, [Block(chords, PHRASE_SRC[p] * 8, p * 8, 8, bed(p)) for p in range(8)])

    def c1_sweep(x):
        """C1 chords: LP sweeping 500 Hz to open over bars 33-40 (STFT magnitude mask, zero-phase).
        Outside C1 the mask is 1, so the STFT round trip leaves the audio unchanged."""
        a, b = pos(33), pos(41)
        nfft, hop = 4096, 1024
        margin = 4 * nfft
        idx = np.arange(a - margin, b + margin) % len(x)
        out = x.copy()
        keep = np.arange(margin // 2, len(idx) - margin // 2)
        for ch in range(2):
            seg = x[idx, ch]
            f, t, Z = signal.stft(seg, fs=SR, window="hann", nperseg=nfft, noverlap=nfft - hop,
                                  boundary=None, padded=False)
            tf = (t * SR - margin) / (b - a)                   # 0..1 across C1
            fc = 500 * (20000 / 500) ** np.clip(tf, 0, 1)
            mask = 1.0 / np.sqrt(1 + (f[:, None] / fc[None, :]) ** 6)
            mask = np.where((tf >= 0) & (tf < 1), mask, 1.0)
            with warnings.catch_warnings():       # NOLA fails only at the cropped margins
                warnings.simplefilter("ignore")
                _, y = signal.istft(Z * mask, fs=SR, window="hann", nperseg=nfft, noverlap=nfft - hop, boundary=False)
            out[idx[keep], ch] = y[keep]
        return out

    chords_day = c1_sweep(chords_arr)
    day.add(chords_day, -18)

    mel_bars = [b for b in range(1, 65) if (b <= 16) or (17 <= b <= 20) or (25 <= b <= 28) or (49 <= b <= 64)]
    mel_blocks = [Block(melody, (b - 1) % 16, b - 1, 1) for b in mel_bars]
    melody_day = assemble(N_DAY, mel_blocks)
    day.add(melody_day, -14)

    l2_blocks = [Block(lead2, (b - 1) % 8, b - 1, 1) for b in list(range(21, 25)) + list(range(29, 33))]
    l2_blocks += [Block(balance(lead2, 0.25), (b - 1) % 8, b - 1, 1, db(-5)) for b in range(57, 65)]
    day.add(assemble(N_DAY, l2_blocks), -12)

    # day samples
    SEND_S = -10
    chroma_of = lambda b: chroma_main[sp(b)]
    pan_cycle = [0.4, -0.4]
    pc_i = [0]

    def nextpan(scale=1.0):
        pc_i[0] += 1
        return pan_cycle[pc_i[0] % 2] * scale

    if pal.on("pip"):
        for k, b in enumerate((4, 12, 36, 44, 60)):
            v = pal.best("pip", chroma_of(b), k=2)
            v = v if k % 2 == 0 else v[::-1]
            p = nextpan()
            for j, (m, s, vs) in enumerate(v):
                day.hit("pip", pal.render("pip", m, s, vs), pos(b, 4.5 + 0.25 * j), rel(-10), p, SEND_S)
    if pal.on("tok"):
        for b in list(range(1, 9)) + list(range(33, 41)):
            for bt in (1.5, 2.5, 3.5, 4.5):
                if b in (8,) and bt >= 4:
                    continue
                m, s, vs = pal.variants["tok"][int(bt) % 2]
                day.hit("tok", pal.render("tok", m, s, vs), pos(b, bt), rel(-15), nextpan(0.75), SEND_S)
        for b in (8, 24, 56):
            fill = sorted(pal.variants["tok"], key=lambda v: -v[0])
            for j, bt in enumerate((4.0, 4 + 1 / 3, 4 + 2 / 3)):
                m, s, vs = fill[j]
                day.hit("tok-fill", pal.render("tok", m, s, vs), pos(b, bt), rel(-11), (-0.3, 0.0, 0.3)[j], SEND_S)
    if pal.on("plip"):
        for b in (8, 24, 40):
            v = pal.best("plip", chroma_of(b), k=2)
            beats = (4 + 1 / 6, 4.5) if b in (8, 24) else (4.0, 4.375)
            p = nextpan(0.9)
            for j, (m, s, vs) in enumerate(v):
                day.hit("plip", pal.render("plip", m, s, vs), pos(b, beats[j]), rel(-11), p * (1 - 2 * j), SEND_S)
    if pal.on("boing"):
        for b in (16, 48):
            m, s, vs = pal.variants["boing"][b % 3]
            day.hit("boing", pal.render("boing", m, s, vs), pos(b, 4), rel(-12), -0.2 if b == 16 else 0.2, SEND_S)
    if pal.on("swell"):
        sw = make_swell(chords, 31, 0.25)
        for b in (16, 32, 48, 64):
            day.hit("swell", sw, pos(b, 1), rel(-10) * np.sqrt(0.5), 0.0, SEND_S)
    if pal.on("music-box"):
        line = melody_line(mel_notes, 8, 8, +1)
        play_line(day, pal, line, 40, rel(-4), -14)
    if pal.on("shaker"):
        r = np.random.default_rng(args.seed + 8)
        six = BAR / 16
        for b in list(range(17, 33)) + list(range(49, 65)):
            for k in range(16):
                swing = 0.1 * six if k % 2 == 1 else 0.0
                accent = db(6) if k in (4, 12) else db(r.uniform(-1.5, 1.5))
                snd = s_shaker(1.0, 1 + r.uniform(-0.04, 0.04), np.random.default_rng(int(r.integers(1 << 30))))
                snd = snd / max(body_rms(snd), 1e-9)
                day.hit("shaker", snd, pos(b) + int(round(k * six + swing)), rel(-24) * accent, 0.3 if k % 4 else -0.3, SEND_S)
    if pal.on("kalimba"):
        cyc = [76, 79, 81]
        i = 0
        for b in (33, 34, 37, 38, 57, 58, 61, 62):
            for e8 in range(8):
                m = cyc[i % 3]
                i += 1
                snd = pal.note("kalimba", m, i)
                acc = db(0) if e8 % 2 == 0 else db(-3)
                day.hit("kalimba", snd, pos(b, 1 + e8 * 0.5), rel(-11) * acc, 0.25 if e8 % 2 else -0.25, SEND_S)
    if pal.on("eep"):
        for b, bt in ((31, 4.5), (63, 2.5)):
            m, s, vs = pal.best("eep", chroma_of(b), k=1)[0]
            day.hit("eep", pal.render("eep", m, s, vs), pos(b, bt), rel(-14), 0.4, SEND_S)
    if pal.on("la-chop"):
        chops = make_lachop(G["melody"], mel_notes, args.seed + 3)
        for b in (34, 38, 62):
            order = sorted(range(len(chops)), key=lambda i: -pc_fit(chroma_of(b), chops[i][0]))
            for j, bt in enumerate((2.5, 3.0, 4.0)):
                m, y = chops[order[(0, 1, 0)[j] % len(order)]]
                day.hit("la-chop", y, pos(b, bt), rel(-11), (-0.3, 0.3, -0.1)[j], SEND_S)
        report["la_chop_pitches"] = [librosa.midi_to_note(m) for m, _ in chops]

    print("  day room + bus")
    day_wet = room(day.send, 0.25)
    day_mix = day.dry + day_wet
    day_mix, glue_day = glue(day_mix)
    shelf = 0.0
    while hf_share(day_mix) > 0.04 and shelf > -3.0:
        shelf -= 0.5
        day_mix = fft_filter(day_mix, lambda f: mag_rbj(f, "highshelf", 6000, -0.5, 0.707))
    if shelf:
        report["notes"].append(f"day: {shelf} dB master shelf at 6 kHz to keep the share above 6 kHz under 4%")
    day_out = finish(day_mix, -17.6, -1.5)
    report["glue"] = {"day": glue_day}

    # ---------------------------------------------------------------- NIGHT
    print("arranging night")
    night = Mix(N_DAY)
    night.add(assemble(N_DAY, [Block(bass_night, PHRASE_SRC[p] * 8, p * 8, 8, bed(p)) for p in range(8)]))
    chords_night = c1_sweep(fft_filter(chords_arr, lambda f: mag_lp(f, 1800, 2)))
    night.add(chords_night, -12)
    mel_night = fft_filter(melody_day, lambda f: mag_lp(f, 1200, 2)) * db(-10)
    night.add(mel_night, -10)
    NSEND = -8
    if pal.on("music-box"):
        for b in mel_bars:
            line = melody_line(mel_notes, (b - 1) % 16, 1, +1, keep={0, 4, 8})
            play_line(night, pal, line, b - 1, rel(-2), NSEND)
        play_line(night, pal, melody_line(mel_notes, 8, 8, +1), 40, rel(-4), NSEND)
    # lead2 ghost: bar-wise reversed (so each bar stays on its chord), room only
    ghost = np.zeros((N_DAY, 2))
    for b in range(57, 65):
        seg = lead2[barf((b - 1) % 8): barf((b - 1) % 8 + 1)][::-1]
        place(ghost, seg, pos(b))
    night.send += ghost * db(-4)
    if pal.on("tok"):
        for b in list(range(17, 33)) + list(range(49, 65)):
            for bt, idx in ((2, 0), (4, 1)):
                v = sorted(pal.variants["tok"], key=lambda q: -q[0])[0 if idx == 0 else -1]
                night.hit("tok-ticktock", pal.render("tok", *v), pos(b, bt), rel(-20), (0.2, -0.2)[idx], NSEND)
    if pal.on("ribbit"):
        for b, bt, p in ((12, 2.5, -0.4), (44, 3.5, 0.4)):
            m, s, vs = pal.variants["ribbit"][b % 3]
            night.hit("ribbit", pal.render("ribbit", m, s, vs), pos(b, bt), rel(-12), p, NSEND)
    if pal.on("hoo"):
        for b, bt, p in ((30, 2.0, 0.3), (62, 2.5, -0.3)):
            m, s, vs = pal.variants["hoo"][b % 3]
            night.hit("hoo", pal.render("hoo", m, s, vs), pos(b, bt), rel(-11), p, NSEND)
    if pal.on("plip"):
        for b in (8, 24, 40):
            v = pal.best("plip", chroma_of(b), k=2)
            for j, (m, s, vs) in enumerate(v):
                night.hit("plip", pal.render("plip", m, s, vs), pos(b, (4.0, 4.375)[j]), rel(-15), (0.35, -0.35)[j], NSEND)
    if pal.on("pip"):
        for b in (4, 36, 60):
            m, s, vs = pal.best("pip", chroma_of(b), k=1)[0]
            night.hit("pip", pal.render("pip", m - 12, s, vs), pos(b, 4.5), rel(-14), 0.3, NSEND)

    print("  night room + bus")
    night_wet = room(night.send, 0.6)
    night_mix = night.dry + night_wet
    night_mix = fft_filter(night_mix, lambda f: mag_rbj(f, "highshelf", 5000, -3, 0.707))
    night_mix, glue_night = glue(night_mix)
    night_out = finish(night_mix, -20.6, -6.0)
    report["glue"]["night"] = glue_night

    # ---------------------------------------------------------------- POCKET DECK
    print("arranging pocket deck")
    ddrums, dinfo2 = drum_chain(D["drums"], "deck")
    report["drums_deck"] = dinfo2
    dtops = fft_filter(ddrums, lambda f: mag_hp(f, 250, 2)) * db(-6)
    dchords = D["chords"].copy()
    dlead = D["lead"] * db(-2)
    if mono_loss_db(dlead) < -1.0:
        m, s = ms_split(dlead)
        dlead = ms_join(m, s * db(-8))
    REFD = active_rms(dlead)
    reld = lambda d: REFD * db(d) / np.sqrt(0.5)
    dk = Mix(N_DECK)
    blocks = [Block(dtops, 0, 0, 8)] + [Block(ddrums, 0, p * 8, 8, db(-2) if p == 2 else 1.0) for p in (1, 2, 3)]
    dk.add(assemble(N_DECK, blocks), -30)
    dk_chords = assemble(N_DECK, [Block(dchords, 0, p * 8, 8, db(1.5) if p == 2 else 1.0) for p in range(4)])
    dk.add(dk_chords, -24)
    lead_arr = assemble(N_DECK, [Block(dlead, 0, p * 8, 8) for p in (0, 1, 3)])
    gaps = [(pos(b, 3), pos(b + 1, 1)) for b in (26, 28, 30)]
    lead_arr_g = gate(lead_arr, gaps)
    echo = np.roll(lead_arr, int(round(0.75 * BEAT)), axis=0) * db(-12) + np.roll(lead_arr, int(round(1.5 * BEAT)), axis=0) * db(-18)
    echo = gate(echo, [(0, gaps[0][0])] + [(gaps[i][1], gaps[i + 1][0]) for i in range(len(gaps) - 1)] + [(gaps[-1][1], N_DECK)])
    dk.add(lead_arr_g + echo, -20)
    DS = -16
    chroma_d = lambda b: chroma_deck[(b - 1) % 8]
    if pal.on("tok"):
        for b in range(1, 9):
            for bt in (1.5, 2.5, 3.5, 4.5):
                m, s, vs = pal.variants["tok"][int(bt) % 2]
                dk.hit("tok", pal.render("tok", m, s, vs), pos(b, bt), reld(-16), nextpan(0.75), DS)
    if pal.on("pip"):
        for b in (12, 16):
            v = pal.best("pip", chroma_d(b), k=2)
            p = nextpan()
            for j, (m, s, vs) in enumerate(v):
                dk.hit("pip", pal.render("pip", m, s, vs), pos(b, 4.5 + 0.25 * j), reld(-11), p, DS)
    if pal.on("kalimba"):
        for b in (17, 19, 21, 23, 24):
            fig = [72, 76, 79] if b != 24 else [79, 76, 72]
            for j, m in enumerate(fig):
                dk.hit("kalimba", pal.note("kalimba", m, j), pos(b, 3 + 0.5 * j), reld(-7), (-0.25, 0.0, 0.25)[j], DS)
    if pal.on("plip"):
        for b in (20, 24):
            v = pal.best("plip", chroma_d(b), k=2)
            for j, (m, s, vs) in enumerate(v):
                dk.hit("plip", pal.render("plip", m, s, vs), pos(b, (4.5, 4.875)[j]), reld(-12), (0.35, -0.35)[j], DS)
    if pal.on("swell"):
        dsw = make_swell(dchords, 7, 0.25)
        dk.hit("swell", dsw, pos(32, 1), reld(-11) * np.sqrt(0.5), 0.0, DS)
    print("  deck room + bus")
    deck_mix = dk.dry + room(dk.send, 0.25)
    deck_mix = fft_filter(deck_mix, lambda f: mag_rbj(f, "peak", 3000, -2, 0.7))
    deck_mix, glue_deck = glue(deck_mix)
    deck_target = round(lufs(ref_d), 1)
    deck_out = finish(deck_mix, deck_target, -1.5)
    report["glue"]["deck"] = glue_deck

    # ---------------------------------------------------------------- DECK LITE
    print("arranging deck lite")
    lt = Mix(N_LITE)
    lt.add(assemble(N_LITE, [Block(dchords, 0, p * 8, 8) for p in range(2)]), -24)
    if pal.on("tok"):
        for b in range(1, 17):
            for bt, idx in ((2, 0), (4, 1)):
                v = sorted(pal.variants["tok"], key=lambda q: -q[0])[0 if idx == 0 else -1]
                lt.hit("tok-ticktock", pal.render("tok", *v), pos(b, bt), reld(-20), (0.2, -0.2)[idx], DS)
    if pal.on("music-box"):
        play_line(lt, pal, melody_line(deck_notes, 0, 8, +1, src_len_bars=8), 0, reld(-3), -16)
        play_line(lt, pal, melody_line(deck_notes, 0, 8, +1, keep={0, 4, 8}, src_len_bars=8), 8, reld(-3), -16)
    lite_mix = lt.dry + room(lt.send, 0.25)
    lite_mix = fft_filter(lite_mix, lambda f: mag_rbj(f, "peak", 3000, -2, 0.7))
    lite_mix, glue_lite = glue(lite_mix)
    lite_out = finish(lite_mix, deck_target - 3.0, -1.5)
    report["glue"]["lite"] = glue_lite

    # ---------------------------------------------------------------- feature-sound checks
    feats = {"pip", "la-chop", "plip", "boing", "eep", "ribbit", "hoo"}
    warn = []
    for label, mx in (("day", day), ("night", night)):
        wins = {}
        for e in mx.events:
            if e["sound"] in feats:
                w = int((e["bar"] - 1) // 2)
                wins.setdefault(w, set()).add(e["sound"])
        for w, s in sorted(wins.items()):
            if len(s) > 1:
                warn.append(f"{label}: bars {2 * w + 1}-{2 * w + 2} carry {sorted(s)}")
    report["feature_density_warnings"] = warn
    report["event_counts"] = {lab: _count(mx.events) for lab, mx in (("day", day), ("night", night), ("deck", dk), ("lite", lt))}
    report["sample_vs_bed_db"] = {lab: mx.fx_levels() for lab, mx in (("day", day), ("night", night), ("deck", dk), ("lite", lt))}
    print("sample level vs everything else in its window (dB):")
    for lab, v in report["sample_vs_bed_db"].items():
        print(f"  {lab}: {v}")

    # ---------------------------------------------------------------- write
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(SAMPLE_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    files = {"garden-day-v2": day_out, "garden-night-v2": night_out, "pocket-deck-v2": deck_out,
             "pocket-deck-lite-v2": lite_out}
    q = {}
    for i, (name, x) in enumerate(files.items()):
        qi = quantize16(x, args.seed + 100 + i)
        sf.write(os.path.join(OUT_DIR, name + ".wav"), qi, SR, subtype="PCM_16")
        q[name] = qi.astype(np.float64) / 32767.0
    write_samples(pal, chords, dchords, G["melody"], mel_notes, args.seed)

    print("measuring")
    meas = {name: measure(x, name + ".wav") for name, x in q.items()}
    report["files"] = meas

    # dusk crossfade: midpoint loudness bump (brief section 3)
    dayq, nightq = q["garden-day-v2"], q["garden-night-v2"]
    l_day = meas["garden-day-v2"]["integrated_lufs"]
    mid1 = lufs(np.sqrt(0.5) * dayq + np.sqrt(0.5) * nightq)
    mid15 = lufs(np.sqrt(0.5) ** 1.5 * dayq + np.sqrt(0.5) ** 1.5 * nightq)
    expo = 1.0 if mid1 - l_day <= 1.0 else 1.5
    sweep = []
    for w in np.linspace(0, 1, 11):
        gd, gn = np.cos(w * np.pi / 2) ** expo, np.sin(w * np.pi / 2) ** expo
        sweep.append(round(lufs(gd * dayq + gn * nightq) - l_day, 2))
    report["crossfade"] = {
        "day_lufs": l_day, "night_lufs": meas["garden-night-v2"]["integrated_lufs"],
        "midpoint_equal_power_lufs": round(mid1, 2), "bump_equal_power_lu": round(mid1 - l_day, 2),
        "midpoint_exp1_5_lufs": round(mid15, 2), "bump_exp1_5_lu": round(mid15 - l_day, 2),
        "ship_exponent": expo, "loudness_vs_day_at_w_0_to_1": sweep,
        "rule": "day = V*cos(w*pi/2)^e, night = V*sin(w*pi/2)^e; e = 1.5 only if the equal-power midpoint is > 1 LU over day"}

    if not args.no_encode:
        print("encoding OGG / MP3")
        for name in files:
            wav = os.path.join(OUT_DIR, name + ".wav")
            ogg = os.path.join(OUT_DIR, name + ".ogg")
            ffmpeg(["-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg])
            dec = decode(ogg)
            ref = q[name]
            n = min(len(dec), len(ref))
            err = dec[:n] - ref[:n]
            meas[name]["ogg"] = {
                "bytes": os.path.getsize(ogg), "decoded_frames": int(len(dec)),
                "frames_match": bool(len(dec) == len(ref)),
                "snr_vs_wav_db": round(todb(np.sqrt((ref[:n] ** 2).mean()) / max(np.sqrt((err ** 2).mean()), 1e-12)), 1),
                "seam": seam_stats(dec), "true_peak_dbtp": round(true_peak_db(dec), 2)}
            ffmpeg(["-i", wav, "-c:a", "libmp3lame", "-q:a", "2", os.path.join(PREVIEW_DIR, name + ".mp3")])
        write_previews(q, ref_g, expo, args.seed)

    with open(os.path.join(QA_DIR, "report.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(report, fh, indent=2, default=_jsonable)
        fh.write("\n")
    update_manifest(meas, report)
    print_summary(report)
    return report


def _count(events):
    c = {}
    for e in events:
        c[e["sound"]] = c.get(e["sound"], 0) + 1
    return dict(sorted(c.items()))


def _jsonable(o):
    if isinstance(o, (np.integer,)):
        return int(o)
    if isinstance(o, (np.floating,)):
        return float(o)
    if isinstance(o, np.bool_):
        return bool(o)
    raise TypeError(type(o))


def ffmpeg(args):
    cmd = ["ffmpeg", "-y", "-v", "error"] + args[:-1] + \
          ["-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", args[-1]]
    subprocess.run(cmd, check=True)


def decode(path):
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(out, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def write_mp3(x, path, seed):
    tmp = path[:-4] + ".tmp.wav"
    sf.write(tmp, quantize16(x, seed), SR, subtype="PCM_16")
    ffmpeg(["-i", tmp, "-c:a", "libmp3lame", "-q:a", "2", path])
    os.remove(tmp)


def smoothstep(u):
    u = np.clip(u, 0, 1)
    return u * u * (3 - 2 * u)


def dusk(day, night, total_s, fade_start_s, fade_s, expo):
    n = int(total_s * SR)
    idx = np.arange(n) % len(day)
    t = np.arange(n) / SR
    w = smoothstep((t - fade_start_s) / fade_s)
    gd = np.cos(w * np.pi / 2) ** expo
    gn = np.sin(w * np.pi / 2) ** expo
    y = day[idx] * gd[:, None] + night[idx] * gn[:, None]
    f = int(0.5 * SR)
    y[-f:] *= np.linspace(1, 0, f)[:, None]
    return y


def write_previews(q, ref_g, expo, seed):
    day, night = q["garden-day-v2"], q["garden-night-v2"]
    # 60 s: day, 20 s smoothstep fade (brief's shortened preview) from 20 s, night to the end
    write_mp3(dusk(day, night, 60, 20, 20, expo), os.path.join(PREVIEW_DIR, "dusk-crossfade-60s.mp3"), seed + 201)
    # real dusk: 15 s day, the 120 s in-game fade, 15 s night
    write_mp3(dusk(day, night, 150, 15, 120, expo), os.path.join(PREVIEW_DIR, "dusk-crossfade-120s-realtime.mp3"), seed + 202)
    # before / after: old loop 30 s, then new day 30 s
    n = 30 * SR
    old = ref_g[np.arange(n) % len(ref_g)]
    new = day[:n]
    f = int(0.03 * SR)
    old[-f:] *= np.linspace(1, 0, f)[:, None]
    new = new.copy()
    new[:f] *= np.linspace(0, 1, f)[:, None]
    write_mp3(np.concatenate([old, np.zeros((int(0.4 * SR), 2)), new]), os.path.join(PREVIEW_DIR, "before-after.mp3"), seed + 203)


def write_samples(pal, chords, dchords, melody_src, mel_notes, seed):
    for name in ("pip", "tok", "plip", "boing", "music-box", "kalimba", "eep", "ribbit", "hoo"):
        for i, (m, s, vs) in enumerate(pal.variants[name]):
            y = pal.render(name, m, s, vs)
            y = y / np.abs(y).max() * db(-3)
            sf.write(os.path.join(SAMPLE_DIR, f"{name}-{i + 1}-{librosa.midi_to_note(m).replace('♯', '#')}.wav"),
                     quantize16(y, seed + i), SR, subtype="PCM_16")
    for i, (m, y) in enumerate(make_lachop(melody_src, mel_notes, seed + 3)):
        y = y / np.abs(y).max() * db(-3)
        sf.write(os.path.join(SAMPLE_DIR, f"la-chop-{i + 1}-{librosa.midi_to_note(m).replace('♯', '#')}.wav"),
                 quantize16(y, seed + 10 + i), SR, subtype="PCM_16")
    r = np.random.default_rng(seed + 8)
    for i in range(3):
        y = s_shaker(1.0, 1 + r.uniform(-0.04, 0.04), np.random.default_rng(int(r.integers(1 << 30))))
        sf.write(os.path.join(SAMPLE_DIR, f"shaker-{i + 1}.wav"), quantize16(y / np.abs(y).max() * db(-3), seed + 20 + i), SR,
                 subtype="PCM_16")
    for tag, src, bar in (("garden", chords, 31), ("deck", dchords, 7)):
        y = make_swell(src, bar, 0.25)
        sf.write(os.path.join(SAMPLE_DIR, f"swell-{tag}.wav"), quantize16(y / np.abs(y).max() * db(-3), seed + 30), SR,
                 subtype="PCM_16")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def update_manifest(meas, report):
    path = os.path.join(OUT_DIR, "manifest.json")
    man = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            man = json.load(fh)
    v2 = {"date": "2026-11-28", "built_by": "scripts/build_music.py", "brief": report["brief"],
          "credit": "Spencer's own stems (assets/audio/music-src), arranged and mixed; sample palette synthesized "
                    "in the script or chopped from his stems. No downloads, no generated audio.",
          "upload_format": "ogg (Vorbis q6); WAV is the master", "assets": {}}
    for name, m in meas.items():
        wav = os.path.join(OUT_DIR, name + ".wav")
        entry = {"wav": name + ".wav", "wav_bytes": os.path.getsize(wav), "wav_sha256": sha256(wav),
                 "frames": m["frames"], "seconds": m["seconds"], "sample_rate": SR, "channels": 2, "bits": 16,
                 "loop": True, "integrated_lufs": m["integrated_lufs"], "true_peak_dbtp": m["true_peak_dbtp"],
                 "loudness_range_lu": m["loudness_range_lu"]}
        ogg = os.path.join(OUT_DIR, name + ".ogg")
        if os.path.exists(ogg) and "ogg" in m:
            entry.update({"ogg": name + ".ogg", "ogg_bytes": os.path.getsize(ogg), "ogg_sha256": sha256(ogg)})
        v2["assets"][name] = entry
    v2["crossfade"] = report["crossfade"]
    man["v2"] = v2
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(man, fh, indent=2)
        fh.write("\n")


def print_summary(report):
    print("\n%-22s %10s %9s %8s %8s %6s %6s %7s %6s" % ("file", "frames", "seconds", "LUFS", "dBTP", "LRA", "mono", ">6k", "seam"))
    for name, m in report["files"].items():
        print("%-22s %10d %9.3f %8.2f %8.2f %6.2f %6.2f %6.1f%% %6.2f" % (
            name, m["frames"], m["seconds"], m["integrated_lufs"], m["true_peak_dbtp"], m["loudness_range_lu"],
            m["mono_loss_db"], 100 * m["share_above_6k"], m["seam"]["wrap_step_ratio_p99"]))
        if "ogg" in m:
            o = m["ogg"]
            print("   ogg %d bytes, %d frames (match %s), SNR %.1f dB, seam step ratio %.2f, TP %.2f" % (
                o["bytes"], o["decoded_frames"], o["frames_match"], o["snr_vs_wav_db"], o["seam"]["wrap_step_ratio_p99"],
                o["true_peak_dbtp"]))
    c = report["crossfade"]
    print(f"\ncrossfade midpoint: equal-power {c['bump_equal_power_lu']:+.2f} LU vs day, exponent 1.5 "
          f"{c['bump_exp1_5_lu']:+.2f} LU -> ship exponent {c['ship_exponent']}")
    print("loudness vs day across w (0..1):", c["loudness_vs_day_at_w_0_to_1"])
    print("mono loss:", report["mono_loss_db"])
    if report["feature_density_warnings"]:
        print("feature density:", report["feature_density_warnings"])


# ============================================================================= v3 (2026-11-28, second pass)
# Spencer on the v2 previews: "can we make them less dense, etc, for the day and night music, more background
# ambience, but the pocket deck songs should be more exciting I think".
# Garden day/night become a bed: soft synth pad from his chords, quiet bass, light shaker/brush, the melody once
# per 32 bars, samples a third as often. The Pocket Deck gets a programmed kit, octave bass, arpeggio, stabs,
# pumping pad, a build into bar 17 and a short drop. The lite variant stays calm.

V3_LUFS = {"garden-day-v3": -18.6, "garden-night-v3": -21.6, "pocket-deck-v3": -17.5, "pocket-deck-lite-v3": -21.9}
V3_TP = {"garden-day-v3": -1.5, "garden-night-v3": -6.0, "pocket-deck-v3": -1.5, "pocket-deck-lite-v3": -1.5}
V3_DEFAULT_OFF = ("boing", "la-chop")
V3_SAMPLE_DIR = os.path.join(OUT_DIR, "samples-v3")
V3_PREVIEW_DIR = os.path.join(QA_DIR, "previews-v3")
# Pocket Deck harmony per stem bar, from the chord-stem chroma and the lead's notes (template match + ear)
DECK_CHORDS = ["C", "Am", "C", "G", "Em", "G", "C", "G"]
_ROOT = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
TAB = 4096


def chord_pcs(name):
    r = _ROOT[name[0]]
    return [r, (r + (3 if name.endswith("m") else 4)) % 12, (r + 7) % 12]


def voice(pc, low):
    """MIDI note of pitch class `pc` in the octave starting at `low`."""
    return low + ((pc - low) % 12)


def wtable(harm):
    ph = np.arange(TAB) * 2 * np.pi / TAB
    y = np.zeros(TAB)
    for k, a in harm:
        y += a * np.sin(k * ph)
    return y / np.abs(y).max()


TAB_PAD = wtable([(k, 1.0 / k ** 1.4) for k in range(1, 9)])                  # soft saw
TAB_PAD_BRIGHT = wtable([(k, 1.0 / k ** 1.1) for k in range(1, 13)])
TAB_TRI = wtable([(k, ((-1) ** ((k - 1) // 2)) / k ** 2) for k in range(1, 12, 2)])
TAB_PULSE = wtable([(k, np.sin(np.pi * k * 0.25) / k) for k in range(1, 15)])
TAB_SQ = wtable([(k, 1.0 / k) for k in range(1, 12, 2)])


def tab_loop(tab, f, n, frames):
    """Loop-periodic oscillator: the frequency is snapped (by < 0.01 Hz) so the loop holds a whole number of
    cycles, and the phase comes from integer math, so the wrap is seamless and runs are bit-identical."""
    k = max(1, int(round(f * n / SR)))
    t = np.asarray(frames, dtype=np.int64) % n
    p = ((k * t) % n).astype(np.float64) * (TAB / n)
    i = np.floor(p).astype(np.int64)
    fr = p - i
    return tab[i % TAB] * (1 - fr) + tab[(i + 1) % TAB] * fr


def tab_tone(tab, f, n):
    """One-shot oscillator at a fixed frequency, phase from 0."""
    p = (np.arange(n) * (f / SR)) % 1.0 * TAB
    i = np.floor(p).astype(np.int64)
    fr = p - i
    return tab[i % TAB] * (1 - fr) + tab[(i + 1) % TAB] * fr


def unit(y):
    return y / max(body_rms(y), 1e-9)


def note_env(n, att, tau, rel):
    t = np.arange(n) / SR
    e = np.exp(-t / tau)
    a = max(1, int(att * SR))
    e[:a] *= np.linspace(0, 1, a)
    r = min(n, max(1, int(rel * SR)))
    e[-r:] *= np.linspace(1, 0, r)
    return e


def pad_render(n, notes_per_bar, tab, det_cents=7.0, breathe_bars=2, bar=None):
    """Sustained pad: each bar's chord tones, legato across bar lines (half-beat raised-cosine overlap; a held
    note keeps its phase, so it does not dip), three detuned voices (centre, left -det, right +det), and a slow
    loop-periodic breathing on each note."""
    bl = bar or BAR
    out = np.zeros((n, 2))
    xf = int(bl / 8)
    r = 0.5 - 0.5 * np.cos(np.pi * (np.arange(2 * xf) + 0.5) / (2 * xf))
    nb = int(round(n / bl))
    cyc = nb / breathe_bars
    for b, notes in enumerate(notes_per_bar):
        frames = np.arange(int(round(b * bl)) - xf, int(round((b + 1) * bl)) + xf, dtype=np.int64)
        w = np.ones(len(frames))
        w[: 2 * xf] = r
        w[-2 * xf:] = r[::-1]
        t = frames % n
        for m in notes:
            f = hz(m)
            lfo = 1 + 0.12 * np.sin(2 * np.pi * cyc * t / n + (m % 12) * 0.9)
            c = tab_loop(tab, f, n, frames)
            lft = tab_loop(tab, f * 2 ** (-det_cents / 1200), n, frames)
            rgt = tab_loop(tab, f * 2 ** (det_cents / 1200), n, frames)
            g = w * lfo / max(1, len(notes))
            out[t, 0] += g * (0.55 * c + 0.45 * lft)
            out[t, 1] += g * (0.55 * c + 0.45 * rgt)
    return out


def duck_shape(n, tau=0.16):
    """Sidechain-style duck on every beat: 0 at the beat, up to 1 within 6 ms, recovering with `tau`."""
    t = np.arange(n, dtype=np.float64)
    ph = (t - np.floor(t / BEAT) * BEAT) / SR
    return np.minimum(1.0, ph / 0.006) * np.exp(-ph / tau)


# --- new one-shots (all original recipes)

def s_kick(rng):
    n = int(0.24 * SR)
    t = np.arange(n) / SR
    f = 48 + 115 * np.exp(-t / 0.028)
    y = np.sin(osc(f)) * np.exp(-t / 0.15)
    c = int(0.002 * SR)
    y[:c] += fft_filter_padded(rng.standard_normal(c), lambda fr: mag_lp(fr, 4000, 2)) * np.linspace(0.3, 0, c)
    k = int(0.003 * SR)                                       # 3 ms 2.5 kHz click: phone speakers hear the kick
    y[:k] += 0.35 * np.sin(2 * np.pi * 2500 * t[:k]) * np.exp(-t[:k] / 0.001)
    return y * note_env(n, 0.0005, 10, 0.01)


def phone_weight(y, rel_db):
    """Parallel tanh drive kept to 300 Hz-2 kHz, `rel_db` under the dry sound: harmonics a phone can play."""
    d = fft_filter_padded(np.tanh(3 * y / max(np.abs(y).max(), 1e-9)), lambda f: mag_hp(f, 300, 2) * mag_lp(f, 2000, 2))
    return d * (np.sqrt((y ** 2).mean()) / max(np.sqrt((d ** 2).mean()), 1e-12)) * db(rel_db)


def s_hat(rng, open_=False):
    n = int((0.22 if open_ else 0.03) * SR)
    t = np.arange(n) / SR
    nz = fft_filter_padded(rng.standard_normal(n), lambda fr: mag_hp(fr, 7000, 2))
    return nz * note_env(n, 0.0005, 0.09 if open_ else 0.008, 0.004)


def s_crash(rng):
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    nz = fft_filter_padded(rng.standard_normal(n), lambda fr: mag_hp(fr, 3000, 2))
    return nz * np.exp(-t / (1.2 / 3)) * note_env(n, 0.001, 10, 0.05)     # ~1.2 s to -26 dB


def s_snare(rng):
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    tone = np.sin(osc(190 - 12 * (1 - np.exp(-t / 0.02)))) * np.exp(-t / 0.05) * 0.7
    nz = fft_filter_padded(rng.standard_normal(n), lambda fr: mag_hp(fr, 900, 2) * mag_lp(fr, 6000, 2)) * np.exp(-t / 0.08)
    return (tone + 0.8 * nz) * note_env(n, 0.0008, 10, 0.01)


def s_tom(midi, rng):
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    f = hz(midi) * (1 + 0.45 * np.exp(-t / 0.025))
    y = np.sin(osc(f)) * np.exp(-t / 0.15)
    tip = int(0.003 * SR)
    y[:tip] += fft_filter_padded(rng.standard_normal(tip), lambda fr: mag_lp(fr, 3000, 2)) * 0.3
    return y * note_env(n, 0.0008, 10, 0.01)


def s_laser(midi, rng):
    n = int(0.16 * SR)
    u = np.arange(n) / n
    f = hz(midi) * 13.0 * (1 / 13.0) ** (u ** 0.7)          # ~2.4 kHz down to the note: a zip
    ph = osc(f)
    y = np.sin(ph) + 0.25 * np.sin(2 * ph)
    return y * note_env(n, 0.002, 0.08, 0.01)


def s_coin(midi, rng):
    a, b = int(0.06 * SR), int(0.24 * SR)
    y1 = tab_tone(TAB_TRI, hz(midi), a) * note_env(a, 0.001, 10, 0.004)
    y2 = tab_tone(TAB_TRI, hz(midi + 5), b) * note_env(b, 0.001, 0.09, 0.02)
    return np.concatenate([y1, y2])


def s_riser(n, rng):
    """Two-bar build: noise through a band-pass sweeping 400 Hz -> 5 kHz, plus a soft rising tone."""
    u = np.arange(n) / n
    x = rng.standard_normal(n)
    fco = 2 * np.sin(np.pi * (400 * (5000 / 400) ** u) / SR)
    q = 2.0
    lo = bp = 0.0
    out = np.zeros(n)
    for i in range(n):
        hi = x[i] - lo - bp / q
        bp += fco[i] * hi
        lo += fco[i] * bp
        out[i] = bp
    tone = np.sin(osc(200 * 4 ** u)) * 0.15
    y = (out / np.abs(out).max() + tone) * u ** 2.5
    y[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
    return y


def s_boom(rng):
    """Drop impact: a 55 Hz sine thump with a short low noise burst."""
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    y = np.sin(osc(55 + 60 * np.exp(-t / 0.04))) * np.exp(-t / 0.3)
    nz = fft_filter_padded(rng.standard_normal(n), lambda fr: mag_lp(fr, 1800, 2)) * np.exp(-t / 0.06) * 0.35
    return (y + nz) * note_env(n, 0.001, 10, 0.02)


def s_cricket(rng):
    """A cricket: two trains of three 9 ms chirps at C8, 40 ms apart."""
    pulse = int(0.009 * SR)
    t = np.arange(pulse) / SR
    p = np.sin(2 * np.pi * hz(108) * t) * np.sin(np.pi * np.arange(pulse) / pulse) ** 2
    n = int(0.6 * SR)
    y = np.zeros(n)
    for train in (0.0, 0.3 + rng.uniform(-0.02, 0.02)):
        for k in range(3):
            a = int((train + 0.04 * k) * SR)
            y[a: a + pulse] += p * (0.8 + 0.2 * k)
    return y


def s_brush(rng):
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    nz = fft_filter_padded(rng.standard_normal(n), lambda fr: mag_hp(fr, 1200, 2) * mag_lp(fr, 4500, 2))
    e = np.minimum(1, t / 0.03) * np.exp(-np.maximum(t - 0.03, 0) / 0.07)
    return nz * e


def load_all(report):
    """Stems cut to the grid with the same alignment as v2."""
    main = {k: load_mp3(os.path.join(SRC_MAIN, f)) for k, f in [
        ("drums", "[stem]maindrumloop.mp3"), ("bass", "[stem]-mainbass.mp3"), ("chords", "[stem]mainchords.mp3"),
        ("melody", "[stem]-mainmelody.mp3"), ("lead2", "[stem]-mainlead2.mp3")]}
    deck = {k: load_mp3(os.path.join(SRC_DECK, f)) for k, f in [
        ("drums", "[stem]gameboydrums.mp3"), ("chords", "[stem]gameboychords.mp3"), ("lead", "[stem]gameboylead.mp3")]}
    ref_g, _ = sf.read(REF_GARDEN, dtype="float64", always_2d=True)
    off = measure_offset(ref_g, {"drums": main["drums"]})["drums"][0]
    report["stem_offset_frames"] = off
    nbars = {"drums": 32, "bass": 32, "chords": 32, "melody": 16, "lead2": 8}
    G = {k: grid_stem(x, off, nbars[k])[0] for k, x in main.items()}
    D = {k: grid_stem(x, off, 8)[0] for k, x in deck.items()}
    return G, D


def build_v3(args):
    disabled = set(V3_DEFAULT_OFF) - set(s.strip() for s in (args.with_ or "").split(",") if s.strip())
    disabled |= set(s.strip() for s in (args.without or "").split(",") if s.strip())
    bad = [s for s in disabled if s not in ALL_SAMPLES + ("crickets", "fun-hits")]
    if bad:
        sys.exit(f"unknown sample(s): {bad}")
    pal = Palette(args.seed, sorted(disabled))
    ver = args.version
    prev = {"v3": "v2", "v4": "v3"}[ver]
    garden_only = ver == "v4"                       # v4: garden day + night only; the deck stays v3
    pads = (args.pad or ("off" if ver == "v4" else "on")) == "on"
    sample_dir = os.path.join(OUT_DIR, f"samples-{ver}")
    preview_dir = os.path.join(QA_DIR, f"previews-{ver}")
    tgt = lambda base: (V3_LUFS[base + "-v3"], V3_TP[base + "-v3"])
    on = lambda name: name not in disabled
    report = {"version": ver, "pads": pads, "brief": "artifacts/qa-2026-11-28-music/MUSIC-BRIEF.md",
              "feedback": "Spencer: less dense day/night, more background ambience; Pocket Deck more exciting",
              "seed": args.seed, "disabled_samples": sorted(disabled), "targets": {"lufs": V3_LUFS, "true_peak": V3_TP}}
    print(f"{ver}: loading stems")
    G, D = load_all(report)
    mel_notes = transcribe(G["melody"], 16)
    deck_notes = transcribe(D["lead"], 8)
    chroma_main = bar_chroma(G["chords"], 32)

    def lead_proc(x, gain_db, lp):
        m, s = ms_split(x)
        return fft_filter(ms_join(m, s * db(-8)) * db(gain_db), lambda f: mag_lp(f, lp, 2))

    def active_rms(x):
        e = (x ** 2).mean(axis=1)
        k = int(0.1 * SR)
        blocks = e[: (len(e) // k) * k].reshape(-1, k).mean(axis=1)
        return float(np.sqrt(blocks[blocks > blocks.max() * db(-30) ** 2].mean()))

    melody = lead_proc(G["melody"], -4, 4500)
    lead2 = lead_proc(G["lead2"], -6, 4500)
    REF = active_rms(lead_proc(G["melody"], 2, 7000))          # the v2 melody level, so the dB numbers compare
    rel = lambda d: REF * db(d) / np.sqrt(0.5)
    sp = lambda b: PHRASE_SRC[(b - 1) // 8] * 8 + (b - 1) % 8

    # ---------------------------------------------------------------- GARDEN (bed shared by day and night)
    print(f"{ver}: garden bed")
    N = N_DAY
    pad_notes = []
    for b in range(1, 65):
        ch = chroma_main[sp(b)]
        pcs = [int(p) for p in np.argsort(ch)[::-1] if ch[p] > 0.5][:4]
        pad_notes.append(sorted(voice(p, 53) for p in pcs))
    chords_arr = assemble(N, [Block(fft_filter(G["chords"], lambda f: mag_hp(f, 110, 2)), PHRASE_SRC[p] * 8, p * 8, 8)
                              for p in range(8)])
    if pads:
        pad = pad_render(N, pad_notes, TAB_PAD)
        pad = fft_filter(pad, lambda f: mag_hp(f, 120, 2) * mag_lp(f, 3200, 2))
        pad *= active_rms(chords_arr) / active_rms(pad) * db(-1)
    chords_soft = fft_filter(chords_arr, lambda f: mag_lp(f, 3500, 2)) * db(-7)
    if not pads:
        # no pad: Spencer's chords stem carries the emptiest stretches (bars 1-8 and 33-40), 1.5 dB up there
        chords_soft = gate(chords_soft, [(pos(1), pos(9)), (pos(33), pos(41))], value=db(1.5), ramp=int(BEAT))
    bass_m = fft_filter(G["bass"].mean(axis=1), lambda f: mag_hp(f, 35, 2))
    harm = fft_filter(np.tanh(4 * bass_m / np.abs(bass_m).max()), lambda f: mag_hp(f, 120, 2) * mag_lp(f, 500, 2))
    harm *= np.sqrt((bass_m ** 2).mean()) / np.sqrt((harm ** 2).mean()) * db(-16)
    bass_blocks = lambda src: assemble(N, [Block(src, sp(b), b - 1, 1) for b in range(1, 65)])
    bass_day = bass_blocks(stereo(bass_m + harm) * db(-3))
    bass_night = bass_blocks(stereo(bass_m) * db(-6))
    report["garden_pad_notes_bars_1_8"] = [[librosa.midi_to_note(m) for m in ns] for ns in pad_notes[:8]]

    # ---------------------------------------------------------------- DAY
    print(f"{ver}: day")
    day = Mix(N)
    if pads:
        day.add(gate(pad, [(pos(33), pos(41))], value=db(-6), ramp=int(BEAT)), -6)   # real space in 33-40
    day.add(chords_soft, -8)
    day.add(bass_day)
    perc_bars = list(range(9, 33)) + list(range(41, 65))
    m_, _s = ms_split(fft_filter(G["drums"], lambda f: mag_lp(f, 160, 4)) * db(-12))
    thump = stereo(m_)                              # the drum loop filtered to a soft kick heartbeat, mono
    day.add(assemble(N, [Block(thump, sp(b), b - 1, 1) for b in list(range(9, 17)) + list(range(41, 49))]))
    mel_bars = list(range(9, 17)) + list(range(41, 49))           # the melody once per 32 bars
    day.add(assemble(N, [Block(melody, (b - 1) % 16, b - 1, 1) for b in mel_bars]), -8)
    day.add(assemble(N, [Block(balance(lead2, 0.2), (b - 1) % 8, b - 1, 1) for b in range(57, 61)]), -6)
    SEND = -6
    r = np.random.default_rng(args.seed + 31)
    six = BAR / 16
    if on("shaker"):
        for b in perc_bars:
            for k in range(0, 16, 2):
                acc = db(3) if k in (4, 12) else db(r.uniform(-2, 0))
                snd = unit(s_shaker(1.0, 1 + r.uniform(-0.04, 0.04), np.random.default_rng(int(r.integers(1 << 30)))))
                day.hit("shaker", snd, pos(b) + int(round(k * six + (0.1 * six if k % 4 == 2 else 0))), rel(-23) * acc,
                        0.25 if k % 4 else -0.25, -12)
            day.hit("brush", unit(s_brush(np.random.default_rng(int(r.integers(1 << 30))))), pos(b, 3), rel(-25), -0.2, -12)
    chroma_of = lambda b: chroma_main[sp(b)]
    if on("pip"):
        for k, b in enumerate((20, 52)):
            v = pal.best("pip", chroma_of(b), k=2)
            for j, (m, s, vs) in enumerate(v if k == 0 else v[::-1]):
                day.hit("pip", pal.render("pip", m, s, vs), pos(b, 4.5 + 0.25 * j), rel(-13), (0.4, -0.4)[k], SEND)
    if on("plip"):
        for b in (28, 60):
            v = pal.best("plip", chroma_of(b), k=2)
            for j, (m, s, vs) in enumerate(v):
                day.hit("plip", pal.render("plip", m, s, vs), pos(b, (4.0, 4.375)[j]), rel(-14), (0.35, -0.35)[j], SEND)
    if on("eep"):
        m, s, vs = pal.best("eep", chroma_of(45), k=1)[0]
        day.hit("eep", pal.render("eep", m, s, vs), pos(45, 4.5), rel(-17), 0.4, SEND)
    if on("kalimba"):
        cyc = [76, 79, 81]
        for i, (b, e8) in enumerate([(b, e) for b in (29, 30) for e in range(8)]):
            day.hit("kalimba", pal.note("kalimba", cyc[i % 3], i), pos(b, 1 + 0.5 * e8),
                    rel(-14) * (1 if e8 % 2 == 0 else db(-3)), 0.25 if e8 % 2 else -0.25, SEND)
    if on("music-box"):
        play_line(day, pal, melody_line(mel_notes, 4, 4, +1, keep={0, 8}), 20, rel(-9), SEND)
        play_line(day, pal, melody_line(mel_notes, 4, 4, +1, keep={0}), 52, rel(-10), SEND)
    if on("swell"):
        sw = make_swell(G["chords"], 31, 0.25)
        for b in (32, 64):
            day.hit("swell", sw, pos(b, 1), rel(-14) * np.sqrt(0.5), 0.0, SEND)
    if on("boing"):
        for b in (16, 48):
            m, s, vs = pal.variants["boing"][b % 3]
            day.hit("boing", pal.render("boing", m, s, vs), pos(b, 4), rel(-15), 0.2, SEND)
    if on("la-chop"):
        chops = make_lachop(G["melody"], mel_notes, args.seed + 3)
        for j, bt in enumerate((2.5, 3.0, 4.0)):
            m, y = chops[(0, 1, 0)[j] % len(chops)]
            day.hit("la-chop", y, pos(38, bt), rel(-14), (-0.3, 0.3, -0.1)[j], SEND)
    print(f"{ver}: day room + bus")
    day_mix = day.dry + room(day.send, 0.78)
    day_mix, g_day = glue(day_mix, 1.0)
    day_out = finish(day_mix, *tgt("garden-day"))

    # ---------------------------------------------------------------- NIGHT
    print(f"{ver}: night")
    night = Mix(N)
    if pads:
        night.add(fft_filter(pad, lambda f: mag_lp(f, 1600, 2)), -3)
    night.add(fft_filter(chords_soft, lambda f: mag_lp(f, 1600, 2)) * db(-6), -4)
    night.add(bass_night)
    NS = -4
    if on("music-box"):
        for b in mel_bars:
            play_line(night, pal, melody_line(mel_notes, (b - 1) % 16, 1, +1, keep={0}), b - 1, rel(-7), NS)
        for b in (25, 29, 57, 61, 3, 7, 19, 23, 35, 39, 51, 55):
            play_line(night, pal, melody_line(mel_notes, (b - 1) % 16, 1, +1, keep={8}), b - 1, rel(-10), NS)
    if on("crickets"):
        for b, bt, p in ((6, 2.5, 0.4), (14, 1.5, -0.3), (22, 3.25, -0.4), (30, 3.75, 0.35), (38, 1.75, 0.3),
                         (46, 2.25, -0.35), (54, 3.0, -0.3), (62, 1.25, 0.4)):
            night.hit("crickets", unit(s_cricket(np.random.default_rng(args.seed + b))), pos(b, bt), rel(-15), p, NS)
    if on("hoo"):
        for b, bt, p in ((30, 2.0, 0.3), (62, 2.5, -0.3)):
            m, s, vs = pal.variants["hoo"][b % 3]
            night.hit("owl-hoo", pal.render("hoo", m, s, vs), pos(b, bt), rel(-13), p, NS)
    if on("ribbit"):
        m, s, vs = pal.variants["ribbit"][1]
        night.hit("ribbit", pal.render("ribbit", m, s, vs), pos(44, 3.5), rel(-15), 0.4, NS)
    if on("plip"):
        m, s, vs = pal.best("plip", chroma_of(40), k=1)[0]
        night.hit("plip", pal.render("plip", m, s, vs), pos(40, 4.0), rel(-16), -0.35, NS)
    print(f"{ver}: night room + bus")
    night_mix = night.dry + room(night.send, 0.88)
    night_mix = fft_filter(night_mix, lambda f: mag_rbj(f, "highshelf", 5000, -3, 0.707))
    night_mix, g_night = glue(night_mix, 1.0)
    night_out = finish(night_mix, *tgt("garden-night"))

    if not garden_only:
        # ---------------------------------------------------------------- POCKET DECK
        print(f"{ver}: pocket deck")
        ND = N_DECK
        dk = Mix(ND)
        ddrums, dinfo = drum_chain(D["drums"], "deck-v3")
        dlead = D["lead"] * db(-2)
        REFD = active_rms(dlead)
        reld = lambda d: REFD * db(d) / np.sqrt(0.5)
        chords_of = lambda b: DECK_CHORDS[(b - 1) % 8]
        # the stem drums (its hats and groove) under the programmed kit; out for the back half of bar 16
        stem_dr = gate(assemble(ND, [Block(ddrums, 0, p * 8, 8, db(-3)) for p in range(4)]), [(pos(16, 3), pos(17))])
        dk.add(stem_dr, -30)
        kit = Mix(ND)                                   # the kit gets the garden drum shelf before it joins the mix
        kick = s_kick(np.random.default_rng(args.seed + 41))
        kick = unit(kick + phone_weight(kick, -6))
        snares = [unit(s_snare(np.random.default_rng(args.seed + 42 + i))) for i in range(3)]
        fills = (8, 24, 32)
        for b in range(1, 33):
            if 17 <= b <= 20 or 29 <= b <= 32:
                kicks = (1, 2, 3, 4)                    # the drop, and the last phrase: four on the floor
            elif b == 16:
                kicks = (1, 2)
            else:
                kicks = (1, 2.75, 3) if b % 2 else (1, 3, 3.5)
            for bt in kicks:
                if b in fills and bt >= 4:
                    continue
                kit.hit("kick", kick, pos(b, bt), reld(-3), 0.0, -40)
            if b in (15, 16):
                continue
            for bt in (2, 4):
                if b in fills and bt == 4:
                    continue
                kit.hit("snare", snares[(b + bt) % 3], pos(b, bt), reld(-7), 0.05, -24)
        # snare roll into bar 17: 8ths through bar 15, 16ths then 32nds through bar 16, rising
        roll = [(15, 1 + 0.5 * k) for k in range(8)] + [(16, 1 + 0.25 * k) for k in range(8)] + \
               [(16, 3 + 0.125 * k) for k in range(16)]
        for i, (b, bt) in enumerate(roll):
            kit.hit("snare-roll", snares[i % 3], pos(b, bt), reld(-18 + 8 * i / (len(roll) - 1)), 0.05, -24)
        toms = [unit(s_tom(m, np.random.default_rng(args.seed + 50 + m))) for m in (55, 52, 50, 48)]   # G3 E3 D3 C3
        for b in fills:
            for j in range(4):
                kit.hit("tom", toms[j], pos(b, 4 + 0.25 * j), reld(-6), (0.3, 0.1, -0.1, -0.3)[j], -24)
        hr = np.random.default_rng(args.seed + 45)
        closed = [unit(s_hat(hr)) for _ in range(3)]
        opened = unit(s_hat(hr, open_=True))
        for b in range(9, 33):
            for k in range(16):
                kit.hit("hat", closed[k % 3], pos(b, 1 + 0.25 * k), reld(-18) * (1 if k % 2 == 0 else db(-3)),
                        0.2 if k % 2 else -0.2, -30)
            if 17 <= b <= 20:
                for bt in (1.5, 2.5, 3.5, 4.5):
                    kit.hit("open-hat", opened, pos(b, bt), reld(-13), 0.15, -24)
        dk.add(fft_filter(kit.dry, lambda f: mag_rbj(f, "highshelf", 6000, -1, 0.707)))
        dk.send += kit.send
        dk.events += kit.events
        # octave bass, 8ths (16ths in the drop); out on beat 4 of bar 16
        for b in range(1, 33):
            root = voice(chord_pcs(chords_of(b))[0], 36)
            step = 0.25 if 17 <= b <= 20 else 0.5
            for k in range(int(round(4 / step))):
                bt = 1 + k * step
                if b == 16 and bt >= 4:
                    continue
                m = root + (12 if k % 2 else 0)
                ln = int(step * BEAT * 0.85)
                y = tab_tone(TAB_PULSE, hz(m), ln) * 1.0 + np.sin(2 * np.pi * hz(m) * np.arange(ln) / SR) * 0.5
                y = fft_filter_padded(y * note_env(ln, 0.003, 0.25, 0.012), lambda f: mag_lp(f, 2200, 2))
                y = y + phone_weight(y, -4)
                lift = db(2) if 17 <= b <= 20 else 1.0
                dk.hit("bass", unit(y), pos(b, bt), reld(-5) * lift * (1 if k % 2 == 0 else db(-2)), 0.0, -40)
        # pumping pad from the deck chords
        dpad_notes = [sorted(voice(p, 55) for p in chord_pcs(chords_of(b))) for b in range(1, 33)]
        dpad = pad_render(ND, dpad_notes, TAB_PAD_BRIGHT, det_cents=9)
        dpad = fft_filter(dpad, lambda f: mag_hp(f, 150, 2) * mag_lp(f, 2600, 2))
        dpad *= REFD / active_rms(dpad) * db(-9)
        depth = np.full(ND, 0.55)
        depth[pos(17):pos(21)] = 0.75
        dpad = dpad * (1 - depth * duck_shape(ND))[:, None]
        dpad = gate(dpad, [(pos(17), pos(21))], value=db(3))     # pad up and pumping harder in the drop
        dk.add(dpad, -16)
        dk.add(assemble(ND, [Block(D["chords"], 0, p * 8, 8) for p in range(4)]), -24)
        # arpeggio countermelody (16ths over the chord tones, octave 5), from bar 9
        for b in range(9, 33):
            pcs = chord_pcs(chords_of(b))
            seq = [voice(pcs[0], 72), voice(pcs[1], 72), voice(pcs[2], 72), voice(pcs[0], 72) + 12]
            if b % 2 == 0:
                seq = seq[::-1]
            for k in range(8 if b == 16 else 16):
                ln = int(0.25 * BEAT * 0.9)
                y = tab_tone(TAB_TRI, hz(seq[k % 4]), ln) * note_env(ln, 0.002, 0.07, 0.01)
                lift = db(6) if 17 <= b <= 20 else 1.0          # the arp leads the drop
                dk.hit("arp", unit(y), pos(b, 1 + 0.25 * k), reld(-10) * lift * (1 if k % 4 == 0 else db(-2)),
                       0.3 if k % 2 else -0.3, -18)
        # call-and-response stabs
        stab_at = {b: (4.0, 4.5) for b in (10, 12, 14)}
        stab_at.update({b: (3.5, 4.0, 4.5) for b in (26, 28, 30)})
        stab_at.update({b: (1.5, 2.5, 3.5, 4.5) for b in (17, 18, 19, 20)})      # the drop: offbeat stabs
        for b, beats in sorted(stab_at.items()):
            ln = int(0.5 * BEAT * 0.6)
            y = sum(tab_tone(TAB_SQ, hz(voice(p, 60)), ln) for p in chord_pcs(chords_of(b))) * note_env(ln, 0.002, 0.09, 0.01)
            y = unit(fft_filter_padded(y, lambda f: mag_lp(f, 2200, 2)))
            for j, bt in enumerate(beats):
                dk.hit("stab", y, pos(b, bt), reld(-8) * (db(3) if 17 <= b <= 20 else 1.0), (-0.25, 0.25, 0.0)[j % 3], -18)
        # lead: out in the drop (17-20), back for 21-24; in 26/28/30 its back half rests and the stabs answer
        lead_arr = assemble(ND, [Block(dlead, 0, p * 8, 8) for p in (0, 1, 3)] + [Block(dlead, 4, 20, 4)])
        lead_arr = gate(lead_arr, [(pos(b, 3), pos(b + 1)) for b in (26, 28, 30)])
        dk.add(lead_arr, -20)
        # the drop hook: the lead's first four bars on the pulse voice, an octave up
        for s16, m, d in melody_line(deck_notes, 0, 4, +1, src_len_bars=8):
            ln = int(d * BEAT / 4)
            y = tab_tone(TAB_PULSE, hz(m), ln) * note_env(ln, 0.003, 0.3, 0.02)
            y = unit(fft_filter_padded(y, lambda f: mag_lp(f, 4000, 2)))
            dk.hit("drop-hook", y, barf(16) + int(round(s16 * BAR / 16)), reld(-5), 0.0, -18)
        # the gap: everything but the riser stops for the last half beat of bar 16
        gap = [(pos(16, 4.5), pos(17))]
        dk.dry = gate(dk.dry, gap)
        dk.send = gate(dk.send, gap)
        rz = Mix(ND)                                   # riser on its own, so its reverb rides through the gap
        if on("fun-hits"):
            rr = np.random.default_rng(args.seed + 60)
            rz.hit("riser", unit(s_riser(pos(17) - pos(15), rr)), pos(15), reld(-11), 0.0, -14)
            dk.hit("boom", unit(s_boom(rr)), pos(17), reld(-2), 0.0, -14)                    # the drop lands
            dk.hit("crash", unit(s_crash(np.random.default_rng(args.seed + 61))), pos(17), reld(-12), 0.0, -14)
            dk.hit("laser", unit(s_laser(43, rr)), pos(8, 4.5), reld(-12), 0.35, -16)       # zip down to G2
            dk.hit("laser", unit(s_laser(45, rr)), pos(24, 4.5), reld(-12), -0.35, -16)     # zip down to A2
            dk.hit("coin", unit(s_coin(79, rr)), pos(12, 4.5), reld(-13), 0.3, -16)          # G5 -> C6
            dk.hit("coin", unit(s_coin(79, rr)), pos(32, 3.5), reld(-13), -0.3, -16)
        print(f"{ver}: deck room + bus")
        deck_mix = dk.dry + gate(room(dk.send, 0.35), gap) + rz.dry + room(rz.send, 0.35)
        dk.events += rz.events
        deck_mix = fft_filter(deck_mix, lambda f: mag_rbj(f, "peak", 3000, -3, 0.7))   # leave 3 kHz to the merge SFX
        # low shelf -6 dB under ~120 Hz (high shelf +6 with -6 overall): the lows came up 10 dB on v2, phones need mids
        deck_mix = fft_filter(deck_mix, lambda f: mag_rbj(f, "highshelf", 120, 6.0, 0.707) * db(-6.0)
                             * mag_rbj(f, "peak", 800, 1.5, 0.7))           # and +1.5 dB of 800 Hz body
        deck_mix, g_deck = glue(deck_mix, 1.5)
        ramp = int(0.03 * SR)                           # section gains after the glue: the drop sits up
        deck_mix = gate(deck_mix, [(pos(1), pos(15))], value=db(-1.0), ramp=ramp)
        deck_mix = gate(deck_mix, [(pos(17), pos(21))], value=db(1.3), ramp=ramp)
        deck_out = finish(deck_mix, *tgt("pocket-deck"))

        # ---------------------------------------------------------------- DECK LITE (calm: the v2 recipe plus a soft pad)
        print(f"{ver}: deck lite")
        NL = N_LITE
        lt = Mix(NL)
        lt.add(assemble(NL, [Block(D["chords"], 0, p * 8, 8) for p in range(2)]), -24)
        lpad = pad_render(NL, dpad_notes[:16], TAB_PAD, det_cents=7)
        lpad = fft_filter(lpad, lambda f: mag_hp(f, 150, 2) * mag_lp(f, 1800, 2))
        lt.add(lpad * (REFD / active_rms(lpad) * db(-14)), -12)
        if on("tok"):
            for b in range(1, 17):
                for bt, idx in ((2, 0), (4, 1)):
                    v = sorted(pal.variants["tok"], key=lambda q: -q[0])[0 if idx == 0 else -1]
                    lt.hit("tok-ticktock", pal.render("tok", *v), pos(b, bt), reld(-20), (0.2, -0.2)[idx], -16)
        if on("music-box"):
            play_line(lt, pal, melody_line(deck_notes, 0, 8, +1, src_len_bars=8), 0, reld(-3), -16)
            play_line(lt, pal, melody_line(deck_notes, 0, 8, +1, keep={0, 4, 8}, src_len_bars=8), 8, reld(-3), -16)
        lite_mix = lt.dry + room(lt.send, 0.35)
        lite_mix = fft_filter(lite_mix, lambda f: mag_rbj(f, "peak", 3000, -2, 0.7))
        lite_mix, g_lite = glue(lite_mix, 1.5)
        lite_out = finish(lite_mix, *tgt("pocket-deck-lite"))

    report["glue"] = {"day": g_day, "night": g_night}
    mixes = [("day", day), ("night", night)]
    files = {f"garden-day-{ver}": day_out, f"garden-night-{ver}": night_out}
    if not garden_only:
        report["glue"].update(deck=g_deck, lite=g_lite)
        report["drums_deck"] = dinfo
        report["deck_chords"] = DECK_CHORDS
        mixes += [("deck", dk), ("lite", lt)]
        files.update({f"pocket-deck-{ver}": deck_out, f"pocket-deck-lite-{ver}": lite_out})
    report["event_counts"] = {lab: _count(mx.events) for lab, mx in mixes}
    report["sample_vs_bed_db"] = {lab: mx.fx_levels() for lab, mx in mixes}

    # ---------------------------------------------------------------- write + measure
    os.makedirs(preview_dir, exist_ok=True)
    q = {}
    for i, (name, x) in enumerate(files.items()):
        qi = quantize16(x, args.seed + 300 + i)
        sf.write(os.path.join(OUT_DIR, name + ".wav"), qi, SR, subtype="PCM_16")
        q[name] = qi.astype(np.float64) / 32767.0
    rs = np.random.default_rng(args.seed + 70)
    if not garden_only:
        os.makedirs(sample_dir, exist_ok=True)
    for name, y in ([] if garden_only else (("kick", s_kick(rs)), ("snare", s_snare(rs)), ("tom-G3", s_tom(55, rs)), ("tom-C3", s_tom(48, rs)),
                    ("laser-G2", s_laser(43, rs)), ("coin-G5-C6", s_coin(79, rs)),
                    ("riser-2bars", s_riser(pos(17) - pos(15), rs)), ("boom", s_boom(rs)), ("cricket-C8", s_cricket(rs)), ("brush", s_brush(rs)))):
        sf.write(os.path.join(sample_dir, name + ".wav"), quantize16(y / np.abs(y).max() * db(-3), args.seed + 80),
                 SR, subtype="PCM_16")
    print(f"{ver}: measuring")
    meas = {name: measure(x, name + ".wav") for name, x in q.items()}
    report["files"] = meas

    def phone_lufs(x):
        """Phone speaker proxy: mono (played on both channels), high-passed at 300 Hz."""
        return round(float(_METER.integrated_loudness(stereo(fft_filter(x.mean(axis=1), lambda f: mag_hp(f, 300, 2))))), 2)

    def seg_lufs(x, b0, b1):
        return float(_METER.integrated_loudness(x[pos(b0): pos(b1)]))

    def band_db(x, b0, b1, lo):
        y = fft_filter(x, lambda f: mag_hp(f, lo, 4))[pos(b0): pos(b1)]
        return 10 * np.log10((y ** 2).mean())

    dq = q.get(f"pocket-deck-{ver}")
    drop = {} if dq is None else {"bar16_lufs": round(seg_lufs(dq, 16, 17), 2), "bar17_lufs": round(seg_lufs(dq, 17, 18), 2),
            "bars1_16_lufs": round(seg_lufs(dq, 1, 17), 2), "bars17_20_lufs": round(seg_lufs(dq, 17, 21), 2),
            "above5k_17_20_vs_1_16_db": round(band_db(dq, 17, 21, 5000) - band_db(dq, 1, 17, 5000), 2)}
    if drop:
        drop["bar17_minus_bar16_lu"] = round(drop["bar17_lufs"] - drop["bar16_lufs"], 2)
        drop["drop_minus_1_16_lu"] = round(drop["bars17_20_lufs"] - drop["bars1_16_lufs"], 2)
        report["deck_drop"] = drop
    phone = {}
    for name, x in q.items():
        phone[name] = phone_lufs(x)
        old = os.path.join(OUT_DIR, name.replace("-" + ver, "-" + prev) + ".wav")
        if os.path.exists(old):
            phone[name.replace("-" + ver, "-" + prev)] = phone_lufs(sf.read(old, dtype="float64", always_2d=True)[0])
    report["phone_lufs_mono_hp300"] = phone
    if drop:
        print("deck drop:", drop)
    print("phone loudness (mono, HP 300 Hz):", phone)
    dayq, nightq = q[f"garden-day-{ver}"], q[f"garden-night-{ver}"]
    l_day = meas[f"garden-day-{ver}"]["integrated_lufs"]

    def mid(e):
        return lufs(np.sqrt(0.5) ** e * dayq + np.sqrt(0.5) ** e * nightq) - l_day

    sweep = [round(lufs(np.cos(w * np.pi / 2) ** 1.5 * dayq + np.sin(w * np.pi / 2) ** 1.5 * nightq) - l_day, 2)
             for w in np.linspace(0, 1, 11)]
    grid = [(round(float(e), 2), mid(e)) for e in np.arange(1.0, 3.01, 0.1)]
    fit = min(grid, key=lambda t: (abs(t[1]), t[0]))
    b15 = mid(1.5)
    report["crossfade"] = {
        "day_lufs": l_day, "night_lufs": meas[f"garden-night-{ver}"]["integrated_lufs"],
        "bump_equal_power_lu": round(mid(1.0), 2), "bump_exp1_5_lu": round(b15, 2),
        "exp1_5_within_1lu": bool(abs(b15) <= 1.0), "loudness_vs_day_at_w_0_to_1_exp1_5": sweep,
        "exponent_for_flat_midpoint": fit[0], "midpoint_at_that_exponent_lu": round(fit[1], 2),
        "midpoint_by_exponent": {str(e): round(v, 2) for e, v in grid}}
    if not args.no_encode:
        print(f"{ver}: encoding")
        for name in files:
            wav = os.path.join(OUT_DIR, name + ".wav")
            ogg = os.path.join(OUT_DIR, name + ".ogg")
            ffmpeg(["-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg])
            dec = decode(ogg)
            meas[name]["ogg"] = {"bytes": os.path.getsize(ogg), "sha256": sha256(ogg), "decoded_frames": int(len(dec)),
                                 "frames_match": bool(len(dec) == len(q[name])), "seam": seam_stats(dec),
                                 "true_peak_dbtp": round(true_peak_db(dec), 2)}
            meas[name]["wav_sha256"] = sha256(wav)
            ffmpeg(["-i", wav, "-c:a", "libmp3lame", "-q:a", "2", os.path.join(preview_dir, name + ".mp3")])
        write_mp3(dusk(dayq, nightq, 60, 20, 20, 1.5), os.path.join(preview_dir, "dusk-crossfade-60s.mp3"), args.seed + 301)
        for v3 in files:
            v2 = os.path.join(OUT_DIR, v3.replace("-" + ver, "-" + prev) + ".wav")
            if not os.path.exists(v2):
                continue
            a, _ = sf.read(v2, dtype="float64", always_2d=True)
            n = 25 * SR
            a = a[np.arange(n) % len(a)].copy()
            bq = q[v3][np.arange(n) % len(q[v3])].copy()
            f = int(0.03 * SR)
            a[-f:] *= np.linspace(1, 0, f)[:, None]
            bq[:f] *= np.linspace(0, 1, f)[:, None]
            write_mp3(np.concatenate([a, np.zeros((int(0.6 * SR), 2)), bq]),
                      os.path.join(preview_dir, f"compare-{v3.replace('-' + ver, '')}-{prev}-then-{ver}.mp3"), args.seed + 310)
    with open(os.path.join(QA_DIR, f"report-{ver}.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(report, fh, indent=2, default=_jsonable)
        fh.write("\n")
    print("\n%-22s %10s %9s %8s %8s %6s %7s %6s" % ("file", "frames", "seconds", "LUFS", "dBTP", "LRA", ">6k", "seam"))
    for name, m in meas.items():
        print("%-22s %10d %9.3f %8.2f %8.2f %6.2f %6.1f%% %6.2f" % (
            name, m["frames"], m["seconds"], m["integrated_lufs"], m["true_peak_dbtp"], m["loudness_range_lu"],
            100 * m["share_above_6k"], m["seam"]["wrap_step_ratio_p99"]))
        if "ogg" in m:
            o = m["ogg"]
            print("   ogg %d bytes, %d frames (match %s), TP %.2f" % (o["bytes"], o["decoded_frames"], o["frames_match"],
                                                                     o["true_peak_dbtp"]))
    c = report["crossfade"]
    print(f"\ncrossfade midpoint with exponent 1.5: {c['bump_exp1_5_lu']:+.2f} LU (equal power {c['bump_equal_power_lu']:+.2f}); "
          f"flattest exponent {c['exponent_for_flat_midpoint']} ({c['midpoint_at_that_exponent_lu']:+.2f} LU)")
    print("loudness vs day across w (exp 1.5):", c["loudness_vs_day_at_w_0_to_1_exp1_5"])
    print("sample level vs bed (dB):")
    for lab, v in report["sample_vs_bed_db"].items():
        print(f"  {lab}: {v}")
    return report


# ============================================================================= Pocket Deck v4, "Marimba Pop"
# artifacts/qa-2026-11-28-music/DECK-V4-BRIEF.md (Fable). Spencer: a different deck song, maybe faster, like other
# drop-and-merge puzzle games, still on the garden's melody. 140 BPM, re-synthesized from the transcription below:
# marimba lead, glock doubling, Karplus-Strong nylon chops, a round bass, ocarina dyads, hand percussion.

BAR4 = 75600                      # 140 BPM: 60 / 140 * 4 * 44100, exact
SIX4 = BAR4 // 16                 # 4725 frames per 16th
N_DECK4 = 64 * BAR4               # 4,838,400
N_LITE4 = 32 * BAR4               # 2,419,200 (exactly half)
DECK4_LUFS, DECK4_TP = -17.5, -1.5
LITE4_LUFS, LITE4_TP = -22.0, -6.0
DECK4_PREVIEWS = os.path.join(QA_DIR, "previews-deck-v4")

CELL4 = {"X": [0, 4, 6, 8, 10, 12], "Y": [0, 2, 4, 8, 10, 12]}
_MEL4 = [("X", "C4 E4 G4 C5 G4 E4"), ("Y", "G4 A4 G4 E4 G4 E4"), ("X", "C4 E4 G4 C5 G4 E4"), ("Y", "E4 G4 E4 C4 E4 C4"),
         ("X", "E4 G4 E4 B4 G4 E4"), ("Y", "E4 A4 E4 G4 B4 G4"), ("X", "E4 G4 B4 C5 G4 E4"), ("Y", "E4 G4 E4 C4 E4 C4"),
         ("X", "C4 E4 G4 C5 G4 E4"), ("Y", "E4 A4 E4 E4 G4 E4"), ("X", "C4 E4 G4 C5 G4 E4"), ("Y", "E4 G4 E4 C4 G4 C4"),
         ("X", "E4 G4 B4 C5 B4 G4"), ("Y", "E4 A4 E4 G4 B4 G4"), ("X", "E4 G4 B4 C5 G4 E4"), ("Y", "E4 G4 E4 C4 E4 C4")]
MEL4 = [[(s, int(librosa.note_to_midi(n))) for s, n in zip(CELL4[c], notes.split())] for c, notes in _MEL4]
_n = lambda s: [int(librosa.note_to_midi(x)) for x in s.split()]
# (first half voicing, second half voicing) per chord bar
CHORDS4 = [(_n("F3 A3 C4 D4"), _n("E3 G3 A3 C4")), (_n("F3 A3 C4 D4"), _n("F3 A3 C4 D4")),
           (_n("D3 F#3 A3 B3"), _n("E3 G3 A3 C4")), (_n("E3 F#3 A3 C4"), _n("D3 F#3 A3 B3")),
           (_n("F3 A3 C4 D4"), _n("E3 G3 A3 C4")), (_n("F3 A3 C4 D4"), _n("F3 A3 C4 D4")),
           (_n("G3 B3 D4 E4"), _n("E3 G3 B3 D4")), (_n("E3 F#3 A3 C#4"), _n("D3 F#3 A3 B3"))]
# bass roots per half bar. Bars 4 and 8 open on F#, not the brief's A: Spencer's bass stem sits on F#/G there
# (measured in build_deck_v4 and reported), and F# is a tone of both voicings.
ROOTS4 = [("D", "A"), ("F", "F"), ("D", "A"), ("F#", "D"), ("D", "A"), ("F", "F"), ("G", "E"), ("F#", "D")]
LEAD2_4 = [_n("B4 D5"), _n("D5 B4"), _n("C5 A4"), _n("G4 A4"), _n("D5 B4"), _n("B4 D5"), _n("A4 C5"), _n("A4 G4")]
_PC = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def p4(bar, slot=0.0):
    return int(round((bar - 1) * BAR4 + slot * SIX4))


def root4(cb, half):
    return voice(_PC[ROOTS4[cb][half]], 38)          # D2..C#3


# --- instruments (all synthesized)

def s_marimba(midi, vel, rng):
    f = hz(midi)
    tau = 0.28 * (523.25 / f) ** 0.6
    n = int(min(1.6, 5 * tau) * SR)
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t / tau)
         + vel * db(-18) * np.sin(2 * np.pi * 3.93 * f * t) * np.exp(-t / 0.06)      # brief: -14; -18 clears 2-5 kHz
         + vel * db(-24) * np.sin(2 * np.pi * 9.6 * f * t) * np.exp(-t / 0.02))
    k = int(0.005 * SR)
    bp = lambda fr: 1.0 / np.sqrt(1 + (2 * (fr / 1200 - 1200 / np.maximum(fr, 1e-9))) ** 2)
    y[:k] += fft_filter_padded(rng.standard_normal(k), bp) * db(-18) * 3 * np.linspace(1, 0, k)
    return y * note_env(n, 0.003, 10, 0.01)


def s_glock(midi, rng):
    f = hz(midi)
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.5) + db(-22) * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-t / 0.15)
         + db(-26) * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t / 0.05))
    # brief: low-pass 6 kHz; 2.2 kHz (4th order) keeps the top notes out of the merge-SFX band
    return fft_filter_padded(y * note_env(n, 0.001, 10, 0.02), lambda fr: mag_lp(fr, 2200, 4))


def ks_pluck(midi, tau, rng):
    """Karplus-Strong nylon string: noise burst low-passed 3 kHz, loop filter 0.5(1 + z^-1) x 0.996, fractional
    delay by linear interpolation, vectorized one period at a time; damped with exp(-t/tau)."""
    f = hz(midi)
    n = int(min(1.6, 6 * tau) * SR)
    period = SR / f - 0.5                         # the two-tap average adds half a sample
    L = int(np.floor(period))
    d = period - L
    y = np.zeros(n + L + 2)
    burst = fft_filter_padded(rng.standard_normal(L + 2), lambda fr: mag_lp(fr, 2200, 2))
    y[:L + 2] = burst
    g = 0.996 * 0.5
    i = L + 2
    while i < len(y):
        j = min(len(y), i + L - 1)
        a = y[i - L: j - L]
        b = y[i - L - 1: j - L - 1]
        c = y[i - L - 2: j - L - 2]
        y[i:j] = g * ((1 - d) * (a + b) + d * (b + c))
        i = j
    y = y[L + 2:]
    t = np.arange(n) / SR
    y = y[:n] * np.exp(-t / tau) * note_env(n, 0.0005, 10, 0.01)
    return fft_filter_padded(y, lambda fr: mag_lp(fr, 2000, 2))           # muted nylon


def s_bass4(midi, rng, tau=0.22):
    n = int(min(2.0, 5 * tau) * SR)
    t = np.arange(n) / SR
    f = hz(midi) * 2 ** ((40 / 1200) * np.maximum(0, 1 - t / 0.025))      # falls 40 cents in 25 ms
    ph = osc(f)
    tri2 = sum(((-1) ** ((k - 1) // 2)) * np.sin(k * 2 * ph) / k ** 2 for k in (1, 3, 5))
    y = np.sin(ph) + db(-10) * tri2 + db(-18) * np.sin(3 * ph)
    y *= np.exp(-t / tau)
    c = int(0.004 * SR)
    y[:c] += fft_filter_padded(rng.standard_normal(c), lambda fr: mag_lp(fr, 800, 2)) * 0.3 * np.linspace(1, 0, c)
    y = y * note_env(n, 0.002, 10, 0.02)
    return y + phone_weight(y, -6)


def s_ocarina(midi, dur, rng):
    n = int((dur + 0.06) * SR)
    t = np.arange(n) / SR
    vib = np.where(t > 0.12, np.minimum(1, (t - 0.12) / 0.1), 0) * (12 / 1200) * np.sin(2 * np.pi * 5.5 * t)
    f = hz(midi) * 2 ** vib
    ph = osc(f)
    y = np.sin(ph) + db(-20) * np.sin(2 * ph) + db(-28) * np.sin(3 * ph)
    fc = hz(midi)
    bp = lambda fr: 1.0 / np.sqrt(1 + (8 * (fr / fc - fc / np.maximum(fr, 1e-9))) ** 2)
    y += fft_filter_padded(rng.standard_normal(n), bp) * db(-26) * 4
    e = np.minimum(1, t / 0.025) * np.where(t > dur, np.exp(-(t - dur) / 0.02), 1.0)
    return y * e * note_env(n, 0.0, 10, 0.01)


def s_clap(rng):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    bp = lambda fr: 1.0 / np.sqrt(1 + (1.5 * (fr / 1200 - 1200 / np.maximum(fr, 1e-9))) ** 2)
    nz = fft_filter_padded(rng.standard_normal(n), lambda fr: bp(fr) * mag_lp(fr, 2000, 2))
    e = np.zeros(n)
    for k in range(3):
        a = int(k * 0.01 * SR)
        seg = np.arange(n - a) / SR
        e[a:] += np.where(seg < 0.008, 1.0, 0.0) if k < 2 else np.exp(-seg / 0.09)
    return nz * e * note_env(n, 0.0005, 10, 0.01)


def s_tamb(rng):
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    return fft_filter_padded(rng.standard_normal(n), lambda fr: mag_hp(fr, 6000, 4)) * np.exp(-t / 0.05) * note_env(n, 0.001, 10, 0.01)


def transcription_check(G):
    """Ear-proxy: the table's melody re-synthesized with sines at 117 BPM against Spencer's melody stem."""
    stem = G["melody"].mean(axis=1).astype(np.float32)
    n = len(stem)
    syn = np.zeros(n)
    six = BAR / 16
    for b in range(16):
        for s, m in MEL4[b]:
            a = int(round((b * 16 + s) * six))
            ln = int(1.5 * six)
            t = np.arange(ln) / SR
            syn[a: a + ln] += np.sin(2 * np.pi * hz(m) * t) * note_env(ln, 0.003, 0.15, 0.01)
    hop = 512
    cq = lambda x: np.abs(librosa.cqt(x.astype(np.float32), sr=SR, hop_length=hop, fmin=librosa.note_to_hz("C3"), n_bins=60))
    S, R = cq(stem), cq(syn)
    S, R = np.log1p(S / S.max() * 100), np.log1p(R / R.max() * 100)
    fb = lambda b: (int(round(b * BAR / hop)), int(round((b + 1) * BAR / hop)))
    corr, ctrl = [], []
    for b in range(16):
        a, e = fb(b)
        a2, e2 = fb((b + 1) % 16)
        m = min(e - a, e2 - a2)
        corr.append(float(np.corrcoef(R[:, a:a + m].ravel(), S[:, a:a + m].ravel())[0, 1]))
        ctrl.append(float(np.corrcoef(R[:, a:a + m].ravel(), S[:, a2:a2 + m].ravel())[0, 1]))
    hits = 0
    misses = []
    for b in range(16):
        for s, m in MEL4[b]:
            a = int(round((b * 16 + s) * six / hop)) + 1
            e = a + max(1, int(six / hop))
            top = int(np.argmax(S[:, a:e].mean(axis=1))) + int(librosa.note_to_midi("C3"))
            if top == m:
                hits += 1
            else:
                misses.append(f"bar {b + 1} slot {s}: table {librosa.midi_to_note(m, unicode=False)}, stem {librosa.midi_to_note(top, unicode=False)}")
    return {"notes_matched": hits, "notes_total": 96, "misses": misses,
            "per_bar_corr_mean": round(float(np.mean(corr)), 3), "per_bar_corr_min": round(float(np.min(corr)), 3),
            "shifted_bar_control_mean": round(float(np.mean(ctrl)), 3)}


def bass_root_check(G):
    """Spencer's bass stem in the first half of bars 4 and 8 (three clean source phrases): A or F#?"""
    b = G["bass"].mean(axis=1).astype(np.float32)
    hop = 1024
    C = np.abs(librosa.cqt(b, sr=SR, hop_length=hop, fmin=librosa.note_to_hz("C1"), n_bins=36))
    out = {}
    for bar in (4, 8):
        acc = np.zeros(12)
        for rep in range(3):
            a, e = barf(rep * 8 + bar - 1) // hop, barf(rep * 8 + bar - 0.5) // hop
            seg = C[:, a:e].sum(axis=1)
            for k in range(36):
                acc[k % 12] += seg[k]
        acc /= acc.max()
        out[f"bar{bar}_first_half"] = {"A": round(float(acc[9]), 2), "F#": round(float(acc[6]), 2),
                                        "G": round(float(acc[7]), 2), "strongest": librosa.midi_to_note(24 + int(np.argmax(acc)), unicode=False)[:-1]}
    out["chosen_root"] = "F#"
    out["chord_stem_voicing"] = {"bar4": "E3 F#3 A3 C4", "bar8": "E3 F#3 A3 C#4"}
    return out


def build_deck_v4(args):
    disabled = set(s.strip() for s in (args.without or "").split(",") if s.strip())
    on = lambda name: name not in disabled
    pal = Palette(args.seed, sorted(disabled))
    report = {"version": "deck-v4", "brief": "artifacts/qa-2026-11-28-music/DECK-V4-BRIEF.md", "bpm": 140.0,
              "bar_frames": BAR4, "seed": args.seed, "disabled": sorted(disabled)}
    print("deck-v4: loading stems")
    G, D = load_all(report)
    print("deck-v4: checking the transcription and the bar 4 / 8 bass roots")
    report["transcription_check"] = transcription_check(G)
    report["bass_root_check"] = bass_root_check(G)
    print("  transcription:", {k: v for k, v in report["transcription_check"].items() if k != "misses"})
    print("  bass roots:", report["bass_root_check"])

    jit = lambda layer, bar, slot: int(round(np.random.default_rng(
        [args.seed, layer, (bar - 1) % 16, int(slot * 4)]).uniform(-0.005, 0.005) * SR))
    rng = np.random.default_rng(args.seed + 400)
    cache = {}

    def snd(key, fn):
        if key not in cache:
            cache[key] = unit(fn())
        return cache[key]

    def mel(bar):
        return MEL4[(bar - 1) % 16]

    def cb(bar):
        return (bar - 1) % 8

    class Bus:
        def __init__(self, n):
            self.mix = Mix(n)

        def hit(self, name, y, frame, gain_db, pan=0.0, send=None):
            self.mix.hit(name, y, frame, db(gain_db) * np.sqrt(2), pan, send if send is not None else -60)

    def marimba(bus, bar, gain=0.0, octave=12, slots=None, layer=1, glock=False):
        for s, m in mel(bar):
            if slots is not None and s not in slots:
                continue
            soft = -5.0 if (s in (6, 10) and (bar - 1) % 2 == 0) else 0.0
            vel = db(soft)
            y = snd(("mar", m + octave, round(vel, 3)), lambda: s_marimba(m + octave, vel, np.random.default_rng(m)))
            bus.hit("marimba", y, p4(bar, s) + jit(layer, bar, s), gain + soft, 0.0, -16)
            if glock:
                g = snd(("glk", m + 24), lambda: s_glock(m + 24, np.random.default_rng(m + 1)))
                bus.hit("glock", g, p4(bar, s) + jit(layer + 10, bar, s), gain - 17 + soft, 0.1, -12)

    def music_box(bus, bar, gain, slots=(0, 8)):
        for s, m in mel(bar):
            if s in slots:
                y = snd(("mb", m + 12), lambda: s_music_box(m + 12, 1.0, None, dur=0.6))
                bus.hit("music-box", y, p4(bar, s) + jit(3, bar, s), gain, 0.0, -12)

    def chop(bus, bar, slots, tau, gain, strings=3, held=False):
        c = cb(bar)
        for i, s in enumerate(slots):
            voicing = CHORDS4[c][0 if s < 8 else 1]
            notes = voicing[-strings:]
            order = notes if i % 2 == 0 else notes[::-1]
            for k, m in enumerate(order):
                y = snd(("ks", m, tau), lambda: ks_pluck(m, tau, np.random.default_rng(m * 7 + int(tau * 1000))))
                bus.hit("chop" if not held else "stab", y, p4(bar, s) + int(k * 0.009 * SR) + jit(4, bar, s),
                        gain - 3, -0.2, -20)

    def arp(bus, bar, gain):
        c = cb(bar)
        for half in (0, 1):
            for k, m in enumerate(CHORDS4[c][half]):
                s = half * 8 + 2 * k
                y = snd(("ks", m, 0.25), lambda: ks_pluck(m, 0.25, np.random.default_rng(m * 7 + 250)))
                bus.hit("arp", y, p4(bar, s) + jit(5, bar, s), gain, -0.2, -20)

    def bass(bus, bar, pattern, gain, nxt=None):
        c = cb(bar)
        r0, r1 = root4(c, 0), root4(c, 1)
        hits = {"roots": [(0, r0), (8, r1)], "whole": [(0, r0)]}.get(pattern)
        if pattern == "two-step":
            coming = root4((c + 1) % 8, 0)
            hits = [(0, r0), (8, r1), (14, coming - 7 if coming - 7 >= 33 else coming + 5)]
        elif pattern == "octave":
            hits = [(0, r0), (4, r0 + 12), (8, r1), (12, r1 + 12), (14, root4((c + 1) % 8, 0) - 7 + 12)]
        elif pattern == "walk":
            hits = []
            for half in (0, 1):
                tones = sorted(set(voice(m % 12, 38) for m in CHORDS4[c][half]))
                root = root4(c, half)
                seq = [root] + [x for x in tones if x != root]
                for k in range(4):
                    hits.append((half * 8 + 2 * k, seq[k % len(seq)]))
        tau = 0.8 if pattern == "whole" else 0.22
        for s, m in hits:
            y = snd(("bass", m, tau), lambda: s_bass4(m, np.random.default_rng(m), tau=tau))
            bus.hit("bass", y, p4(bar, s), gain)

    def ocarina(bus, bar, gain, slots=(12,), held=3):
        for s in slots:
            for m in LEAD2_4[cb(bar)]:
                y = snd(("oca", m, held), lambda: s_ocarina(m, held * SIX4 / SR, np.random.default_rng(m + 3)))
                bus.hit("ocarina", y, p4(bar, s) + jit(6, bar, s), gain, 0.2, -12)

    kick = snd("kick", lambda: fft_filter_padded(s_kick(np.random.default_rng(args.seed + 41)), lambda f: mag_lp(f, 3000, 2)))
    rimv = sorted(pal.variants["tok"], key=lambda q: -q[0])[0]
    rim = snd("rim", lambda: pal.render("tok", rimv[0] + 12, rimv[1], rimv[2]))
    toks = [snd(("tok", v[0]), lambda v=v: pal.render("tok", *v)) for v in sorted(pal.variants["tok"], key=lambda q: -q[0])]
    claps = [snd(("clap", i), lambda i=i: s_clap(np.random.default_rng(args.seed + 90 + i))) for i in range(2)]
    tambs = [snd(("tamb", i), lambda i=i: s_tamb(np.random.default_rng(args.seed + 95 + i))) for i in range(3)]
    toms = [snd(("tom", m), lambda m=m: s_tom(m, np.random.default_rng(args.seed + 50 + m))) for m in (57, 55, 52, 50)]

    def shaker(bus, bar, gain):
        for k in range(16):
            sw = 0.12 * SIX4 if k % 2 else 0.0                       # 56% swing
            y = snd(("shk", k % 3), lambda k=k: fft_filter_padded(s_shaker(1.0, 1.0, np.random.default_rng(args.seed + 100 + k % 3)),
                                                                  lambda f: mag_hp(f, 5500, 4)))
            bus.hit("shaker", y, p4(bar, k) + int(sw), gain + (2 if k % 4 == 0 else 0), 0.25 if k % 2 else -0.25, -24)

    # ---------------------------------------------------------------- main, 64 bars
    print("deck-v4: main")
    N = N_DECK4
    keep, rest = Bus(N), Bus(N)                     # keep = marimba + the bar-64 tok fill; rest = everything else
    bounce = (2, 6, 10, 14)
    for bar in range(1, 65):
        sec = (bar - 1) // 8
        if sec == 0:                                    # A hello
            marimba(keep, bar)
            chop(rest, bar, bounce, 0.07, -8)
            bass(rest, bar, "roots", -2)
            shaker(rest, bar, -22)
            for s in (4, 12):
                rest.hit("rim", rim, p4(bar, s), -17, -0.1, -24)
        elif sec == 1:                                  # A2
            marimba(keep, bar, glock=(bar % 2 == 1))
            if bar >= 13:
                ocarina(rest, bar, -6)
            chop(rest, bar, bounce, 0.07, -8)
            bass(rest, bar, "two-step", -2)
            shaker(rest, bar, -22)
            for s in (4, 12):
                rest.hit("rim", rim, p4(bar, s), -17, -0.1, -24)
            for s in (0, 8):
                rest.hit("kick", kick, p4(bar, s), -4)
        elif sec == 2:                                  # B answer
            if bar in (17, 18, 21, 22):
                marimba(keep, bar)
                ocarina(rest, bar, -6)
            else:
                ocarina(rest, bar, -6, slots=(4, 12))
            chop(rest, bar, (3, 8), 0.25, -6, held=True)
            bass(rest, bar, "walk", -3)
            for s in (4, 12):
                rest.hit("rim", rim, p4(bar, s), -17, -0.1, -24)
            for s in (0, 8):
                rest.hit("kick", kick, p4(bar, s), -4)
            if bar == 24:
                for j in range(4):
                    rest.hit("tom", toms[j], p4(bar, 12 + j), -8, (0.3, 0.1, -0.1, -0.3)[j], -20)
        elif sec == 3:                                  # A3
            marimba(keep, bar, glock=True)
            chop(rest, bar, bounce, 0.07, -8)
            bass(rest, bar, "two-step", -2)
            shaker(rest, bar, -22)
            for s in (4, 12):
                rest.hit("rim", rim, p4(bar, s), -17, -0.1, -24)
            for s in (0, 8):
                rest.hit("kick", kick, p4(bar, s), -4)
            for s in (2, 6, 10, 14):
                rest.hit("tamb", tambs[s % 3], p4(bar, s), -20, 0.3, -24)
        elif sec == 4:                                  # C breather
            music_box(rest, bar, -2)
            bass(rest, bar, "whole", -4)
        elif sec == 5:                                  # D build
            marimba(keep, bar, gain=-4, octave=0)
            chop(rest, bar, bounce, 0.07, -8)
            bass(rest, bar, "two-step" if bar >= 45 else "roots", -2)
            for s in range(0, 16, 2):
                rest.hit("rim", rim, p4(bar, s), -19 + (2 if s % 4 == 0 else 0), -0.1, -24)
            if bar >= 45:
                for s in (0, 8):
                    rest.hit("kick", kick, p4(bar, s), -4)
            if bar == 48:
                for j, s in enumerate((8, 9, 10, 11, 12, 13)):
                    rest.hit("tom", toms[j % 4], p4(bar, s), -8, (0.3, 0.1, -0.1, -0.3)[j % 4], -20)
        else:                                           # E lift (49-56, 57-60) and E2 home (61-64)
            lift = bar <= 60
            marimba(keep, bar, glock=(bar <= 60))
            if lift:
                ocarina(rest, bar, -6, held=6)
            chop(rest, bar, bounce, 0.07, -7, strings=4 if lift else 3)
            bass(rest, bar, "octave" if lift else "two-step", -2)
            shaker(rest, bar, -22)
            if lift:
                for s in (0, 4, 8, 12):
                    rest.hit("kick", kick, p4(bar, s), -7)
                for s in (4, 12):
                    rest.hit("clap", claps[s // 8], p4(bar, s), -10, 0.0, -18)
                for k in range(16):
                    rest.hit("tamb", tambs[k % 3], p4(bar, k), -23 + (2 if k % 2 else 0), 0.3, -24)
            else:
                for s in (0, 8):
                    rest.hit("kick", kick, p4(bar, s), -4)
                for s in (4, 12):
                    rest.hit("rim", rim, p4(bar, s), -17, -0.1, -24)
    # breather touches: two plips, one pip pair (E/G/A only)
    if on("plip"):
        for bar in (34, 38):
            v = [q for q in pal.variants["plip"] if q[0] % 12 in (4, 9)][0]
            keep.hit("plip", snd(("plip", v[0]), lambda v=v: pal.render("plip", *v)), p4(bar, 12), -12, 0.35, -12)
    if on("pip"):
        for j, v in enumerate([q for q in pal.variants["pip"] if q[0] % 12 in (7, 9)][:2]):
            keep.hit("pip", snd(("pip", v[0]), lambda v=v: pal.render("pip", *v)), p4(36, 14 + j), -10, -0.4, -12)
    # bar 64 beats 3-4: marimba and a tok fill only
    for j, s in enumerate((12, 13, 14, 15)):
        keep.hit("tok-fill", toks[j % len(toks)], p4(64, s), -10, (-0.2, 0.0, 0.2, 0.0)[j], -24)
    if on("garden-ghost"):
        # Spencer's own melody stem bars 1-8 time-stretched to 140 BPM, under the music box in the breather
        x = G["melody"][: barf(8)]
        st = np.stack([librosa.effects.time_stretch(x[:, ch].astype(np.float32), rate=140.0 / 117.0) for ch in range(2)], axis=1)
        gh = np.zeros((8 * BAR4, 2))
        gh[: min(len(st), len(gh))] = st[: len(gh)]
        gh = fft_filter(gh, lambda f: mag_lp(f, 2000, 2))
        mb_ref = db(-2) * np.sqrt(2)                   # the music box hits at unit body RMS
        e = (gh ** 2).mean(axis=1)
        k = int(0.1 * SR)
        blocks = e[: (len(e) // k) * k].reshape(-1, k).mean(axis=1)
        gh *= mb_ref * db(-12) / np.sqrt(blocks[blocks > blocks.max() * 1e-3].mean())
        f = int(0.05 * SR)
        gh[:f] *= np.linspace(0, 1, f)[:, None]
        gh[-f:] *= np.linspace(1, 0, f)[:, None]
        place(rest.mix.dry, gh, p4(33))
        place(rest.mix.send, gh * db(-12), p4(33))
    # the silence on bar 48's last 8th, and bar 64's thin ending
    for bus in (keep, rest):
        bus.mix.dry = gate(bus.mix.dry, [(p4(48, 14), p4(49))])
        bus.mix.send = gate(bus.mix.send, [(p4(48, 14), p4(49))])
    rest.mix.dry = gate(rest.mix.dry, [(p4(64, 8), N)], ramp=441)
    rest.mix.send = gate(rest.mix.send, [(p4(64, 8), N)], ramp=441)
    # the pad, breather only
    pad_notes = [CHORDS4[((h // 2)) % 8][h % 2] for h in range(128)]
    pad = pad_render(N, pad_notes, TAB_PAD, bar=BAR4 / 2)
    pad = fft_filter(pad, lambda f: mag_hp(f, 120, 2) * mag_lp(f, 1400, 2))
    e = (pad ** 2).mean(axis=1)
    pad *= db(-10) * np.sqrt(2) * np.sqrt(0.5) / np.sqrt(e.mean())
    pad = gate(pad, [(0, p4(33)), (p4(41), N)], ramp=int(BAR4 / 4))
    dry = keep.mix.dry + rest.mix.dry + pad
    send = keep.mix.send + rest.mix.send + pad * db(-14)
    events = keep.mix.events + rest.mix.events

    def bus_chain(dry, send):
        y = dry + room(send, 0.2)
        # merge SFX room: the brief's -3 dB bell at 3 kHz (Q 1), plus a wide -5 dB across 2-5 kHz
        y = fft_filter(y, lambda f: mag_rbj(f, "peak", 3000, -3, 1.0) * mag_rbj(f, "peak", 3300, -5, 0.6))
        return y

    print("deck-v4: main bus")
    main_mix, g_main = glue(bus_chain(dry, send), 1.5)
    seg = lambda x, a, b: float(_METER.integrated_loudness(x[p4(a): p4(b)]))
    base = seg(main_mix, 1, 17)
    g_lift = float(np.clip(1.25 - (seg(main_mix, 49, 61) - base), -4, 4))
    g_br = float(np.clip(-2.5 - (seg(main_mix, 33, 41) - base), -4, 4))
    main_mix = gate(main_mix, [(p4(49), p4(61))], value=db(g_lift), ramp=int(0.05 * SR))
    main_mix = gate(main_mix, [(p4(33), p4(41))], value=db(g_br), ramp=int(0.05 * SR))
    report["section_gain_db"] = {"lift_49_60": round(g_lift, 2), "breather_33_40": round(g_br, 2)}
    main_out = finish(main_mix, DECK4_LUFS, DECK4_TP)

    # ---------------------------------------------------------------- lite, 32 bars
    print("deck-v4: lite")
    NL = N_LITE4
    lite = Bus(NL)
    for bar in range(1, 33):
        arp(lite, bar, -6)
        bass(lite, bar, "roots", -5)
        if bar <= 16:
            music_box(lite, bar, -3)
        elif bar <= 24:
            ocarina(lite, bar, -6)
        elif bar <= 28:
            marimba(lite, bar, gain=-6)
        else:
            marimba(lite, bar, gain=-6, slots=(0, 8))
        if 9 <= bar <= 16 or 25 <= bar <= 32:
            shaker(lite, bar, -26)
    lpad = pad_render(NL, pad_notes[:64], TAB_PAD, bar=BAR4 / 2)
    lpad = fft_filter(lpad, lambda f: mag_hp(f, 120, 2) * mag_lp(f, 1400, 2))
    lpad *= db(-12) * np.sqrt(2) * np.sqrt(0.5) / np.sqrt((lpad ** 2).mean(axis=1).mean())
    lpad = gate(lpad, [(0, p4(17)), (p4(25), NL)], ramp=int(BAR4 / 4))
    lite_mix, g_lite = glue(bus_chain(lite.mix.dry + lpad, lite.mix.send + lpad * db(-14)), 1.0)
    lite_out = finish(lite_mix, LITE4_LUFS, LITE4_TP)
    report["glue"] = {"main": g_main, "lite": g_lite}
    report["event_counts"] = {"main": _count(events), "lite": _count(lite.mix.events)}

    # ---------------------------------------------------------------- write + measure
    os.makedirs(DECK4_PREVIEWS, exist_ok=True)
    files = {"pocket-deck-v4": main_out, "pocket-deck-lite-v4": lite_out}
    q = {}
    for i, (name, x) in enumerate(files.items()):
        qi = quantize16(x, args.seed + 500 + i)
        sf.write(os.path.join(OUT_DIR, name + ".wav"), qi, SR, subtype="PCM_16")
        q[name] = qi.astype(np.float64) / 32767.0
    print("deck-v4: measuring")
    meas = {name: measure(x, name + ".wav", bar=BAR4) for name, x in q.items()}
    mq = q["pocket-deck-v4"]
    L = lambda a, b: round(seg(mq, a, b), 2)
    phone = lambda x: round(float(_METER.integrated_loudness(stereo(fft_filter(x.mean(axis=1), lambda f: mag_hp(f, 300, 2))))), 2)
    band = []
    for s0 in range(1, 65, 8):
        y = mq[p4(s0): p4(s0 + 8)]
        full = 10 * np.log10((y ** 2).mean())
        b25 = 10 * np.log10((fft_filter(y, lambda f: mag_hp(f, 2000, 4) * mag_lp(f, 5000, 4)) ** 2).mean())
        band.append(round(full - b25, 1))
    report["shape"] = {"bars1_16_lufs": L(1, 17), "lift_49_60_lufs": L(49, 61), "breather_33_40_lufs": L(33, 41),
                       "lift_minus_1_16_lu": round(L(49, 61) - L(1, 17), 2),
                       "breather_minus_1_16_lu": round(L(33, 41) - L(1, 17), 2),
                       "band_2_5k_below_full_db_per_8_bars": band}
    for name, x in q.items():
        meas[name]["phone_lufs"] = phone(x)
    v3 = os.path.join(OUT_DIR, "pocket-deck-v3.wav")
    if os.path.exists(v3):
        report["phone_pocket_deck_v3"] = phone(sf.read(v3, dtype="float64", always_2d=True)[0])
    report["files"] = meas
    if not args.no_encode:
        print("deck-v4: encoding")
        for name in files:
            wav = os.path.join(OUT_DIR, name + ".wav")
            ogg = os.path.join(OUT_DIR, name + ".ogg")
            ffmpeg(["-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg])
            dec = decode(ogg)
            meas[name]["ogg"] = {"bytes": os.path.getsize(ogg), "sha256": sha256(ogg), "decoded_frames": int(len(dec)),
                                 "frames_match": bool(len(dec) == len(q[name])), "seam": seam_stats(dec, bar=BAR4),
                                 "true_peak_dbtp": round(true_peak_db(dec), 2)}
            meas[name]["wav_sha256"] = sha256(wav)
            ffmpeg(["-i", wav, "-c:a", "libmp3lame", "-q:a", "2", os.path.join(DECK4_PREVIEWS, name + ".mp3")])
        lq = q["pocket-deck-lite-v4"]
        n = 40 * SR
        t = np.arange(n) / SR
        w = np.clip((t - 13.33) / 0.8, 0, 1) - np.clip((t - 26.67) / 0.8, 0, 1)          # 0 main, 1 lite
        demo = mq[np.arange(n) % len(mq)] * np.cos(w * np.pi / 2)[:, None] + lq[np.arange(n) % len(lq)] * np.sin(w * np.pi / 2)[:, None]
        f = int(0.5 * SR)
        demo[-f:] *= np.linspace(1, 0, f)[:, None]
        write_mp3(demo, os.path.join(DECK4_PREVIEWS, "main-to-lite-and-back-40s.mp3"), args.seed + 510)
        if os.path.exists(v3):
            a = sf.read(v3, dtype="float64", always_2d=True)[0][: 20 * SR].copy()
            f = int(0.03 * SR)
            a[-f:] *= np.linspace(1, 0, f)[:, None]
            gap = np.zeros((int(0.6 * SR), 2))
            p1, p2 = mq[p4(1): p4(17)].copy(), mq[p4(41): p4(57)].copy()
            for p in (p1, p2):
                p[:f] *= np.linspace(0, 1, f)[:, None]
                p[-f:] *= np.linspace(1, 0, f)[:, None]
            write_mp3(np.concatenate([a, gap, p1, gap, p2]), os.path.join(DECK4_PREVIEWS, "compare-pocket-deck-v3-then-v4.mp3"),
                      args.seed + 511)
    with open(os.path.join(QA_DIR, "report-deck-v4.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(report, fh, indent=2, default=_jsonable)
        fh.write("\n")
    print("\n%-22s %10s %9s %8s %8s %6s %7s %6s %6s" % ("file", "frames", "seconds", "LUFS", "dBTP", "LRA", "phone", "mono", ">6k"))
    for name, m in meas.items():
        print("%-22s %10d %9.3f %8.2f %8.2f %6.2f %7.2f %6.2f %5.1f%%" % (
            name, m["frames"], m["seconds"], m["integrated_lufs"], m["true_peak_dbtp"], m["loudness_range_lu"],
            m["phone_lufs"], m["mono_loss_db"], 100 * m["share_above_6k"]))
        if "ogg" in m:
            o = m["ogg"]
            print("   ogg %d bytes, %d frames (match %s), TP %.2f, seam curvature %.2f" % (
                o["bytes"], o["decoded_frames"], o["frames_match"], o["true_peak_dbtp"], o["seam"]["wrap_curvature_ratio_p99"]))
    print("shape:", report["shape"])
    print("section gains:", report["section_gain_db"])
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", choices=("v2", "v3", "v4", "deck-v4"), default="v4",
                    help="v4 (default: garden day + night without the pads), deck-v4 (Pocket Deck 'Marimba Pop' + lite), "
                         "v3 (all four), or the first-pass v2")
    ap.add_argument("--pad", choices=("on", "off"), help="garden synth pads (day breathing pad, night darker pad); "
                    "default on for v3, off for v4")
    ap.add_argument("--without", help="comma list of samples to leave out, e.g. eep,kalimba (v3 also: crickets, fun-hits)")
    ap.add_argument("--with", dest="with_", help="v3: turn back on samples that are off by default (boing, la-chop)")
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--no-encode", action="store_true", help="skip OGG/MP3 encoding and previews")
    args = ap.parse_args()
    {"v2": build, "deck-v4": build_deck_v4}.get(args.version, build_v3)(args)


if __name__ == "__main__":
    main()
