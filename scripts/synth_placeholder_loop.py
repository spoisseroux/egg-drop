"""Render original, periodic Egg Drop music and purr upload masters.

Requires numpy. Never runs the draft's audition/export code or external tools.
"""
from pathlib import Path
import argparse
import hashlib
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SR = 44100
DRAFT = ROOT / "assets/concepts/music/egg_drop_quirky_lounge.py"
DRAFT_MP3 = DRAFT.with_name("egg_drop_pocket_apricot_quirky.mp3")
MARKER = "# Small room, not a cloud of reverb."
REVIEWED_PREFIX_SHA256 = "54cabfc3653674e7e9e7e12fef2f9e7bf61ab8b70d3cd65ce346e27881c2ad5b"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def music():
    source = DRAFT.read_text(encoding="utf-8")
    if source.count(MARKER) != 1:
        raise ValueError("Draft render boundary changed; review before rendering")
    # This checked boundary excludes every draft file writer and subprocess call.
    prefix = source.split(MARKER)[0]
    if hashlib.sha256(prefix.encode("utf-8")).hexdigest() != REVIEWED_PREFIX_SHA256:
        raise ValueError("Dry score changed; review its code before executing")
    namespace = {"__file__": str(DRAFT), "__name__": "egg_drop_dry_score"}
    exec(compile(prefix, str(DRAFT), "exec"), namespace)
    frames = 2352000  # Exactly 64 beats at 72 BPM and 44100 Hz.
    dry = namespace["out"]
    folded = dry[:frames].copy()
    tail = dry[frames:]
    if len(tail) > frames:
        raise ValueError("Unexpected release length")
    folded[:len(tail)] += tail
    rendered = folded.copy()
    for delay, gain in [(0.071, 0.12), (0.113, 0.09), (0.181, 0.055), (0.283, 0.026)]:
        rendered += np.roll(folded[:, ::-1], int(delay * SR), axis=0) * gain
    rendered *= 1.65
    rendered *= 0.63 / max(0.63, float(np.max(np.abs(rendered))))
    return rendered


def purr():
    # Integer cycles over two seconds make carrier, pulse, and breath periodic.
    t = np.arange(2 * SR, dtype=np.float64) / SR
    carrier = (np.sin(2 * np.pi * 55 * t)
               + 0.30 * np.sin(2 * np.pi * 110 * t + 0.3)
               + 0.10 * np.sin(2 * np.pi * 165 * t + 0.6))
    pulse = 0.73 + 0.27 * np.cos(2 * np.pi * 25 * t)
    breath = 0.78 + 0.22 * np.cos(2 * np.pi * 0.5 * t)
    rendered = carrier * pulse * breath
    rendered *= 0.22 / np.max(np.abs(rendered))
    return rendered[:, None]


def write_asset(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.rint(samples * 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(samples.shape[1])
        output.setsampwidth(2)
        output.setframerate(SR)
        output.writeframes(pcm.tobytes())
    # Measure the actual quantized delivery, including the circular seam.
    delivered = pcm.astype(np.float64) / 32768
    delta = delivered[0] - delivered[-1]
    incoming = delivered[-1] - delivered[-2]
    outgoing = delivered[1] - delivered[0]
    window = SR // 2
    nearby = np.concatenate((np.diff(delivered[-window:], axis=0),
                             np.diff(delivered[:window], axis=0)))
    nearby_max = float(np.max(np.abs(nearby)))
    peak = float(np.max(np.abs(delivered)))
    rms = float(np.sqrt(np.mean(delivered ** 2)))
    return {
        "file": path.name, "sha256": digest(path), "bytes": path.stat().st_size,
        "sample_rate": SR, "channels": samples.shape[1], "sample_bits": 16,
        "frames": len(samples), "duration_seconds": len(samples) / SR,
        "peak": peak, "rms": rms,
        "peak_dbfs": float(20 * np.log10(peak)),
        "rms_dbfs": float(20 * np.log10(rms)),
        "start_minus_end": delta.tolist(),
        "incoming_slope": incoming.tolist(), "outgoing_slope": outgoing.tolist(),
        "seam_slope_change": (outgoing - delta).tolist(),
        "nearby_max_sample_step": nearby_max,
        "nearby_window_seconds_each_side": window / SR,
        "seam_step_vs_nearby_max": float(np.max(np.abs(delta))) / nearby_max if nearby_max else 0.0,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "assets/audio")
    args = parser.parse_args()
    original = {path.relative_to(ROOT).as_posix(): digest(path) for path in (DRAFT, DRAFT_MP3)}
    assets = [write_asset(args.output_dir / "egg_drop_meadow_loop.wav", music()),
              write_asset(args.output_dir / "egg_drop_purr_loop.wav", purr())]
    if any(digest(ROOT / name) != value for name, value in original.items()):
        raise RuntimeError("Original draft changed during render")
    metadata = {"composition": "Pocket Apricot; original seeded procedural score",
                "draft_sha256_unchanged": original, "assets": assets,
                "note": "Circular PCM masters; Roblox transcoding still requires listening review."}
    manifest = args.output_dir / "egg_drop_audio_manifest.json"
    manifest.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
