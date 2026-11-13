# PLACEHOLDER audio: replace these

**Every file in this folder is a PLACEHOLDER.** They were synthesised by `scripts/build_placeholder_audio.py` (numpy, fixed seeds, re-runnable) so each cue has some sound now. Spencer makes the final audio: drop a real take named `egg_drop_<cue>.wav` into `assets/audio/custom/` and it supersedes the placeholder here.

Format: 44.1 kHz, mono, 16-bit WAV plus an OGG (Vorbis q6) encode. Loudness matched to the existing `assets/audio/egg_drop_*.wav` set: one-shots about -18 to -25 dBFS RMS with peaks at or below -2 dBFS; the one loop sits at -31 dBFS RMS. 12 ms fade-out, no leading silence (the two whooshes swell in by design). `manifest.json` lists `cue`, `file`, `seconds`, `loop` and measured levels.

## Played in src/ today (no asset id yet)

| Status | Cue | File | Sec | Loop | Sound | Where it plays |
|---|---|---|---|---|---|---|
| PLACEHOLDER | `danger_enter` | `egg_drop_danger_enter.wav` | 0.42 |  | soft low two-tone "uh-oh" | BoardDanger: stack goes over the fill line (once) |
| PLACEHOLDER | `danger_clear` | `egg_drop_danger_clear.wav` | 0.6 |  | relieved rising three-bell chime | BoardDanger: stack drops back under the line |
| PLACEHOLDER | `deck_boot` | `egg_drop_deck_boot.wav` | 1.3 |  | two chip blips into a bright bell bloom | DeckBoot: Pocket Deck power-on (810 ms in) |
| PLACEHOLDER | `quest_complete` | `egg_drop_quest_complete.wav` | 0.8 |  | small rising fanfare, smaller than win | Quest finished / results |
| PLACEHOLDER | `bear_boop` | `egg_drop_bear_boop.wav` | 0.18 |  | plush squeak, up-and-down pitch | RevealStage: tapping the pet on the reveal |
| PLACEHOLDER | `reveal_hush` | `egg_drop_reveal_hush.wav` | 0.22 |  | short downward suck of air (closing low-pass noise) | RevealStage t=0: room goes quiet |
| PLACEHOLDER | `spot_on` | `egg_drop_spot_on.wav` | 0.48 |  | soft thunk with a warm hum swell | RevealStage t=0.12: stage light |
| PLACEHOLDER | `streak_whoosh` | `egg_drop_streak_whoosh.wav` | 0.339 |  | airy rising band-pass noise swipe | RevealStage t=0.30: streak |
| PLACEHOLDER | `reveal_shimmer` | `egg_drop_reveal_shimmer.wav` | 1.5 |  | detuned bell arpeggio C-E-G-C-E with glitter | RevealStage t=0.42: the main reveal (pitched +3 st for rare) |
| PLACEHOLDER | `tag_slam` | `egg_drop_tag_slam.wav` | 0.15 |  | paper-and-wood thwack | RevealStage t=0.48: rarity tag |
| PLACEHOLDER | `name_slam` | `egg_drop_name_slam.wav` | 0.34 |  | low thump with a chime on top | RevealStage t=0.60: pet name |
| PLACEHOLDER | `desc_tick` | `egg_drop_desc_tick.wav` | 0.05 |  | light wooden tick | RevealStage t=0.84: description |
| PLACEHOLDER | `spin_whoosh` | `egg_drop_spin_whoosh.wav` | 0.26 |  | soft cloth whirl | RevealStage: drag-spin the pet (repitched by speed) |
| PLACEHOLDER | `shimmer_loop` | `egg_drop_shimmer_loop.wav` | 3.2 | yes | seamless pentatonic twinkle bed + air | Reveal idle bed (very quiet) |
| PLACEHOLDER | `reveal_out` | `egg_drop_reveal_out.wav` | 0.26 |  | hum closing down, tiny thud | RevealStage exit |
| PLACEHOLDER | `goal_tick` | `egg_drop_goal_tick.wav` | 0.08 |  | bright check "tik" | DeckResults: each goal checked (repitched up) |
| PLACEHOLDER | `row_flip` | `egg_drop_row_flip.wav` | 0.11 |  | soft card flip | DeckResults: result rows flip in |
| PLACEHOLDER | `star_land` | `egg_drop_star_land.wav` | 0.42 |  | boing + metal clink | DeckResults: Stars land |
| PLACEHOLDER | `stars_total` | `egg_drop_stars_total.wav` | 1.15 |  | two-note ta-da over a soft cymbal bloom | DeckResults: Stars total payoff |
| PLACEHOLDER | `new_best` | `egg_drop_new_best.wav` | 0.55 |  | rising three-note flourish | DeckResults: new best score |
| PLACEHOLDER | `egg_ready` | `egg_drop_egg_ready.wav` | 0.55 |  | hollow knock-knock with a twinkle | DeckResults finale: can hatch an egg |
| PLACEHOLDER | `meter_fill` | `egg_drop_meter_fill.wav` | 0.26 |  | eight rising blips | DeckResults: meter fills (also on loss, quiet) |
| PLACEHOLDER | `win` | `egg_drop_win.wav` | 1.25 |  | 3-note rising jingle into a held chord | DeckResults: round won |
| PLACEHOLDER | `lose` | `egg_drop_lose.wav` | 0.95 |  | gentle 2-note descending "aww" (never harsh) | DeckResults: round lost |

## Spec'd, not wired yet

| Status | Cue | File | Sec | Loop | Sound | Where it plays |
|---|---|---|---|---|---|---|
| PLACEHOLDER | `danger_tick` | `egg_drop_danger_tick.wav` | 0.06 |  | soft wooden tick | Danger state: quiet tick per second (doubles in last second); spec 6.3 |
| PLACEHOLDER | `egg_wobble` | `egg_drop_egg_wobble.wav` | 0.36 |  | three little toks over a wobbling hum | Hatch preview: egg wobbles |
| PLACEHOLDER | `egg_crack_glint` | `egg_drop_egg_crack_glint.wav` | 0.38 |  | tiny crack + high glint bell | Hatch preview: crack glint |
| PLACEHOLDER | `egg_select` | `egg_drop_egg_select.wav` | 0.15 |  | soft rising pop | Hatch preview: egg chosen |

## Optional: AUDIO-HANDOFF cues with no sound (not wired)

| Status | Cue | File | Sec | Loop | Sound | Where it plays |
|---|---|---|---|---|---|---|
| PLACEHOLDER | `clear_v` | `egg_drop_clear_v.wav` | 0.95 |  | glass bells with a downward whoosh | Top tier (V) clears (handoff; not wired) |
| PLACEHOLDER | `purchase` | `egg_drop_purchase.wav` | 0.6 |  | noise "cha" + coin "ching" | Buying an egg (handoff; not wired) |
| PLACEHOLDER | `deny` | `egg_drop_deny.wav` | 0.22 |  | dull soft low buzz | Unusable/unaffordable button (handoff; not wired) |
| PLACEHOLDER | `deck_button` | `egg_drop_deck_button.wav` | 0.05 |  | crisp plastic click | Deck A/B/screen button (handoff; uses menu now) |
| PLACEHOLDER | `deck_move` | `egg_drop_deck_move.wav` | 0.04 |  | tiny soft tick | Deck D-pad move (handoff; uses aim now) |
| PLACEHOLDER | `deck_back` | `egg_drop_deck_back.wav` | 0.13 |  | descending two-note blip | Deck back arrow (handoff; uses menu now) |

## Ambient "feel alive" set (2026-11-13, not wired, no asset ids yet)

Built by `scripts/build_ambient_placeholder_audio.py` (same primitives and finishing as the main script; it merges its entries into `manifest.json` and leaves every other entry and every `assetId` alone). Direction, mix levels and triggers: `FEEL-ALIVE-DIRECTION-2026-11-13.md`. Levels: beds -31 dBFS RMS (like `shimmer_loop`), the falls -27, birds -24, coos -22, the attract ping -21.

| Status | Cue | File | Sec | Loop | Sound | Where it plays |
|---|---|---|---|---|---|---|
| PLACEHOLDER | `water_bed_loop` | `egg_drop_water_bed_loop.wav` | 10.0 | yes | soft brook: mid hiss, slow swells, scattered bloops | Garden ambience: global bed, heard everywhere, louder by the stream |
| PLACEHOLDER | `waterfall_loop` | `egg_drop_waterfall_loop.wav` | 10.0 | yes | fuller rush with low body and light spray | Positional loop at Tumble Falls and Sky Falls |
| PLACEHOLDER | `bird_chirp_1` | `egg_drop_bird_chirp_1.wav` | 0.42 |  | two-note "tsee-wit": slide down, flick up | Bird ambience from tree canopies (day) |
| PLACEHOLDER | `bird_chirp_2` | `egg_drop_bird_chirp_2.wav` | 0.468 |  | fast eight-pip trill | Bird ambience (day) |
| PLACEHOLDER | `bird_chirp_3` | `egg_drop_bird_chirp_3.wav` | 0.46 |  | single falling whistle with a warbled tail | Bird ambience (day and dusk) |
| PLACEHOLDER | `bird_chirp_4` | `egg_drop_bird_chirp_4.wav` | 0.52 |  | cheerful "chip-chip-cheep" | Bird ambience (day) |
| PLACEHOLDER | `bird_chirp_5` | `egg_drop_bird_chirp_5.wav` | 0.6 |  | liquid warble that slows down | Bird ambience (day) |
| PLACEHOLDER | `bird_chirp_6` | `egg_drop_bird_chirp_6.wav` | 0.78 |  | low sleepy "hoo-hoo" | Bird ambience (dusk and night only) |
| PLACEHOLDER | `pet_coo_1` | `egg_drop_pet_coo_1.wav` | 0.34 |  | rising "oo?" | Pet coo: curious, look-around beat |
| PLACEHOLDER | `pet_coo_2` | `egg_drop_pet_coo_2.wav` | 0.5 |  | two-syllable "ah-oo" | Pet coo: happy, greeting, after petting |
| PLACEHOLDER | `pet_coo_3` | `egg_drop_pet_coo_3.wav` | 0.52 |  | low falling "mmm-m" | Pet coo: sleepy, sit, end of a yawn |
| PLACEHOLDER | `machine_attract` | `egg_drop_machine_attract.wav` | 0.9 |  | two soft bells a fifth apart with glitter | Station attract: walking into range of an unused machine |

- `water_bed_loop` and `waterfall_loop` are circular by construction (random-phase spectrum, whole-cycle swells, bloops wrapped around the end); set `Looped = true`. The build asserts the seam step is no larger than an ordinary step inside the loop.
- Bird chirps and coos are repitched at runtime (0.92 to 1.12), so keep replacements at a neutral pitch.
- `machine_attract` is repitched per station (deck 1.0, eggs 1.12, care 0.89).
- These were checked by level and spectrogram, not by ear. Listen before upload.

## Pocket Deck round music (2026-11-13, W2)

Built by `scripts/build_deck_music_placeholder.py` (its own script; it never rewrites `manifest.json`, whose `deck_music` entry was added by hand). Played by `src/client/AmbientAudio.lua` only during a Pocket Deck round (Board mode): it fades in over 1 s, the world music and all garden ambience fade out, and both come back when the round ends. See `AUDIO-HANDOFF.md` ("Pocket Deck music") for what Spencer's track should be.

| Status | Cue | File | Sec | Loop | Sound | Where it plays |
|---|---|---|---|---|---|---|
| PLACEHOLDER | `deck_music` | `egg_drop_deck_music.wav` | 22.857 | yes | calm 84 BPM chip lullaby: triangle bass, soft pad, sparse pentatonic bells | Pocket Deck rounds only, replacing the world music and ambience |

- Circular by construction (every note tail wraps around the loop end); set `Looped = true`. File RMS -24 dBFS; the runtime voice volume is 0.2.

## Notes for replacing
- `shimmer_loop` is a seamless 3.2 s loop (notes wrap around the end); set `Looped = true`.
- `goal_tick`, `spin_whoosh` and `reveal_shimmer` get repitched at runtime; keep a neutral base pitch.
- `danger_tick` is spec'd in UI-SPEC-REDESIGN-MENUS 6.3 (per-second tick) but not yet in `BoardAudio` cues.
- `egg_wobble`, `egg_crack_glint`, `egg_select` are for the hatch-preview eggs and are not wired yet.
