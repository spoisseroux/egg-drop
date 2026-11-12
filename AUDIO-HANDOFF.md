# Audio handoff: Egg Drop

This is everything an audio engineer needs to make the sound set for Egg Drop. Written 2026-11-12. Questions go to Spencer.

## The game in one paragraph
Egg Drop is a cozy Roblox game for all ages. Players hold a little handheld console, the **Pocket Deck**, and play a physics merge game on it: drop eggs, matching eggs merge into a bigger tier, the board must not overflow, and finishing a round earns **Stars**. Players spend Stars on eggs that customise their pet. The pet is a plush stuffed-animal baby, currently a teddy **Bear**, that lives with them in a bright floating sky-island garden with marble ruins. Players pet it, play with toys and dress it up. The visual style is retro low-poly (late-90s console) with a PICO-8-style palette.

## Sound direction
- **Mood:** soft, round, toy-like and cheerful. Think handheld-console chiptune meets plush toy.
- **Gentle on repeat.** Players hear some of these sounds hundreds of times per session. Avoid harsh transients, piercing highs and heavy sub-bass, since many players are on phone speakers. Nothing scary or mean, even on a loss.
- **Two layers of sound:**
  - **Device sounds:** UI, board, merges. These are crisp, chippy and "inside the handheld".
  - **World sounds:** pet, toys, garden, ambience. These are warm, organic and squishy.
- **Pets:** every pet shares one voice set for now. Each pet will get its own set later.
- **Must be original:** no samples from other games, no copyrighted music, no Sega/Nintendo-style imitations. Use your own recordings or synthesis, or libraries you have the rights to use commercially.

## Technical specs
| Item | Requirement |
|---|---|
| Format | WAV, 16-bit, 44.1 kHz or 48 kHz. OGG or FLAC also accepted. Roblox re-encodes on upload. |
| Channels | Mono for every one-shot sound effect. Stereo only for music and ambience loops. |
| Loudness | One-shot peaks at about -1 dBFS, roughly matched in perceived loudness. Loops quieter: the current music loop peaks at -6 dBFS with an RMS around -24 dBFS. |
| Heads and tails | No silence at the start, so it triggers instantly. Add a 5-20 ms fade-out so nothing clicks. |
| Loops | Sample-accurate seamless loop points: the end must flow into the start with no click or level jump. |
| Roblox limits | Under 20 MB, under 7 minutes, 48 kHz or lower, single track. Uploads have a monthly quota (100 per 30 days without ID verification), so please deliver final takes, not lots of alternates. |
| Pitch | The game repitches some sounds at runtime (see "Runtime behaviour"). Deliver those at a neutral base pitch. |

## Naming and delivery
- Name every file `egg_drop_<cue>.wav` using the cue names in the tables below. For variants, add `_1`, `_2`, `_3` (e.g. `egg_drop_bear_boop_2.wav`).
- Put them in `assets/audio/custom/` in the repo, or send them to Spencer, who will drop them there. Claude uploads them, wires them into `src/client/BoardAudio.lua` and checks each one loads in Studio.
- Optional: include a short `notes.txt` with any loop points or intended volume.

## Runtime behaviour (so you can design for it)
- **Merges climb in pitch:** each merge in a chain plays faster and higher (`BoardAudio:mergePitch`). Design merge pops to sound good shifted up by about an octave.
- **Star count-up:** the recap ticks once per Star earned, each tick about 3% higher. One short coin tick is enough.
- **Ducking:** hatch sounds duck the music to about 22% for about a second. The music loop plays at about 13% volume under gameplay.
- **Overflow warning:** repeats at most every 0.65 s while the board is in danger, so it must sit comfortably when looped like that.
- **Petting:** the purr is a 2-second seamless loop that fades in and out while the player holds pet. Boops are one-shots on each tap.
- **Device sounds stop** when a menu or recap covers the board.
- Players can mute music separately from sound effects.

## Cue list
Priority: **P1** = needed for launch; **P2** = nice for launch; **P3** = later.

### Device: board, merges and rounds
| Cue | When it plays | Sound | Length | Priority | Status |
|---|---|---|---|---|---|
| `aim` | Moving the drop aim | Soft click/tick | 0.03-0.08 s | P2 | exists, replaceable |
| `drop` | An egg is released | Short "plip" | 0.1-0.2 s | P1 | exists, replaceable |
| `land` | An egg lands or bounces | Wet jelly thud (pitched by impact) | 0.1-0.3 s | P1 | exists, replaceable |
| `bank` | An egg settles into the bank | Softer thud or tap | 0.1-0.25 s | P2 | exists, replaceable |
| `merge_bubble` | Small-tier merge | Bubble pop | 0.15-0.35 s | P1 | exists, replaceable |
| `merge_jelly` | Mid-tier merge | Squishier jelly pop | 0.2-0.4 s | P1 | exists, replaceable |
| `merge_chain` | Each extra link in a chain | Bright arpeggio note, built to be stacked and repitched | 0.15-0.3 s | P1 | exists, replaceable |
| `clear_v` | The top tier (V) clears | Sparkly glass chime with a soft downward whoosh | 0.6-1.0 s | P1 | **new** |
| `overflow` | Board is in danger, repeating | Low, soft two-note warning blip | 0.2-0.35 s | P1 | exists, replaceable |
| `win` | Round won | Bright 4-note chiptune jingle | 1.0-1.5 s | P1 | **new** |
| `lose` | Round lost | Soft, friendly descending "wah-wah" | 0.8-1.2 s | P1 | **new** |
| `charge` | Each Star in the recap count-up | Coin tick (repitched up per Star) | 0.05-0.15 s | P1 | exists, replaceable |
| `retry` | Try again / new board | Cartridge "ka-chunk" | 0.2-0.4 s | P2 | exists, replaceable |

### Device: menus and shop
| Cue | When | Sound | Length | Priority | Status |
|---|---|---|---|---|---|
| `menu` | Menu open/close, tab change, button press | Soft UI blip, 2-3 variants welcome | 0.05-0.15 s | P1 | exists, replaceable |
| `deny` | Pressing something you can't use or afford | Dull soft buzz | 0.15-0.3 s | P2 | **new** |
| `purchase` | Buying an egg with Stars | Coin-purse "cha-ching" | 0.4-0.8 s | P1 | **new** |
| `hatch_rise` | An egg starts cracking | Rising shimmer or build | 0.8-1.4 s | P1 | exists, replaceable |
| `hatch` | The egg pops open and reveals | Pop plus sparkle burst | 0.5-1.0 s | P1 | exists, replaceable |

### World: pet voice (shared by every pet for now)
| Cue | When | Sound | Length | Priority | Status |
|---|---|---|---|---|---|
| `pet` | Pet greeting or general happy noise | Small cute plush "mm!" | 0.2-0.5 s | P1 | exists, replaceable |
| `bear_boop_1/2/3` | Tapping or booping the pet | Plush squeak, 3 variants | 0.1-0.3 s | P1 | **new** |
| `bear_chirp` | Pet is happy or cheering after a good round | Tiny rising "mew-hm" hum | 0.3-0.6 s | P1 | **new** |
| `bear_yawn` | Idle yawn or sleepy moment | Breathy, soft descending hum | 0.6-1.0 s | P2 | **new** |
| `bear_sneeze` | Idle sneeze | Tiny "pff-chu" | 0.2-0.4 s | P3 | **new** |
| purr loop | Held petting | Warm purr or hum, seamless loop | 2.0 s loop | P1 | exists, replaceable |

(The `bear_` names are historical; these cues play for every pet.)

### World: toys and garden
| Cue | When | Sound | Length | Priority | Status |
|---|---|---|---|---|---|
| `toy_squeak` | A pet bites the ball or bone toy | Rubber squeak | 0.15-0.3 s | P2 | **new** |
| `sparkler` | The Sparkler toy fizzes | Soft crackle fizz, loopable | 1-2 s loop | P3 | **new** |
| `ambience_day` | Garden in daytime | Gentle birds and light breeze | 30-60 s stereo loop | P2 | **new** |
| `ambience_night` | Garden at night | Soft crickets and a faint wind chime | 30-60 s stereo loop | P2 | **new** |
| `waterfall` | Near the waterfalls (3D positional) | Soft falling water | 10-20 s mono loop | P3 | **new** |

### Music
| Cue | When | Notes | Priority |
|---|---|---|---|
| Garden music | Background in the garden | Currently a 53 s procedural chiptune loop, "Pocket Apricot". Could be replaced by a calm, bright, loopable track of 1-2 min that sits under everything at low volume. | P2 |

## Where the current sounds are
- The source WAVs for the existing cues are in `assets/audio/` (`egg_drop_*.wav`), with measured levels in `egg_drop_audio_manifest.json`.
- They were synthesised by `scripts/synth_egg_drop.py`.
- Listen to them to match levels, or replace them for one cohesive set.

## Delivery checklist
- [ ] Every file is named `egg_drop_<cue>.wav` (with `_1`/`_2`/`_3` for variants)
- [ ] Mono one-shots, stereo loops, 44.1/48 kHz, 16-bit
- [ ] Peaks around -1 dBFS for one-shots; quieter loops
- [ ] No leading silence; short fade-outs; seamless loops
- [ ] P1 cues first
- [ ] Every sound is original or properly licensed for commercial use
