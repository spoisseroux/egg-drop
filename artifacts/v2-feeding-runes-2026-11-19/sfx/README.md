# Feeding sounds for Stat Snacks (proposal, 2026-11-19)

**Not approved, not uploaded, not wired. Nobody has listened to these yet:** they were made and measured by script (Fable), so the first step is Spencer's ears. Design notes: `V2-FEEDING-RUNES-ONBOARDING-2026-11-19.md`, section 3.

## Listen first

| File | What |
|---|---|
| `sequence-nibble.mp3` | Sniff, 2 bites, gulp, squeak, sparkle |
| `sequence-snack.mp3` | Sniff, 3 bites, gulp, coo, sparkle |
| `sequence-feast.mp3` | Sniff, the Feast crunch, 3 bites, gulp, coo, squeak, sparkle |
| `sequence-feast-favourite.mp3` | The Feast, then the favourite-stat extra: a second squeak, coo and sparkle |

These four are offline mixes on the doc's timeline, at the suggested gains. They are not Studio recordings. The 0.6 s the snack takes to reach the mouth is trimmed.

## The single sounds (each as `.wav` master and `.mp3`)

| File | What | Length | Suggested gain |
|---|---|---:|---:|
| `sniff` | Two quick little inhales, the second higher. Plays on the offer, on your own client only. | 0.40 s | 0.45 |
| `nom_a`, `nom_b`, `nom_c` | One soft "nom" each: a small voiced syllable that closes to "m", a biscuit snap and a few crumb ticks. Three pitches and lengths so bites never repeat back to back. | 0.23 to 0.26 s | 0.70 |
| `crunch_feast` | The Feast's first bite: a low thump, two cracks, a dense crackle of crumbs, then a short nom. | 0.50 s | 0.85 |
| `gulp` | A small swallow, down then up. Kept above 300 Hz so a phone speaker plays it. | 0.16 s | 0.50 |
| `happy_squeak` | A short rising squeak. Nibble's reaction, and the Feast's spin. | 0.22 s | 0.60 |
| `happy_coo` | A two-part "oo-ooh" with a little vibrato. Snack's and Feast's reaction. | 0.52 s | 0.65 |
| `boost_sparkle` | Three rising bell notes (E, G, C) and glitter, in the rarity chimes' key but smaller. Plays with the rune burst. | 1.00 s | 0.70 |
| `refuse_hm` | A questioning "hm?" for when the server says no and the snack goes back. | 0.26 s | 0.55 |

`report.json` has length, peak, loudness and brightness for each, and the timeline used for the mixes.

## How they were made

`python scripts/synth_feeding_sfx.py`: sine partials and shaped white noise in numpy, using the helpers in `scripts/synth_hatch_rarity.py`. Fixed seeds, the same bytes on every run (checked by running it twice). No samples, no recordings, no AI audio. 44.1 kHz, mono, 16-bit.

## Not done

- Not heard on a phone speaker or in the game. The "nom" voice is the riskiest: if it sounds like a person and not a pet, raise its pitch or lean on the snap and crumbs.
- No masters were written to `assets/audio/custom/`. Do that after approval, then upload and map them in `BoardAudio`.
- The Kitten's purr and lick are not here.
