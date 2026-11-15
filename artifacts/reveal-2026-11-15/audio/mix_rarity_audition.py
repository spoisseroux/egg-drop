"""Offline audition and loudness check for the tiered hatch sound lines (QA v685 H3).

Mixes the EXISTING source WAVs of the uploaded cues exactly as HatchRarityCue.events
schedules them (time, playback speed, gain) over the unchanged 3.1 s Material hatch body,
then measures K-weighted (ITU-R BS.1770 pre-filter) loudness in the three beats a player
hears: the build-up, the burst and the answer to the name slam.

No sound is generated here: every sample comes from assets/audio. Playback speed is
modelled as a resample (pitch and length change together, as Roblox PlaybackSpeed does).
Roblox's own resampler, SoundGroup volume and the device will differ a little, so this is
a loudness model and an audition, not a recording of Studio output.

Run from the repository root:  python artifacts/reveal-2026-11-15/audio/mix_rarity_audition.py
"""
import json, math, os, wave
import numpy as np

ROOT = os.getcwd()
OUT = os.path.join(ROOT, "artifacts", "reveal-2026-11-15", "audio")
BODY = os.path.join(ROOT, "assets", "audio", "original-2026-11-14", "hatch-v3", "hatch-material-v3-tightened-burst.wav")
CUES = os.path.join(ROOT, "assets", "audio", "placeholder", "egg_drop_%s.wav")
SR = 48000
READY = 1.65   # HatchDisplayPose.ItemReady
BURST = 0.98   # HatchRarityCue.BurstAt
FLOURISH = 0.45  # HatchRarityCue.FlourishAfter


def st(n):
    return 2 ** (n / 12)


# Mirrors src/client/HatchRarityCue.lua (Policy.events). Keep in step with it.
EVENTS = {
    "common": [(0.34, "egg_wobble", 1, 0.40), (BURST, "egg_crack_glint", 1, 0.50), (READY, "name_slam", 1, 0.90)],
    "uncommon": [(0.30, "star_land", st(0), 0.40), (0.62, "star_land", st(4), 0.46), (BURST, "reveal_shimmer", 1, 0.55),
                 (READY, "name_slam", 1.06, 0.90), (READY + FLOURISH, "quest_complete", 1, 0.85)],
    "rare": [(0.16, "star_land", st(0), 0.36), (0.36, "star_land", st(4), 0.40), (0.56, "star_land", st(7), 0.46),
             (0.76, "star_land", st(12), 0.52), (0.86, "streak_whoosh", 1, 0.55), (BURST, "reveal_shimmer", st(3), 0.80),
             (BURST + 0.06, "new_best", 1, 0.70), (READY, "name_slam", 0.94, 1.0), (READY + FLOURISH, "stars_total", st(2), 0.80)],
}


def load(path):
    with wave.open(path, "rb") as w:
        n, width, channels, rate = w.getnframes(), w.getsampwidth(), w.getnchannels(), w.getframerate()
        raw = w.readframes(n)
    if width == 2:
        data = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768
    elif width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        data = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int8).astype(np.int32) << 16)).astype(np.float64) / 8388608
    else:
        data = np.frombuffer(raw, dtype="<i4").astype(np.float64) / 2 ** 31
    data = data.reshape(-1, channels).mean(axis=1)
    if rate != SR:
        x = np.arange(0, len(data), rate / SR)
        data = np.interp(x, np.arange(len(data)), data)
    return data


def resample(data, speed):
    if abs(speed - 1) < 1e-9:
        return data
    x = np.arange(0, len(data) - 1, speed)
    return np.interp(x, np.arange(len(data)), data)


def biquad(x, b, a):
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b
    _, a1, a2 = a
    for i, v in enumerate(x):
        out = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, out
        y[i] = out
    return y


def k_weight(x):
    # ITU-R BS.1770-4 pre-filter coefficients at 48 kHz (shelf, then RLB high-pass).
    x = biquad(x, (1.53512485958697, -2.69169618940638, 1.19839281085285), (1.0, -1.69065929318241, 0.73248077421585))
    return biquad(x, (1.0, -2.0, 1.0), (1.0, -1.99004745483398, 0.99007225036621))


def lufs(x):
    power = float(np.mean(x ** 2))
    return -0.691 + 10 * math.log10(power) if power > 1e-12 else -120.0


def window(x, start, end):
    return x[int(start * SR):int(end * SR)]


def centroid(x):
    if len(x) < 256:
        return 0.0
    spectrum = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    total = spectrum.sum()
    return float((spectrum * freqs).sum() / total) if total > 0 else 0.0


def write(path, data):
    clipped = np.clip(data, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((clipped * 32767).astype("<i2").tobytes())


def main():
    body = load(BODY)
    length = len(body)
    report = {"sampleRate": SR, "body": os.path.relpath(BODY, ROOT).replace("\\", "/"), "ready": READY, "burst": BURST, "tiers": {}}
    mixes = {}
    beats = {"build 0.10-0.95": (0.10, 0.95), "burst 0.95-1.60": (0.95, 1.60), "slam 1.60-2.10": (1.60, 2.10), "flourish 2.10-3.10": (2.10, 3.10)}
    body_k = k_weight(body)
    for tier, events in EVENTS.items():
        layer = np.zeros(length)
        rows = []
        for at, cue, speed, gain in events:
            src = resample(load(CUES % cue), speed) * gain
            start = int(at * SR)
            end = min(length, start + len(src))
            layer[start:end] += src[:end - start]
            # The note against the body in the note's own first 250 ms (or its length).
            span = min(0.25, len(src) / SR)
            note_k = k_weight(np.concatenate([np.zeros(2048), src[:int(span * SR)], np.zeros(2048)]))
            rows.append({"at": round(at, 3), "cue": cue, "semitones": round(12 * math.log2(speed), 2), "gain": gain,
                         "noteLUFS": round(lufs(note_k[2048:2048 + int(span * SR)]), 1),
                         "bodyLUFSsameWindow": round(lufs(window(body_k, at, at + span)), 1)})
            rows[-1]["noteOverBodyLU"] = round(rows[-1]["noteLUFS"] - rows[-1]["bodyLUFSsameWindow"], 1)
        mix = body + layer
        mixes[tier] = mix
        mix_k = k_weight(mix)
        tier_report = {"notes": rows, "peakDBFS": round(20 * math.log10(float(np.abs(mix).max())), 2), "beats": {}}
        for name, (a, b) in beats.items():
            tier_report["beats"][name] = {"mixLUFS": round(lufs(window(mix_k, a, b)), 1), "bodyOnlyLUFS": round(lufs(window(body_k, a, b)), 1),
                                          "layerCentroidHz": round(centroid(window(layer, a, b)))}
            tier_report["beats"][name]["liftOverBodyLU"] = round(tier_report["beats"][name]["mixLUFS"] - tier_report["beats"][name]["bodyOnlyLUFS"], 1)
        report["tiers"][tier] = tier_report
        write(os.path.join(OUT, "item-hatch-%s.wav" % tier), mix)
    gap = np.zeros(int(0.7 * SR))
    write(os.path.join(OUT, "common-then-uncommon-then-rare.wav"), np.concatenate([mixes["common"], gap, mixes["uncommon"], gap, mixes["rare"]]))
    write(os.path.join(OUT, "common-then-rare.wav"), np.concatenate([mixes["common"], gap, mixes["rare"]]))
    # Tier-to-tier differences in each beat (the part Spencer could not hear before).
    report["differences"] = {}
    for name in beats:
        c, u, r = (report["tiers"][t]["beats"][name]["mixLUFS"] for t in ("common", "uncommon", "rare"))
        report["differences"][name] = {"uncommonMinusCommonLU": round(u - c, 1), "rareMinusUncommonLU": round(r - u, 1), "rareMinusCommonLU": round(r - c, 1)}
    with open(os.path.join(OUT, "loudness-report.json"), "w") as f:
        json.dump(report, f, indent=1)
    print(json.dumps(report["differences"], indent=1))
    for tier in EVENTS:
        print(tier, "peak", report["tiers"][tier]["peakDBFS"], {k: (v["mixLUFS"], v["liftOverBodyLU"], v["layerCentroidHz"]) for k, v in report["tiers"][tier]["beats"].items()})
        for row in report["tiers"][tier]["notes"]:
            print("   %5.2f %-16s %+6.2f st gain %.2f  note %6.1f LUFS  body %6.1f  over body %+5.1f LU" % (row["at"], row["cue"], row["semitones"], row["gain"], row["noteLUFS"], row["bodyLUFSsameWindow"], row["noteOverBodyLU"]))


if __name__ == "__main__":
    main()
