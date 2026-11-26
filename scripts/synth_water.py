"""Two original water loops for the garden (Spencer, beta 35, 2026-11-26): the fountain "should be heard from farther
away ... and make it sound less like fried chicken", and "the waterfall barely makes any sound".

Synthesised from scratch with numpy (audio_draft_kit helpers): shaped noise and bubble partials. No samples, no
recordings, no downloaded assets, no AI audio. Fixed seeds: every run is byte-identical.

Why the old fountain loop (synth_fountain_loop.py) read as frying: all of its energy sat at 900 Hz to 9 kHz, its bed
was noise chopped by a 25 to 60 Hz flutter, and it carried ~85 hard-edged ticks and plinks a second. Fast
amplitude flutter on bright noise plus hard grains is exactly the sound of oil spitting. Nothing in it was below 500 Hz.

What these are instead. Real water noise is mostly bubbles ringing as they form (Minnaert resonance): each is a damped
sine whose pitch RISES a little as it rings, bigger bubbles lower and longer. So both loops are built from thousands of
such bubbles with soft 2 to 4 ms attacks (no clicks), over a smooth noise body whose level only moves slowly. No grain
is broadband, no layer is chopped faster than 0.6 Hz, and everything is rolled off above ~5 kHz (fountain) or ~5.2 kHz
(falls), so there is no hiss and no crackle. A crackle meter (below) checks it against the old loop.

  fountain  egg_drop_fountain_trickle   10 s   a soft trickle into a basin, close by:
            A wash     pink noise 160 Hz to 3 kHz, two slow swells (2 and 3 cycles a loop, +-12 percent)
            B chorus   ~110 bubbles a second, 420 Hz to 2 kHz, rising 6-18 percent, 6-25 ms rings
            C burble   ~18 a second, 110 to 360 Hz, 30-70 ms rings: the low "blub" of the basin
            D plinks   ~5 a second, 1.1 to 2.6 kHz droplets, rising 15-35 percent, louder; their density breathes
            E sheen    smooth noise 3 to 6 kHz, 19 dB down, a slow drift only: air, not sizzle
  waterfall egg_drop_waterfall_roar     12 s   a fuller, lower roar with spray:
            A roar     brown-ish noise 45 Hz to 1.1 kHz, a slow surge (1 and 2 cycles a loop, +-10 percent)
            B body     pink noise 280 Hz to 2.4 kHz (the part a phone speaker can play), its own slow surge
            C chorus   ~340 bubbles a second, 160 Hz to 1.1 kHz: the roar sounds wet, not like wind
            D chunks   ~14 a second, 90 to 260 Hz, big splashes in the pool
            E spray    noise 2.2 to 6.5 kHz, 16 dB down, smooth (no grains), its level drifting slowly

Seamless by construction: every filter is applied in the frequency domain of the whole loop (periodic in its length),
every slow curve has a whole number of cycles per loop, and bubbles that run past the end wrap to the start.

Levels: both loops are normalised to the integrated loudness of the stand-in they replace (the placeholder
waterfall_loop, measured here with ffmpeg's ebur128), true peak under -3 dBTP, so filling the id in AmbientAudio
(Ambient.WaterLoops) is level-neutral and the game's volumes keep their meaning.

Run from the repository root:  python scripts/synth_water.py
Writes assets/audio/custom/egg_drop_fountain_trickle.{wav,ogg}, egg_drop_waterfall_roar.{wav,ogg}
(44.1 kHz, 16-bit mono WAV; the OGG is Vorbis q6 from that WAV by ffmpeg, for the upload) and
artifacts/water-audio-2026-11-26/report.json. Spencer's ears decide; the numbers only keep a bad file from him.
"""
import json
import math
import os
import shutil
import subprocess

import numpy as np

import audio_draft_kit as K

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio", "custom")
REPORT = os.path.join(ROOT, "artifacts", "water-audio-2026-11-26", "report.json")
STAND_IN = os.path.join(ROOT, "assets", "audio", "placeholder", "egg_drop_waterfall_loop.wav")
OLD_FOUNTAIN = os.path.join(OUT, "egg_drop_fountain_loop.wav")
SR = 44100
CEILING_DBTP = -3.0


class Loop:
    """One loop's sample grid and its periodic helpers."""

    def __init__(self, seconds, seed):
        self.seconds = seconds
        self.n = int(round(SR * seconds))
        self.t = np.arange(self.n) / SR
        self.f = np.fft.rfftfreq(self.n, 1 / SR)
        self.rng = np.random.default_rng(seed)

    def ramp(self, a, b):
        """0 at a, 1 at b (raised cosine) on the frequency axis."""
        k = np.clip((self.f - a) / (b - a), 0, 1)
        return .5 - .5 * np.cos(np.pi * k)

    def band(self, lo, hi, lo_w, hi_w):
        return self.ramp(lo - lo_w, lo) * (1 - self.ramp(hi, hi + hi_w))

    def filt(self, x, gain):
        return np.fft.irfft(np.fft.rfft(x) * gain, self.n)

    def tilt(self, db_per_octave, ref=1000.0):
        """A spectral slope (pink is -3 dB/oct, brown -6) about `ref`; DC held at the 20 Hz value."""
        return (np.maximum(self.f, 20) / ref) ** (db_per_octave / (20 * math.log10(2)))

    def noise(self, lo, hi, lo_w, hi_w, slope):
        return self.filt(self.rng.standard_normal(self.n), self.band(lo, hi, lo_w, hi_w) * self.tilt(slope))

    def swell(self, cycles, depth):
        """1 + depth * a whole-cycle sine: periodic in the loop."""
        return 1 + depth * np.sin(2 * math.pi * cycles * self.t / self.seconds + self.rng.uniform(0, 2 * math.pi))

    def times(self, rate, curve=None, depth=0.0):
        """Event times (s) at `rate` a second; with a curve, the density follows it (rejection sampling)."""
        count = self.rng.poisson(rate * self.seconds * (1 + depth))
        at = self.rng.uniform(0, self.seconds, count)
        if curve is not None:
            keep = self.rng.uniform(0, 1 + depth, count) < curve[(at * SR).astype(int) % self.n]
            at = at[keep]
        return np.sort(at)

    def place(self, out, grain, at):
        start = int(at * SR) % self.n
        end = start + len(grain)
        if end <= self.n:
            out[start:end] += grain
        else:
            k = self.n - start
            out[start:] += grain[:k]
            out[:end - self.n] += grain[k:]


def bubble(rng, f0, rise, tau, attack):
    """One bubble: a sine ringing at f0, its pitch rising by `rise` (share) over its ring, soft raised-cosine onset."""
    length = min(int(SR * tau * 6.5), int(SR * .5))
    tt = np.arange(length) / SR
    freq = f0 * (1 + rise * (1 - np.exp(-tt / tau)))
    phase = 2 * math.pi * np.cumsum(freq) / SR + rng.uniform(0, 2 * math.pi)
    onset = .5 - .5 * np.cos(math.pi * np.clip(tt / attack, 0, 1))
    tail = np.ones(length)
    fade = max(8, length // 8)
    tail[-fade:] = .5 + .5 * np.cos(math.pi * np.arange(fade) / fade)  # never cut a ring off with a step
    return np.sin(phase) * onset * np.exp(-tt / tau) * tail


def bubbles(loop, rate, lo, hi, rise, tau, attack, loud_db, curve=None, depth=0.0):
    """A layer of bubbles: f0 log-uniform in lo..hi, each ring `tau` (s, a range) scaled with pitch (lower rings longer),
    loudness spread over loud_db dB (mostly quiet ones, a few near the top)."""
    out = np.zeros(loop.n)
    rng = loop.rng
    for at in loop.times(rate, curve, depth):
        f0 = math.exp(rng.uniform(math.log(lo), math.log(hi)))
        share = (math.log(f0) - math.log(lo)) / max(1e-9, math.log(hi) - math.log(lo))  # 0 low .. 1 high
        ring = tau[1] + (tau[0] - tau[1]) * share
        ring *= rng.uniform(.8, 1.25)
        gain = 10 ** ((-loud_db + loud_db * rng.uniform(0, 1) ** 2.2) / 20)
        loop.place(out, bubble(rng, f0, rng.uniform(*rise), ring, rng.uniform(*attack)) * gain, at)
    return out


def rms(x):
    return float(np.sqrt(np.mean(np.square(x))))


def mix(loop, layers, levels, lo_cut, hi_cut, hi_w):
    out = np.zeros(loop.n)
    for name, x in layers.items():
        out += x / max(rms(x), 1e-12) * 10 ** (levels[name] / 20)
    # The whole loop's band: a gentle high-pass (rumble the speakers cannot play) and the soft top roll-off.
    return loop.filt(out, loop.ramp(lo_cut * .5, lo_cut) * (1 - loop.ramp(hi_cut, hi_cut + hi_w)))


def fountain():
    loop = Loop(10.0, 20261126)
    wash = loop.noise(160, 3000, 90, 1500, -3) * loop.swell(2, .12) * loop.swell(3, .08)
    chorus = bubbles(loop, 110, 420, 2000, (.06, .18), (.006, .025), (.002, .004), 18)
    burble = bubbles(loop, 18, 110, 360, (.04, .12), (.030, .070), (.003, .006), 12)
    density = loop.swell(2, .30)
    plinks = bubbles(loop, 5, 1100, 2600, (.15, .35), (.008, .018), (.002, .003), 10, density, .30)
    sheen = loop.noise(3000, 6000, 1200, 2500, -3) * loop.swell(3, .10)
    layers = {"A_wash": wash, "B_chorus": chorus, "C_burble": burble, "D_plinks": plinks, "E_sheen": sheen}
    levels = {"A_wash": -4.0, "B_chorus": 0.0, "C_burble": -3.0, "D_plinks": -6.0, "E_sheen": -19.0}
    return loop, mix(loop, layers, levels, 90, 5000, 3500)


def waterfall():
    loop = Loop(12.0, 20261127)
    roar = loop.noise(45, 1100, 25, 900, -5.5) * loop.swell(1, .10) * loop.swell(2, .06)
    body = loop.noise(280, 2400, 140, 1400, -3) * loop.swell(1, .08) * loop.swell(3, .05)
    chorus = bubbles(loop, 340, 160, 1100, (.04, .12), (.010, .040), (.003, .005), 16)
    chunks = bubbles(loop, 14, 90, 260, (.03, .10), (.050, .110), (.004, .008), 10)
    spray = loop.noise(2200, 6500, 900, 2500, -3) * loop.swell(2, .15)
    layers = {"A_roar": roar, "B_body": body, "C_chorus": chorus, "D_chunks": chunks, "E_spray": spray}
    levels = {"A_roar": 0.0, "B_body": -2.0, "C_chorus": -5.0, "D_chunks": -6.0, "E_spray": -16.0}
    return loop, mix(loop, layers, levels, 40, 5200, 3500)


# ---------------------------------------------------------------- meters

def band_signal(x, lo, hi):
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) * ((f >= lo) & (f < hi)), len(x))


def crackle(x):
    """How "fried" a loop is. Frying is bright, impulsive energy: the share of energy at 2.5-8 kHz and above 5 kHz, and
    the kurtosis of the band above 5 kHz (Gaussian noise = 3; hard clicks and spits push it up: the old loop is ~13).
    Also the share at 60-500 Hz (the burble the old loop lacked), the centroid, and the 2.5-8 kHz envelope's flutter
    at 15-80 Hz (for information)."""
    power = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1 / SR)
    hf = band_signal(x, 2500, 8000)
    env = np.convolve(np.abs(hf), np.ones(int(.002 * SR)) / int(.002 * SR), mode="same")
    env_spec = np.abs(np.fft.rfft(env - env.mean())) ** 2
    ef = np.fft.rfftfreq(len(env), 1 / SR)
    flutter = math.sqrt(env_spec[(ef >= 15) & (ef < 80)].sum() / max(1e-20, env_spec[ef > 0].sum()))
    top = band_signal(x, 5000, 16000)
    k = float(np.mean(top ** 4) / max(1e-30, np.mean(top ** 2) ** 2))
    above = float(power[f >= 5000].sum() / power.sum())
    share = float(power[(f >= 2500) & (f < 8000)].sum() / power.sum())
    low = float(power[(f >= 60) & (f < 500)].sum() / power.sum())
    centroid = float((f * power).sum() / power.sum())
    return {"hf_2500_8000_share_db": round(10 * math.log10(max(share, 1e-20)), 1),
            "low_60_500_share_db": round(10 * math.log10(max(low, 1e-20)), 1),
            "above_5000_share_db": round(10 * math.log10(max(above, 1e-20)), 1), "click_kurtosis_above_5000": round(k, 2),
            "spectral_centroid_hz": round(centroid), "hf_flutter_share": round(flutter, 3)}


def slow_spread(x, seconds=.5):
    w = int(seconds * SR)
    levels = [20 * math.log10(max(rms(x[i:i + w]), 1e-12)) for i in range(0, len(x) - w + 1, w)]
    return round(max(levels) - min(levels), 2)


def ogg(wav):
    """Vorbis q6 from the WAV, for the upload. None if ffmpeg (with libvorbis) is not on PATH."""
    if not shutil.which("ffmpeg"):
        return None
    out = wav[:-4] + ".ogg"
    run = subprocess.run(["ffmpeg", "-hide_banner", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "6",
                          "-map_metadata", "-1", "-fflags", "+bitexact", out], capture_output=True, text=True)
    return out if run.returncode == 0 else None


def main():
    stand_in, sr = K.read_wav(STAND_IN)
    assert sr == SR
    target = K.measure_array(stand_in, SR)["integrated_lufs"]
    report = {"target_lufs": round(target, 2), "target_from": os.path.relpath(STAND_IN, ROOT).replace("\\", "/"),
              "ceiling_dbtp": CEILING_DBTP, "loops": {}, "references": {}}
    for name, make in (("egg_drop_fountain_trickle", fountain), ("egg_drop_waterfall_roar", waterfall)):
        loop, x = make()
        x, reduction = K.normalise(x, SR, target, CEILING_DBTP, circular=True)
        path = os.path.join(OUT, name + ".wav")
        x = K.write_wav(path, x, SR)
        encoded = ogg(path)
        entry = K.basic_stats(x, SR)
        entry.update(K.measure_array(x, SR))
        entry["limiter_db"] = round(reduction, 2)
        entry["seam"] = K.join_check(x, x, SR)
        entry["rms_0_5s_spread_db"] = slow_spread(x)
        entry["crackle"] = crackle(x)
        entry["wav"] = os.path.relpath(path, ROOT).replace("\\", "/")
        entry["wav_sha256"] = K.sha256(path)
        entry["ogg"] = os.path.relpath(encoded, ROOT).replace("\\", "/") if encoded else None
        report["loops"][name] = entry
    for label, path in (("old_fountain_loop", OLD_FOUNTAIN), ("stand_in_waterfall_loop", STAND_IN)):
        if os.path.exists(path):
            ref, _ = K.read_wav(path)
            report["references"][label] = {"crackle": crackle(ref), "integrated_lufs": round(K.measure_array(ref, SR)["integrated_lufs"], 2)}
    # The guards: what "not fried" means in numbers, against the old loop.
    new, old = report["loops"]["egg_drop_fountain_trickle"]["crackle"], report["references"].get("old_fountain_loop", {}).get("crackle")
    for name, entry in report["loops"].items():
        c = entry["crackle"]
        # Whatever is up there must be smooth air, not clicks (or so little it cannot be heard).
        assert c["above_5000_share_db"] < -40 or c["click_kurtosis_above_5000"] < 4.5, (name, "clicky highs", c)
        assert c["above_5000_share_db"] < -20, (name, "hiss", c)
        assert entry["seam"]["step_ratio"] <= 1.0 and entry["seam"]["curvature_ratio"] <= 1.0, (name, "seam", entry["seam"])
        assert entry["true_peak_dbtp"] <= CEILING_DBTP + .05, (name, entry["true_peak_dbtp"])
        assert entry["rms_0_5s_spread_db"] < 4.5, (name, "lumpy", entry["rms_0_5s_spread_db"])
    if old:
        assert new["hf_2500_8000_share_db"] < old["hf_2500_8000_share_db"] - 6, ("no darker than the old loop", new, old)
        assert new["low_60_500_share_db"] > old["low_60_500_share_db"] + 10, ("no low burble", new, old)
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    K.save_report(REPORT, report)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
