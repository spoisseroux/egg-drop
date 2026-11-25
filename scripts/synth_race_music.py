"""Hop to It: the Garden Dash race song (RACE-AND-MUSIC-LOOK.md section 2.1 and 2.2, Fable's score).

One file: a 3.000 s countdown lead-in, then a seamless 16-bar loop (32.000 s) at 120 bpm in C major.
48 kHz stereo, 1,680,000 frames. Loop it with Sound.LoopRegion = NumberRange.new(3, 35).
Additive synthesis only (the voice() kinds of qa20261114_music.py); no samples, no generated audio.
Fixed seed: every run is byte-identical.

Run from the repository root:  python scripts/synth_race_music.py
Writes artifacts/qa-2026-11-23-beta14/audio/race/ (drafts for Spencer to hear; nothing uploaded).
"""
import math
import os

import numpy as np

import audio_draft_kit as K

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "artifacts", "qa-2026-11-23-beta14", "audio", "race")
SR, BPM = 48000, 120
BEAT = 60 / BPM                      # 0.5 s
BAR = 4 * BEAT                       # 2.0 s
LEAD_IN = 3.0
LOOP = 16 * BAR                      # 32.0 s
F_BEAT, F_LEAD, F_LOOP = 24000, 144000, 1536000
assert round(BEAT * SR) == F_BEAT and round(LEAD_IN * SR) == F_LEAD and round(LOOP * SR) == F_LOOP
assert F_LEAD == 6 * F_BEAT and F_LOOP == 64 * F_BEAT
TOTAL = F_LEAD + F_LOOP              # 1,680,000
XFADE = .040                         # lead-in hands over to the loop's own wrap in the last 40 ms
LEAD = .23                           # lead (wood) gain; every other part is set relative to it

CHORDS = ["C", "C", "F", "G", "C", "Am", "F", "G", "F", "G", "Em", "Am", "F", "G", "C", "G"]
MELODY = [
    "E5:.5 G5:.5 C6:1 G5:.5 E5:.5 G5:1",
    "A5:.5 G5:.5 E5:1 D5:.5 E5:.5 G5:1",
    "F5:.5 A5:.5 C6:1 A5:.5 F5:.5 A5:1",
    "G5:.5 B5:.5 D6:1 B5:.5 A5:.5 G5:1",
    "E5:.5 G5:.5 C6:1 D6:.5 C6:.5 G5:1",
    "A5:.5 C6:.5 E6:1 D6:.5 C6:.5 A5:1",
    "F5:.5 A5:.5 C6:.5 A5:.5 F5:.5 A5:.5 C6:1",
    "D6:1 B5:.5 G5:.5 D5:.5 G5:.5 B5:.5 D6:.5",
    "C6:1.5 A5:.5 F5:1 r:1",
    "B5:1.5 G5:.5 D5:1 r:1",
    "G5:.5 B5:.5 E6:1 D6:.5 B5:.5 G5:1",
    "A5:.5 C6:.5 E6:1 C6:.5 A5:.5 E5:1",
    "F5:.5 A5:.5 C6:.5 F6:.5 E6:1 C6:1",
    "D6:.5 B5:.5 G5:.5 B5:.5 D6:1 G5:1",
    "E6:1 C6:.5 G5:.5 E5:.5 G5:.5 C6:1",
    "D6:.5 B5:.5 G5:1 G5:.5 A5:.5 B5:.5 D6:.5",
]
BASS = {
    "C": "C3:1 C4:.5 C3:.5 G3:1 C3:.5 G3:.5",
    "F": "F3:1 F4:.5 F3:.5 C4:1 F3:.5 C4:.5",
    "G": "G2:1 G3:.5 G2:.5 D3:1 G2:.5 D3:.5",
    "Am": "A2:1 A3:.5 A2:.5 E3:1 A2:.5 E3:.5",
    "Em": "E3:1 E4:.5 E3:.5 B3:1 E3:.5 B3:.5",
}
BAR16_BASS = "G2:1 G3:.5 G2:.5 D3:1 G2:.5 B2:.5"   # walks up to C
OFFBEAT = {"C": "E4 G4 C5", "F": "F4 A4 C5", "G": "D4 G4 B4", "Am": "E4 A4 C5", "Em": "E4 G4 B4"}
ANSWERS = {9: "A5:.25 C6:.25 F6:.5", 10: "B5:.25 D6:.25 G6:.5"}

MIX = dict(bass=-4, offbeat=-12, kick=-6, brush=-10, shaker_on=-18, shaker_off=-12, woodblock=-14,
           double=-8, bell=-14, pad=-20, answer=-9)


def g(part):
    return LEAD * K.db(MIX[part])


def build_loop(rng, ledger):
    out = np.zeros((F_LOOP, 2))
    add = lambda at, s, gain, pan=0.0: K.add(out, at, s, gain, SR, pan, wrap=True)
    for b in range(1, 17):
        t0 = (b - 1) * BAR
        chord = CHORDS[b - 1]
        # Lead: wood, doubled an octave lower by pluck at -8 dB; bell double in bars 13 to 16.
        beat = 0.0
        events = K.parse(MELODY[b - 1])
        assert abs(sum(d for _, d in events) - 4) < 1e-9, b
        for i, (note, beats) in enumerate(events):
            if note != "r":
                gate = .85 if beats == .5 else .92
                dur = beats * BEAT * gate
                gain = LEAD * (K.db(2) if i == 0 else 1.0)
                add(t0 + beat * BEAT, K.voice(note, dur, "wood", SR), gain)
                add(t0 + beat * BEAT, K.voice(K.octave(note, -1), dur, "pluck", SR), gain * K.db(MIX["double"]))
                if b >= 13:
                    add(t0 + beat * BEAT, K.voice(note, dur, "bell", SR), gain * K.db(MIX["bell"]), .05)
                ledger.append(dict(part="lead", bar=b, beat=beat, note=note, beats=beats))
            beat += beats
        # Pluck answers, bars 9 and 10, from beat 3.
        if b in ANSWERS:
            beat = 3.0
            for note, beats in K.parse(ANSWERS[b]):
                add(t0 + beat * BEAT, K.voice(note, beats * BEAT * .85, "pluck", SR), g("answer"), .08)
                ledger.append(dict(part="answer", bar=b, beat=beat, note=note, beats=beats))
                beat += beats
        # Bass, one pattern per chord; bar 16 walks up to C.
        beat = 0.0
        for note, beats in K.parse(BAR16_BASS if b == 16 else BASS[chord]):
            add(t0 + beat * BEAT, K.voice(note, beats * BEAT * .9, "bass", SR), g("bass"))
            ledger.append(dict(part="bass", bar=b, beat=beat, note=note, beats=beats))
            beat += beats
        # Off-beat chords (bars 3 to 16) and the pad (bars 9 to 12).
        notes = OFFBEAT[chord].split()
        if b >= 3:
            for off in (.5, 1.5, 2.5, 3.5):
                for k, note in enumerate(notes):
                    add(t0 + off * BEAT, K.gated(K.voice(note, .18, "pluck", SR), SR, .18 + .12), g("offbeat") / math.sqrt(3), (-.1, 0, .1)[k])
        if 9 <= b <= 12:
            for k, note in enumerate(notes):
                add(t0, K.voice(K.octave(note, -1), BAR, "pad", SR), g("pad"), (-.12, 0, .12)[k])
        # Drums.
        kicks = [0, 2] + ([2.5] if b in (4, 8, 12) else [])
        for k in kicks:
            add(t0 + k * BEAT, K.kick(SR), g("kick"))
        if b >= 3:
            brushes = [(1, 0)] + ([(3, 0)] if b not in (8, 16) else [(3, 2), (3.25, 4), (3.5, 6), (3.75, 8)])
            for at, lift in brushes:
                add(t0 + at * BEAT, K.brush(rng, SR), g("brush") * K.db(lift))
        for e in range(8):
            add(t0 + e * .5 * BEAT, K.shaker(rng, SR), g("shaker_off" if e % 2 else "shaker_on"), .1)
        if b >= 9:
            for at in (1.5, 3.75):
                add(t0 + at * BEAT, K.woodblock(SR), g("woodblock"), -.06)
    return K.room(out, SR, .05, wrap=True)


def build_lead_in(rng):
    out = np.zeros((F_LEAD + SR, 2))
    add = lambda at, s, gain, pan=0.0: K.add(out, at, s, gain, SR, pan)
    for at in (0, 2, 4):
        add(at * BEAT, K.woodblock(SR), g("woodblock"), -.06)
        for k, note in enumerate("D4 G4 C5".split()):
            add(at * BEAT, K.gated(K.voice(note, .2, "pluck", SR), SR, .2 + .12), g("offbeat") / math.sqrt(3), (-.1, 0, .1)[k])
    beat = 0.0
    for note, beats in K.parse("G2:1 r:1 G2:1 r:1 G2:.5 A2:.5 B2:.5 B2:.5"):
        if note != "r":
            add(beat * BEAT, K.voice(note, beats * BEAT * .9, "bass", SR), g("bass"))
        beat += beats
    for i, at in enumerate(np.arange(3, 6, .5)):
        add(at * BEAT, K.shaker(rng, SR), LEAD * K.db(-18 + 12 * i / 5), .1)
    for at in (5, 5.5):
        add(at * BEAT, K.brush(rng, SR), g("brush"))
    for at, note in ((5, "C5"), (5.5, "D5")):
        dur = .5 * BEAT * .85
        add(at * BEAT, K.voice(note, dur, "wood", SR), LEAD)
        add(at * BEAT, K.voice(K.octave(note, -1), dur, "pluck", SR), LEAD * K.db(MIX["double"]))
    return K.room(out, SR, .05, wrap=False)


def main():
    rng = np.random.default_rng(20261123)
    ledger = []
    loop = build_loop(rng, ledger)
    lead = build_lead_in(rng)
    full = np.zeros((TOTAL, 2))
    full[F_LEAD:] = loop
    full[:F_LEAD] = lead[:F_LEAD]
    # The 3.0 s point must be the same sample path as the 35.0 -> 3.0 loop jump, so the lead-in's last
    # 40 ms crossfade (equal power) into the loop's own last 40 ms: frame 143,999 then continues into
    # frame 144,000 exactly as frame 1,679,999 does on every loop.
    n = int(XFADE * SR)
    x = np.linspace(0, 1, n)[:, None]
    full[F_LEAD - n:F_LEAD] = lead[F_LEAD - n:F_LEAD] * np.cos(x * np.pi / 2) + loop[-n:] * np.sin(x * np.pi / 2)
    full -= full[F_LEAD:].mean(axis=0)

    full, gr = K.normalise(full, SR, -19.0, -6.0, circular=False)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "hop_to_it_120bpm_leadin3_loop32.wav")
    pcm = K.write_wav(path, full, SR)
    assert len(pcm) == TOTAL == 1680000

    loop_pcm = pcm[F_LEAD:]
    whole = K.ebur128(path)
    loop_only = K.measure_array(loop_pcm, SR)
    seam = K.join_check(loop_pcm, loop_pcm, SR)          # 35.0 -> 3.0
    lead_join = K.join_check(pcm[:F_LEAD], loop_pcm, SR)  # first pass through 3.0
    tail_vs_seam = float(np.max(np.abs(pcm[F_LEAD - 1] - loop_pcm[-1])))

    # Audition: the last 4 s of the loop into the first 4 s, twice, as heard on the phone.
    audition = np.concatenate([loop_pcm[-4 * SR:], loop_pcm[:4 * SR], loop_pcm[-4 * SR:], loop_pcm[:4 * SR]])
    apath = os.path.join(OUT, "hop_to_it_seam_audition_16s.wav")
    K.write_wav(apath, audition, SR)

    bars = [dict(bar=b, starts_s=LEAD_IN + (b - 1) * BAR, starts_frame=F_LEAD + (b - 1) * 2 * 2 * F_BEAT) for b in (1, 9, 16)]
    report = dict(
        file=os.path.basename(path), sha256=K.sha256(path), bpm=BPM, beat_frames=F_BEAT, bar_frames=4 * F_BEAT,
        lead_in_frames=F_LEAD, loop_frames=F_LOOP, total_frames=TOTAL, loop_region_seconds=[3, 35], bar_starts=bars,
        whole_file=whole, loop_region=loop_only, limiter_max_gain_reduction_db=round(gr, 2),
        loop_seam_35_to_3=seam, lead_in_join_at_3=lead_join, lead_in_last_frame_minus_loop_last_frame=tail_vs_seam,
        stats=K.basic_stats(pcm, SR), audition=os.path.basename(apath), score=ledger)
    K.save_report(os.path.join(OUT, "race-report.json"), report)
    print(path, "frames", len(pcm), "I", whole["integrated_lufs"], "LRA", whole["loudness_range_lu"], "TP", whole["true_peak_dbtp"],
          "| loop I", loop_only["integrated_lufs"], "LRA", loop_only["loudness_range_lu"], "| limiter GR", round(gr, 2))
    print("seam 35->3", seam)
    print("join at 3.0", lead_join, "| lead-in last frame vs loop last frame", tail_vs_seam)


if __name__ == "__main__":
    main()
