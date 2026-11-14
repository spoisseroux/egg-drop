# Sparse garden and Pocket Deck candidates

Two aligned **72-second local candidates**, three varied 24-second passages each. No music upload or runtime mapping. Optional feedback on the earlier audition has not arrived; silence is not treated as approval. This reversible continuation follows Astra's `MUSIC-V3-FULL-CANDIDATES.md`.

| Version | Matched first 24 seconds | Full loop | Mono | Last 4 + first 4 twice |
|---|---|---|---|---|
| Garden | [Play excerpt](garden-matched-excerpt-24s.mp3) | [72s WAV](garden-texture-72s.wav) | [Mono](garden-texture-72s-mono.wav) | [16s seam](garden-seam-16s.mp3) |
| Pocket Deck | [Play excerpt](pocket-deck-matched-excerpt-24s.mp3) | [72s WAV](pocket-deck-texture-72s.wav) | [Mono](pocket-deck-texture-72s-mono.wav) | [16s seam](pocket-deck-seam-16s.mp3) |

| Measurement | Garden | Pocket Deck |
|---|---:|---:|
| Integrated loudness | −38.06 LUFS | −38.64 LUFS |
| True peak | −15.53 dBTP | −15.82 dBTP |
| Foreground occupancy | 8.646% | 6.737% |
| Maximum foreground layers | 2 | 2 |
| Motif below principal sample peak | 18.97 dB | 18.39 dB |
| Mono versus stereo per-channel RMS | −0.009 dB | −0.002 dB |
| PCM boundary jump | 0 | 0 |

No final gain normalization or additional overall attenuation was applied. The three-note A4–C5–D5 motif now plays at speed 1 with stable pitch, rather than the audition's foley-style randomization. Positive-crossing measurements of all six emitted motif samples are within 0.03 cents of the declared notes. Foley playback varies within ±3.5%; each new passage follows the brief's sparse event list. Brief background dyads sit below the motif; no continuous noise, drum or bass pattern was added.

The deck uses the same source palette, note frequencies and event times. Its recorded fragments retain 80% of their original edited duration, lowpass at 4 kHz, then 20 kHz/13-bit colour; bass gestures last 160 ms. Its narrow pan and 5%/250 ms room are quieter and drier than the garden's 14%/550 ms room. The motif uses a small finite-harmonic triangle/pulse voice without a new lead line. Both renders accumulate room tails cyclically; the 16-second seam files are provided for actual listening, not a claim that meters prove an inaudible seam.

Recorded foley remains **bart's CC0 rubber-toy sounds** and **BMacZero's CC0 bubble effects**, with archived primary pages and exact source hashes in `assets/audio/sample-sources/opengameart-2026-11-14/provenance.json`. [Squeak source](https://opengameart.org/content/squeak-toy-sounds), [bubble source](https://opengameart.org/content/bubble-sound-effects), [CC0](https://creativecommons.org/publicdomain/zero/1.0/). The generator verifies the original source and audition bytes before/after; it sequences the emitted per-version WAV banks. The full report records every source, sample recipe, event, gain, pitch, pan, duration, room parameter, output hash and meter result.

Technical source review and actual listening remain distinct. No subjective listening, speech-free certification or user approval is claimed. Prior audition, rejected masters and uploaded assets are preserved. Run `python scripts/qa20261114_music_sparse.py --full` to reproduce only this new directory.
