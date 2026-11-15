# Garden music v4 — a soft, connected toy melody

Creative direction: Astra, 2026-11-14. Local audition only; preserve all v3 masters, uploads and current runtime mappings. No upload, runtime change or experience publish in this slice.

Spencer's actual feedback on garden v3: **“i like the direction of it, but not melodic enough, too sparse; the samples are too distinct and not manipulative enough, should be softer?”** This supersedes v3's hidden three-note motif, roughly 9% foreground occupancy and deliberately recognizable raw foley. Keep the unusual rubber/bubble material, but turn it into a small musical voice with a tune that can be remembered after one listen. Fuller means connected phrasing and gentle harmonic support, not a full lead/bass/drum arrangement.

## Evidence and listening limit

I inspected the v3 generator, actual candidate report/readme and previous review. The v3 melody was reported about 19 dB below principal sample peaks, with only a few notes per 24 seconds; raw squeaks/plops received short edits and slight speed changes. Those choices explain why this revision must change the hierarchy and synthesis approach. **I cannot actually listen to these files through the tools available to me. I have not heard v3 and will not claim to have heard or subjectively approved v4.** The user's listening feedback is the perceptual evidence. Render inspection and technical compliance can support another audition, not substitute for hearing it.

## One audition, 26.667 seconds

Produce a single **eight-bar garden sketch at 72 BPM, 4/4**: 32 beats, exactly 1,280,000 frames at 48 kHz. No intro; the main voice enters at beat 0.5 so the direction is immediately clear. Use F major with a slightly curious sixth rather than a triumphant cadence. The tune below is an original working composition, not a transcription of a Sonic/Chao cue.

One principal melodic voice throughout, centered with at most ±6% slow pan. Durations below are voiced gate lengths in beats, followed by a soft 100–180 ms release; preserve overlap into the next note where it connects the phrase. Timing can breathe ±12 ms, except the repeated hook retains its rhythmic identity. Stable pitches, no broad random detuning; tiny pitch settling of at most 12 cents over the first 60 ms is optional.

| Bar | Melody: local beat → note (gate in beats) | Quiet harmony |
|---|---|---|
| 1 | 0.5 → A4 (.75); 1.5 → C5 (.5); 2.25 → D5 (1.25) | F3 + C4, warm swell |
| 2 | 0 → C5 (.75); 1 → A4 (1); 2.5 → G4 (.5); 3.25 → A4 (.5) | Continue same dyad |
| 3 | .5 → F4 (.75); 1.5 → A4 (.5); 2.25 → C5 (1.25) | D3 + A3, warm swell |
| 4 | 0 → D5 (.75); 1 → C5 (1); 2.5 → A4 (.5); 3.25 → G4 (.5) | Continue same dyad |
| 5 | Same pitches/timing as bar 1; slightly softer first note | Bb2 + F3, warm swell |
| 6 | Same pitches/timing as bar 2 | Continue same dyad |
| 7 | .5 → A4 (.75); 1.5 → G4 (.5); 2.25 → F4 (1.25) | C3 + G3 for this bar |
| 8 | 0 → G4 (.75); 1 → A4 (.75); 2.25 → F4 (1.25) | F3 + C4, soft landing |

This gives 27 melodic notes, four intelligible two-bar phrases and a repeated hook. Keep the short phrase breaths. Do not restore the old 12% occupancy ceiling: roughly half to two thirds of the sketch should carry melody including release, while individual notes stay relaxed. The arrangement should feel inhabited even if the listener misses a tiny detail.

**Render clarification, accepted by Astra:** the exact score above already has 21 beats of gates (65.625%), before release. Its rendered 140 ms releases produce 79.8% support occupancy. Preserve the exact notes and phrase rests, and report both figures honestly. This corrects the preceding rough including-release estimate; do not shorten the melody to fit that estimate or use an amplitude threshold to conceal its tails.

## Transform the recordings into the instrument

Reuse verified bart rubber-toy and BMacZero bubble CC0 sources. Their provenance must remain explicit. The original composition and processing are ours; do not call the source recordings self-recorded. Build a **new v4 bank**; do not modify v3's bank or the archived originals.

The target is a pillowy, rounded, slightly liquid toy voice. The ear should follow its melody before identifying a squeaky toy or a water drop. Lowpass alone is insufficient. Use an actual source-driven transformation chain, for example:

1. Remove the identifiable initial squeal/plop attack. Select small interior regions from the rubber body and bubble tail; record exact input regions. Highpass around 100–150 Hz to discard handling rumble.
2. Create a sustained, softly changing texture by overlap-adding 40–90 ms Hann-windowed grains from those regions, with 65–80% overlap. Alternate nearby interior regions smoothly; no repeated audible loop click or unpitched squeal cycling. Rubber supplies most of the body, bubble about a quarter of the blend. Some low-level reversed grains can soften identity further.
3. Tune the transformed texture to the requested notes using source-excited resonators or another reproducible sample transformation. Establish a clear fundamental and a few gentle harmonic bands; attenuate the original sweeping squeak/formant that would compete with pitch. A resonator ring is acceptable; a pure synthesized lead with the raw sample quietly underneath does not satisfy this brief. A separate sine support, if required, must remain at least 14 dB RMS below the transformed sample voice over its active gate.
4. Round the envelope: 35–60 ms attack, smooth gate sustain with a small natural sag, 100–180 ms release. Lowpass near 2.8–3.5 kHz; tame any piercing 1–3 kHz resonance locally. Keep enough upper body for phone playback. No hard bitcrushing, bright glass ping, sharp chirp, strongly identifiable duck-like squeak or cartoon slide between notes.
5. Add a shared small soft room, roughly 12–20 ms predelay, 0.7–0.9 s decay and 10–16% send. Stereo decorrelation belongs in this quiet room, not opposite-phase melody. Do not use a long reverb wash as the only softening technique.

Those numbers are implementation starting points, not an auditory guarantee. The report must identify which transformations were actually applied. Include a private diagnostic strip of one raw fragment → transformed single note → first complete two-bar phrase, separated and labeled in its manifest. This tests whether the recording really became an instrument. Do not present the strip as the finished song.

## Support and hierarchy

- Melody is the main musical idea, clearly above incidental foley. The previous “motif 12–19 dB below squeaks” rule is retired. Any residual decorative tap or transformed bubble should peak at least 8 dB below the principal melodic notes.
- Use the dyads in the table as slow, smooth, two-note harmonic air: roughly 12–16 dB RMS below the melody's active phrase. They may overlap at transitions by 150–300 ms. No arpeggio, chord stab on every beat or bass pattern. Use the existing quiet synthetic harmonic method if suitable; all melody must remain sample-derived.
- At most **three** tiny decorative events in the whole audition, in phrase breaths, with the same softened treatment. They are optional. Omit the old raw rattle and squeak hits. No separate drum kit, shaker grid or ostinato.
- Do not duck the melody around its own decorative events. Stable musical continuity matters more than showcasing each source.
- Do not produce a Pocket Deck version yet; settle the garden voice/tune with this focused audition first. The eventual Deck version can inherit the accepted tune.

## Render, technical checks and presentation

Write a new generator under a new filename in `scripts/`; write all new audio outputs only under `artifacts/qa-2026-11-14-v634/audio/revision-4-melodic/`. Preserve the earlier files byte-for-byte. Deliver:

- `garden-melodic-audition-27s.wav` and a playable MP3, actual duration 26.667 s stated in the report.
- Mono fold-down, an 8-second seam audition (last two + first two seconds, twice), and the source-transformation diagnostic strip.
- Compact README and JSON report with source hashes, processing recipes, note/event ledger, exact duration, peak/true peak, integrated loudness, mono energy and output hashes. Report melodic active occupancy distinctly from any decorative foley occupancy.

Render tails cyclically so this short sketch can be evaluated as a loop. End on the soft F4; the first A4 pickup should feel like continuation. Check for boundary clicks, doubled attacks and excessive repeated-tail buildup. A numeric zero boundary jump alone does not certify an inaudible seam.

Keep headroom: no clipping, true peak below −3 dBTP. Begin with principal note peaks around v3's main sample peaks (about −16 dBFS), then balance the new support underneath. Integrated loudness will rise naturally because more music is present; do not force the fuller piece back to v3's −38 LUFS or normalize it to commercial music loudness. Report any mix gain change explicitly. A separately labeled equal-loudness A/B excerpt is optional; never silently loudness-normalize only one candidate.

Present **one clearly labeled inline audio player**: “Garden v4 audition — more melody, softer transformed toy sounds — 27 seconds.” Follow it with one sentence: “This is a local listening draft; the current build still uses v3.” Provide the v3 player only when useful for direct comparison, labeled “Current v3 — sparse reference.” Put seam/mono/diagnostic files behind links rather than flooding the conversation with players.

For the broader QA packet, show a screenshot only for the exact UI or gameplay change it depicts. Use a plain caption naming the screen, action and whether it is actual Studio output. Do not reuse a debug size-comparison image from an unrelated screen to explain an audio or gameplay change. Music needs playable sound, not a screenshot of an editor or waveform. A visual QA image must stand on its own without requiring the user to decode internal labels.

## Acceptance for this slice

Technical review verifies the files and processing are real, safe and reproducible. Creative compliance review checks the exact report and rendered artifact availability against this brief. **Neither establishes that Astra heard the music.** The audition asks whether the tune is memorable, the timbre soft and strange, and the arrangement comfortably full. Present the actual audio for Spencer's listening feedback before extending it to a full garden loop or Deck treatment. No new runtime integration is authorized by this document.
