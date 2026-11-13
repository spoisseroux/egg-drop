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
- **Pocket Deck music** (`deck_music`): fades in over 1 s when a round starts and out over 0.6 s when it ends, at about 20% voice volume (the world music sits at 13%). The music mute and Sound setting apply to it. It replaces the world music and the garden ambience for the whole round, so it should be calm enough to hear for many minutes.

## Cue list (sorted by priority)
- **Placeholder:** the game already plays a synthesised stand-in sound for this cue. Replacing it is welcome, but it isn't blocking.
- **Partial:** borrows another cue for now.
- **None:** silent until delivered, so these matter most within each tier.

### High priority (needed for launch)
| Cue | When it plays | Sound | Length | Placeholder in game? |
|---|---|---|---|---|
| `drop` | An egg is released | Short "plip" | 0.1-0.2 s | placeholder |
| `land` | An egg lands or bounces | Wet jelly thud (pitched by impact) | 0.1-0.3 s | placeholder |
| `merge_bubble` | Small-tier merge | Bubble pop | 0.15-0.35 s | placeholder |
| `merge_jelly` | Mid-tier merge | Squishier jelly pop | 0.2-0.4 s | placeholder |
| `merge_chain` | Each extra link in a chain | Bright arpeggio note, built to be stacked and repitched | 0.15-0.3 s | placeholder |
| `clear_v` | The top tier (V) clears | Sparkly glass chime with a soft downward whoosh | 0.6-1.0 s | **none** |
| `overflow` | Board in danger, repeats while armed | Low, soft two-note warning blip | 0.2-0.35 s | placeholder |
| `win` | Round won | Bright 4-note chiptune jingle | 1.0-1.5 s | **none** |
| `lose` | Round lost | Soft, friendly descending "wah-wah" | 0.8-1.2 s | **none** |
| `charge` | Each Star in the results count-up | Coin tick (repitched up per Star) | 0.05-0.15 s | placeholder |
| `deck_boot` | Pocket Deck powers on (startup animation) | Original retro handheld boot chime: short, bright, 2-3 notes | 1.0-1.8 s | **none** |
| `deck_button` | Pressing A/B or a screen button on the deck | Crisp plastic button click | 0.03-0.08 s | partial (`menu` blip is used now) |
| `deck_move` | Moving the selection with the D-pad | Tiny soft tick, lighter than the button click | 0.03-0.06 s | partial (`aim` tick is used now) |
| `menu` | Menu open/close, tab change | Soft UI blip, 2-3 variants welcome | 0.05-0.15 s | placeholder |
| `purchase` | Buying an egg with Stars | Coin-purse "cha-ching" | 0.4-0.8 s | **none** |
| `hatch_rise` | An egg starts cracking | Rising shimmer or build | 0.8-1.4 s | placeholder |
| `hatch` | The egg pops open and reveals | Pop plus sparkle burst | 0.5-1.0 s | placeholder |
| `pet` | Pet greeting or general happy noise | Small cute plush "mm!" | 0.2-0.5 s | placeholder |
| `bear_boop_1/2/3` | Tapping or booping the pet | Plush squeak, 3 variants | 0.1-0.3 s | **none** |
| `bear_chirp` | Pet is happy or cheering after a good round | Tiny rising "mew-hm" hum | 0.3-0.6 s | **none** |
| `purr (loop)` | Held petting | Warm purr or hum, seamless loop | 2.0 s loop | placeholder |
| `deck_music` | **Pocket Deck music.** Plays only during a Pocket Deck round; the world music, brook, falls, birds and coos all fade out while it plays (Spencer, 2026-11-13) | Calm, loopable handheld-style tune: friendly, unhurried, never busy enough to fight the merge sounds. Stereo OK | 20-60 s seamless loop | placeholder (`egg_drop_deck_music.wav`, 84 BPM chip lullaby) |
| `count_blip` | **Results count-up blip.** One per +1 while the Star total counts up on the results screen; each blip is cut off by the next, like collecting rings (Spencer, 2026-11-13) | Tiny bright chip blip, rising feel; must sound fine repeated 20+ times a second | 40-80 ms | placeholder (`egg_drop_count_blip.wav`, G6 to C7 hop) |

### Medium priority (nice for launch)
| Cue | When it plays | Sound | Length | Placeholder in game? |
|---|---|---|---|---|
| `aim` | Moving the drop aim | Soft click/tick | 0.03-0.08 s | placeholder |
| `bank` | An egg settles into the bank | Softer thud or tap | 0.1-0.25 s | placeholder |
| `retry` | Replay from the results screen / new board | Cartridge "ka-chunk" | 0.2-0.4 s | placeholder |
| `deck_back` | The back arrow on the deck screen | Soft descending two-note blip | 0.08-0.15 s | partial (`menu` blip is used now) |
| `deck_power_off` | Leaving the deck / putting it away | Short descending power-down chirp | 0.3-0.6 s | **none** |
| `difficulty_select` | Choosing Easy / Medium / Hard before a round | Three related blips, rising in pitch for harder (or one blip repitched) | 0.1-0.2 s | **none** |
| `quest_complete` | A quest is finished | Bright little fanfare, smaller than `win` | 0.5-0.9 s | **none** |
| `deny` | Pressing something you can't use or afford | Dull soft buzz | 0.15-0.3 s | **none** |
| `bear_yawn` | Idle yawn or sleepy moment | Breathy, soft descending hum | 0.6-1.0 s | **none** |
| `toy_squeak` | A pet bites the ball or bone toy | Rubber squeak | 0.15-0.3 s | **none** |
| `ambience_day` | Garden in daytime | Gentle birds and light breeze (stereo loop) | 30-60 s loop | **none** |
| `ambience_night` | Garden at night | Soft crickets and a faint wind chime (stereo loop) | 30-60 s loop | **none** |
| `garden music` | Background in the garden | Calm, bright loopable track under everything at low volume | 1-2 min loop | placeholder (53 s procedural loop) |

### Low priority (later)
| Cue | When it plays | Sound | Length | Placeholder in game? |
|---|---|---|---|---|
| `faceplate_swap` | Swapping the deck's faceplate | Satisfying plastic snap/click | 0.15-0.3 s | **none** |
| `quest_log` | Opening the quest log | Page-flip or soft chime | 0.1-0.25 s | **none** |
| `quest_reroll` | Rerolling a quest | Quick shuffle or whoosh | 0.2-0.4 s | **none** |
| `bear_sneeze` | Idle sneeze | Tiny "pff-chu" | 0.2-0.4 s | **none** |
| `sparkler (loop)` | The Sparkler toy fizzes | Soft crackle fizz, loopable | 1-2 s loop | **none** |
| `waterfall (loop)` | Near the waterfalls (3D positional) | Soft falling water (mono loop) | 10-20 s loop | **none** |
| `chimes` | Wind chimes on the arch sway | Gentle random chime notes, 3-4 single hits | 0.5-1.5 s each | **none** |

Notes:
- The `bear_` names are historical: every pet uses these voice cues.
- The `deck_*`, `difficulty_select`, `faceplate_swap` and `quest_*` cues are for Pocket Deck features being designed now (boot animation, faceplates, difficulty picker, quest log). They're planned, not in the game yet.
- QA 2026-11-13: `lose` now always plays once on the results screen of a lost round (it used to be skipped when the save was still pending). It is the uploaded placeholder until the real "wah-wah" lands.
- QA 2026-11-13: the wait for the last ball to settle (4 s) plays a soft tick each second (0, 1, 2, 3 s) with a rising pitch. It borrows the `desc_tick` placeholder for now; a dedicated `settle_tick` (very short, soft, wooden or glassy, 0.05-0.1 s, neutral pitch) would replace it. Name it `egg_drop_settle_tick.wav`.
- QA 2026-11-13: the results flourish (`stars_total`, `new_best`, `egg_ready`) now plays to its natural end, or fades over 0.35 s when the player skips or leaves. Tails can ring out; keep them under about 1.2 s.

## Where the current sounds are
- The source WAVs for the existing cues are in `assets/audio/` (`egg_drop_*.wav`), with measured levels in `egg_drop_audio_manifest.json`.
- They were synthesised by `scripts/synth_egg_drop.py`.
- Listen to them to match levels, or replace them for one cohesive set.

## Delivery checklist
- [ ] Every file is named `egg_drop_<cue>.wav` (with `_1`/`_2`/`_3` for variants)
- [ ] Mono one-shots, stereo loops, 44.1/48 kHz, 16-bit
- [ ] Peaks around -1 dBFS for one-shots; quieter loops
- [ ] No leading silence; short fade-outs; seamless loops
- [ ] High-priority cues first, starting with the ones that have no placeholder
- [ ] Every sound is original or properly licensed for commercial use
