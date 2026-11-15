"""Local matched rarity-finish auditions; never uploads or edits runtime/audio assets."""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PREVIOUS = ROOT / "artifacts/qa-followup-v685-2026-11-14/audio"
OUT = PREVIOUS / "revision-2-audible"
SR = 48000
BASE = ROOT / "assets/audio/original-2026-11-14/hatch-v3"
TICK = ROOT / "assets/audio/placeholder/egg_drop_goal_tick.wav"
EVENTS = {"Common": [], "Uncommon": [(.24, 2 ** (2 / 12), .22)],
          "Rare": [(.20, 2 ** (-2 / 12), .35), (.42, 2 ** (5 / 12), .32)]}
ANSWER_END = .60


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


def masking_stats(note, tail, active):
    accent = np.repeat(note[:, None], tail.shape[1], axis=1)[active]
    body = tail[active]
    mix = np.rint((body + accent) * 32768) / 32768
    accent_rms = float(np.sqrt(np.mean(accent ** 2)))
    body_rms = float(np.sqrt(np.mean(body ** 2)))
    return {"frames": int(np.count_nonzero(active)), "duration_seconds": int(np.count_nonzero(active)) / SR,
            "accent_rms_dbfs": db(accent_rms), "body_rms_dbfs": db(body_rms) if body_rms else None,
            "body_digital_silence": body_rms == 0,
            "accent_minus_body_rms_db": db(accent_rms / body_rms) if body_rms else None,
            "mixed_rms_dbfs": db(float(np.sqrt(np.mean(mix ** 2)))),
            "accent_peak_dbfs": db(float(np.max(np.abs(accent)))),
            "mixed_peak_dbfs": db(float(np.max(np.abs(mix))))}


def mixed(base, tick, tick_sr, tier, ready):
    signal = base.astype(np.float64) / 32768
    notes = []
    for delay, speed, gain in EVENTS[tier]:
        # A constant playback-rate change, without altering the approved body.
        positions = np.arange(math.ceil(len(tick) * SR / (tick_sr * speed))) * tick_sr * speed / SR
        note = np.interp(positions, np.arange(len(tick)), tick[:, 0] / 32768, right=0) * gain
        at = round((ready + delay) * SR)
        tail = base[at:at + len(note)].astype(np.float64) / 32768
        # Explicit RMS envelope, not cherry-picked target-adjacent sample peaks.
        envelope = np.sqrt(np.convolve(note ** 2, np.ones(240) / 240, mode="same"))
        active = envelope >= float(np.max(envelope)) * .01
        signal[at:at + len(note)] += note[:, None]
        notes.append({"at_seconds": ready + delay, "speed": speed, "gain": gain,
                      "sample_frames": len(note), "end_seconds": (at + len(note)) / SR,
                      "whole_support": masking_stats(note, tail, np.ones(len(note), dtype=bool)),
                      "active_envelope": masking_stats(note, tail, active)})
    assert np.isfinite(signal).all() and np.max(np.abs(signal)) < 1
    pcm = np.rint(signal * 32768).astype("<i2")
    assert np.array_equal(pcm[:round(ready * SR)], base[:round(ready * SR)]), "opening prefix changed"
    if tier == "Common": assert np.array_equal(pcm, base), "Common changed"
    return pcm, notes


def main():
    sources = [BASE / f"hatch-{kind}-v3-tightened-burst.wav" for kind in ("bear", "toy", "hue", "material", "feature")] + [TICK]
    preserved = sources + [path for path in PREVIOUS.iterdir() if path.is_file()]
    before = {str(path.relative_to(ROOT)): sha(path) for path in preserved}
    tick, tick_sr = read(TICK); assert tick.shape[1] == 1
    OUT.mkdir(parents=True, exist_ok=True)
    measurements, outputs, material_pair = {}, {}, {}

    def emit(stem, pcm):
        wav = OUT / f"{stem}.wav"; write(wav, pcm)
        mono = np.rint(pcm.astype(np.float64).mean(axis=1)).astype("<i2")[:, None]
        mono_path = OUT / f"{stem}-mono.wav"; write(mono_path, mono)
        mp3 = OUT / f"{stem}.mp3"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-codec:a", "libmp3lame", "-q:a", "2", str(mp3)], check=True)
        actual_peak = true_peak(wav); assert actual_peak < 10 ** (-3 / 20)
        for output in (wav, mono_path, mp3): outputs[str(output.relative_to(ROOT))] = sha(output)
        return {"audition_true_peak_4x_dbfs": db(actual_peak),
                "audition_rms_dbfs": db(float(np.sqrt(np.mean((pcm.astype(np.float64) / 32768) ** 2)))),
                "mono_true_peak_4x_dbfs": db(true_peak(mono_path)),
                "mono_max_rounding_error_lsb": float(np.max(np.abs(mono[:, 0] - pcm.astype(np.float64).mean(axis=1))))}

    for path in sources[:-1]:
        kind = path.name.split("-")[1]; ready = 2.65 if kind == "bear" else 2.2
        base, rate = read(path); assert rate == SR and base.shape[1] == 2
        window = slice(round(ready * SR), round((ready + ANSWER_END) * SR))
        baseline = float(np.max(np.abs(base[window].astype(np.float64) / 32768)))
        baseline_true = true_peak_pcm(base[window])
        values = {}
        for tier in EVENTS:
            pcm, notes = mixed(base, tick, tick_sr, tier, ready)
            peak = float(np.max(np.abs(pcm[window].astype(np.float64) / 32768)))
            increase = db(peak / baseline); assert increase <= 6.0 + 1e-6
            window_true = true_peak_pcm(pcm[window]); true_increase = db(window_true / baseline_true)
            assert true_increase <= 6.0 + 1e-6
            full_true = true_peak_pcm(pcm); assert full_true < 10 ** (-3 / 20)
            assert all(note["end_seconds"] <= ready + ANSWER_END for note in notes)
            values[tier] = {"finish_sample_peak_dbfs": db(peak), "increase_db_over_same_finish": increase,
                            "finish_true_peak_4x_dbfs": db(window_true), "finish_true_peak_increase_db": true_increase,
                            "full_clip_true_peak_4x_dbfs": db(full_true),
                            "clipped_sample_count": int(np.count_nonzero(np.abs(pcm.astype(np.int32)) >= 32767)),
                            "prefix_bit_exact": True, "common_complete_pcm_bit_exact": True if tier == "Common" else None, "events": notes}
            if kind == "feature" or (kind == "material" and tier in ("Common", "Rare")):
                values[tier].update(emit(f"{kind}-{tier.lower()}-matched-revision-2", pcm))
                if kind == "material": material_pair[tier] = pcm
        measurements[kind] = values
    first_note = measurements["material"]["Rare"]["events"][0]
    assert 3 <= first_note["whole_support"]["accent_minus_body_rms_db"] <= 8
    gap = np.zeros((round(.65 * SR), 2), dtype="<i2")
    comparison = np.concatenate((material_pair["Common"], gap, material_pair["Rare"]))
    comparison_metrics = emit("material-common-then-rare-comparison-revision-2", comparison)
    assert before == {str(path.relative_to(ROOT)): sha(path) for path in preserved}, "source or previous audition changed"
    report = {"scope": "Matched actual Material body: Gloss/Matte Common versus Jelly Rare (active v1). Three matched actual Feature bodies: horns Common, claws Uncommon, wings Rare (authored tiers; feature flag remains off). Local comparisons only; no uploads.",
              "model": "Existing PCM body speed1/gain1; actual goal_tick PCM sampled at constant runtime-equivalent PlaybackSpeed, mono centered. Linear interpolation models rate change; native resampler may differ.",
              "opening_prefix": "Every original sample before existing receipt beat is bit exact; no final normalization.",
              "revision": 2, "supersedes": "User rejected revision1 as indistinguishable. Old audition bytes preserved.",
              "primary_comparison": {"file": "material-common-then-rare-comparison-revision-2.mp3", "order": "Common then Rare", "common_seconds": 3.1, "gap_seconds": .65, "rare_seconds": 3.1, "metrics": comparison_metrics},
              "mask_definition": "Whole support uses every emitted note sample; active envelope uses centered5ms(240sample) RMS envelope >=1% of that note envelope peak (−40dB). Accent/body/mix measured on identical indices/channels. Silence contrast is null.",
              "limits": {"finish_window_seconds": ANSWER_END, "max_finish_peak_growth_db": 6, "full_clip_true_peak_ceiling_dbfs": -3, "first_material_rare_support_rms_contrast_target_db": [3, 8]},
              "loop_seam": "Not applicable: finite one-shot hatch cues, no looping or seam edit.",
              "taste_limit": "Meters establish level and lifecycle compliance, not subjective listening approval.",
              "active_tiers": {"material": {"jelly": "Rare", "gloss": "Common", "matte": "Common", "standard": "Common", "legacy_unknown": "Neutral"},
                               "feature": {"horns": "Common", "claws": "Uncommon", "wings": "Rare"},
                               "hue_toy_unknown": "Neutral", "companion": "Actual catalog base/rares only; earned/unknown Neutral"},
              "generator_sha256": sha(Path(__file__)), "policy_sha256": sha(ROOT / "src/client/HatchRarityCue.lua"),
              "source_and_previous_audition_sha256_unchanged": before, "measurements": measurements, "output_sha256": outputs}
    (OUT / "RARITY-AUDIO-REPORT-REVISION-2.json").write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"auditions": len(outputs) // 3, "outputs": len(outputs), "max_finish_increase_db": max(row["increase_db_over_same_finish"] for group in measurements.values() for row in group.values()),
                      "max_finish_true_peak_increase_db": max(row["finish_true_peak_increase_db"] for group in measurements.values() for row in group.values()),
                      "first_material_rare_accent_minus_tail_rms_db": first_note["whole_support"]["accent_minus_body_rms_db"],
                      "all_opening_prefixes_bit_exact": True, "report": str(OUT / "RARITY-AUDIO-REPORT-REVISION-2.json")}, indent=2))


if __name__ == "__main__":
    main()
