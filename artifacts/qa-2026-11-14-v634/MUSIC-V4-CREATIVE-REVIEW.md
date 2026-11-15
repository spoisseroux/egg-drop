# Garden v4 — creative compliance review

**GO for the local listening audition. No required creative-compliance changes.** This verdict covers the actual generated sketch against `MUSIC-V4-BRIEF.md`; it does not authorize a full loop, Deck version, upload, runtime mapping or experience publish. The current working build remains on v3.

**I have not heard the audio.** My tools do not let me actually listen to these files. I inspected `scripts/qa20261114_music_melodic.py`, the emitted `audio/revision-4-melodic/audition-report.json`, its README and the actual available WAV/MP3 files. Softness, memorability, pleasantness, repetition and audible seam remain listening questions for Spencer; no subjective approval is claimed.

| Brief intention | Actual artifact/source evidence | Compliance |
|---|---|---|
| A connected melody instead of scattered three-note hints | Exact 27-note, eight-bar score at 72 BPM; bars 5–6 repeat the opening hook, with the softer first note. Five prescribed dyad windows. Actual duration 26.666667 s, 1,280,000 stereo frames at 48 kHz. | GO |
| Transform the real recordings into an instrument | Archived rubber and bubble source regions enter 60 ms Hann grains at 75% overlap, 75/25 blend and quieter reversed grains, then source-excited resonant modes. The actual source-derived A4 instrument is resampled for each pitch. Zero excitation produces silence and source replacement changes the voice; no independent melody oscillator enters the mix. | GO for the documented transformation, not a claim about what it sounds like |
| Rounded timbre and musical pitch | 45 ms attack, 140 ms release, 3.2 kHz lowpass. Emitted note WAVs are read back for sequencing and pitch analysis; maximum reported spectral pitch error is 1.963 cents. | GO for the implemented controls; listening must establish softness |
| Fuller without a thick foreground arrangement | One melodic voice; dyad RMS is 14 dB below melody over the same gate mask. No decorative foley, drum pattern, bass pattern or countermelody. Gate occupancy 65.625%, complete release support 79.8%. | GO with the numerical clarification below |
| Preserve headroom and small-room space | Main WAV −24.05 LUFS / −14.70 dBTP, final mix gain 1, no final loudness normalization. Room send 12%, 0.8 s tail, cyclic accumulation. | GO; naturally much louder in average energy than sparse v3, without a peak/loudness target boost |
| Deliver a real audition and inspectable diagnostics | Stereo and mono WAV/MP3, 8 s seam, raw fragment → transformed A4 → two-bar phrase diagnostic, source/output hashes and detailed note ledger are present. Coordinator independently checked all output hashes and main file format. | GO |
| Preserve the current build and sources | Generator confines outputs to the new revision folder, checks source/v3 hashes before and after, and reports uploaded=false/runtime_mapped=false. Coordinator confirms no mapping or upload. | GO |

The brief's rough “half to two thirds including release” estimate was inconsistent with its exact gates, which already sum to 65.625%. **I accept the exact score and the truthful 79.8% release-support measurement.** The brief now records this clarification. Do not remove notes or shorten gates to satisfy the earlier estimate.

The reported mono per-channel energy change is about −0.00931 dB; the loop boundary changes by two PCM least-significant bits. These are useful technical observations, not proof that mono sounds identical or that the seam is inaudible. The source-driven resonator design is real processing of the recordings; this review does not assert that a listener will perceive enough of their rubber/bubble character.

The coordinator has already shown the clearly labeled local audition player and stated that v3 remains current. Keep that single focused presentation. Use the diagnostic only if the user wants to hear how the sound was transformed; it is not a second song candidate. Await normal listening feedback before another musical expansion. No further creative work is required for this audition slice.
