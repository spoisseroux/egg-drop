# Music brief: garden day, garden night, Pocket Deck (Fable, 2026-11-28)

For an Opus implementer writing one deterministic script, `scripts/build_music_v2.py` (numpy, soundfile, pedalboard,
pyloudnorm; fixed seeds; no AI audio, no Sega audio). Nothing here has been heard yet; every number is a starting point.

## 0. What I measured in Spencer's stems

- **Grid**: 117.00 BPM, bar = 60/117*4 s = 90,461.54 frames at 44.1 kHz. Place every event at `round(bar * 90461.538)`.
  Main stems are 32 bars (bass, chords, drums), 16 (melody), 8 (lead2); deck stems 8 bars each.
- **Harmony**: garden chords read as C, F, Am, then a chord with F# (F natural and F# both appear); the deck is plain
  C major. The garden melody and the deck lead are the same tune (C E G C' arpeggios). Added pitches use
  **C D E G A only**; never F or F#. `[check by ear]`
- **Problems found**: the drum loop is one 2-bar pattern 16 times, crest 18 dB, peak -4.6 dBFS. The bass is 99% under
  120 Hz (silent on phones). Chords carry 51% of their energy under 120 Hz. **Melody and lead2 lose 3.9 and 2.9 dB when
  summed to mono** (side louder than mid): on a phone speaker the hook half disappears. The deck lead plays the same
  level in all 8 bars with no rest. Source bars 25-32 already hold a bass dropout (bars 26, 29) and softer chords.
- MP3 stems carry decoder padding. Align each by cross-correlating against `assets/audio/music/garden-loop.wav`
  (2,894,770 frames) / `pocket-deck-loop.wav`, then cut to the grid. Ask Spencer for WAV stems if he has them.

## 1. Catchy, not annoying

What tires people: a short loop (16 s repeats 220 times an hour), a drum pattern that never changes, energy above 5 kHz,
hard transients, a lead that never stops. What sticks: one singable hook, heard, taken away, and given back; a bassline
you can hum; a surprise every 8 bars that is not the same surprise.

**Day loop: 64 bars = 5,789,538 frames = 131.28 s**, four 16-bar sections. All filters zero-phase.

| Bars | Section | Drums | Bass | Chords | Melody | Lead2 | Notes |
|---|---|---|---|---|---|---|---|
| 1-8 | A1 wake | tops only (HP 250 Hz, -6 dB) | in | in | in | out | hook stated plainly |
| 9-16 | A2 | full | in | in | in | out | reverse swell in bar 16 |
| 17-32 | B trade | full | in | in | bars 17-20, 25-28 | bars 21-24, 29-32 | call and response; the resting voice is silent, not ducked |
| 33-40 | C1 breakdown | **none** | source bars 25-32 (its dropouts) | LP sweeping 500 Hz to open | out | out | samples carry it: tok, kalimba, pips |
| 41-48 | C2 | tops only | in | in | music-box doubling only | out | hook returns small |
| 49-56 | D1 | full | in | in | in | out | |
| 57-64 | D2 peak | full | in | in | in | in, -5 dB, 25% right | bar 64 beats 3-4: drums out, swell into bar 1 |

Drum relief: mute the drum stem for the last beat of bars 8, 24, 56 and put a 3-note tok fill there.

**Mix (relative to the stems as delivered)**

- Drums -4 dB; high shelf -4 dB at 6 kHz; soft clip then compressor (4:1, 5 ms attack, 80 ms release) to a crest of
  12-13 dB. Mono below 150 Hz.
- Bass: mono, HP 35 Hz. Add harmonics so phones hear it: parallel `tanh` drive, band 120-500 Hz, mixed 10 dB under the
  dry bass. `[check it stays warm, not fuzzy]`
- Chords: HP 110 Hz (the bass owns the bottom), +1 dB.
- Melody, lead2: cut the side channel 8 dB (target mono loss under 1 dB), melody +2 dB, gentle LP 7 kHz.
- One shared room: pedalboard `Reverb(room_size=.25)`, wet only, return HP 300 Hz / LP 6 kHz. Sends: melody -14 dB,
  lead2 -12, samples -10, drums -24, bass none. Render three loops and keep the middle one so tails wrap the seam.
- Width: bass, kick, melody centre; samples spread up to 40% left/right, alternating; nothing wider.
- Bus: 2:1 glue, 1-2 dB reduction; limiter. **Day -17.6 LUFS** (the current master, so `MusicVolume` .088 stays),
  true peak at or under -1.5 dBTP, loudness range 3-5 LU, under 4% of energy above 6 kHz.

## 2. The weird-sample palette

What makes late-90s console garden music charming (style only, my own description; my search found no technical
breakdown worth citing): toy percussion in place of a rock kit, short bell and mallet tones, small creature-like
voices used as rhythm, a light swung or bossa bounce, bright major-pentatonic answers, and a lot of air between notes.
None of ours copies a melody or a sound.

Rules: all samples sit 8-12 dB under the melody; at most one feature sound per 2 bars; no sound lands on the same beat in
two phrases running; each gets 3 seeded variants (pitch from the set, +/-4% length). Write them to
`assets/audio/music/samples/`.

| # | Name | Recipe | Where | Count / 64 bars |
|---|---|---|---|---|
| 1 | **pip** | sine glide 900 to 1500 Hz, 70 ms, 2nd harmonic -12 dB, 30 Hz vibrato; pairs "pi-pip" on G5/A5/C6 | beat 4.5 of bars 4, 12, 36, 44, 60, answering the hook | 5 |
| 2 | **la-chop** | 120 ms slices cut at onsets of Spencer's melody stem, resampled +12, through two band-passes (700, 1100 Hz, Q 4): a "la/da" syllable | C1: beats 2.5, 3, 4 of bars 34, 38; D2 bar 62 | 3 phrases |
| 3 | **tok** | wood block: modes f, 3.9f, 9.2f, 90 ms decay, 2 ms click | offbeats in A1 and C1 (stands in for hats); the fills | steady in 16 bars |
| 4 | **plip** | water drop: sine 400 to 1400 Hz exponential, 35 ms, 5 ms noise tip | two drops, beat 4 of bars 8, 24, 40 | 3 |
| 5 | **boing** | 110 Hz saw through a band-pass sweeping 400-1800-600 Hz, 250 ms, bend up a 4th | beat 4 of bars 16 and 48 only | 2 |
| 6 | **swell** | last bar of Spencer's chords stem, reversed, through the room, fading up | bars 16, 32, 48, 64 | 4 |
| 7 | **music box** | sine f + 4.07f (-14 dB) + 6.3f click, decay .6 s, LP 5 kHz | C2 hook doubling; the night lead | section |
| 8 | **seed shaker** | noise band 4-8 kHz, 16ths, accents on 2 and 4, 55% swing, -24 dB | B and D only | 32 bars |
| 9 | **kalimba** | f + 5.4f (fast decay), thumb noise 3 ms | E-G-A ostinato, 2 bars on / 2 off, C1 and D2 | 8 bars |
| 10 | **eep** | squeak toy: band-limited pulse 1.2-1.8-1.1 kHz, 90 ms, -14 dB | bar 31 beat 4.5, bar 63 beat 2.5 | 2 |
| 11 | **ribbit** | triangle 220 to 180 Hz with 28 Hz AM, 180 ms | **night only**, bars 12, 44 | 2 |
| 12 | **hoo** | two sine notes E4 to D4, breath noise, LP 2.2 kHz (the stork coo recipe) | **night only**, bars 30, 62 | 2 |

If Spencer finds any of 2, 5 or 10 grating, they are flags in the script (`--without boing,eep`).

## 3. Night version

Same 5,789,538 frames, same section map, same chord stem bar for bar, so the two files can crossfade at any moment.

- **Chords**: LP 1.8 kHz, 6 dB more room send (night room `room_size=.6`). **Bass**: dry sub only, -3 dB, no drive.
- **Drums**: none. B and D get a tok "tick ... tock" on beats 2 and 4 at -20 dB; A and C have no pulse.
- **Melody**: the music box (7) plays the hook an octave up at half the notes (8th-note slots 1, 3, 5 of each bar,
  transcribed from the stem by onset + pitch); Spencer's own melody stem stays underneath, LP 1.2 kHz, -10 dB.
  Lead2: out, except reversed through the room as a ghost in bars 57-64.
- **Samples**: ribbit, hoo, plips, and pips at half count, an octave down. No boing, eep, shaker or la-chop.
- Master: high shelf -3 dB at 5 kHz. **-20.6 LUFS (3 LU under day)**, true peak at or under -6 dBTP.
- Shared stems must stay sample-aligned and zero-phase filtered: no time shifts, or the fade will comb.

**Crossfade** (extends RACE-AND-MUSIC-LOOK 3.3, which stays the runtime spec): both voices start together and never
stop while the garden hour is on. Night weight `w` = the Hour's smoothstepped blend: 0 to 1 over the 120 s that open
night (2880-3000 s), 1 to 0 over dawn's 90 s (0-90 s). Day = `V * cos(w*pi/2)`, night = `V * sin(w*pi/2)`. Because
chords and bass are common to both, the script must render the midpoint (`.707*day + .707*night`) and report its
loudness; if it is more than 1 LU over day, ship exponent 1.5 on both curves. Re-align `TimePosition` when the voices
drift over 40 ms (check once per loop). Joining at night: take `w` from the clock at once.

## 4. Pocket Deck

The player hears this for long sessions with merge sounds on top: calm, steady, and it leaves 2-5 kHz to the SFX.

**32 bars = 2,894,769 frames = 65.64 s**, four 8-bar passes of the stems:

| Bars | Drums | Chords | Lead | Extras |
|---|---|---|---|---|
| 1-8 | tops only | in | in | tok offbeats |
| 9-16 | full | in | in | pip pairs on bars 12, 16 |
| 17-24 | full, -2 dB | in | **out** | kalimba answers the missing lead (C-E-G figures), plips |
| 25-32 | full | in | second half of bars 26, 28, 30 muted; a dotted-8th echo at -12 dB fills the gap | swell in bar 32 |

Mix: drums get the garden treatment (shelf, crest), lead -2 dB, a wide bell cut of 2 dB at 3 kHz on the bus, the same
room at half the sends. Loudness: match the current `pocket-deck-loop.wav` (so `DeckMusicVolume` .105 stays); true
peak at or under -1.5 dBTP.

**Deck lite** (menus, results card): chords + tok + music box hook, no drums, no lead; 16 bars = 32.82 s; 3 LU lower.

## 5. Outside CC0 samples (optional; each file needs Spencer's OK before any download)

Synthesis and his own stems cover the whole palette. If real wood and paper would beat the synth tok and shaker, these
packs state CC0 on their pages and download from a button ("Continue without donating"), no account mentioned:

1. Kenney Impact Sounds, https://kenney.nl/assets/impact-sounds (130 files): wood and soft impacts for **tok** and fills.
2. Kenney Interface Sounds, https://kenney.nl/assets/interface-sounds (100 files): small clicks and drops for the deck.
3. Kenney Casino Audio, https://kenney.nl/assets/casino-audio (50 files): chip and dice foley as a real **shaker** layer.

I read the pages only; nothing was downloaded. Not listed: Freesound (account needed), BigSoundBank (licence is
"CC0-like", account unclear). No nature recordings are needed; the garden already has its own birds and crickets.

## 6. Deliverables

| File (`assets/audio/music/`) | Length | Format |
|---|---|---|
| `garden-day-v2` | 131.28 s | 44.1 kHz stereo; WAV master + **OGG Vorbis q6 for upload** |
| `garden-night-v2` | 131.28 s, identical frame count | same |
| `pocket-deck-v2` | 65.64 s | same |
| `pocket-deck-lite-v2` | 32.82 s | same |

The 131 s WAV is about 23 MB, likely over Roblox's audio size limit `[check the current limit]`; OGG also loops
without the gap MP3 adds. Decode each OGG and confirm the frame count and seam. Also write `samples/*.wav`, an updated
`manifest.json`, and `artifacts/qa-2026-11-28-music/report.json` (LUFS, true peak, range, mono loss, share above 6 kHz,
mid-fade loudness) plus two listening files: `before-after.wav` (old loop, then new, 30 s each) and `dusk-preview.wav`
(day into night with the fade shortened to 20 s).

**Listening checklist for Spencer**

1. Phone speaker first: can you hum the bassline and hear the hook clearly?
2. Leave the day loop on for 10 minutes while doing something else. Anything you want to turn off?
3. Which samples made you smile, which got old? (boing, eep and la-chop are the risky ones.)
4. Is the breakdown (bars 33-40) a welcome rest or a hole?
5. `dusk-preview`: does it feel like one song changing clothes, with no bump or wobble in the middle?
6. Night: sleepy but still your tune? Is the music box too much, too little?
7. Deck: play 5 rounds. Does the music ever fight the merge sounds? Is the lead's rest (bars 17-24) missed?
