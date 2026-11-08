"""Local original arcade auditions. Never uploads or changes runtime/default audio."""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np

from synth_placeholder_loop import SR, music

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/audio/drafts"
BEAT = 60 / 72


def write(name, samples):
    samples = np.asarray(samples, dtype=np.float64)
    if samples.ndim == 1:
        samples = samples[:, None]
    path = OUTPUT / name
    with wave.open(str(path), "wb") as stream:
        stream.setparams((samples.shape[1], 2, SR, 0, "NONE", "not compressed"))
        stream.writeframes(np.rint(np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes())
    return {"file": name, "frames": len(samples), "channels": samples.shape[1],
            "seconds": len(samples) / SR, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "peak": float(np.max(np.abs(samples))), "rms": float(np.sqrt(np.mean(samples ** 2)))}


def stab(frequency, seconds=.18):
    t = np.arange(round(seconds * SR)) / SR
    envelope = np.minimum(1, t / .003) * np.minimum(1, (seconds - t) / .02) * np.exp(-t / .055)
    return (np.sin(2 * np.pi * frequency * t) + .17 * np.sin(4 * np.pi * frequency * t)) * envelope


def load_mono(name, speed=1):
    with wave.open(str(ROOT / "assets/audio" / name), "rb") as stream:
        rate = stream.getframerate()
        samples = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2").astype(float) / 32768
    positions = np.arange(round(len(samples) * SR / rate / speed)) * rate * speed / SR
    return np.interp(positions, np.arange(len(samples)), samples)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    original_paths = [ROOT / "assets/audio/egg_drop_meadow_loop.wav",
                      ROOT / "assets/concepts/music/egg_drop_quirky_lounge.py",
                      ROOT / "assets/concepts/music/egg_drop_pocket_apricot_quirky.mp3"]
    before = {str(p.relative_to(ROOT).as_posix()): hashlib.sha256(p.read_bytes()).hexdigest() for p in original_paths}
    # A short original F-major pentatonic answer; no recordings or borrowed melody.
    stinger = np.zeros(round(.36 * SR))
    for offset, frequency, gain in [(0, 698.456, .13), (.055, 880, .11), (.115, 1046.502, .095)]:
        note = stab(frequency)
        start = round(offset * SR)
        stinger[start:start + len(note)] += note * gain
    assets = [write("egg_drop_chain_spark_local.wav", stinger)]
    # The unchanged score stays the only full melody. These are sparse rhythmic
    # layers and four isolated answers, folded over its exact existing period.
    optional = music() * .92
    count = len(optional)
    rng = np.random.default_rng(260607)

    def add(beat, sample, gain, pan=0):
        frames = (np.arange(len(sample)) + round(beat * BEAT * SR)) % count
        angle = (pan + 1) * np.pi / 4
        optional[frames, 0] += sample * gain * np.cos(angle)
        optional[frames, 1] += sample * gain * np.sin(angle)

    for halfbeat in range(128):
        t = np.arange(round(.055 * SR)) / SR
        noise = rng.normal(size=len(t))
        hat = (noise - np.roll(noise, 1)) * np.exp(-t / .010) * np.minimum(1, t / .0015)
        hat *= np.maximum(0, 1 - t / .055)
        add(halfbeat * .5 + .25, hat, .009 if halfbeat % 4 else .013, -.35 if halfbeat % 2 else .35)
    for bar in range(16):
        add(bar * 4 + 2.75, stab(130.813, .12), .032, -.1)
    for beat, frequency in [(15.25, 698.456), (31.25, 880), (47.25, 1046.502), (63.25, 1174.659)]:
        add(beat, stab(frequency), .055, .2)
    assets.append(write("egg_drop_arcade_spark_loop_local.wav", optional))
    # Explicit sequential audition, with offsets in the manifest; no normalization
    # disguising the production differences between confirm, tab and quieter back.
    pieces, offsets, elapsed = [], [], 0
    for label, sample in [("baseline_menu_at_0.72", load_mono("egg_drop_menu.wav") * .72),
                          ("confirm_1.06_at_0.65", load_mono("egg_drop_menu.wav", 1.06) * .65),
                          ("tab_1.12_at_0.52", load_mono("egg_drop_menu.wav", 1.12) * .52),
                          ("back_0.84_at_0.35", load_mono("egg_drop_menu.wav", .84) * .35),
                          ("baseline_chain_at_0.34", load_mono("egg_drop_merge_chain.wav") * .34),
                          ("original_chain_spark_local_only", stinger)]:
        offsets.append({"label": label, "start_seconds": elapsed / SR})
        pieces.extend((sample, np.zeros(round(.6 * SR))))
        elapsed += len(sample) + round(.6 * SR)
    assets.append(write("egg_drop_arcade_cues_ab_local.wav", np.concatenate(pieces)))
    assert all(hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == value for name, value in before.items())
    metadata = {"status": "LOCAL AUDITION ONLY; unpublished, not wired to runtime",
                "default_music_asset_unchanged": 98540058987296,
                "sample_rate": SR, "sample_bits": 16, "originals_unchanged": before,
                "assets": assets, "cue_audition_offsets": offsets,
                "optional_loop": {"bpm": 72, "beats": 64, "seam_delta": (optional[0] - optional[-1]).tolist(),
                                  "note": "Needs an audible full-loop seam and gameplay intelligibility check before any adoption."}}
    (OUTPUT / "egg_drop_arcade_drafts_manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
