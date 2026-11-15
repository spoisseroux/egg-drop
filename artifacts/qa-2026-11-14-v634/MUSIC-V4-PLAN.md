# Music v4 audition implementation plan

Sol implementation, following Astra's `MUSIC-V4-BRIEF.md`. Architect review requested before code. One garden audition; no Deck variant yet. Preserve every v3/source/runtime/upload byte. Root owns checklist and integration.

## Files and result

- New `scripts/qa20261114_music_melodic.py`; no changes to the v3 generator.
- New `audio/revision-4-melodic/` only: 26.666667-second stereo WAV/MP3, mono, 8-second seam, diagnostic strip, emitted note bank, README and JSON report.
- Exact 72 BPM, eight bars, 27 original notes/gates from the brief; 48 kHz and 1,280,000 frames. Main voice enters at beat0.5. No ornaments in this first draft: focus on the connected tune.

## Recording-derived instrument

1. Verify archived primary-page/license/source hashes. Read interior rubber body and bubble-tail regions only; record exact sample ranges. Remove DC, highpass130Hz and discard identifiable initial attacks.
2. Deterministic60ms Hann grains at75% overlap; nearby crop variation, some quieter reversed grains. Level-match the two source regions explicitly, then blend75% rubber/25% bubble. Report source gains and actual component RMS rather than describing this as self-recorded foley.
3. Drive tuned resonant filters from that texture: clear fundamental plus three quieter harmonic bands, with the original sweeping formant suppressed. FFT convolution is practical without installing scipy. No independent melody oscillator or sine support. Zero source excitation must produce exact zero voice; different source excitation must change the rendered voice.
4. Round with45ms attack, gentle sustain sag and140ms release. Lowpass near3.2kHz and locally reduce piercing upper modes. Calibrate the emitted note bank to principal peaks near−16dBFS before musical velocity, with every calibration gain reported. Use measured spectral pitch correction through resampling if needed; verify pitch again from the final emitted WAV, not just its declared frequency.
5. Sequence the actual emitted note files. Exact hook timing, stable pitch, only quiet musical velocity variation and slow±6% pan. No raw squeak/plop/rattle hits or hidden synthesized lead.

Harmony follows the exact five dyad windows/changes in the brief, with smooth swells and200ms overlap. Calibrate its actual active-phrase RMS to14dB below melody, report the achieved ratio. Shared14ms-predelay/.8s room at12% send; dry melody stays phase-coherent and centered. Render every room tap into a cyclic buffer, preserving the final F4 tail into the pickup. No final loudness normalization.

## Edge cases and checks

| Case | Required behavior |
|---|---|
| Bad/missing source or license hash | Fail before rendering; never substitute a synthetic lead |
| Zero excitation / source replacement | Zero yields silence; changed source changes note hash |
| Pitch instability or weak fundamental | Fail/report measured estimate; correct source-derived voice, not a hidden sine |
| Meter peak/clipping | No clipped/nonfinite samples; independent ffmpeg true peak below−3dBTP |
| Loop/mono | Exact cyclic seam PCM assembly; report discontinuity and mono energy, no inaudibility claim |
| Preservation | Hash all v3/source inputs before/after; generator writes only new output tree |

Checks: exact note/gate/beat ledger and frames; deterministic rerender hashes; actual note-bank spectral fundamental estimates plus independent autocorrelation sanity check; source-ablation test; achieved harmony RMS and melodic gate/release occupancy; stereo/mono loudness/true peak; output/provenance hashes. Diagnostic strip: labeled raw fragment → transformed A4 → complete first two-bar phrase. Its boundaries are separate from finished music.

The exact gates total21beats (65.625%) before release. Report that mask separately from full note/release support (about80%); do not shorten the supplied melody or hide release energy to claim the heuristic two-thirds target. This numerical conflict has been sent to Astra for clarification; independent DSP work can proceed after architect review.

Backlog independently reviews source/output correctness. Astra reviews actual report/artifact compliance while disclosing inability to hear. Present one inline player with the brief's exact label and local-draft/current-v3 sentence. Listening feedback, rather than LUFS or a waveform, determines softness and melodic success. No upload or runtime mapping.

## Completed local audition

Architect GO was received before code. Implementation and artifact review: Backlog technical CODE/PCM GO (`MUSIC-V4-CODE-REVIEW.md`) and Astra creative-compliance GO (`MUSIC-V4-CREATIVE-REVIEW.md`), with no hearing or subjective approval claimed. Exact27 notes/1,280,000frames; main−24.05LUFS/−14.70dBTP; harmony−14dB on the same gate mask. Gate65.625% and full release79.8% accepted as separate metrics. All8primary outputs and27emitted notes repeat byte-identically;86source/v3 files remain unchanged. Independent mix reconstruction matched the final main PCM exactly.

Actual room onset is37ms left/38.3ms right; the nominal14ms offset is already included in the reflection delays, with no separate14ms tap. This report clarification changed no audio bytes. The audition, mono, seam and diagnostic are in `audio/revision-4-melodic/`; the current build still uses v3. No Deck, upload, runtime mapping or publish in this slice.
