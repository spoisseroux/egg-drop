"""Deterministic local auditions of Astra's original overnight scores.

Requires numpy and ffmpeg. Does not upload or modify production audio/runtime.
Run from any directory: python scripts/synth_overnight_aero.py
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/concepts/music/overnight-aero-2026-11-09"
SR = 44100
TAU = 2 * np.pi
# attack, decay, release; decay continues during gate and release.
ENVELOPES = {
    "porcelain_keys": (.011, .65, .16), "porcelain_lead": (.014, .8, .20),
    "bulb_bass": (.018, .9, .12), "gumdrop": (.006, .19, .10),
    "water_glass": (.007, .52, .36), "cushion_kick": (.006, .12, .08),
    "paper_brush": (.008, .060, .04), "thread_bass": (.013, .26, .065),
    "rubber_chord": (.006, .18, .09), "glass_button": (.006, .27, .14),
    "reed_button": (.019, .38, .09), "button_kick": (.003, .095, .06),
    "maple_rim": (.002, .030, .03), "paper_tick": (.003, .009, .008),
    "spring": (.003, .080, .04),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def nearest(value):
    return math.floor(value + .5)


def run(*args):
    return subprocess.run([str(a) for a in args], check=True, capture_output=True, text=True)


def harmonics(t, frequency, partials):
    # Fixed analytic maximum, never normalize an individual event by its peak.
    return sum(weight * np.sin(TAU * frequency * ratio * t)
               for ratio, weight in partials) / sum(abs(w) for _, w in partials)


def filtered_noise(t, rng, low, high):
    noise = rng.uniform(-1, 1, len(t))
    bins = np.fft.rfftfreq(len(t), 1 / SR)
    # Smooth shoulders, deterministic FFT band shaping; no recorded samples.
    weight = (1 - np.exp(-(bins / low) ** 4)) if low else np.ones_like(bins)
    weight *= np.exp(-(bins / high) ** 6)
    return np.fft.irfft(np.fft.rfft(noise) * weight, n=len(t))


def voice(name, midi, gate, rng):
    attack, decay, release = ENVELOPES[name]
    # The score calls the paper tick itself 29ms, regardless of its gate field.
    duration = .029 if name == "paper_tick" else gate + release
    t = np.arange(nearest(duration * SR) + 1, dtype=np.float64) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    envelope = np.sin(np.minimum(t / attack, 1) * np.pi / 2) ** 2 * np.exp(-t / decay)
    release_start = duration - release if name == "paper_tick" else gate
    envelope *= np.cos(np.clip((t - release_start) / release, 0, 1) * np.pi / 2) ** 2
    envelope[-1] = 0
    if name == "porcelain_keys":
        signal = (np.sin(TAU*f*t)*np.exp(-t/.65)
                  + (.23*np.sin(TAU*f*2.002*t)+.055*np.sin(TAU*f*4*t))*np.exp(-t/.14)) / 1.285
        # Partial-specific decays replace the common fundamental decay.
        signal *= np.exp(t / decay)
    elif name == "porcelain_lead":
        signal = harmonics(t, f, [(1, 1), (2, .16), (3, .04)])
    elif name == "bulb_bass":
        signal = harmonics(t, f, [(1, 1), (2, .22), (3, .06)])
    elif name == "gumdrop":
        # Slightly falling third formant, with a much shorter consonant.
        formant_phase = TAU*f*(3*t + .13*.028*(1-np.exp(-t/.028)))
        signal = (np.sin(TAU*f*t)+.22*np.sin(formant_phase)*np.exp(-t/.055))/1.22
    elif name == "water_glass":
        index = .65 * np.maximum(0, 1-t/.050) ** 2
        signal = np.sin(TAU*f*t + index*np.sin(TAU*f*2.7*t))
    elif name in ("cushion_kick", "button_kick"):
        high, low, fall = (84, 51, .035) if name == "cushion_kick" else (110, 55, .026)
        phase = TAU*(low*t+(high-low)*fall*(1-np.exp(-t/fall)))
        signal = np.sin(phase) if name == "cushion_kick" else (np.sin(phase)+.12*np.sin(2*phase))/1.12
    elif name == "paper_brush":
        signal = filtered_noise(t, rng, 1000, 3800)
    elif name == "thread_bass":
        signal = harmonics(t, f, [(1, 1), (2, .30), (3, .10)])
    elif name == "rubber_chord":
        signal = harmonics(t, f, [(1, 1), (2.01, .27), (3.96, .08)])
    elif name == "glass_button":
        signal = harmonics(t, f, [(1, 1), (2.6, .17)])
    elif name == "reed_button":
        signal = harmonics(t, f, [(1, 1), (3, .18), (5, .035)])
        tremolo = np.clip((t-attack)/.05, 0, 1)
        signal *= 1-.045*tremolo*(1-np.cos(TAU*4.8*t))
    elif name == "maple_rim":
        signal = (np.sin(TAU*540*t)+.55*np.sin(TAU*840*t)
                  +.14*filtered_noise(t, rng, 600, 6500)*np.exp(-t/.009))/1.69
    elif name == "paper_tick":
        signal = filtered_noise(t, rng, 900, 5000)
    elif name == "spring":
        # Smooth upward two-semitone bend; integrated analytic frequency.
        bend = 2**(2/12)-1
        phase = TAU*f*((1+bend)*t-bend*.020*(1-np.exp(-t/.020)))
        signal = (np.sin(phase)+.23*np.sin(2*phase))/1.23
    else:
        raise ValueError(name)
    return signal * envelope


def fold_add(output, start, samples):
    # Split rather than fancy-index += so even a multi-period release sums correctly.
    cursor = 0
    while cursor < len(samples):
        offset = (start + cursor) % len(output)
        take = min(len(samples)-cursor, len(output)-offset)
        output[offset:offset+take] += samples[cursor:cursor+take]
        cursor += take


def render(score):
    assert score["format_version"] == 1 and score["sample_rate"] == SR and score["meter"] == "4/4"
    assert len(score["events"]) == score["event_count"] and score["bars"] == 24
    seconds_per_beat = 60 / score["bpm"]
    frames = nearest(score["bars"] * 4 * seconds_per_beat * SR)
    dry, room = np.zeros((frames, 2)), np.zeros((frames, 2))
    rng = np.random.default_rng(score["seed"])
    timing = []
    deck = score["bpm"] == 120
    for event in score["events"]:
        bar, beat, gate, name, midi, amplitude, pan = event
        assert 1 <= bar <= 24 and 0 <= beat < 4 and gate > 0 and 0 <= amplitude <= 1 and -1 <= pan <= 1
        start = nearest(((bar-1)*4+beat)*seconds_per_beat*SR)
        sample = voice(name, midi, gate*seconds_per_beat, rng)*amplitude
        angle = (pan+1)*np.pi/4
        stereo = sample[:, None]*np.array([np.cos(angle), np.sin(angle)])
        fold_add(dry, start, stereo)
        if not (deck and name in ("button_kick", "maple_rim")):
            fold_add(room, start, stereo)
        # The specified left reflection is also circular and release-complete.
        if name == "glass_button":
            reflection = np.column_stack((sample*.045, np.zeros_like(sample)))
            fold_add(dry, start+nearest(.037*SR), reflection)
        timing.append({"event": event, "start_frame": start, "voice_frames": len(sample)})
    taps = [(.049, .055), (.094, .035)] if deck else [(.073, .09), (.117, .065), (.201, .035)]
    mixed = dry.copy()
    for delay, gain in taps:
        mixed += np.roll(room[:, ::-1], nearest(delay*SR), axis=0)*gain
    return mixed, timing, taps


def write_wav(path, samples):
    if np.max(np.abs(samples)) >= 1:
        raise ValueError("Clipping refused")
    pcm = np.rint(samples*32767).astype("<i2")
    with wave.open(str(path), "wb") as stream:
        stream.setparams((samples.shape[1], 2, SR, 0, "NONE", "not compressed"))
        stream.writeframes(pcm.tobytes())
    return pcm.astype(np.float64)/32768


def loudness(path, mono=False):
    filters = (["pan=mono|c0=0.5*c0+0.5*c1"] if mono else [])
    filters.append("loudnorm=I=-18:TP=-1:LRA=11:print_format=json")
    result = run("ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", ",".join(filters), "-f", "null", "-")
    # input_* measures the delivered file; loudnorm's output is discarded.
    match = re.search(r'\{\s*"input_i".*?\}', result.stderr, re.S)
    if not match:
        raise RuntimeError(result.stderr[-3000:])
    values = json.loads(match.group())
    return {key: float(values[key]) for key in ("input_i", "input_tp", "input_lra", "input_thresh")}


def measurements(path, delivered):
    seam = delivered[0]-delivered[-1]
    incoming, outgoing = delivered[-1]-delivered[-2], delivered[1]-delivered[0]
    window = np.concatenate((delivered[-SR//2:], delivered[:SR//2]))
    steps = np.diff(window, axis=0)
    mono = delivered.mean(axis=1)
    stereo_rms = float(np.sqrt(np.mean(delivered**2)))
    mono_rms = float(np.sqrt(np.mean(mono**2)))
    return {"file": path.name, "sha256": sha(path), "bytes": path.stat().st_size,
            "frames": len(delivered), "seconds": len(delivered)/SR, "sample_rate": SR,
            "channels": 2, "bits": 16, "sample_peak_dbfs": float(20*np.log10(np.max(np.abs(delivered)))),
            "stereo_loudness": loudness(path), "mono_downmix_loudness": loudness(path, True),
            "mono_rms_vs_stereo_db": 20*math.log10(mono_rms/stereo_rms),
            "channel_correlation": float(np.corrcoef(delivered.T)[0, 1]),
            "seam_step_per_channel": seam.tolist(), "incoming_slope": incoming.tolist(),
            "outgoing_slope": outgoing.tolist(), "seam_minus_incoming": (seam-incoming).tolist(),
            "outgoing_minus_seam": (outgoing-seam).tolist(),
            "nearby_max_step_per_channel": np.max(np.abs(steps), axis=0).tolist(),
            "seam_step_vs_nearby_max": float(np.max(np.abs(seam))/np.max(np.abs(steps))),
            "nearby_window_seconds_each_side": .5}


def mp3(path, destination):
    run("ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", path,
        "-codec:a", "libmp3lame", "-b:a", "192k", "-map_metadata", "-1", destination)
    return {"file": destination.name, "sha256": sha(destination), "bytes": destination.stat().st_size,
            "note": "Listening copy; PCM WAV alone defines exact loop frames; MP3 decoder padding can vary."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=OUT)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    preserved = [ROOT/"assets/audio/egg_drop_meadow_loop.wav", ROOT/"assets/concepts/music/egg_drop_pocket_apricot_quirky.mp3"]
    before = {p.relative_to(ROOT).as_posix(): sha(p) for p in preserved}
    manifest = {"status": "ORIGINAL LOCAL LISTENING DRAFTS; no upload, runtime change or audible approval",
                "renderer_sha256": sha(Path(__file__)), "numpy_version": np.__version__,
                "ffmpeg_version": run("ffmpeg", "-version").stdout.splitlines()[0],
                "render_policy": "Exact written events; equal-power pan; fixed theoretical instrument normalization; finite tails and cross-channel FIR room circularly folded; one constant gain; no compressor, limiter, fades or per-note peak normalization.",
                "default_preserved_sha256": before, "pieces": []}
    for slug in ("creek-with-one-shoe", "pocket-skip"):
        score_path = OUT/(slug+".score.json")
        score_hash = sha(score_path)
        score = json.loads(score_path.read_text(encoding="utf-8-sig"))
        samples, timing, taps = render(score)
        expected = 2761043 if score["bpm"] == 92 else 2116800
        assert len(samples) == expected and np.all(np.isfinite(samples))
        path = args.output_dir/(slug+".wav")
        write_wav(path, samples)
        initial = loudness(path)
        gain_db = min(-18-initial["input_i"], -1.1-initial["input_tp"])
        gain = 10**(gain_db/20)
        delivered = write_wav(path, samples*gain)
        metrics = measurements(path, delivered)
        assert -19 <= metrics["stereo_loudness"]["input_i"] <= -16, metrics
        assert metrics["stereo_loudness"]["input_tp"] <= -1, metrics
        assert metrics["sample_peak_dbfs"] <= -1
        assert metrics["seam_step_vs_nearby_max"] < 1, "Seam exceeds local waveform steps"
        assert metrics["mono_rms_vs_stereo_db"] > -1, "Unexpected mono cancellation"
        local_step = max(metrics["nearby_max_step_per_channel"])
        assert max(abs(v) for v in metrics["seam_minus_incoming"]+metrics["outgoing_minus_seam"]) < local_step
        timing_path = args.output_dir/(slug+".render-events.json")
        timing_path.write_text(json.dumps(timing, indent=2)+"\n", encoding="utf-8")
        listening = [mp3(path, path.with_suffix(".mp3"))]
        two_path = args.output_dir/(slug+".two-laps.wav")
        # Tile delivered PCM exactly. write_wav's scaling would requantize it.
        with wave.open(str(path), "rb") as source:
            pcm = source.readframes(source.getnframes())
            with wave.open(str(two_path), "wb") as target:
                target.setparams(source.getparams())
                target.writeframes(pcm+pcm)
        listening.append(mp3(two_path, two_path.with_suffix(".mp3")))
        with wave.open(str(two_path), "rb") as check:
            assert check.getnframes() == 2*expected
            raw = check.readframes(check.getnframes())
            assert raw[:len(pcm)] == raw[len(pcm):] == pcm
        assert sha(score_path) == score_hash
        manifest["pieces"].append({"title": score["title"], "score_sha256": score_hash,
            "bpm": score["bpm"], "bars": score["bars"], "event_count": len(timing),
            "seed": score["seed"], "constant_gain_db": gain_db, "room_taps_seconds_gain": taps,
            "master": metrics, "listening": listening,
            "two_laps": {"file": two_path.name, "sha256": sha(two_path), "frames": 2*expected,
                         "cycles_bit_identical": True}, "event_frame_manifest": timing_path.name})
        print(json.dumps({"title": score["title"], "frames": expected, "gain_db": gain_db,
                          "lufs": metrics["stereo_loudness"]["input_i"], "true_peak": metrics["stereo_loudness"]["input_tp"],
                          "seam_ratio": metrics["seam_step_vs_nearby_max"]}), flush=True)
    assert all(sha(ROOT/name) == digest for name, digest in before.items())
    reference_metrics = loudness(preserved[0])
    reference_gain = -18-reference_metrics["input_i"]
    reference_path = args.output_dir/"pocket-apricot.reference-level-matched.mp3"
    run("ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", preserved[0],
        "-af", f"volume={reference_gain:.6f}dB", "-codec:a", "libmp3lame", "-b:a", "192k", "-map_metadata", "-1", reference_path)
    manifest["reference_measured_unchanged"] = {"file": preserved[0].relative_to(ROOT).as_posix(),
        "stereo_loudness": reference_metrics, "mono_downmix_loudness": loudness(preserved[0], True),
        "listening_copy": reference_path.name, "listening_copy_sha256": sha(reference_path),
        "listening_constant_gain_db": reference_gain,
        "note": "Derived level-matched reference only; original Pocket Apricot and runtime default remain unchanged."}
    (args.output_dir/"render-manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    main()
