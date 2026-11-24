# Race finish, race song, night garden song, tip chimes (beta 14 QA: F3, F4, Q6)

Fable, 2026-11-23. For the Opus builder. Look and sound only: no game rules change. Source: `FEEDBACK.md` in this folder.
Everything here is original: scores written below, rendered by additive synthesis scripts in numpy (the
`scripts/qa20261114_music.py` and `scripts/synth_tip_chime.py` pattern). No samples, no generated audio or art.
Nothing in this file has been rendered or heard yet. `[check]` marks what must be confirmed by ear, on the phone, or in code.

## 0. What I found first (read this)

- **The garden song in the game is not the synthesized score.** `BoardAudio` plays asset 70486364707324 =
  `assets/audio/music/garden-loop.wav`, Spencer's own recorded loop (65.641 s, 44.1 kHz, -17.6 LUFS, uploaded unaltered,
  2026-11-16). The 104 bpm "Little Afternoon" score in `assets/audio/original-2026-11-14/manifest.json` was never
  uploaded (`"uploaded": false`). So "a night version of the song" means a night version of **Spencer's loop**. Section 3
  is written for that, with the Little Afternoon route as a fallback.
- Measured from his file (numpy, not by ear): 65.641 s is exactly 128 beats at **117 bpm** (32 bars of 4/4) `[check]`;
  strongest pitch classes A, G, E, C, B, so **A minor / E minor area** `[check]`; the low end sits on E every other bar.
- The results cues in use today (`win`, `new_best`, `star_land`, `stars_total`, `count_blip`) are all **placeholders**
  (`BoardAudio.placeholderIds`). The race plays no music at all: the garden loop runs through it. Crossing the line plays
  `quest_complete`. That is most of why it feels flat.
- The results card opens `Client.ResultAfter` (1.3 s) after the result packet, and the packet can wait up to 20 s for the
  other racers. So there are two moments: **the line** (always at once) and **the card** (later). Both get a sound.

## 1. The race finish moment

### 1.1 New and reused cues

| Cue | New? | Length | What it is | Play volume |
|---|---|---|---|---|
| `dash_line` | new | 0.6 s | Over the line: two wood notes G5 then C6, a short air whoosh under them | .5 |
| `dash_win` | new | 2.6 s | Win sting (section 2.3). 1st place, and a Time Trial cup time | .6 |
| `dash_place` | new | 1.8 s | Soft "you placed" sting (section 2.4). 2nd and lower, a Time Trial with no cup | .5 (4th and lower .4) |
| `dash_best` | new | 0.9 s | New best: a rising glock run (section 2.5) | .5 |
| `star_land` | replace placeholder | 0.22 s | One felt-glock note, C6 (section 2.5). Pitched per Star by the code | .4 |
| `stars_total` | replace placeholder | 0.7 s | Wood + glock dyad C6 + G6 with a soft thump | .5 |
| `tag_slam` | reuse | | The medal landing (1st and cup) | .35 |
| `count_blip` | reuse | | The time count-up, Time Trial only (every 60 ms, each cut by the next) | .2 |

`win` and `new_best` stay for the Pocket Deck; Dash stops using `quest_complete` at the line.

### 1.2 At the line (in the world, before any card)

| t from crossing | What |
|---|---|
| 0.00 | `dash_line`. The race song drops to 35% of its volume over 0.4 s (it keeps playing: the wait for the others is not silent). The HUD rests as now |
| 0.00 | A small popper at the finish gate: two bursts of 16 paper pieces from the gate posts, the five confetti colours, 0.8 s. The same for every place: the client does not know the place for sure yet. Reduced Motion: none |
| 0.00 to card | The pet keeps its home pose. Nothing else: the payoff is saved for the card |

### 1.3 The card: which show plays

| Result | Show | Sting |
|---|---|---|
| 1st in a race (2 or more racers) | **Win** | `dash_win` |
| Time Trial, cup time | **Win** (medal in the cup colour) | `dash_win` |
| Time Trial, new best, no cup | **Best** | `dash_place`, then `dash_best` |
| 2nd or 3rd | **Placed** | `dash_place` |
| 4th and lower; Time Trial with no best | **Finished** | `dash_place` at .4 |
| A race of one, not a trial `[check: can it happen]` | **Finished** | `dash_place` at .4 |

A new best inside a Win or Placed show adds the `dash_best` beat (below); it never replaces the sting.

### 1.4 Win, second by second (t from the card opening)

`dash_win` is built so its big chord is 0.40 s into the file. Start it at 0.15 and the chord lands at **0.55**: everything
big happens on that frame.

| t | Screen | Pet | Sound |
|---|---|---|---|
| 0.00 | Shade 0.2 s; card springs in 0.22 s. The stage is **dark**: spotlight off, no medal, headline hidden | Not shown yet | The race song fades out over 0.15 s |
| 0.15 | | Drops onto the step (12 pt, as now) and goes straight into a **crouch**: body low, head down a little, 0.25 s. Eyes on the camera | `dash_win` starts (three rising pickup notes) |
| 0.40 | Spotlight still off: one beat of held breath | Lowest point of the crouch | |
| **0.55** | **The hit.** Spotlight snaps on (wedge to 72% see-through in 0.08 s). One white flash over the stage only (45% to 0 in 0.18 s). Sun rays open behind the pet. Two confetti cannons fire. The headline lands (scale 1.5 to 1, back-out, 0.32 s) | **Spin jump**: up 34 pt (1.4 x the old hop), one full turn (360 degrees, ease in and out), arms up, mouth open. 0.55 s in the air | The chord of `dash_win` |
| 0.55 | Camera: field of view 30 to 27 in 0.12 s (a small push in) | | |
| 0.70 | The time counts up, 0.4 s (silent: the sting carries it) | Top of the jump at 0.82 | |
| **1.10** | The **medal slams** on: scale 1.6 to 1, back-out 0.2 s, a 6 degree rock that settles. Glow under the step pops 1 to 1.35 and back. Camera eases back to 30 over 0.5 s. **Buttons take input from here** | Lands facing the camera with a squash (0.12 s down, 0.2 s spring back) | `tag_slam` |
| 1.25 | **Stars fly** (1.6). Slow confetti starts falling over the stage | **Two victory hops**, 24 pt and 0.42 s each, arms up, a head tilt left then right | `star_land` per Star |
| 2.05 | The "+N Stars" tray boings; the last pip fills | Lands from the second hop | `stars_total` |
| 2.10 | Only with a new best: the NEW BEST chip slams (scale 1.4 to 1) and shines once | A third, smaller hop (16 pt) | `dash_best` |
| 2.25 | Field chips pop, 60 ms apart | Happy idle: a sway on the spot, a 16 pt hop every 3 s (as now) | Sting tail rings out by 2.75 |
| 2.60 | The See you tomorrow strip comes in | | |
| 2.90 | Race again pulses once, then every 6 s | | |

Done by 3.0 s. Input opens at 1.10 so the hit cannot be skipped by a stray tap, and nobody waits for the rest: a press at
any time after 1.10 closes the card, cuts the stings with a 0.15 s fade and gives every number its final value.

### 1.5 Placed, Best, Finished

**Placed (2nd, 3rd)**, close to today's timing, with the new parts:

| t | What | Sound |
|---|---|---|
| 0.00 | Card in. Spotlight already on (90% see-through, as now). Race song fades out 0.15 s | |
| 0.15 | The pet drops 12 pt onto the step with a squash; the medal pops (as now) | `dash_place` |
| 0.30 | Headline lands | |
| 0.45 | One **big hop** (30 pt, no spin, arms up), then one normal hop (24 pt) | |
| 0.55 | The time counts up 0.4 s | |
| **0.70** | **Buttons take input** | |
| 1.05 | Stars fly (1.6); confetti as today (24 pieces inside the stage, 1.2 s) | `star_land` per Star |
| 1.85 | Tray boings | `stars_total` |
| 1.90 | New best only: chip slams, small hop | `dash_best` |
| 2.00 | Field chips; 2.3 the strip; 2.6 the pulse | |

**Finished (4th and lower)**: the same table without confetti, with **one** normal hop and then the wave or wag, and
`dash_place` at .4. Still a smile, never a sad pose. The Stars still fly: they are the payoff here.

**Best (Time Trial, new best, no cup)**: the clock is the hero.

| t | What | Sound |
|---|---|---|
| 0.15 | Pet drops in; stopwatch medal pops | `dash_place` |
| 0.30 | Headline | |
| 0.55 to 1.15 | The time counts up over 0.6 s, the tray's stroke turning Stars yellow as it runs. The pet leans in and watches it (head turned 15 degrees to the right, toward the tray) | `count_blip` every 60 ms, pitch rising 1.0 to 1.3 |
| **1.15** | The time stops; the NEW BEST chip slams; spotlight flares to 72% and settles; confetti as Placed. The pet does the **spin jump**. **Buttons take input** | `dash_best` |
| 1.70 | Pet lands, squash, then idle | |
| 1.90 | The pulse | |

**Time Trial with a cup time** uses the Win table; the count-up at 0.70 gets the `count_blip` run (0.4 s) under the sting at .15.

### 1.6 Stars landing

- At the Stars time, star icons (18 pt, the wallet's star) leave the **pet's head** and fly to the star icon in the Earned
  tray: one per Star earned, at most 6 icons (more Stars: 6 icons, the count jumps by N/6 per landing).
- Each flies 0.35 s on an arc that rises 30 pt first (a quadratic curve), 90 ms apart, turning half a turn, scale 0.7 to 1.
- On landing: the tray's star does a 1.25 boing (0.12 s), the number ticks up, the pip for this race fills on the **last** one.
- `star_land` plays per landing at playback speeds **1.0, 1.122, 1.26, 1.498, 1.682, 2.0** (C D E G A C: a little run up
  the scale). Then `stars_total` 90 ms after the last.
- "Saving…": nothing flies until the receipt lands, then the same run from that moment (as `paidAt` works today).
- Today's Stars races used up: no stars fly; the five full pips shimmer once left to right (60 ms apart) at the Stars time. No sound.
- Reduced Motion: no flight; the number is final; one `stars_total` at .4.

### 1.7 Pet animation notes (for `DashPose.podium`)

Give `Pose.podium` a `show` ("win" | "placed" | "finished" | "best") instead of reading the place alone.

| Move | Lift | Time | Body |
|---|---|---|---|
| Crouch | 0 | 0.25 s | body lowered about 15% of its height, head pitched down 10 degrees, arms in |
| Spin jump | 34 pt (phone, tall stage; 22 pt on the short stage) | 0.55 s, sine arc | yaw 0 to 360 with smoothstep; arms up from take-off; expression "joy" with the open mouth; stretch 6% taller going up `[check: the rig's squash/stretch channel name]` |
| Landing squash | 0 | 0.12 s down, 0.2 s back (back-out) | 12% shorter, 8% wider; feet stay on the step |
| Victory hop | 24 pt | 0.42 s | arms up; head roll +0.14 then -0.14 rad on alternate hops |
| Big hop (Placed) | 30 pt | 0.48 s | arms up, no spin |
| Watch the clock (Best) | 0 | 0.6 s | yaw 15 degrees toward the tray, head pitched down 5 degrees, a tiny bounce (3 pt) twice a second |
| Idle | 16 pt hop every 3 s | | as now |

- The pet height on the stage goes from 84 to **78 pt** for Win and Best so the 34 pt jump clears the top with 8 pt spare
  (`DashSheetLayout` `pet = {height, hop, ...}`: `hop = 34`). `Stage.camera` already fits the highest hop. `[check on the 132 pt stage]`
- Charms and hats ride along; nothing detaches.
- Channels I saw on the visual: `origin`, `yaw`, `expression`, `careHeadRoll`, `careHeadPitch`, `careBodyLower`,
  `careHand`. Arms-up is `careHand` if it raises both hands `[check]`; if a pet has no arms (Nuum tucks a hand) the jump and the spin are enough.
- Reduced Motion: the pet sits and smiles (as now); no spin, no flash, no rays turning, no cannons; the stings still play.

### 1.8 Light, rays, confetti, camera

- **Spotlight**: Win starts with the wedge fully see-through, snaps to 72% at the hit, eases to 90% (today's value) by 1.6 s.
- **Flash**: one white frame over the stage well only, 45% to 0 in 0.18 s, once. Never over the whole screen, never repeated.
- **Sun rays** (Win only): eight copies of the existing spotlight wedge image, tinted lemon `#FFE14D`, 88% see-through,
  fanned every 45 degrees around the pet's middle, behind the pet and in front of the well. They scale 0.6 to 1 in 0.2 s
  at the hit, turn 20 degrees a second, and fade to 94% after 2.5 s (they keep turning while the card is open). No new image.
- **Confetti, Win**: 28 pieces from two cannons at the stage's bottom corners at the hit (14 each): start speed 260 to
  380 pt/s, aimed 60 to 80 degrees up and inward, gravity 520 pt/s², each spinning. They may fly out over the right
  column: parent them to the card, clipped by the card, above the trays and below the buttons. Then 12 slow pieces fall
  over the stage from 1.25 to 3.0 s. Pieces: 4 x 9 strips and 6 x 6 rounded squares in the five `Sheet.Confetti` colours,
  plus 6 small stars (10 pt) in Stars yellow. 46 in all: fine on a phone, all plain frames.
- **Confetti, Placed and Best**: today's 24 strips inside the stage for 1.2 s.
- **Camera**: only the field-of-view push (30 to 27 to 30). No shake, no orbit: the pet must stay readable at 78 pt.
- **Haptics** `[check: used elsewhere?]`: if the game already buzzes on a hatch, one light tap at the Win hit. Otherwise none.

## 2. Race music

### 2.1 Brief: "Hop to It" (race loop with a countdown lead-in)

- **One file**: 3.000 s lead-in + 32.000 s loop = 35.000 s, 48 kHz stereo, 1,680,000 frames. Loop from 3.0 to 35.0 with
  `Sound.PlaybackRegionsEnabled` and `Sound.LoopRegion = NumberRange.new(3, 35)` so the join is exact `[check on the
  phone]`. If that is not reliable, render two files (lead-in, loop) and start the loop at GO; the lead-in ends on a rest
  so a frame of jitter is not heard.
- **Tempo 120 bpm**, on purpose: one beat is 0.5 s, so the 3, 2, 1 digits (one a second) fall on beats 1, 3 and 5 of the
  lead-in and GO is the downbeat of bar 1. Start the file at `goAt - lead - 3.0`; if the lock comes later than that, start
  at `TimePosition = 3 - time left`.
- **Key C major**, 4/4, straight eighths. 16 bars. Bright and bouncy, a little-kid sports day, not an action cue.
- **Instruments** (the `voice()` kinds in `qa20261114_music.py`): lead **wood** (xylophone), doubled an octave lower by
  **pluck** at -8 dB; **pluck** off-beat chords; **bass**; **pad** in bars 9 to 12; **bell** doubling the lead in bars
  13 to 16 at -10 dB. Drums, all synthesized: kick (sine falling 110 to 50 Hz in 0.12 s), brush (the script's
  `filtered_noise` 1800 to 5800 Hz, 0.09 s, with a 190 Hz sine body at -10 dB), shaker (noise 3 to 7 kHz, 0.04 s), woodblock (the script's 620 + 970 Hz tick).
- **Energy**: bars 1 to 2 lead, bass, kick and shaker only (room for "GO!"). Bars 3 to 8 add brush and off-beat chords.
  Bars 9 to 12 lift: long melody notes, pad, woodblock, pluck answers. Bars 13 to 16 everything plus the bell double; bar
  16 is a fill that falls into bar 1.
- **Hand-off**: at the line the voice goes to 35% in 0.4 s and keeps looping; when the card opens it fades out in 0.15 s
  and the sting (same key and tempo) starts at 0.15. Because the stings begin with their own pickup and end on C, they
  land right from any bar. If the race is abandoned or the pet leaves: fade 0.4 s.
- **Mix in the game**: its own looped voice beside `deck_music` in `AmbientAudio` (same group rules: master, music
  toggle, focus). World music is held out by a duck for the countdown, race and results, like a deck round, and comes
  back over 1.0 s when the card closes. The countdown `count_blip` and GO stay on top `[check the blip's pitch against C;
  if it clashes play it at the speed that makes it a G]`. Racers only: onlookers keep the garden song.
- **Loudness**: integrated **-19 LUFS** (the deck track's level in the manifest), loudness range under 3 LU, true peak
  at or under -6 dBTP. Voice volume starts at `DeckMusicVolume` (.105) `[check on the phone against the dash and jump cues]`.

### 2.2 Score

Rows are bars; `note:beats`, `r` is a rest, four beats a row (the format of `MELODY` in the script).

**Lead-in (6 beats)**, harmony G7sus:

| Part | Beats |
|---|---|
| Woodblock | hits on beats 0, 2, 4 (the three digits) |
| Bass | `G2:1 r:1 G2:1 r:1 G2:.5 A2:.5 B2:.5 B2:.5` |
| Pluck chord (D4 G4 C5) | one soft stab on beats 0, 2, 4, gate 0.2 s |
| Shaker | eighths from beat 3, rising from -18 to -6 dB |
| Brush | beats 5 and 5.5 |
| Lead (wood) | `r:5 C5:.5 D5:.5` (pickup into bar 1) |

**Chords**

| Bars | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| | C | C | F | G | C | Am | F | G |
| **Bars** | **9** | **10** | **11** | **12** | **13** | **14** | **15** | **16** |
| | F | G | Em | Am | F | G | C | G |

**Lead melody**

```
 1  E5:.5 G5:.5 C6:1 G5:.5 E5:.5 G5:1
 2  A5:.5 G5:.5 E5:1 D5:.5 E5:.5 G5:1
 3  F5:.5 A5:.5 C6:1 A5:.5 F5:.5 A5:1
 4  G5:.5 B5:.5 D6:1 B5:.5 A5:.5 G5:1
 5  E5:.5 G5:.5 C6:1 D6:.5 C6:.5 G5:1
 6  A5:.5 C6:.5 E6:1 D6:.5 C6:.5 A5:1
 7  F5:.5 A5:.5 C6:.5 A5:.5 F5:.5 A5:.5 C6:1
 8  D6:1 B5:.5 G5:.5 D5:.5 G5:.5 B5:.5 D6:.5
 9  C6:1.5 A5:.5 F5:1 r:1
10  B5:1.5 G5:.5 D5:1 r:1
11  G5:.5 B5:.5 E6:1 D6:.5 B5:.5 G5:1
12  A5:.5 C6:.5 E6:1 C6:.5 A5:.5 E5:1
13  F5:.5 A5:.5 C6:.5 F6:.5 E6:1 C6:1
14  D6:.5 B5:.5 G5:.5 B5:.5 D6:1 G5:1
15  E6:1 C6:.5 G5:.5 E5:.5 G5:.5 C6:1
16  D6:.5 B5:.5 G5:1 G5:.5 A5:.5 B5:.5 D6:.5
```

Gate .85 on half-beat notes, .92 on the others; the first note of each bar +2 dB.

**Pluck answers** (start on beat 3, +0.08 pan): bar 9 `A5:.25 C6:.25 F6:.5`; bar 10 `B5:.25 D6:.25 G6:.5`.

**Bass**, one pattern per chord, every bar:

| Chord | Bar pattern |
|---|---|
| C | `C3:1 C4:.5 C3:.5 G3:1 C3:.5 G3:.5` |
| F | `F3:1 F4:.5 F3:.5 C4:1 F3:.5 C4:.5` |
| G | `G2:1 G3:.5 G2:.5 D3:1 G2:.5 D3:.5` |
| Am | `A2:1 A3:.5 A2:.5 E3:1 A2:.5 E3:.5` |
| Em | `E3:1 E4:.5 E3:.5 B3:1 E3:.5 B3:.5` |

Bar 16 (G) ends `... G2:.5 B2:.5` in place of the last two notes, walking up to C.

**Off-beat chords** (pluck, gate 0.18 s, on beats 0.5, 1.5, 2.5, 3.5, bars 3 to 16):
C = E4 G4 C5; F = F4 A4 C5; G = D4 G4 B4; Am = E4 A4 C5; Em = E4 G4 B4.
**Pad** (bars 9 to 12, whole bars, -24 dB under the lead): the same three notes an octave lower.

**Drums**

| Part | Pattern |
|---|---|
| Kick | beats 0 and 2 every bar; also 2.5 in bars 4, 8, 12 |
| Brush | beats 1 and 3, from bar 3 |
| Shaker | every eighth; the off-beats 6 dB louder than the beats |
| Woodblock | bars 9 to 16: beats 1.5 and 3.75 |
| Fill, bars 8 and 16 | brush on 3, 3.25, 3.5, 3.75, rising 2 dB a hit; no kick on 2.5 in bar 16 |

Mix, relative to the lead: bass -4 dB, off-beat chords -12, kick -6, brush -10, shaker -18 (beats) and -12 (off-beats),
woodblock -14. Room: the script's wrapped delay network at ratio .05 (dry and tight). Every tail wraps (`add_wrapped`)
inside the 3.0 to 35.0 region so the loop has no seam; the lead-in's tails run on into bar 1.

### 2.3 `dash_win` (2.6 s, C major, the same 120 bpm)

| At (s) | What |
|---|---|
| 0.00, 0.13, 0.26 | Pickup: wood + glock `G5`, `C6`, `E6`, each 0.12 s, rising 2 dB a note. Under it a brush roll: 8 hits 0.05 s apart from -18 to -6 dB |
| **0.40** | **Hit.** Chord F: pluck F4 A4 C5 + bass F3 (0.45 s). Lead (wood + bell): `C6` 0.25 s. Kick + brush |
| 0.65 | Lead `F6` 0.25 s |
| 0.90 | Chord G: pluck D4 G4 B4 + bass G3. Lead `G6` 0.25 s. Kick + brush |
| 1.15, 1.275 | Lead `D6` then `G6`, 0.125 s each |
| **1.40** | **Home.** Chord C: pluck C4 E4 G4 D5, bass C3 + C4, pad C4 E4 G4 (fades to 2.6). Lead `C7` (bell + wood) with E6 and G6 under it, ringing 1.0 s. Kick, and an air swell (noise 3 to 6 kHz, 0.5 s decay, -14 dB) |
| 1.40, 1.46, 1.52, 1.58 | Glock sparkle `C6 E6 G6 C7`, -8 dB, low-passed at 4.5 kHz |
| 2.40 to 2.60 | Fade to silence |

Loudness: integrated about **-16 LUFS** (the hatch bursts are -15.7 to -18.3), true peak at or under -4.5 dBTP. Stereo, 48 kHz.

### 2.4 `dash_place` (1.8 s, warm, no drums)

| At (s) | What |
|---|---|
| 0.00, 0.20 | Kalimba recipe (from `synth_tip_chime.py`, ring .42 s) `E5`, `G5` |
| 0.40 | `C6`, held. Pluck chord C4 E4 A4 D5 (C 6/9, the garden's soft colour), bass C3, 0.6 s |
| 0.90, 1.05 | Kalimba `D6` (0.15 s) then `E6`, ringing out. It ends on the third: happy and a little open, "nice run" rather than "you won" |
| 1.60 to 1.80 | Fade |

Loudness: integrated about **-18 LUFS**, true peak at or under -6 dBTP.

### 2.5 The small cues

- `dash_line` (0.6 s): woodblock double tap at 0.00 and 0.07; wood `G5` at 0.05 and `C6` at 0.17; an air whoosh (noise,
  band sweeping 800 to 4000 Hz over 0.25 s, -12 dB). -18 LUFS short-term.
- `dash_best` (0.9 s): felt glock (the `glock` recipe, ring cut to .25 s, low-pass 4.5 kHz) `G5 C6 E6 G6` 60 ms apart,
  then `G6` + `C7` together at 0.30 ringing to 0.9. -18 LUFS short-term.
- `star_land` (0.22 s): one felt-glock `C6`, ring .12 s, low-pass 4 kHz, a 2 ms soft onset. Peak -6 dBFS.
- `stars_total` (0.7 s): wood `C6` + glock `G6` together, a 90 Hz sine thump (0.08 s, -10 dB), ring .3 s. Peak -4 dBFS.
- All mono, 44.1 kHz, fixed seed, written by one new script (`scripts/synth_dash_stings.py`) to `assets/audio/drafts/`
  for Spencer to hear before any upload.

## 3. Night garden song

### 3.1 Route A (recommended): a night mix of Spencer's own loop, in step with the day loop

His loop is a recording, so I cannot re-voice its melody note by note without its score or stems. What can be done from
the file, and is truly "the same song at night":

**Night bed**, made from `assets/audio/music/garden-loop.wav` by a script (`scripts/synth_garden_night.py`), same length
to the sample (2,894,770 frames, 44.1 kHz), so day and night play **in step** and can crossfade at any moment:

1. Low-pass, 4th order, at **1.8 kHz** `[check 1.5 to 2.5 kHz by ear]`, done on the whole loop in the frequency domain
   (circular, so the seam stays clean). The tune is heard as if from across the pond: darker, softer, lower.
2. Soften the hits: a slow gain rider (10 ms attack, 150 ms release) taking 3 dB off the loudest transients.
3. A longer, wrapped room: the music script's delay network at ratio **.22** (day is dry).
4. No tempo or pitch change. Slowing it would break the step with the day loop and make the crossfade a train wreck.

**Night overlay**, new and synthesized, mixed into the same file:

- **Music-box answers**: the felt `glock` recipe (ring .55 s, low-pass 3 kHz), 12 dB under the bed, one small phrase in
  the last bar of every four. A minor pentatonic (A C D E G), which sits over the A/E/G/C harmony I measured `[check the
  key by ear first; if the tune is in E minor, every C below becomes B]`. Beat = 0.5128 s (117 bpm `[check]`).

```
bar  4  r:2 E5:.5 G5:.5 A5:1
bar  8  r:2 A5:.5 G5:.5 E5:1
bar 12  r:1.5 D5:.5 E5:.5 G5:.5 E5:1
bar 16  r:2 C5:.5 D5:.5 E5:1
bar 20  r:2 E5:.5 G5:.5 A5:1
bar 24  r:2 C6:.5 A5:.5 G5:1
bar 28  r:1.5 A5:.5 G5:.5 E5:.5 D5:1
bar 32  (empty: the seam breathes)
```

- **Night air**: the `pad` voice on E3 + B3 through the whole loop, 20 dB under the bed, swelling 2 dB up and down once
  every 8 bars. `[check it does not rub against his chords; if it does, drop it]`
- No drums, no added bass.

If Spencer has the project file or stems for the loop, a fuller night arrangement (his melody on a music box an octave
lower, half the notes, no drums) is the better version of this; say so and I will write it from the stems.

### 3.2 Loudness

- Rule: **night sits 3 LU under day**. With the manifest's convention (garden -20 LUFS) that is **day -20, night -23**.
- The day file in the game today is his unaltered master at -17.6 LUFS, played at voice volume .088. Keep that untouched;
  master the night file to **-20.6 LUFS** (3 LU under it) and play it through the same voice volume, so the code has one
  number. True peak at or under -6 dBTP; loudness range under 4 LU.
- Night also has the cricket bed (.16); the low-pass leaves the crickets their band above 2 kHz.

### 3.3 Crossfade with the garden hour

- `GardenHour`: night is seconds 2880 to 3600 of the hour and opens with a 120 s blend; dawn (0 to 360) opens with a
  90 s blend. `Hour.isNight(t)` is the hard edge; the music wants the soft one.
- **Night weight w**: 0 by day; rises 0 to 1 with a smoothstep over the night blend (2880 to 3000 s); holds 1; falls 1
  to 0 over the dawn blend (0 to 90 s). Use the Hour module's own blend value if it exposes one `[check]`, so the music
  turns with the sky.
- **Volumes** (equal power): day = `MusicVolume * cos(w * pi/2)`, night = `MusicVolume * sin(w * pi/2)`.
- **In step**: both voices loop; when w first leaves 0, start the night voice at the day voice's `TimePosition`. Re-align
  if they drift more than 60 ms (check once per loop) `[check drift on the phone]`. When w is back at 0 for a second, stop
  the night voice. The day voice keeps running at volume 0 through the night so the step is never lost.
- **Gates**: only while the garden hour runs (`HollowClock.hourOn`); otherwise day only, exactly as now. The night voice
  lives in the same group as the world music, so the master, the music toggle, focus, the deck round, the race and the
  reveal ducks all apply to it with no extra rules.
- Joining at night: start both at 0 and take w from the clock at once (no 120 s wait).

### 3.4 Route B (fallback): the Little Afternoon score

Only if the game goes back to the synthesized garden track (the 104 bpm score in the repo). Night arrangement from the
same `MELODY`, `HARMONY`, `VOICES` arrays, 104 bpm, 32 bars, same length as the day render:

- Lead: `bell` (music box) at written pitch, low-pass 3 kHz, phrases 1 to 4 and 9 to 12 only; phrases 5 to 8 and 13 to 16
  are left to the pad. Reed answers become bell answers an octave lower at -12 dB.
- `pad` on every bar (the chord's notes 2 to 4), 18 dB under the lead; `bass` on beat 0 only, an octave lower where the
  root is at or above D3. No harp dyads, no ticks.
- Room ratio .22. Day -20 LUFS, night -23 LUFS. Crossfade as 3.3.

## 4. Tip chime set

Spencer: a few nice short ones, random pick and pitch. Six variants, one family, all in C pentatonic so any two heard
close together agree, every one **ending upward** (a falling end reads as an error).

| # | Notes | Gaps | Length |
|---|---|---|---|
| 1 | G5, C6 | 100 ms | 0.36 s |
| 2 | E5, A5 | 100 ms | 0.36 s |
| 3 | A5, E6 | 110 ms | 0.37 s |
| 4 | E5, G5, C6 | 80, 80 ms | 0.42 s |
| 5 | D5, G5, A5 | 80, 80 ms | 0.42 s |
| 6 | G5, E5, C6 (a dip, then up) | 75, 85 ms | 0.42 s |

**Recipes** (shortened from `synth_tip_chime.py`; same partials, shorter rings):

| Timbre | Change from the script |
|---|---|
| wood | note length .5 to **.26 s**; fundamental ring .16 to **.11 s**; other partials as they are; click as it is |
| kalimba | note length .9 to **.28 s**; fundamental ring .42 to **.14 s**; second partial .18 to .08 s |
| glock | note length 1.0 to **.28 s**; fundamental ring .55 to **.16 s**; 2.76 partial .16 to .07 s; low-pass 3 kHz stays |

- Note gains rise through a chime: .8, .9, 1.0 (two notes: .9, 1.0).
- `finish()`: fade 30 ms (was 20), peak **-3 dBFS** (was -1), and the six matched to within 0.5 dB RMS of each other.
- Render the six in **all three timbres** (18 drafts in `assets/audio/drafts/tip_chime_{wood,kalimba,glock}_{1..6}.wav`)
  so Spencer picks the timbre once; **ship six, one timbre**. My pick is wood: the driest and shortest, least like a phone.
  Mixing timbres in the shipped set would sound like three different notifications.

**Random pick and pitch**

- **Pick**: a shuffle bag. All six are played once in a random order before any repeats; when the bag refills, its first
  chime is not the one just played. So the same chime is never heard twice in a row and each is at least 5 plays apart on average.
- **Pitch**: playback speed from three steps, **0.891, 1.0, 1.122** (a whole tone down, as written, a whole tone up),
  never the same step twice running, plus a fine drift of up to 1.5% either way. Range 0.878 to 1.139. At the lowest
  speed the longest chime is 0.48 s; if that must stay under 0.45, drop the low step to 0.944 `[check by ear]`.
- Unchanged: volume .25, never more than once in 20 s, silent in a round, race or hatch and with sound off.
- Code shape: `TipChime.SoundIds = {…six}`, cues `tip_chime_1` to `tip_chime_6` in `BoardAudio`; `Chime.pitch(r)` becomes
  a pure `Chime.pick(state, r1, r2, r3)` answering the cue and the speed, so the spec can test the no-repeat rules.

## 5. Loudness summary

| Asset | Target | True peak | In-game volume |
|---|---|---|---|
| Garden day (as in the game) | -17.6 LUFS as mastered (manifest convention -20) | as is | `MusicVolume` .088 |
| Garden night | 3 LU under day: -20.6 (convention -23) | <= -6 dBTP | the same voice volume, times the night weight |
| Race loop "Hop to It" | -19 LUFS, range < 3 LU | <= -6 dBTP | .105 `[check]` |
| `dash_win` | about -16 LUFS | <= -4.5 dBTP | .6 |
| `dash_place` | about -18 LUFS | <= -6 dBTP | .5 / .4 |
| `dash_line`, `dash_best` | -18 LUFS short-term | <= -6 dBTP | .5 |
| `star_land`, `stars_total` | peak -6 / -4 dBFS | | .4 / .5 |
| Tip chimes | peak -3 dBFS, matched within 0.5 dB | | .25 |

## 6. Open checks, in one place

1. Spencer's loop: 117 bpm and the A minor / E minor reading (measured, not heard). Decides the night overlay notes.
2. Does Spencer have stems or the project for the garden loop? Then a real night arrangement beats the night mix.
3. `Sound.LoopRegion` on the phone for the lead-in + loop file; otherwise two files.
4. `count_blip`'s pitch against C major.
5. The rig channel names for arms-up and squash/stretch; armless pets.
6. The 34 pt spin jump on the short (132 pt) stage.
7. Race loop voice volume and the stings' volumes on the phone speaker, against the dash and jump cues.
8. Day and night voices staying in step on a phone over a full hour.
9. Whether a race of one that is not a trial can happen.
10. Nothing here has been rendered: every sound needs Spencer's ear before upload, as drafts in `assets/audio/drafts/`.
