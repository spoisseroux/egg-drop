# Hatch rarity sounds, redone from scratch (QA v735 H3)

**Auditions only. Not uploaded, not wired in.** Nobody has listened to these yet: they were built and checked by measurement and spectrogram, not by ear. Spencer's ear is the test.

## Listen

| File | What |
|---|---|
| `all-three-common-uncommon-rare.mp3` | The three in a row, at their in-game gains |
| `common.mp3` | A light, round pop with one soft bell note (0.5 s) |
| `uncommon.mp3` | A brighter pop, a rising three-note chime, then glitter (1.25 s) |
| `rare.mp3` | A harp run and shimmer rising into the pop and a big chord chime, an answering twinkle, a long glitter tail (2.7 s; the hit is at 0.70 s) |
| `in-hatch-*.mp3` | Each one over the unchanged Material hatch body, timed so the pop lands on the burst (0.98 s). An offline mix, not a Studio recording |

## How they were made

`python scripts/synth_hatch_rarity.py`: sine partials and shaped white noise in numpy, fixed seeds, the same bytes on every run. No samples, no recordings, no AI audio. Masters: `assets/audio/custom/egg_drop_rarity_<tier>.wav` (44.1 kHz, mono, 16-bit, peak -1 dBFS).

Each tier contains the one below it, all in C major pentatonic, so they sound like one family and climb: pop, then pop + chime + sparkle, then rise + pop + big chime + sparkle. Measurements are in `report.json` (length, loudness, brightness per tier).

## If approved, the wiring

- Upload the three masters (Open Cloud, Audio) and add `rarity_common`, `rarity_uncommon`, `rarity_rare` to `BoardAudio`.
- `HatchRarityCue.events` becomes one sound per tier, replacing the lines built from old cues: Common and Uncommon start at the burst (0.98 s), Rare starts 0.70 s earlier (0.28 s) so its hit lands on the burst. Suggested gains 0.55, 0.75, 1.0.
- Rare rings until 2.98 s on the hatch clock; the accent voice is stopped at 3.10 s, so nothing is cut.
- The pet reveal keeps its own sound line (`RevealStage.Cues`); say if it should be redone in this family too.
- Update `HatchRarityAudio` and `HatchRarityCue` specs, which pin the old cue names.
