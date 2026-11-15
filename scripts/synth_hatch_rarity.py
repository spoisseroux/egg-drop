"""Hatch rarity reveal sounds, synthesised from scratch (QA v735 H3).

Three original stings for the item reveal, one per tier, built only from sine partials and
shaped white noise in numpy. No samples, no recordings, no AI audio. A fixed seed makes
every run byte-identical.

  Common    a light, round pop with one soft bell note               0.50 s, hit at 0.00
  Uncommon  a brighter pop, a rising three-note chime and glitter    1.25 s, hit at 0.00
  Rare      a harp run and shimmer rising into the pop and a big     2.70 s, hit at 0.70
            chord chime, an answering twinkle and a long glitter tail

Each tier contains the tier below it (pop -> pop + chime + sparkle -> rise + pop + big
chime + sparkle), all in C major pentatonic, so they sound like one family and climb.
`HIT` is the time of the pop inside each file: the game starts the sound `HIT` seconds
before the burst so the pop lands on it.

Run from the repository root:  python scripts/synth_hatch_rarity.py
Writes: assets/audio/custom/egg_drop_rarity_<tier>.wav          (masters, 44.1 kHz mono 16-bit)
        artifacts/hatch-sounds-2026-11-15/*.mp3 and report.json  (auditions; needs ffmpeg)
"""
import json
import math
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MASTERS = os.path.join(ROOT, "assets", "audio", "custom")
OUT = os.path.join(ROOT, "artifacts", "hatch-sounds-2026-11-15")
BODY = os.path.join(ROOT, "assets", "audio", "original-2026-11-14", "hatch-v3", "hatch-material-v3-tightened-burst.wav")
SR = 44100
HIT = {"common": 0.0, "uncommon": 0.0, "rare": 0.70}
# Suggested playback gains (HatchRarityCue events), also used for the in-context mixes.
GAIN = {"common": 0.55, "uncommon": 0.75, "rare": 1.0}
BURST = 0.98   # HatchRarityCue.BurstAt

# C major pentatonic, equal temperament.
NOTE = {name: 440.0 * 2 ** (semis / 12) for name, semis in {
    "C5": 3, "D5": 5, "E5": 7, "G5": 10, "A5": 12, "C6": 15, "D6": 17, "E6": 19, "G6": 22, "A6": 24,
    "C7": 27, "D7": 29, "E7": 31, "G7": 34, "A7": 36, "C8": 39, "D8": 41, "E8": 43}.items()}


def buf(seconds):
    return np.zeros(int(round(seconds * SR)))


def add(dst, src, at, gain=1.0):
    """Mix a voice in. Every voice gets a short release so none ends on a step (a click)."""
    i = int(round(at * SR))
    n = min(len(src), len(dst) - i)
    if n > 0:
        part = src[:n] * gain
        r = min(n, int(0.010 * SR))
        part[-r:] *= np.linspace(1, 0, r)
        dst[i:i + n] += part


def tone(freq, seconds, phase=0.0):
    """Sine at a fixed or per-sample frequency."""
    n = int(round(seconds * SR))
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, dtype=float)[:n]
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def decay(seconds, tau, attack=0.002):
    t = np.arange(int(round(seconds * SR))) / SR
    return np.minimum(1.0, t / attack) * np.exp(-t / tau)


def fade_out(x, seconds=0.012):
    n = min(len(x), int(seconds * SR))
    x[-n:] *= np.linspace(1, 0, n) ** 2
    return x


def band_noise(rng, seconds, lo, hi):
    """White noise kept between lo and hi Hz (soft edges), unit peak."""
    n = int(round(seconds * SR))
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    edge = lambda x, centre, width: 1 / (1 + np.exp(-(x - centre) / width))
    spec *= edge(f, lo, lo * 0.12) * (1 - edge(f, hi, hi * 0.12))
    out = np.fft.irfft(spec, n)
    return out / (np.max(np.abs(out)) + 1e-12)


def pop(rng, pitch=1.0, weight=0.0):
    """The shared hit: a round pop (a fast downward chirp), a bubble 'plip' gliding up and
    a soft click. `weight` adds a low thump for the bigger tiers."""
    out = buf(0.30)
    t = np.arange(int(0.16 * SR)) / SR
    chirp = tone((430 + 1250 * np.exp(-t / 0.011)) * pitch, 0.16) * decay(0.16, 0.040, 0.0008)
    add(out, chirp, 0.0, 0.95)
    t = np.arange(int(0.11 * SR)) / SR
    glide = (640 + 640 * (1 - np.exp(-t / 0.030))) * pitch
    plip = tone(glide, 0.11) * np.sin(np.pi * np.minimum(1, t / 0.11)) ** 1.5
    add(out, plip, 0.014, 0.50)
    click = band_noise(rng, 0.006, 3500, 12000) * decay(0.006, 0.0015, 0.0002)
    add(out, click, 0.0, 0.16)
    if weight > 0:
        t = np.arange(int(0.22 * SR)) / SR
        thump = tone(92 + 70 * np.exp(-t / 0.030), 0.22) * decay(0.22, 0.070, 0.003)
        add(out, thump, 0.0, weight)
    return out


def bell(freq, seconds, tau, bright=1.0, detune=0.0):
    """A glockenspiel-like note: the fundamental, an octave for warmth and the two bar
    partials (2.756 and 5.404) that give the strike its glint and die quickly."""
    out = buf(seconds)
    for ratio, amp, t_scale in ((1.0, 1.0, 1.0), (2.0, 0.16, 0.55), (2.756, 0.22 * bright, 0.30), (5.404, 0.10 * bright, 0.12)):
        f = freq * ratio
        if f < SR * 0.45:
            out += amp * tone(f, seconds) * decay(seconds, tau * t_scale, 0.0015)
    if detune:   # a second fundamental a few cents away: a slow, sweet beat
        out += 0.55 * tone(freq * 2 ** (detune / 1200), seconds, 1.3) * decay(seconds, tau, 0.004)
    return out


def harp(freq, seconds, tau):
    """A soft plucked string for the Rare run."""
    out = buf(seconds)
    for ratio, amp, t_scale in ((1.0, 1.0, 1.0), (2.0, 0.34, 0.5), (3.0, 0.13, 0.3), (4.0, 0.05, 0.2)):
        out += amp * tone(freq * ratio, seconds) * decay(seconds, tau * t_scale, 0.003)
    return out


def glitter(rng, seconds, count, lo="C7", hi="E8", lean=1.6):
    """Tiny high pings scattered through `seconds`, thinning and fading toward the end."""
    names = [n for n in NOTE if NOTE[lo] <= NOTE[n] <= NOTE[hi]]
    out = buf(seconds + 0.25)
    for _ in range(count):
        at = seconds * rng.random() ** lean
        f = NOTE[names[rng.integers(len(names))]]
        length = 0.20
        ping = tone(f, length) * decay(length, rng.uniform(0.030, 0.065), 0.001)
        ping += 0.3 * tone(f * 2.0, length) * decay(length, 0.02, 0.001) if f * 2 < SR * 0.45 else 0
        add(out, ping, at, rng.uniform(0.45, 1.0) * (1 - 0.75 * at / seconds))
    return out


def comb(x, delay, feedback, damp):
    """Feedback comb with a one-pole low-pass in the loop, computed a delay block at a time."""
    y = np.zeros(len(x))
    low = np.zeros(delay)
    for start in range(0, len(x), delay):
        end = min(start + delay, len(x))
        n = end - start
        prev = y[start - delay:start - delay + n] if start >= delay else np.zeros(n)
        low[:n] = (1 - damp) * prev + damp * low[:n]
        y[start:end] = x[start:end] + feedback * low[:n]
    return y


def allpass(x, delay, g=0.5):
    y = np.zeros(len(x))
    for start in range(0, len(x), delay):
        end = min(start + delay, len(x))
        n = end - start
        xd = x[start - delay:start - delay + n] if start >= delay else np.zeros(n)
        yd = y[start - delay:start - delay + n] if start >= delay else np.zeros(n)
        y[start:end] = -g * x[start:end] + xd + g * yd
    return y


def reverb(x, wet, size=1.0, feedback=0.78):
    """A small Schroeder room: four combs into two all-passes, mixed under the dry sound."""
    if wet <= 0:
        return x
    tail = sum(comb(x, int(d * size), feedback, 0.35) for d in (1557, 1617, 1491, 1422)) / 4
    tail = allpass(allpass(tail, 225), 556)
    return x + wet * tail


def finish(x, peak_db=-1.0, release=0.05):
    x = x - np.mean(x)
    x = fade_out(x, release)
    x[:int(0.0005 * SR)] *= np.linspace(0, 1, int(0.0005 * SR))
    return x * (10 ** (peak_db / 20) / np.max(np.abs(x)))


def common(rng):
    x = buf(0.50)
    add(x, pop(rng), 0.0, 1.0)
    add(x, bell(NOTE["C6"], 0.42, 0.085, bright=0.5), 0.012, 0.30)
    return finish(reverb(x, 0.07, 0.6, 0.6))


def uncommon(rng):
    x = buf(1.25)
    add(x, pop(rng, 1.12), 0.0, 0.95)
    # Up a fourth, then to the octave: "da-da-ding".
    for name, at, gain, tau in (("G6", 0.010, 0.34, 0.14), ("C7", 0.095, 0.40, 0.17), ("E7", 0.180, 0.46, 0.26)):
        add(x, bell(NOTE[name], 1.05, tau, detune=5), at, gain)
    add(x, glitter(rng, 0.78, 11), 0.26, 0.20)
    return finish(reverb(x, 0.13, 0.8, 0.72), release=0.25)


def rare(rng):
    hit = HIT["rare"]
    x = buf(2.70)
    # The rise: a pentatonic harp run that speeds up and swells into the hit...
    run = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6", "G6", "A6", "C7"]
    for i, name in enumerate(run):
        u = i / len(run)
        at = 0.015 + (hit - 0.03) * (1 - (1 - u) ** 1.55)
        add(x, harp(NOTE[name], 0.55, 0.17), at, 0.20 + 0.26 * u)
    # ...under a breath of shimmer that climbs in pitch and cuts at the hit.
    n = int(round(hit * SR))
    u = np.arange(n) / n
    swell = u ** 2.4 * np.minimum(1, (1 - u) / 0.03)
    low, mid, high = (band_noise(rng, hit, a, b) for a, b in ((1800, 3600), (3600, 7000), (7000, 13000)))
    shimmer = low * np.clip(1 - 2 * u, 0, 1) + mid * (1 - np.abs(2 * u - 1)) + high * np.clip(2 * u - 1, 0, 1)
    add(x, shimmer * swell, 0.0, 0.16)
    # The hit: the family pop with weight, and a big strummed chord chime that rings.
    add(x, pop(rng, 0.94, weight=0.55), hit, 0.90)
    for i, (name, gain, tau) in enumerate((("C5", 0.22, 0.55), ("C6", 0.42, 0.70), ("G6", 0.34, 0.64), ("E7", 0.30, 0.56), ("C7", 0.26, 0.60))):
        add(x, bell(NOTE[name], 1.95, tau, bright=1.2, detune=6 if i % 2 else -6), hit + 0.004 + i * 0.011, gain)
    # An answering twinkle, rising, then glitter falling away.
    for name, at, gain in (("G7", 0.30, 0.20), ("C8", 0.41, 0.17), ("E8", 0.52, 0.13)):
        add(x, bell(NOTE[name], 0.7, 0.22, bright=0.6, detune=4), hit + at, gain)
    add(x, glitter(rng, 1.55, 30), hit + 0.07, 0.17)
    return finish(reverb(x, 0.22, 1.0, 0.80), release=0.55)


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).round().astype("<i2").tobytes())


def read_wav(path):
    with wave.open(path, "rb") as w:
        width, channels, rate = w.getsampwidth(), w.getnchannels(), w.getframerate()
        raw = w.readframes(w.getnframes())
    if width == 2:
        data = np.frombuffer(raw, dtype="<i2").astype(float) / 32768
    elif width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        data = ((b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)) - ((b[:, 2] & 0x80) << 17)).astype(float) / 8388608
    else:
        data = np.frombuffer(raw, dtype="<i4").astype(float) / 2 ** 31
    data = data.reshape(-1, channels).mean(axis=1)
    if rate != SR:
        data = np.interp(np.arange(0, len(data), rate / SR), np.arange(len(data)), data)
    return data


def mp3(wav_path):
    out = os.path.splitext(wav_path)[0] + ".mp3"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-codec:a", "libmp3lame", "-b:a", "192k", out], check=True)
    os.remove(wav_path)
    return out


def describe(x):
    """Plain measurements, so the tiers can be compared without ears."""
    spec = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1 / SR)
    rms = math.sqrt(float(np.mean(x ** 2)))
    win = int(0.05 * SR)
    loud = max(math.sqrt(float(np.mean(x[i:i + win] ** 2))) for i in range(0, max(1, len(x) - win), win // 2))
    return {"seconds": round(len(x) / SR, 3), "peak_dbfs": round(20 * math.log10(float(np.max(np.abs(x)))), 2),
            "rms_dbfs": round(20 * math.log10(rms), 2), "loudest_50ms_dbfs": round(20 * math.log10(loud), 2),
            "energy": round(float(np.sum(x ** 2)) / SR, 5),
            "centroid_hz": round(float(np.sum(f * spec) / np.sum(spec))),
            "above_4khz_share": round(float(np.sum(spec[f >= 4000]) / np.sum(spec)), 4)}


def main():
    os.makedirs(OUT, exist_ok=True)
    made = {"common": common(np.random.default_rng(11)), "uncommon": uncommon(np.random.default_rng(22)), "rare": rare(np.random.default_rng(33))}
    report = {"sample_rate": SR, "hit_seconds": HIT, "suggested_gain": GAIN, "tiers": {}}
    for tier, x in made.items():
        write_wav(os.path.join(MASTERS, "egg_drop_rarity_%s.wav" % tier), x)
        path = os.path.join(OUT, "%s.wav" % tier)
        write_wav(path, x)
        mp3(path)
        report["tiers"][tier] = describe(x * GAIN[tier])
        hit = int(HIT[tier] * SR)
        report["tiers"][tier]["hit_peak_at"] = round((hit + int(np.argmax(np.abs(x[hit:hit + int(0.05 * SR)])))) / SR, 4)
    # All three back to back at their in-game gains, 0.6 s apart.
    gap = buf(0.6)
    row = np.concatenate([np.concatenate([made[t] * GAIN[t], gap]) for t in ("common", "uncommon", "rare")])
    path = os.path.join(OUT, "all-three-common-uncommon-rare.wav")
    write_wav(path, row)
    mp3(path)
    # In context: over the unchanged 3.1 s Material hatch body, started so the pop lands on
    # the burst. An offline model of the game mix, not a Studio recording.
    if os.path.exists(BODY):
        body = read_wav(BODY)
        mixes = []
        for tier in ("common", "uncommon", "rare"):
            mix = np.concatenate([body, buf(0.9)])
            add(mix, made[tier], BURST - HIT[tier], GAIN[tier])
            mix = np.clip(mix, -1, 1)
            mixes.append(mix)
            path = os.path.join(OUT, "in-hatch-%s.wav" % tier)
            write_wav(path, mix)
            mp3(path)
        path = os.path.join(OUT, "in-hatch-all-three.wav")
        write_wav(path, np.concatenate(mixes))
        mp3(path)
    with open(os.path.join(OUT, "report.json"), "w", newline="\n") as fh:
        json.dump(report, fh, indent=1)
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
