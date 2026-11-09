# Local listening drafts

The original JSON scores and SCORE-NOTES.md are Astra's compositions. The adjacent WAVs and MP3s were synthesized from their exact events by `scripts/synth_overnight_aero.py`. These files have not been uploaded or connected to gameplay. Pocket Apricot remains the default.

- **Creek With One Shoe:** `creek-with-one-shoe.mp3`; the `.two-laps.mp3` copy crosses the join at **62.608685 seconds**. Listen for the open bars 9–12, the glass replies in bars 10 and 14, and the final E carrying across the return to D. Bar 10 begins at 23.478261 seconds; bar 14 begins at 33.913043 seconds. The written glass answers start 1.58 beats into those bars.
- **Pocket Skip:** `pocket-skip.mp3`; `.two-laps.mp3` crosses the join at **48 seconds**. Listen for the middle-eight register exchange and final D-sharp pickup at **47.86 seconds**, followed by the low E on the second lap.
- **Level reference:** `pocket-apricot.reference-level-matched.mp3` is a derived copy of the unchanged existing WAV, adjusted with constant gain to the same −18 LUFS target. Comparing equal slider levels against the untouched default would bias the review.

The single-lap **PCM WAVs** define the exact loop periods: 2,761,043 and 2,116,800 stereo frames at 44,100 Hz. All note releases and room taps wrap over the period. The `.two-laps.wav` copies concatenate the delivered PCM bytes twice without requantization. MP3s are listening copies; decoder padding is not a loop guarantee.

`render-manifest.json` records the score and output hashes, exact frames, gain, stereo/mono loudness and true peak, sample peak, seam samples/slopes, nearby sample steps and preservation hashes for the current default. The adjacent `.render-events.json` files record every event and its exact start frame. FFmpeg's loudnorm **input** values measure the delivered WAV; its processed output is discarded. Masters use a single constant gain with no compression or limiting.

Mono loudness is measured as `(L+R)/2` in one output channel, so it is naturally about 3 LU below two correlated stereo channels. The mono RMS ratio measures actual cancellation separately. A small nonzero last-to-first step is expected for a continuous waveform; compare it with the incoming/outgoing slopes and local steps rather than forcing endpoints to equality.

These are technical checks, not an audible approval. Astra/root still need to hear timbre, call/answer balance, repeated-lap phrasing and phone-speaker translation. Gameplay cue overlays were not rendered; check the accepted aim/drop/merge/hatch cues alongside the pieces before adopting either draft. No claim is made about Roblox transcoding or in-game loudness.

Reproduce with `python scripts/synth_overnight_aero.py` (NumPy and FFmpeg required). It writes only local listening outputs and verifies preservation of the existing default assets.
