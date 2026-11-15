# Rarity sound lines: loudness check (QA v685 H3)

Spencer heard Common and Rare as the same sound. The old accent was one 80 ms tick at about -34 dBFS under a hatch body that peaks near -14 LUFS, so it was masked. This check asks the question the last pass skipped: **is each note louder than the hatch body at the moment it plays, and are the tiers different in every beat where they are meant to differ?**

## Listen first

- `common-then-uncommon-then-rare.mp3` (also `.wav`): the three lines in a row, 0.7 s apart.
- `common-then-rare.mp3`: the pair Spencer compared before.
- `item-hatch-common`, `item-hatch-uncommon`, `item-hatch-rare`: one each.

These are offline mixes of the source WAVs in `assets/audio`, scheduled exactly as `HatchRarityCue.events` schedules them over the unchanged 3.1 s Material hatch body. **They are not recordings of Studio.** Roblox's resampler, the SFX group volume and the device will differ a little. No sound is generated or uploaded; nothing here is AI-made.

## What each tier plays

| Beat | Common (and untiered) | Uncommon | Rare |
|---|---|---|---|
| Build-up, 0.1 to 0.95 s | one soft wobble | two rising notes (+0, +4 semitones) | four rising notes over an octave (+0, +4, +7, +12), then a whoosh |
| Burst, 0.98 s | a short crack | a shimmer (1.5 s) | a higher (+3 st), louder shimmer and a fanfare |
| Name slam, 1.65 s | slam | slam, a touch higher | slam, a touch lower |
| Flourish, 2.10 s | nothing | a chime (0.8 s) | a long rising total (1.0 s, +2 st) |
| Notes in all | 3 | 5 | 9 |

All nine cues are sounds already uploaded for the game (`star_land`, `reveal_shimmer`, `new_best`, `stars_total`, `quest_complete`, `egg_wobble`, `egg_crack_glint`, `name_slam`, `streak_whoosh`). In the Studio client every one of them is loaded and its length matches the local WAV to 0.01 s, so the model uses the same audio the game plays.

## Each note against the hatch body

K-weighted loudness (ITU-R BS.1770 pre-filter) of the note in its first 250 ms, against the body in the same window. Positive means the note is louder than the body under it.

| Tier | Time | Cue | Pitch | Gain | Note | Body | Note over body |
|---|---|---|---|---|---|---|---|
| Common | 0.34 | egg_wobble | 0 | 0.40 | -26.1 | -28.6 | +2.5 LU |
| Common | 0.98 | egg_crack_glint | 0 | 0.50 | -21.6 | -25.8 | +4.2 LU |
| Common | 1.65 | name_slam | 0 | 0.90 | -19.3 | -14.4 | **-4.9 LU** |
| Uncommon | 0.30 | star_land | 0 | 0.40 | -25.0 | -28.8 | +3.8 LU |
| Uncommon | 0.62 | star_land | +4 | 0.46 | -24.7 | -30.7 | +6.0 LU |
| Uncommon | 0.98 | reveal_shimmer | 0 | 0.55 | -17.1 | -25.8 | +8.7 LU |
| Uncommon | 1.65 | name_slam | +1 | 0.90 | -19.4 | -14.4 | **-5.0 LU** |
| Uncommon | 2.10 | quest_complete | 0 | 0.85 | -20.2 | -22.3 | +2.1 LU |
| Rare | 0.16 | star_land | 0 | 0.36 | -25.9 | -29.7 | +3.8 LU |
| Rare | 0.36 | star_land | +4 | 0.40 | -25.9 | -28.6 | +2.7 LU |
| Rare | 0.56 | star_land | +7 | 0.46 | -25.4 | -31.6 | +6.2 LU |
| Rare | 0.76 | star_land | +12 | 0.52 | -24.7 | -29.7 | +5.0 LU |
| Rare | 0.86 | streak_whoosh | 0 | 0.55 | -21.1 | -31.3 | +10.2 LU |
| Rare | 0.98 | reveal_shimmer | +3 | 0.80 | -13.3 | -25.8 | +12.5 LU |
| Rare | 1.04 | new_best | 0 | 0.70 | -16.4 | -23.8 | +7.4 LU |
| Rare | 1.65 | name_slam | -1 | 1.00 | -18.3 | -14.4 | **-3.9 LU** |
| Rare | 2.10 | stars_total | +2 | 0.80 | -15.1 | -22.3 | +7.2 LU |

**The name slam is the one masked note** (4 to 5 LU under the body, in every tier). The hatch body has its own loud hit from 1.5 to 2.0 s, exactly on the slam, so the body is the slam sound for all three tiers and the pitch change on `name_slam` will not be heard. I did not push the slam above the body: that needs a gain over 1.6 and risks clipping. Instead each tier's answer was moved off the peak: the first draft put the Uncommon chime and the Rare total at 1.73 to 1.75 s, where the chime measured 8.2 LU under the body and the total only level with it. They now play at 2.10 s, after the body falls away.

## Tier against tier, beat by beat

Loudness of the whole mix in each beat, and the difference between tiers.

| Beat | Common | Uncommon | Rare | Uncommon over Common | Rare over Common |
|---|---|---|---|---|---|
| Build-up 0.10 to 0.95 | -27.3 | -25.3 | -23.6 | +2.0 LU | +3.7 LU |
| Burst 0.95 to 1.60 | -18.6 | -16.1 | -12.7 | +2.5 LU | +5.9 LU |
| Slam 1.60 to 2.10 | -14.7 | -14.4 | -14.3 | +0.3 LU | +0.4 LU |
| Flourish 2.10 to 3.10 | -28.2 | -18.6 | -18.2 | +9.6 LU | +10.0 LU |

Reading it: the tiers differ by ear in three of the four beats. The slam beat is the same for everyone (see above). Uncommon and Rare are close in loudness in the flourish (0.4 LU apart), but they are different sounds there (a 0.8 s chime against a 1.0 s rising total, spectral centre about 2.8 kHz against 6.7 kHz), and Rare is 3.4 LU louder than Uncommon at the burst.

Mix peaks stay under full scale: Common -0.84 dBFS, Uncommon -1.47, Rare -0.53 (the offline sum; Roblox adds its own headroom).

## What this does not prove

- It is a model. **Nobody has listened to it in the game yet**, and the last two passes showed that numbers alone do not settle this. Spencer's ear on a phone is the acceptance test.
- Only the Material body was measured. The Toy, Hue and Feature bodies have the same shape (quiet until 1.0 s, a peak near -15 dBFS RMS from 1.5 to 2.0 s), so the result should carry over, but they were not run, and they differ from the Material body by up to 4 dB between 1.25 and 1.5 s.
- In the live game today only Material eggs have tiers that differ (Gloss and Matte are Common, Jelly is Rare). Toys and Hue jars have no authored tier, so they play the Common line; Feature eggs (Common, Uncommon, Rare) are behind a flag that is off. **Uncommon cannot be heard in the game yet.**

Numbers: `loudness-report.json`. Generator: `mix_rarity_audition.py` (run from the repository root).
