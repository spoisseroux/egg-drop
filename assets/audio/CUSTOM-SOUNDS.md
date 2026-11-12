# Making custom sounds for Egg Drop

You can make all of these yourself. Make them original: recorded, synthesised, or built from samples you have the rights to.

## Where to put them
Drop finished files in `assets/audio/custom/`, named `egg_drop_<cue>.wav`, for example `egg_drop_bear_boop_1.wav`. Claude uploads them through Open Cloud (this folder is approved), wires the asset IDs into `src/client/BoardAudio.lua`, and checks that each one loads in Studio.

## Export settings
- **Format:** WAV, 16-bit, 44.1 kHz or 48 kHz. OGG also works. Roblox re-encodes on upload, so WAV is the safest source.
- **Channels:** mono for sound effects. Stereo only for music or ambience loops.
- **Loudness:** normalise peaks to about -1 dBFS. Trim the silence at the start, so a sound plays the instant it's triggered, and give the end a short fade of 5-20 ms so it doesn't click.
- **Roblox limits:** under 20 MB, under 7 minutes, sample rate 48 kHz or lower. Uploads count against a monthly quota: 100 audio uploads per 30 days if you're not ID verified, 2,000 if you are.

## Lengths
- UI ticks, plips and boops: 0.05-0.3 s
- Pops, squeaks and chimes: 0.2-0.8 s
- Win and lose jingles: 0.8-1.5 s
- Ambience loops: 20-60 s, seamless (the end must flow into the start)

## What to make
| File (cue) | What it is | Notes |
|---|---|---|
| `bear_boop_1/2/3` | Plush squeak when you tap the Bear | 3 small pitch or shape variants |
| `bear_chirp` | Happy little rising "mew-hm" hum | When it's pleased or cheering |
| `bear_yawn` | Breathy, soft, descending hum | Idle yawn and sleepy moments |
| `clear_v` | Sparkly glass chime with a soft downward whoosh | Top-tier egg clear |
| `win` | 4-note bright chiptune jingle | About 1.2 s |
| `lose` | Soft descending "wah-wah", friendly, not mean | About 1 s |
| `toy_squeak` | Rubber squeak | When a pet bites the ball or bone |
| `deny` | Dull soft buzz | A button you can't use yet |
| `purchase` | Coin-purse "cha-ching" | Buying an egg |
| `ambience_day` | Gentle birds and breeze loop | Stereo |
| `ambience_night` | Soft crickets loop | Stereo |

These already exist and can be replaced if you want them in the same style: `aim`, `drop`, `land`, `bank`, `merge_bubble`, `merge_jelly`, `merge_chain`, `charge`, `overflow`, `retry`, `menu`, `hatch`, `hatch_rise`, `pet`, and the music/purr loops. Their current sources are the `egg_drop_*.wav` files in `assets/audio/`.

Style: soft, round, toy-like and chiptune-adjacent, like the PICO-8 palette. Keep everything gentle. Kids hear these sounds hundreds of times.
