"""Local matched rarity-finish auditions; never uploads or edits runtime/audio assets."""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/qa-followup-v685-2026-11-14/audio"
SR = 48000
BASE = ROOT / "assets/audio/original-2026-11-14/hatch-v3"
TICK = ROOT / "assets/audio/placeholder/egg_drop_goal_tick.wav"
EVENTS = {"Common": [], "Uncommon": [(.10, 2 ** (2 / 12), .026)],
          "Rare": [(.12, 1., .035), (.26, 2 ** (3 / 12), .035)]}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    with wave.open(str(path), "rb") as handle:
        assert handle.getsampwidth() == 2
        values = np.frombuffer(handle.readframes(handle.getnframes()), "<i2").copy()
        return values.reshape(-1, handle.getnchannels()), handle.getframerate()


def write(path, pcm):
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(pcm.shape[1]); handle.setsampwidth(2); handle.setframerate(SR)
        handle.writeframes(pcm.astype("<i2").tobytes())


def true_peak(path):
    result = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-af", "aresample=192000",
                             "-f", "f32le", "pipe:1"], capture_output=True, check=True)
    return float(np.max(np.abs(np.frombuffer(result.stdout, "<f4"))))


def true_peak_pcm(pcm):
    result = subprocess.run(["ffmpeg", "-v", "error", "-f", "s16le", "-ar", str(SR),
                             "-ac", str(pcm.shape[1]), "-i", "pipe:0", "-af", "aresample=192000",
                             "-f", "f32le", "pipe:1"], input=pcm.astype("<i2").tobytes(), capture_output=True, check=True)
    return float(np.max(np.abs(np.frombuffer(result.stdout, "<f4"))))


def db(value):
    return 20 * math.log10(max(value, 1e-20))


def mixed(base, tick, tick_sr, tier, ready):
    signal = base.astype(np.float64) / 32768
    notes = []
    for delay, speed, gain in EVENTS[tier]:
        # A constant playback-rate change, without altering the approved body.
        positions = np.arange(math.ceil(len(tick) * SR / (tick_sr * speed))) * tick_sr * speed / SR
        note = np.interp(positions, np.arange(len(tick)), tick[:, 0] / 32768, right=0) * gain
        at = round((ready + delay) * SR)
        signal[at:at + len(note)] += note[:, None]
        notes.append({"at_seconds": ready + delay, "speed": speed, "gain": gain,
                      "sample_frames": len(note), "end_seconds": (at + len(note)) / SR})
    assert np.isfinite(signal).all() and np.max(np.abs(signal)) < 1
    pcm = np.rint(signal * 32768).astype("<i2")
    assert np.array_equal(pcm[:round(ready * SR)], base[:round(ready * SR)]), "opening prefix changed"
    return pcm, notes


def main():
    sources = [BASE / f"hatch-{kind}-v3-tightened-burst.wav" for kind in ("bear", "toy", "hue", "material", "feature")] + [TICK]
    before = {str(path.relative_to(ROOT)): sha(path) for path in sources}
    tick, tick_sr = read(TICK); assert tick.shape[1] == 1
    OUT.mkdir(parents=True, exist_ok=True)
    measurements, outputs = {}, {}
    for path in sources[:-1]:
        kind = path.name.split("-")[1]; ready = 2.65 if kind == "bear" else 2.2
        base, rate = read(path); assert rate == SR and base.shape[1] == 2
        window = slice(round(ready * SR), round((ready + .45) * SR))
        baseline = float(np.max(np.abs(base[window].astype(np.float64) / 32768)))
        baseline_true = true_peak_pcm(base[window])
        values = {}
        for tier in EVENTS:
            pcm, notes = mixed(base, tick, tick_sr, tier, ready)
            peak = float(np.max(np.abs(pcm[window].astype(np.float64) / 32768)))
            increase = db(peak / baseline); assert increase <= 1.0 + 1e-6
            window_true = true_peak_pcm(pcm[window]); true_increase = db(window_true / baseline_true)
            assert true_increase <= 1.0 + 1e-6
            assert all(note["end_seconds"] <= ready + .45 for note in notes)
            values[tier] = {"finish_sample_peak_dbfs": db(peak), "increase_db_over_same_finish": increase,
                            "finish_true_peak_4x_dbfs": db(window_true), "finish_true_peak_increase_db": true_increase,
                            "prefix_bit_exact": True, "events": notes}
            if kind == "feature" or (kind == "material" and tier in ("Common", "Rare")):
                stem = f"{kind}-{tier.lower()}-matched"
                wav = OUT / f"{stem}.wav"; write(wav, pcm)
                mono = np.rint(pcm.astype(np.float64).mean(axis=1)).astype("<i2")[:, None]
                mono_path = OUT / f"{stem}-mono.wav"; write(mono_path, mono)
                mp3 = OUT / f"{stem}.mp3"
                subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-codec:a", "libmp3lame", "-q:a", "2", str(mp3)], check=True)
                actual_peak = true_peak(wav); assert actual_peak < 1
                values[tier].update({"audition_true_peak_4x_dbfs": db(actual_peak),
                                    "audition_rms_dbfs": db(float(np.sqrt(np.mean((pcm.astype(np.float64) / 32768) ** 2)))),
                                    "mono_true_peak_4x_dbfs": db(true_peak(mono_path)),
                                    "mono_max_rounding_error_lsb": float(np.max(np.abs(mono[:, 0] - pcm.astype(np.float64).mean(axis=1))))})
                for output in (wav, mono_path, mp3): outputs[str(output.relative_to(ROOT))] = sha(output)
        measurements[kind] = values
    assert before == {str(path.relative_to(ROOT)): sha(path) for path in sources}, "source assets changed"
    report = {"scope": "Matched actual Material body: Gloss/Matte Common versus Jelly Rare (active v1). Three matched actual Feature bodies: horns Common, claws Uncommon, wings Rare (authored tiers; feature flag remains off). Local comparisons only; no uploads.",
              "model": "Existing PCM body speed1/gain1; actual goal_tick PCM sampled at constant runtime-equivalent PlaybackSpeed, mono centered. Linear interpolation models rate change; native resampler may differ.",
              "opening_prefix": "Every original sample before existing receipt beat is bit exact; no final normalization.",
              "loop_seam": "Not applicable: finite one-shot hatch cues, no looping or seam edit.",
              "taste_limit": "Meters establish level and lifecycle compliance, not subjective listening approval.",
              "active_tiers": {"material": {"jelly": "Rare", "gloss": "Common", "matte": "Common", "standard": "Common", "legacy_unknown": "Neutral"},
                               "feature": {"horns": "Common", "claws": "Uncommon", "wings": "Rare"},
                               "hue_toy_unknown": "Neutral", "companion": "Actual catalog base/rares only; earned/unknown Neutral"},
              "generator_sha256": sha(Path(__file__)), "policy_sha256": sha(ROOT / "src/client/HatchRarityCue.lua"),
              "source_sha256_unchanged": before, "measurements": measurements, "output_sha256": outputs}
    (OUT / "RARITY-AUDIO-REPORT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"auditions": len(outputs) // 3, "outputs": len(outputs), "max_finish_increase_db": max(row["increase_db_over_same_finish"] for group in measurements.values() for row in group.values()),
                      "max_finish_true_peak_increase_db": max(row["finish_true_peak_increase_db"] for group in measurements.values() for row in group.values()),
                      "all_opening_prefixes_bit_exact": True, "report": str(OUT / "RARITY-AUDIO-REPORT.json")}, indent=2))


if __name__ == "__main__":
    main()
