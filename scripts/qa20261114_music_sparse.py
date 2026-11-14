"""Local24s audition and72s candidates from CC0 recordings and sparse original additions.

No runtime/manifest wiring, upload, package installation or prior audio edits.
Inputs remain under assets/audio/sample-sources. Default writes revision-3-sparse;
--full reads/preserves that audition and writes only new revision-3-full candidates.
"""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/audio/sample-sources/opengameart-2026-11-14"
OUT = ROOT / "artifacts/qa-2026-11-14-v634/audio/revision-3-sparse"
SR, SECONDS, SEED = 48000, 24, 20261114
N = SR * SECONDS


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR),
                          "-f", "f32le", "pipe:1"], capture_output=True, check=True).stdout
    signal = np.frombuffer(raw, "<f4").astype(np.float64)
    assert len(signal) and np.isfinite(signal).all()
    return signal


def write(path, signal):
    signal = np.asarray(signal)
    assert np.isfinite(signal).all() and np.max(np.abs(signal)) < .95
    pcm = np.rint(signal * 32767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1 if signal.ndim == 1 else signal.shape[1])
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())
    return pcm.astype(np.float64) / 32767


def edges(signal, fade=.010):
    signal = signal.copy()
    count = min(round(fade * SR), len(signal) // 3)
    curve = .5 - .5 * np.cos(np.linspace(0, np.pi, count))
    signal[:count] *= curve
    signal[-count:] *= curve[::-1]
    return signal


def attenuation_only(signal, ceiling):
    return signal * min(1, ceiling / max(1e-12, float(np.max(np.abs(signal)))))


def verify_sources():
    provenance = json.loads((SOURCE / "provenance.json").read_text(encoding="utf-8"))
    checked = {}
    for row in provenance["sources"]:
        assert row["author"] in {"bart", "BMacZero"}
        page = SOURCE / row["license_page_file"]
        assert digest(page) == row["license_page_sha256"]
        assert "creativecommons.org/publicdomain/zero/1.0/" in page.read_text(encoding="utf-8")
        for item in row["files"]:
            path = SOURCE / item["source_filename"]
            assert path.parent == SOURCE and digest(path) == item["sha256"]
            checked[str(path.relative_to(ROOT))] = digest(path)
            for extracted in item.get("extracted_wavs", []):
                path = (SOURCE / extracted["local_file"]).resolve()
                assert path.is_relative_to(SOURCE.resolve()) and path.suffix.lower() == ".wav"
                assert digest(path) == extracted["sha256"]
                checked[str(path.relative_to(ROOT))] = digest(path)
    return provenance, checked


def knock(rng, low=False, duration=.19):
    t = np.arange(round(duration * SR)) / SR
    ratios = (.83 if low else 1)
    signal = sum(gain * np.sin(2 * np.pi * frequency * ratios * t + phase) * np.exp(-t / decay)
                 for frequency, decay, gain, phase in [(180, .070, .50, 0), (620, .045, .65, .1),
                                                       (1040, .090, .27, .4), (1730, .035, .13, .8)])
    signal += rng.normal(0, .07, len(t)) * np.exp(-t / .008)
    signal *= .18 * (1 - np.exp(-t / .0025))
    return edges(np.tanh(signal), .008)


def bass(frequency):
    t = np.arange(round(.29 * SR)) / SR
    return edges(.045 * np.sin(2 * np.pi * frequency * t) * np.exp(-t / .075) * (1 - np.exp(-t / .008)), .012)


def shadow_note(frequency, duration):
    t = np.arange(round(duration * SR)) / SR
    sound = (np.sin(2 * np.pi * frequency * t) + .06 * np.sin(4 * np.pi * frequency * t))
    return edges(sound * .033 * np.exp(-t / .105) * (1 - np.exp(-t / .008)), .012)


def meter(path):
    result = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af",
                             "loudnorm=I=-30:TP=-3:LRA=11:print_format=json", "-f", "null", "-"],
                            capture_output=True, text=True, check=True)
    start, end = result.stderr.rfind("{"), result.stderr.rfind("}")
    values = json.loads(result.stderr[start:end + 1])
    def number(key):
        value = float(values[key])
        return value if math.isfinite(value) else None
    return {"integrated_lufs": number("input_i"), "true_peak_dbfs": number("input_tp"),
            "loudness_range_lu": number("input_lra"), "meter_only_no_normalization_applied": True}


def main():
    provenance, source_hashes = verify_sources()
    OUT.mkdir(parents=True, exist_ok=True)
    bank_dir = OUT / "sample-bank"
    bank_dir.mkdir(exist_ok=True)
    rng = np.random.default_rng(SEED)
    bank = {}

    def save(name, sound, **metadata):
        path = bank_dir / (name + ".wav")
        sound = edges(sound - np.mean(sound), .010)
        pcm = write(path, sound)
        bank[name] = dict(file=str(path.relative_to(OUT)), seconds=len(pcm) / SR, sha256=digest(path),
                          sample_peak_dbfs=20 * math.log10(max(1e-12, float(np.max(np.abs(pcm))))), **metadata)

    def recorded(name, relative, start, end, gain):
        path = SOURCE / relative
        data = decode(path)
        sound = data[round(start * SR):round(end * SR)] * gain
        assert len(sound) >= .06 * SR and gain <= 1
        save(name, sound, kind="third-party CC0 recording edit", source=str(path.relative_to(ROOT)),
             source_sha256=digest(path), source_region_seconds=[start, end], fixed_gain=gain,
             boundary_fade_ms=10, no_gain_normalization=True)

    recorded("rubber-squeak-main", "squeak_wavs/squeak toy - squeak2.wav", .040, .245, .18)
    recorded("rubber-squeak-small", "squeak_wavs/squeak toy - squeak5.wav", .100, .335, .14)
    recorded("rubber-grain", "squeak_wavs/squeak toy - squeak2.wav", .265, .345, .18 * 10 ** (-12 / 20))
    recorded("water-plop-one", "bubbles-single1.wav", .035, .295, .90)
    recorded("water-plop-two", "bubbles-single2.wav", .018, .325, .75)
    recorded("water-plop-three", "bubbles-single3.wav", .115, .400, .85)
    save("hollow-knock", attenuation_only(knock(rng), .22), kind="original synthetic addition", seed=SEED,
         recipe="Inharmonic180/620/1040/1730Hz damped body with2.5ms contact and short noise impulse; not a pitched MIDI instrument")
    save("hollow-knock-low", attenuation_only(knock(rng, low=True), .18), kind="original synthetic addition", seed=SEED,
         recipe="Same hollow-object resonances at0.83 ratio; no equal-tempered assignment")
    rattle = np.zeros(round(.25 * SR))
    for offset, gain in [(0, .48), (.037, .26), (.108, .35), (.173, .15)]:
        tick = knock(rng, duration=.070) * gain
        at = round(offset * SR)
        rattle[at:at + len(tick)] += tick[:len(rattle) - at]
    save("soft-rattle", rattle, kind="original synthetic addition", seed=SEED,
         recipe="Four quiet irregular hollow ticks at0/37/108/173ms; no shaker or percussion loop")
    save("secondary-tick", knock(rng, duration=.070) * .20, kind="original synthetic addition", seed=SEED,
         recipe="One very quiet original hollow tick")
    save("rounded-f2", bass(87.30705786), kind="original synthetic shadow", seed=SEED,
         recipe="One roundedF2 sine body with75ms decay; occurs once, no bass pattern")
    for name, frequency, duration in [("shadow-a4", 440, .25), ("shadow-c5", 523.2511306, .35), ("shadow-d5", 587.3295358, .40)]:
        save(name, shadow_note(frequency, duration), kind="original synthetic hidden motif", seed=SEED,
             recipe="Subdued fundamental and6% second partial; originalA4-C5-D5 fragment only")

    # The sequence actually reads the edited WAV bank, rather than relabeling live oscillators as samples.
    events = [(1.8, "hollow-knock", -.09, 1, True), (3.1, "water-plop-one", .08, 1, True),
              (5.5, "soft-rattle", -.04, 1, True), (7.2, "rubber-squeak-main", -.02, 1, True),
              (7.35, "rubber-grain", .01, 1, True), (9.3, "rounded-f2", 0, 1, True),
              (11.6, "shadow-a4", -.04, 1, False), (11.90, "shadow-c5", .02, 1, False),
              (12.30, "shadow-d5", -.02, 1, False), (14.4, "water-plop-two", -.07, 1, True),
              (16.7, "rubber-squeak-small", .07, 1, True), (20.4, "hollow-knock-low", -.08, 1, True),
              (20.53, "secondary-tick", .03, 1, True), (22.6, "water-plop-three", .09, 1, True)]
    dry = np.zeros((N, 2)); room_send = np.zeros_like(dry); foreground = np.zeros(N, dtype=np.int16)
    ledger = []
    for at, name, pan, gain, prominent in events:
        variation = float(rng.uniform(.965, 1.035))
        semitones = 12 * math.log2(variation)
        assert abs(semitones) <= 3 and abs(variation - 1) <= .08 and abs(pan) <= .12
        signal = decode(OUT / bank[name]["file"])
        signal = np.interp(np.arange(0, len(signal), variation), np.arange(len(signal)), signal)
        signal = edges(signal) * gain * 10 ** (float(rng.uniform(-1.1, 0)) / 20)
        jitter = float(rng.uniform(0, .004)); start = round((at + jitter) * SR)
        count = min(len(signal), N - start)
        gains = np.array([math.cos((pan + 1) * np.pi / 4), math.sin((pan + 1) * np.pi / 4)])
        stereo = signal[:count, None] * gains
        dry[start:start + count] += stereo
        if prominent:
            room_send[start:start + count] += stereo
            foreground[start:start + count] += 1
        ledger.append(dict(time_seconds=at + jitter, bank=name, playback_speed=variation, semitones=semitones,
                           pan=pan, prominent=prominent, duration_seconds=count / SR))

    # Quiet two-note air, no noise bed and no new attacks between the scheduled gestures.
    bed = np.zeros(N)
    for start, duration in [(.05, 7.95), (18.8, 3.2)]:
        t = np.arange(round(duration * SR)) / SR
        fade = np.minimum(1, t / 1.2) * np.minimum(1, (duration - t) / 1.0)
        signal = .012 * (np.sin(2 * np.pi * 174.6141157 * t) + np.sin(2 * np.pi * 261.6255653 * t + .3)) * fade
        offset = round(start * SR);bed[offset:offset + len(signal)] += signal
    dry += bed[:, None] * .7071067812

    # Shared small room:14ms predelay,23/41/67ms early reflections,550ms T60 tail.
    room = np.zeros_like(dry)
    taps = [(.014 + .023, .30), (.014 + .041, .23), (.014 + .067, .18)]
    taps += [(float(d), float(.14 * math.exp(-math.log(1000) * (d - .08) / .55))) for d in np.arange(.095, .665, .019)]
    total_gain = sum(g for _, g in taps)
    for delay, gain in taps:
        samples = round(delay * SR)
        room[samples:] += room_send[:-samples] * (gain / total_gain)
    mix = dry + .14 * room
    assert np.isfinite(mix).all() and np.max(np.abs(mix)) < .70
    assert int(foreground.max()) <= 2 and np.mean(foreground > 0) < .35
    stereo_path = OUT / "garden-texture-audition-24s.wav"
    pcm = write(stereo_path, mix)
    mono_path = OUT / "garden-texture-audition-mono-24s.wav"
    mono = write(mono_path, mix.mean(axis=1))
    assert len(pcm) == N and np.max(np.abs(mono - pcm.mean(axis=1))) <= 2 / 32767
    strip, strip_ledger = [], []
    for name, row in bank.items():
        signal = decode(OUT / row["file"])
        strip_ledger.append(dict(name=name, start_seconds=sum(len(x) for x in strip) / SR, duration_seconds=len(signal) / SR))
        strip += [signal, np.zeros(round(.65 * SR))]
    strip_path = OUT / "sample-bank-strip.wav"
    write(strip_path, np.concatenate(strip))
    for path in (stereo_path, mono_path):
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(path), "-c:a", "libmp3lame", "-b:a", "192k", str(path.with_suffix(".mp3"))], check=True)
    measurements = {path.name: meter(path) for path in (stereo_path, mono_path, strip_path)}
    assert all(m["true_peak_dbfs"] is not None and m["true_peak_dbfs"] < -3 for m in measurements.values())
    report = dict(title="Sparse garden texture audition", audition_only=True, installed=False, uploaded=False,
                  sample_rate=SR, frames=N, seconds=SECONDS, seed=SEED, actual_recorded_sources=provenance,
                  source_hashes=source_hashes, sample_bank=bank, events=ledger, bank_strip=strip_ledger,
                  measurements=measurements, final_gain_normalization=False, max_foreground_layers=int(foreground.max()),
                  fraction_without_foreground_sample=1 - float(np.mean(foreground > 0)),
                  mono_vs_stereo_per_channel_rms_db=20 * math.log10(float(np.sqrt(np.mean(mono * mono))) / float(np.sqrt(np.mean(pcm * pcm)))),
                  dc_per_channel=[float(value) for value in pcm.mean(axis=0)],
                  room=dict(predelay_ms=14, early_reflections_ms=[23, 41, 67], tail_t60_seconds=.55, wet=.14),
                  limitations=["No subjective listening approval claimed; Spencer's actual audition is the acceptance gate.",
                               "Third-party CC0 recordings are attributed, not described as our own recorded foley.",
                               "A24-second passage, not an installed seamless long loop or a deck arrangement."])
    report["output_sha256"] = {p.name: digest(p) for p in OUT.glob("*.wav")}
    (OUT / "audition-report.json").write_text(json.dumps(report, indent=2, allow_nan=False), encoding="utf-8")
    verify_sources()
    for name, values in measurements.items():
        print(name, json.dumps(values))
    print("foreground max", foreground.max(), "unoccupied fraction", report["fraction_without_foreground_sample"])


def deck_colour(signal, source_rate=SR):
    """Typed PCM transform:4kHz lowpass,20kHz sampling,13-bit amplitude; no gain lift."""
    result = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(source_rate), "-ac", "1",
                             "-i", "pipe:0", "-af", "lowpass=f=4000:p=2", "-ar", "20000", "-f", "f32le", "pipe:1"],
                            input=np.asarray(signal, dtype="<f4").tobytes(), capture_output=True, check=True)
    low = np.frombuffer(result.stdout, "<f4").astype(np.float64)
    low = np.rint(low * 4095) / 4095
    count = round(len(signal) * SR / source_rate)
    return np.interp(np.arange(count) * 20000 / SR, np.arange(len(low)), low)


def deck_note(frequency, duration):
    t = np.arange(round(duration * SR)) / SR
    # Finite harmonic sums are band-limited at4kHz, unlike a naive pulse oscillator.
    triangle = sum(((-1) ** ((k - 1) // 2)) * np.sin(2 * np.pi * k * frequency * t) / k ** 2
                   for k in range(1, 10, 2) if k * frequency < 4000)
    pulse = sum(2 * np.sin(np.pi * k * .22) / (np.pi * k) * np.cos(2 * np.pi * k * frequency * t)
                for k in range(1, 10) if k * frequency < 4000)
    return edges((triangle + .035 * pulse) * .033 * np.exp(-t / .105) * (1 - np.exp(-t / .012)), .012)


def measured_pitch(signal, frequency):
    """Positive-crossing regression over the audible40–120ms steady portion."""
    x = signal[round(.04*SR):round(.12*SR)]
    indices = np.flatnonzero((x[:-1] <= 0) & (x[1:] > 0))
    crossings = indices - x[indices] / (x[indices+1]-x[indices])
    assert len(crossings) >= 20
    period = np.polyfit(np.arange(len(crossings)),crossings,1)[0]
    hz = SR / period
    cents = 1200 * math.log2(hz/frequency)
    assert abs(cents) <= 5, (frequency,hz,cents)
    return dict(hz=float(hz),error_cents=float(cents),method="40–120ms positive-crossing linear regression")


def full_candidates():
    """New72s reversible candidates only; preserve every audition/source byte."""
    provenance, source_hashes = verify_sources()
    audition = json.loads((OUT / "audition-report.json").read_text(encoding="utf-8"))
    originals = {str(p): digest(p) for p in OUT.rglob("*") if p.is_file()}
    destination = OUT.parent / "revision-3-full"
    destination.mkdir(parents=True, exist_ok=True)
    bank, bank_sources = {}, {}
    for name, row in audition["sample_bank"].items():
        path = (OUT / row["file"]).resolve()
        assert path.is_relative_to(OUT.resolve()) and digest(path) == row["sha256"]
        bank[name] = decode(path)
        bank_sources[name] = dict(file=str(path.relative_to(ROOT)), sha256=digest(path), kind=row["kind"])
    bank["rounded-d2"] = bass(73.41619198)
    bank["rounded-c3"] = bass(130.8127827)
    events = [(e["time_seconds"], e["bank"], e["pan"], e["prominent"]) for e in audition["events"]]
    schedules = [
        [(2.3,"water-plop-three"), (4.7,"hollow-knock-low"), (8.2,"rubber-squeak-small"),
         (10.1,"rounded-d2"), (11.4,"soft-rattle"), (12.8,"shadow-a4"), (13.1,"shadow-c5"),
         (13.5,"shadow-d5"), (15.8,"water-plop-one"), (19.6,"hollow-knock"), (22.1,"water-plop-two")],
        [(1.9,"hollow-knock"), (4.1,"water-plop-two"), (7.6,"rubber-squeak-main"), (7.75,"rubber-grain"),
         (9.4,"rounded-c3"), (10.8,"shadow-a4"), (11.1,"shadow-c5"), (11.5,"shadow-d5"),
         (12.9,"water-plop-three"), (16.4,"soft-rattle"), (20.0,"hollow-knock-low"), (22.4,"water-plop-one")],
    ]
    for passage, rows in enumerate(schedules, 1):
        for index, (at, name) in enumerate(rows):
            events.append((24 * passage + at, name, (-1 if index % 2 else 1) * (.04 + .02 * (index % 3)), not name.startswith("shadow-")))
    events.sort()
    frequencies = {"shadow-a4":440.0, "shadow-c5":523.2511306, "shadow-d5":587.3295358,
                   "rounded-f2":87.30705786, "rounded-d2":73.41619198, "rounded-c3":130.8127827}
    harmonic = [(.05,7.95,174.6141157,261.6255653), (18.8,3.2,174.6141157,261.6255653),
                (24,6,146.83238396,220), (42,3,146.83238396,220),
                (48,5,116.5409404,174.6141157), (62,5,130.8127827,195.997718)]
    frames = SR * 72
    outputs, versions = {}, {}
    for device in ("garden", "pocket-deck"):
        rng = np.random.default_rng(SEED + 72)  # Same event variation in both versions.
        rendered_bank = {}
        for name, signal in bank.items():
            if device == "pocket-deck":
                if name.startswith("shadow-"):
                    signal = deck_note(frequencies[name], len(signal) / SR)
                elif name.startswith("rounded-"):
                    signal = signal[:round(.16 * SR)] * .85
                else:
                    signal = signal[:round(len(signal) * .80)]
                signal = deck_colour(edges(signal))
            rendered_bank[name] = signal
        bank_directory = destination / (device + "-bank")
        bank_directory.mkdir(exist_ok=True)
        bank_ledger = {}
        for name, signal in rendered_bank.items():
            path = bank_directory / (name + ".wav")
            write(path, signal)
            rendered_bank[name] = decode(path)  # Sequence the emitted edited bank.
            bank_ledger[name] = dict(file=str(path.relative_to(destination)), sha256=digest(path),
                                     source_bank=bank_sources.get(name), original_frequency_hz=frequencies.get(name),
                                     seconds=len(signal) / SR)
            if name.startswith("shadow-"):
                bank_ledger[name]["measured_pitch"] = measured_pitch(rendered_bank[name],frequencies[name])
        dry = np.zeros((frames, 2)); send = np.zeros_like(dry); occupancy = np.zeros(frames, dtype=np.int16)
        ledger = []; principal_peak = 0; motif_peak = 0
        for at, name, pan, foreground in events:
            pitched = name in frequencies
            speed = 1.0 if pitched else float(rng.uniform(.965,1.035))
            # Gain variation is attenuation only; source-bank hierarchy is retained.
            gain = 10 ** (float(rng.uniform(-1.1,0)) / 20)
            signal = rendered_bank[name]
            signal = edges(np.interp(np.arange(0,len(signal),speed),np.arange(len(signal)),signal)) * gain
            pan *= .5 if device == "pocket-deck" else 1
            assert abs(pan) <= (.05 if device == "pocket-deck" else .1)
            assert abs(speed - 1) <= .08
            if pitched: assert abs(1200 * math.log2(speed)) <= 5
            start = round(at * SR); indices = (start + np.arange(len(signal))) % frames
            stereo = signal[:,None] * np.array([math.cos((pan+1)*np.pi/4),math.sin((pan+1)*np.pi/4)])
            dry[indices] += stereo
            if foreground:
                send[indices] += stereo;occupancy[indices] += 1
                if not pitched: principal_peak = max(principal_peak,float(np.max(np.abs(signal))))
            if name.startswith("shadow-"): motif_peak = max(motif_peak,float(np.max(np.abs(signal))))
            ledger.append(dict(time_seconds=at, bank=name, pan=pan, playback_speed=speed,
                               cents=1200*math.log2(speed), frequency_hz=frequencies.get(name), gain=gain,
                               duration_seconds=len(signal)/SR, foreground=foreground))
        # Six sparse two-note windows, below the motif; no continuous noise or pad.
        for at, duration, first, second in harmonic:
            t = np.arange(round(duration * SR)) / SR
            envelope = np.minimum(1,t/1.2) * np.minimum(1,(duration-t)/1)
            level = .004 if device == "pocket-deck" else .006
            signal = level * (np.sin(2*np.pi*first*t)+np.sin(2*np.pi*second*t+.3)) * envelope
            dry[(round(at*SR)+np.arange(len(signal))) % frames] += signal[:,None]*.7071067812
        decay, wet = (.25,.05) if device == "pocket-deck" else (.55,.14)
        taps = [(.037,.30),(.055,.23),(.081,.18)]
        taps += [(float(d),float(.14*math.exp(-math.log(1000)*(d-.08)/decay))) for d in np.arange(.095,decay+.115,.019)]
        room = np.zeros_like(dry);total = sum(g for _,g in taps)
        for delay, gain in taps: room += np.roll(send,round(delay*SR),axis=0)*(gain/total)
        mix = dry + wet * room
        assert np.isfinite(mix).all() and np.max(np.abs(mix)) < .70
        assert occupancy.max() <= 2 and np.mean(occupancy>0) <= .12
        assert 20*math.log10(motif_peak/principal_peak) <= -12
        path = destination / (device + "-texture-72s.wav")
        pcm = write(path,mix);mono_path=path.with_name(path.stem+"-mono.wav")
        mono = write(mono_path,mix.mean(axis=1))
        assert len(pcm)==frames and np.max(np.abs(mono-pcm.mean(axis=1))) <= 2/32767
        excerpt = path.with_name(device+"-matched-excerpt-24s.wav");write(excerpt,mix[:24*SR])
        seam = path.with_name(device+"-seam-16s.wav")
        cycle = np.concatenate([mix[-4*SR:],mix[:4*SR]],axis=0);write(seam,np.tile(cycle,(2,1)))
        measurements={}
        for output in (path,mono_path,excerpt,seam):
            measurements[output.name]=meter(output)
            assert measurements[output.name]["true_peak_dbfs"] < -3
            outputs[output.name]=digest(output)
            subprocess.run(["ffmpeg","-y","-v","error","-i",str(output),"-c:a","libmp3lame","-b:a","192k",str(output.with_suffix(".mp3"))],check=True)
        versions[device]=dict(bank=bank_ledger,events=ledger,measurements=measurements,
          foreground_fraction=float(np.mean(occupancy>0)),max_foreground_layers=int(occupancy.max()),
          motif_peak_below_principal_db=20*math.log10(motif_peak/principal_peak),
          mono_vs_stereo_per_channel_rms_db=20*math.log10(float(np.sqrt(np.mean(mono*mono)))/float(np.sqrt(np.mean(pcm*pcm)))),
          dc_per_channel=[float(v) for v in pcm.mean(axis=0)],
          loop_boundary_jump=[float(v) for v in pcm[0]-pcm[-1]],
          room=dict(predelay_ms=14,t60_seconds=decay,send=wet,cyclic_tail=True),
          colour=None if device=="garden" else dict(lowpass_hz=4000,amplitude_bits=13,sample_rate=20000,foley_tail_fraction=.80))
        print(device,json.dumps(measurements[path.name]),"foreground",versions[device]["foreground_fraction"])
    assert all(digest(Path(p))==expected for p,expected in originals.items()), "audition mutated"
    verify_sources()
    report=dict(seconds=72,sample_rate=SR,frames=frames,seed=SEED+72,source_hashes=source_hashes,
                provenance=provenance,audition_report_sha256=digest(OUT/"audition-report.json"),
                generator_sha256=digest(Path(__file__)),harmonic_windows=harmonic,versions=versions,output_sha256=outputs,
                preserved_audition_file_hashes=originals,
                no_gain_normalization=True,uploaded=False,runtime_mapped=False,
                limits=["No subjective listening approval claimed.","Meters and cyclic buffers do not certify an inaudible seam.",
                        "Deck is a reversible local candidate, not a conventional chiptune arrangement."])
    (destination/"candidate-report.json").write_text(json.dumps(report,indent=2,allow_nan=False),encoding="utf-8")


if __name__ == "__main__":
    import sys
    if "--full" in sys.argv: full_candidates()
    else: main()
