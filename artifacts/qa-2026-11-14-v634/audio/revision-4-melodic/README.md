# Garden v4 audition

**More melody, softer transformed toy sounds — 27 seconds.** Actual duration26.666667s: eight bars at72BPM,27 notes,1,280,000 stereo frames at48kHz. This is a local listening draft; the current build still uses v3.

[Play MP3](garden-melodic-audition-27s.mp3) · [Stereo WAV](garden-melodic-audition-27s.wav) · [Mono](garden-melodic-audition-27s-mono.wav) · [8s seam](garden-melodic-seam-8s.mp3) · [Source-transformation diagnostic](source-transformation-diagnostic.mp3)

The new voice comes from actual CC0 rubber-toy and bubble recordings, transformed into one tuned instrument. It uses interior regions,130Hz highpass,60ms Hann grains at75% overlap, a75/25 rubber/bubble blend, quieter reversed grains, source-excited resonant modes and final3.2kHz lowpass. A calibrated A4 source instrument is resampled into the exact score, with45ms attacks and140ms releases. There is no independent synthesized melody oscillator, raw rattle/squeak punctuation, drum pattern or Deck treatment.

Every note is emitted as a WAV and read back for sequencing and pitch checks. The report records exact source regions/gains, calibration and pitch-correction gains, frequencies, onsets, gates, pan and measured pitch. Source ablation produces exact silence; replacing the excitation changes the voice. These prove the source-driven processing path, not a subjective claim that the timbre sounds soft. Full-gate spectral estimates stay within1.97cents; the independent review's shorter windows measured up to6.22cents. Neither is a claim about exact instantaneous pitch at every sample.

| Check | Actual result |
|---|---:|
| Integrated loudness | −24.05LUFS |
| True peak | −14.70dBTP |
| Spectral pitch error, maximum | 1.97cents |
| Melody gates | 65.625% |
| Gates plus full140ms releases | 79.8% |
| Decorative foley | None |
| Harmony RMS under melody | −14.00dB, same exact gate mask |
| Final mix gain | 1; no loudness normalization |

The exact supplied gates already occupy65.625% before release. Full release support is reported separately, rather than shortening the score or pretending it is under two thirds. The fuller arrangement naturally meters louder than sparse v3; it was not forced back to−38LUFS. Harmony uses the five specified dyad windows, and the small12% room wraps its tails cyclically. Its first actual wet reflection is37ms (38.3ms right): the nominal14ms offset is already included in the37/55/81ms tap delays, with no separate14ms tap. This is an explicit deviation from treating14ms as the wet onset; the audio is unchanged. The seam file is assembled from the final authoritative PCM: last2s+first2s, twice. Numbers cannot establish an inaudible seam or listening approval.

Source authors remain **bart** ([rubber toy](https://opengameart.org/content/squeak-toy-sounds)) and **BMacZero** ([bubbles](https://opengameart.org/content/bubble-sound-effects)), licensed [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Their source pages, license evidence and file hashes remain in the unchanged source provenance. All source/v3 files are hash-checked before/after. Original composition and processing are new; the recordings are not described as ours.

The diagnostic is separate from the finished audition: one raw rubber-body region, one transformed A4, then the first complete two-bar phrase, with quiet gaps. Segment offsets are in `audition-report.json`. Independent technical and creative-compliance reviews are requested. No one is claimed to have heard or approved this audition. No upload, runtime mapping or publish.

Reproduce with `python scripts/qa20261114_music_melodic.py`. New output files remain confined to this directory; all prior masters are preserved.
