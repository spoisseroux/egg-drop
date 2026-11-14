# Sparse garden and Pocket Deck — full local candidates

Continue authorized music work from the actual24-second sample-led audition. Optional user feedback has not arrived; **that does not block building reversible local candidates**. This document supersedes the “wait for accepted character before making Deck” production-work stop in `MUSIC-V3-SPARSE-AUDITION.md`. Do not interpret silence as approval or claim the user liked the audition. Actual candidate review still precedes asset upload/runtime mapping, as instructed by the coordinator.

## Evidence and limits

Read `audio/revision-3-sparse/README.md` and `audition-report.json`. The actual bank uses bart's CC0 rubber-toy recordings and BMacZero's CC0 bubble recordings, with provenance/hashes and original synthetic additions. Reported24-second level is−37.19 LUFS /−15.49 dBTP, foreground sample occupancy9.3%, maximum two overlapping foreground events, mono per-channel energy difference−.007dB. The room is14ms predelay,550ms decay,14% send. These show a sparse, technically intact source arrangement; **I have not heard it** and cannot certify the listening experience from these numbers.

Keep this palette and spaciousness. No return to the rejected104-BPM lead/bass/drum arrangement, even softly layered underneath. Full candidates are **72 seconds**, arranged as three related24-second passages, not three byte-identical copies. Same harmonic anchors and tiny original A4–C5–D5 fragment in both garden and deck. No foreground MIDI melody.

## Garden72-second arrangement

Keep the first24-second passage's main event schedule and relative levels. Use source-specific variation for foley: playback speed within±8%, minor level variation, no new continuous bed. For the actual pitched motif, however, **use exact A4/C5/D5 playback pitch (speed1), with at most±5 cents intentional detune**. The current report shows roughly−.50/+0.04/+.50 semitone variation on these notes; that degree of randomization belongs to squeaks/plops, not the little shared melody. This is a source/report correction, not a listening claim.

| Passage | Foreground event times within its24seconds | Quiet harmonic/melodic background |
|---|---|---|
| 0–24 | Preserve existing schedule: knock1.8, plop3.1, rattle5.5, squeak7.2 + tinygrain7.35, roundedF2 9.3, plop14.4, shortsqueak16.7, knock20.4 + tick20.53, plop22.6. | F/C airy dyad only if already present in actual audition; do not add a new louder pad. A4–C5–D5 at11.6/11.9/12.3, same soft hierarchy. |
| 24–48 | Relative times: plop2.3, lowknock4.7, shortsqueak8.2, rattle11.4, plop15.8, knock19.6, smallplop22.1. Omit the extra grain and secondary tick in this quieter passage. | Brief veryquiet D3/A3 dyad at0–6 and18–21; one soft D2 pluck at10.1. Same A4–C5–D5 motif at12.8/13.1/13.5. No chord-tone arpeggio. |
| 48–72 | Relative times: knock1.9, plop4.1, squeak7.6 + tinygrain7.75, plop12.9, soft rattle16.4, knock20.0, tinyplop22.4. Alternate source bubble variant and pan, not event density. | Brief Bb2/F3 dyad at0–5, C3/G3 at14–19; one quiet C3 bass pluck at9.4. Same motif at10.8/11.1/11.5. Let the last texture decay into the loop. |

Foley is the audible character. Background dyads must remain below the shadow motif, without bright attacks or a constant wide hiss. At most two foreground transients overlap; no more than about12% foreground sample occupancy for the full loop. Do not count long low-level reverb as an excuse to add more foreground events. Keep gaps and small surprises. Avoid additional birds, chatter or running-water beds that compete with existing world ambience.

## Pocket Deck72-second arrangement

Same event schedule, duration, harmonic anchors and **exact same tiny motif**. Make the device sound like a small toy handling this material, not a conventional chiptune track.

- Reuse the licensed squeak/plop fragments, shortened at their natural tails by15–25%, filtered to about4kHz and with modest12–14-bit/18–22kHz resampling colour. Preserve recognizable noisy attacks; avoid crunchy aliasing, hard clipping or continuous noise.
- Hollow taps become drier, shorter synthetic/contact ticks from the existing bank, at the same relative levels. No added metronomic kick/snare/hat pattern. Keep only the three isolated bass gestures, shortened to120–180ms and quieter than foley.
- The A4–C5–D5 fragment uses a subdued triangle plus a very small band-limited pulse component, rounded attack/release; its peak remains at least12dB below the principal sample peaks. No octave doubling, vibrato lead or new countermelody. Pitch stable as above.
- Room send4–6%, decay200–300ms; narrow stereo±5% versus garden's existing modest spread. The difference comes from articulation and box-like timbre, not louder level or more notes.

## Level, loop and handoff

Retain the audition's event-level hierarchy as the starting gain; do not normalize the sparse72seconds up to a conventional music LUFS target. Also do not automatically attenuate another large amount merely because the measured integrated level is low. Report actual loudness and true peak; compare matched excerpts at equal intended playback gain. Peak below−3dBTP; no clipped samples or DC jump.

Render tails in a cyclic buffer at72seconds. Last4+first4 twice should contain a natural quiet continuation, not a fade-to-silence restart or new double-attack. Preserve identical72-second length and transport alignment for both versions. Existing owner handles garden/deck transition and mute/duck; these local candidates do not authorize new runtime audio ownership or change the approved hatch SFX.

Write only new candidate artifacts under `audio/revision-3-full/`: `garden-texture-72s.wav`, `pocket-deck-texture-72s.wav`, matched24-second excerpts, mono versions,16-second seam auditions, compact manifest/report with CC0 source hashes and exact event schedule. Preserve audition and rejected104 files. Show the two playable excerpts and make full loops accessible. Independent technical review plus actual candidate presentation/review follows; adjust from any incoming user feedback. **No music asset upload or runtime mapping yet.**
