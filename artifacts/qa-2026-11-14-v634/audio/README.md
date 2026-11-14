# Little Afternoon — original local audition pair

Astra's new original F-major score, synthesized by Sol. 96 BPM, 4/4, the explicit 16-bar melody/harmony repeated into **32 bars / 80 seconds**. No external recordings, samples or music service. Existing music/IDs are unchanged; these are local audition files, not installed tracks.

| Arrangement | Full loop | Matched excerpt | Measured full-loop level |
|---|---|---|---|
| Garden: soft wooden mallet, flute answer, sparse nylon/harp, rounded bass and brushes | `little-afternoon-garden-80s.wav` | `little-afternoon-garden-20s.wav` | -20.00 LUFS, -8.61 dBTP |
| Pocket Deck: band-limited pulse/triangle rendition of the same tune, short bass and restrained noise percussion | `little-afternoon-pocket-deck-80s.wav` | `little-afternoon-pocket-deck-20s.wav` | -19.00 LUFS, -7.00 dBTP |

All WAVs are48kHz16-bit PCM; loops/excerpts stereo. Twenty-second previews measure **-20.00 / -20.01 LUFS**, within0.01dB for a fair comparison. Full-loop loudness uses gain only, no limiter/compression. `music-report.json` includes actual sample/true peak, RMS, DC, mono fold energy, zero clipping, boundary derivative checks and every note/rest event. Bar32 retains its final2-beat rest. Melody/bass centered; garden accompaniment pan<=20%, timing variation<=8ms.

Seam auditions: `little-afternoon-<arrangement>-seam-last4-first4-twice.wav`, **16 seconds** each: last4s + first4s, twice. Authoritative loop uses cyclic note/reverb tails; audition PCM rather than judging AAC/MP4 encoder padding. `little-afternoon-<arrangement>-mono-20s.wav` uses **(L+R)/2**, with no renormalization hiding cancellation. Full-loop mono RMS difference is garden-0.0048dB, deck-0.0004dB.

Generated and checked with `scripts/qa20261114_music.py`, NumPy/stdlib and FFmpeg loudnorm measurement. Listening/creative mix approval remains Astra/Spencer's audition; numeric checks establish file integrity and mix levels, not musical taste.

Integration handoff after approval only: existing music/mute owner stays authoritative; duck active music6dB during reveal and release over600ms; crossfade garden↔deck over180–300ms equal-power, preserve bar phase if a shared transport exists. Never play both full-volume tracks together. No new runtime glue or uploaded asset id was introduced by this packet.
