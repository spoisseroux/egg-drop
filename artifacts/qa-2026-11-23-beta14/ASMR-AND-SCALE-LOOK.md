# ASMR hatching, vibration, and the size of the world: the feel (Fable, 2026-11-23)

For Spencer after beta (14): "we need asmr-y egg hatching etc, vibrations, maybe vibrations in the pocket deck game
too? this needs to be a cathartic experience" and "the world feels too small is what I'm saying".
Direction only; Opus builds. Builds on `V3-SCOPE-2026-11-21.md` section 13 (ASMR things to play with) and replaces the
last paragraph of W4 in `WORLD-AND-NEST-LOOK.md` (section 3 here).

**What I read:** `HatchCinematic.lua`, `HatchRarityCue.lua` (the timing policy and the foley line), `EggHatchView.lua`
(`eggBeat`), `HatchFlow.lua`, `NestClient.lua` (its two hatch cues), `BoardAudio.lua`, the deck's sound calls in
`init.client.lua` (2851 to 4295), `FieldEffects.lua`, `DeckMergeJolt.lua`, `DeckSettings.lua`, `BoardConfig.Tiers`,
`HollowWorldLayout.lua`, `IslandBounds.lua`, `scripts/synth_egg_drop.py`. The Roblox reference pages for
`HapticService` and `HapticEffect` (fetched today). **Nothing here has been heard, felt or seen in Studio or on a
phone.** There is no haptic code in `src` today. Every `[check]` is for Opus or Spencer to settle.

**The one idea:** catharsis is **build, release, stillness**. Small dry sounds get closer together, one full release
lands in the ear and the hand at the same instant, then a beat of quiet. Every section below is that shape at a
different size. Sounds are dry (no reverb, no music under them), close, and quiet enough to want to lean in.

**Rules for all of it**

- No AI audio. Everything is synthesised by script (a new `scripts/synth_asmr.py`, in the style of the other
  `synth_*.py`) or recorded by Spencer. Section 13.3 already says synthesised crunch may sound thin; so every recipe
  below also names **what to record instead** if Spencer does not like the render. He hears candidates first (13.4 A).
- Render these at **44.1 kHz, 16-bit mono**, not the 24 kHz of the older scripts: crunch lives at 4 to 10 kHz and
  24 kHz cuts it off. `[check]` nothing in the upload path assumes 24 kHz.
- Sound and vibration fire from the same call, so they land within one frame of each other. A buzz that trails its
  sound by 50 ms feels broken.
- Vibration never carries meaning on its own. Everything works the same with it off.

---

## 0. Vibration: what Roblox gives us

- **`HapticService` is marked Deprecated** on its reference page (`SetMotor`, `GetMotor`, `IsVibrationSupported`,
  `IsMotorSupported`; its sample only handles gamepads). Motors: `Enum.VibrationMotor.Large` (the low, heavy rumble)
  and `Small` (the light, sharp one). The enum also has `LeftTrigger`, `RightTrigger`, `LeftHand`, `RightHand`
  `[check]` (from memory, the page did not list them).
- **`HapticEffect` is the current way**: an instance with `Type` (`Enum.HapticEffectType`), `Looped`, `Position`,
  `Radius`, `:Play()`, `:Stop()`, `.Ended`, and `:SetWaveformKeys()` for `Type = Custom`. Keys are `FloatCurveKey`s:
  **time in milliseconds, value 0 (nothing) to 1 (full)**. Preset types include `GameplayExplosion` and `Custom`;
  I believe also `UIHover`, `UIClick`, `UINotification`, `GameplayCollision` `[check]`.
- **Build on `HapticEffect` with custom waveforms.** One client module (say `Haptics.lua`) owns a named pattern table
  and the rate cap of section 2; nothing else touches the API. Keep a `HapticService:SetMotor(Gamepad1, ...)` path only
  if a gamepad does not answer to `HapticEffect` `[check]`.
- **`[check]`, on real devices, before anything else is tuned** (a ten-minute test place: one button per pattern):
  1. Does `HapticEffect` vibrate an **iPhone**? An **Android phone**? (The reference page does not say. I believe yes
     for both; do not ship on belief.)
  2. Does intensity work? Many Android phones only do on / off, or two or three levels. If so, 0.2 and 0.6 feel the
     same there. **So every pattern below differs by length and by count of pulses, not only by strength.**
  3. The shortest pulse a phone will play. I ask for 12 to 25 ms ticks; some motors need 30+ ms to spin. If the ticks
     are missing or mushy on Spencer's phone, raise every tick to that floor.
  4. iPads and most tablets have no motor; desktop without a pad has none. The module must report "not supported"
     and the setting row hides (section 2).
  5. Where the instance must be parented to play, and what `Position` / `Radius` mean for a phone (leave them at
     their defaults unless the test shows they matter).
  6. Lag between `:Play()` and the buzz, by ear against a click sound. If it is over about 40 ms on the phone, fire
     the haptic a frame early.

Pattern notation below: **motor, strength, length**. "Small" = light and sharp (waveform value as given, short).
"Large" = heavy (on a phone there is one motor: Large patterns are simply longer and stronger). `a > b over N ms`
is a ramp.

---

## 1. The hatch as a ritual

### Today

The hatch is a film you watch: about **3.1 s** (pet 4.4 s; Rare item 3.6 s with the freeze and cannons). Three
`egg_wobble`s at 0.21 / 0.48 / 0.81 s, `egg_crack_glint` at 0.65, the shell opens at **0.98** with the tier sting.
A tap anywhere skips (not on the first hatch of each egg type). Nothing is felt, and nothing is done by the player.

### The change: you crack it

**Three touches crack the egg; the third opens it.** Each touch answers within a frame with a crack where the finger
landed. If the player does nothing, the egg does it alone on today's clock, so nothing ever waits on them.

| Beat | What the player does | What happens | Length |
|---|---|---|---|
| 0. Settle | nothing | The egg lands on its spot with a soft thud and one small rock. A quiet line under it: **`Tap the egg`** (first three hatches ever, then never again). | 0.25 s |
| 1. Rub (optional) | drags or holds a finger on the egg | The egg leans toward the finger (up to 6 degrees), a dry shell-rub sound follows the finger's speed, faint flutter in the hand. No progress: it is only for the pleasure of it. After 1.2 s of rubbing the egg cracks once by itself (counts as touch 1). | free |
| 2. Crack 1 | tap (or A / E / Space) | A hairline crack starts **at the tap point** and runs 20 to 30% of the shell. 2 to 3 flakes. A 3% squash and back. | answer in 1 frame; settle 0.18 s |
| 3. Crack 2 | tap | The crack forks (2 new branches, to 55 to 65%). 4 to 6 flakes. A shell creak as the egg bulges 4%. Light leaks through the crack (the pet's or item's palette colour, faint: this is the only hint of what is inside). | settle 0.22 s |
| 4. Open | tap | Creak (0.18 s, the egg swells to 108%, cracks reach 100%), **the pop**: the top lifts and shards fly. Then the tier's own ending, unchanged: Common and Uncommon burst at once; a **Rare still plays its wind-up, freeze and jackpot** (today's 0.77 s from wind-up to burst), so the jackpot stays a surprise. | 0.18 s + today's ending |
| 5. Stillness | nothing | **0.25 s with no new sound and no buzz.** Then one soft exhale as the reveal settles, and the pet's / item's entrance as today. | 0.25 s + 0.8 s |

- **Hands off:** each stage waits at most **1.1 s** for a touch, then cracks by itself with a wobble first (today's
  `egg_wobble`). Untouched, the whole thing runs about 3.6 s: near today's length. Touched briskly it runs about 2.2 s.
- **Holding** a finger down past stage 1 auto-taps every **0.32 s**: hold to hatch.
- **Input:** tap anywhere on the egg's half of the screen counts (a generous target), pad A, keyboard E or Space.
- **How it fits the code:** the cinematic already lets a host hold its clock (`clockHold`, `Cinematic:held()`). The
  three stages are a gate **before** today's age 0.98; from the open onward the existing `HatchRarityCue` line runs
  untouched (sting on the burst, jackpot timings, `quiet` windows). `[check]` that holding the clock before the burst
  does not trip `Cue:due`'s "jump over 0.25 s" rule and swallow the sting. The pre-burst `Policy.Foley` wobbles play
  only on a stage the player did not touch.
- **The nest's daily egg** (`NestClient`, `hatch_rise` then `hatch`) gets the same three touches and the same sound
  set. It is the calmest hatch in the game, so it should be the nicest.
- **Reduced Motion:** no squash, lean, bulge or flying shards (cracks appear, the shell fades as today). **All the
  sounds and the vibration stay**; they are not motion.

### The sounds, layer by layer

Naming: `asmr_<name>_<a|b|c>`. Every one-shot gets **3 variants** (different random seeds, not just pitch). Peak
levels are relative to the tier sting at 0 dB. None has reverb.

| Layer | When | Recipe (synth) | Or record |
|---|---|---|---|
| **Settle thud** `egg_set` | beat 0 | Sine 110 Hz dropping to 80 Hz over 50 ms, decay 70 ms. Plus a 2 ms click through a 2 kHz high-pass at -14 dB (the shell touching down). 0.12 s. -12 dB. | An egg set down on a folded tea towel. |
| **Shell rub** `shell_rub` (loop, 0.8 s, 2 variants) | beat 1, volume and pitch follow finger speed | Pink noise, band-pass 2.5 to 7 kHz. Multiply by a grain envelope: 40 to 60 grains a second, each 8 to 20 ms, random level 0.3 to 1. A slow 3 Hz wobble on the band centre (±400 Hz). Volume 0 at rest to -20 dB at a fast drag; playback speed 0.9 to 1.15 with speed. Fades in 60 ms, out 120 ms. | A fingertip circling on a dry eggshell, phone mic 3 cm away. |
| **Crack 1** `shell_crack1` | touch 1 | Three parts summed. (a) Snap: a 1 ms step through a 1.5 kHz high-pass. (b) Bite: white noise, band-pass 3 to 9 kHz, decay 12 ms. (c) Hollow body: damped sines at **420, 610 and 880 Hz**, decay 25 ms, -10 dB under the bite. Then a tail of **3 grains** (noise, 4 to 10 kHz, 2 to 4 ms each) scattered over 60 to 110 ms, each 4 dB quieter than the last. Total 0.16 s. **-9 dB.** | A thumbnail pressing through a clean eggshell half. |
| **Crack 2** `shell_crack2` | touch 2 | As crack 1, with the body a third lower (**300, 440, 640 Hz**, decay 35 ms), bite decay 18 ms, and **6 grains** over 150 ms. Total 0.24 s. **-6 dB.** | Two quick presses on the same shell. |
| **Creak** `shell_creak` | start of touch 3 (and under the bulge in touch 2, at -8 dB more) | Stick-slip: a train of 0.5 ms pulses whose rate glides **18 to 45 a second** over the length (irregular: jitter each gap ±20%). Each pulse rings two resonators: 900 to 1400 Hz (pick per variant, Q about 12) and 2.8 kHz (Q about 8), each decaying in 6 ms. Level rises 6 dB across it. **0.18 s** for touch 3 (a 0.35 s version for the Rare wind-up). -10 dB. | Slowly squeezing an eggshell half until just before it gives. A wicker basket also works. |
| **The pop** `shell_pop` | the open | Four parts. (a) Thump: sine **150 Hz dropping to 70 Hz** in 60 ms, decay 90 ms. (b) Pop: a sine chirp rising **520 to 1100 Hz** in 25 ms, decay 30 ms (the hollow "tok"). (c) Crunch: white noise 1.5 to 12 kHz, decay 35 ms. (d) Shard scatter: **12 to 18 grains** (2 to 5 ms, 4 to 10 kHz) over 350 ms, thinning out, the last few at -24 dB. Total 0.5 s. **-3 dB**, the loudest dry sound in the game, still under the sting. | Crushing a whole dry eggshell in a fist, once, close. Layer the synth thump (a) under it. |
| **Flake tick** `flake_tick` (5 variants) | each shard that lands, at most 4 per hatch, 30 ms apart at least | One grain: noise 5 to 9 kHz, 3 ms, plus a 2.4 to 3.6 kHz sine blip of 6 ms. -22 dB. | Shell crumbs dropped on a plate. |
| **Exhale** `hatch_exhale` | beat 5, 0.25 s after the pop | Pink noise through a band-pass (Q about 1.5) sliding **1.8 kHz down to 700 Hz**. Attack 120 ms, decay 600 ms. No pitch, no voice. 0.8 s. **-18 dB.** | Spencer breathing out slowly past the mic, off axis. |

The tier sting, the jackpot layer and the pet's entrance cue stay exactly as they are and still land on the burst.
`[check]` by ear that the pop does not mask the sting's first note; if it does, pull the pop's crunch (c) down 3 dB,
not the thump.

### What you see

- **Crack lines:** a 2 px dark line (#3A2E28 at 85%) with a 1 px light edge on its lower side, drawn from the tap
  point. Each stage's line grows over **0.09 s** (ease out), never instant. 4 seeded branch patterns per stage; the
  seed is the hatch's receipt, so the same hatch replays the same and two hatches rarely match.
- **Flakes:** small irregular shell chips, 3 to 7 px on a phone, the egg's own shell colour with a paler inside face.
  They fall with gravity, turn, land on the floor line and **stay** until the reveal (a little mess is part of it).
  Counts: 2 to 3, then 4 to 6, then 14 to 18 on the pop. Phone cap 24 on screen.
- **Squash:** touch 1: 3% for 0.12 s. Touch 2: bulge to 104% over 0.15 s, held. Touch 3: swell to 108% over 0.18 s,
  then the top half lifts 30% of the egg's height and tips back as the shards go. Use the existing `eggBeat` shape
  for the rocks.
- **Light:** from touch 2, a soft glow through the cracks in the reveal's palette colour, 25% then 60%. No white flash
  before the burst.
- Everything else on screen dims 15% during the ritual and the music ducks as it does today for `hatch`.

### In the hand

| Beat | Motor | Strength | Length | Note |
|---|---|---|---|---|
| Settle thud | Small | 0.20 | 20 ms | |
| Rub | Small | 0.10 | 20 ms on / 60 ms off while the finger moves | stops with the finger; never longer than 1.2 s in one go |
| Crack 1 | Small | 0.35 | 25 ms | one tick |
| Crack 2 | Small | 0.50 | 30 ms, gap 40 ms, then 0.25 for 20 ms | tick and a crumb |
| Creak | Small | 0.10 > 0.40 | ramp over 180 ms | the build; ends exactly on the pop |
| **Pop** | **Large** | **0.90** | 60 ms, then 0.90 > 0 over 120 ms | the release |
| Stillness | none | 0 | 250 ms at least | do not fill it |
| Exhale | none | | | sound only |
| Common / Uncommon burst | (the pop is the burst) | | | |
| Rare: wind-up | Small | 0.10 > 0.50 | ramp over the wind-up | with the long creak |
| Rare: jackpot burst | Large | 1.00 | 80 ms, then > 0 over 200 ms | |
| Rare: each cannon | Small | 0.40 | 30 ms | two, as timed today |
| Rare: stamp | Large | 0.70 | 50 ms | on today's 2.30 |
| Pet's first hop lands | Small | 0.20 | 20 ms | |

### The 100th hatch

- **Variation:** 3 variants per sound, never the same twice running; playback speed 0.94 to 1.06 and gain ±1.5 dB at
  random; crack patterns seeded per hatch; the crack starts where you tapped, so no two feel placed the same.
- **Per egg type:** each egg type gets a `shellPitch` (for example 0.90 thick and low, 1.00, 1.12 thin and bright)
  applied to the crack and pop set, so the Pet, Toy and Customization eggs do not share one sound `[check]` the list
  of egg types and what their shells are meant to be; tell me if one is not a shell at all (the Toy Egg has a lid).
- **Streaks:** "Hatch another" within 20 s of the last hatch: the 2nd in a row needs **two** touches, the 3rd onward
  **one** touch (the three cracks cascade 90 ms apart, then the pop). The pop, the stillness and the exhale are never
  shortened. The exhale plays on the first hatch of a streak and every third after it, not every time.
- **Skip:** tap-anywhere can no longer mean skip, because tapping is now the ritual. A small **`Skip`** pill, bottom
  right, 44 px high, appears under today's rule (not on the first hatch of each egg type). Skip still rings the sting
  once (today's behaviour) with one Small 0.3 / 25 ms tick. Pad B / Esc skip too.
- **Loudness:** the whole dry set follows the Sound setting. On "Quiet" the dry set drops less than the music does
  (it is already quiet) `[check]` how `DeckSettings.Sound` is applied per group.

### "etc": the same shape elsewhere (small, after the hatch lands)

| Moment | Sound | Hand |
|---|---|---|
| **Petting** (held) | today's | A purr: Small 0.12, 25 ms on / 15 ms off, for as long as the hold, fading out over 300 ms on release. The only long vibration in the game; it stops the moment the finger lifts. `[check]` that a 25 Hz pulse train reads as a purr and not as a phone ringing. |
| **Snack crunch** (feeding) | today's | Small 0.30, 20 ms on each bite, at most 3. |
| **A Star lands in the wallet** | today's `star_land` | Small 0.12, 12 ms, at most 12 a second. |
| **Find picked up** | today's | Small 0.30 / 25 ms, gap 50, 0.45 / 30 ms. |
| **Race finish, first place** | per `RACE-AND-MUSIC-LOOK.md` | Large 0.70 / 60 ms, then two Small 0.30 / 25 ms. |

The world toys of V3 section 13 (keycaps, crunch patch, pop pad) each get one tick per press (Small 0.25 to 0.40,
15 to 25 ms) through the same module and the same cap.

---

## 2. Pocket Deck: vibration and crunch

### What buzzes

The deck has five ball tiers (I to V). In the code `land` is a ball hitting the floor or pile, `bank` is a ball
hitting a side wall, `overflow` is the danger line, and a merge reports the new tier, the chain count and "cleared"
(two tier V balls).

| Event | Motor | Strength | Length | Rule |
|---|---|---|---|---|
| **Drop** (release) | Small | 0.15 | 12 ms | Every drop: the finger's own click. |
| **Land** | Small | `0.30 * clamp((speed - 25) / 45, 0, 1)` | 15 ms | Only the player's own just-dropped ball, only its first hit, only above speed 25 (the same `strongest` value that sets the sound's volume `[check]` its range; the sound code divides by 70). Settling and rolling never buzz. |
| **Bank** (side wall) | none | | | Too frequent, means nothing. |
| **Merge to II** | Small | 0.30 | 25 ms | |
| **Merge to III** | Small | 0.45 | 35 ms | |
| **Merge to IV** | Large | 0.55 | 45 ms | |
| **Merge to V** | Large | 0.75 | 60 ms, then > 0 over 80 ms | |
| **Clear** (V + V) | Large | 1.00 | 80 ms, then 0.40 for 120 ms | The biggest thing the deck does. |
| **Chain** | adds to the merge | +0.08 per chain step past the first, up to +0.25 | +5 ms per step, up to +20 ms | A chain feels like it is climbing. Merges of one chain that land within 90 ms of each other become **one** buzz at the strongest one's values. |
| **Danger starts** (pile crosses the line) | Small | 0.30 | 30 ms, gap 60 ms, 30 ms | Once when it starts. Not again for 4 s. Never a continuous warning buzz. |
| **Round lost (overflow)** | Large | 0.60 > 0 | fade over 300 ms | One long sigh. |
| **Round won / goal met** | Large then Small | 0.60 / 0.30 | 50 ms, gap 70 ms, 25 ms | |
| **Results: each Star counted** | Small | 0.12 | 12 ms | At most 12 a second; the last one 0.30 / 25 ms. |
| **New best** | Large | 0.60 | 50 ms, then Small 0.30 for 100 ms | |

Merge length grows with tier so the tiers still differ on a phone that only does on / off.

### The cap (so it never buzzes constantly)

All of the game's vibration goes through one gate:

1. **At most 6 starts in any 1 s**, and at least **70 ms** between starts.
2. **At most 250 ms of motor-on time in any 1 s** (the clear, the round end and petting are exempt).
3. **Priority** when over: clear > round end > merge V > IV > chain add > III > II > danger > land > drop > Star tick.
   A lower one is **dropped, never queued** (a late buzz is worse than none). A higher one may cut off a lower one
   that is playing.
4. **Mirror and spectate:** only the local player's own board buzzes. A friend's board never does.
5. Nothing buzzes while the app is in the background, in a menu over the board, or during a snapshot replay / resync.

### The setting

- **One switch for the whole game: `Vibration`, On / Off**, in the Pocket menu beside Sound and Music, saved with them.
- **Default: On** where the device supports it. The row is **hidden** where it does not (no motor, no pad).
- Turning it On plays one sample: Small 0.45 / 30 ms. So the player learns what they just chose.
- Two levels only. If the device test shows strengths work well everywhere, a third "Soft" level (all strengths
  x 0.5) is a cheap later addition; do not build it first.
- `[check]` whether Roblox or the phone's own "vibration off" / silent setting already mutes `HapticEffect`. If the
  system setting does not, our switch is the only one, so it must be easy to find.

### Squishier, crunchier merges

Today: `merge_bubble` for tier II, `merge_jelly` for III to V, pitched by chain, three voices each, plus
`merge_chain`. They are pleasant and all one texture. Give each tier its own material, so a climb through the tiers
is a climb through textures: **wet, squish, crunch, thock**. Chain pitch (`mergePitch`) and the chain accent stay.

| Tier made | Character | Recipe (3 variants each) | Or record |
|---|---|---|---|
| **II** `merge_pop` | a small wet pop | Sine chirp **380 to 900 Hz** in 28 ms, decay 40 ms. Plus a 6 ms noise click (3 to 8 kHz) at the start, -12 dB. 0.07 s. | One bubble of bubble wrap, close. |
| **III** `merge_squish` | a jelly squelch | Body: sine falling **180 to 120 Hz** over 110 ms, its pitch wobbled at 22 Hz by ±15%, decay 110 ms. Wet: noise through a band-pass sliding **900 up to 2400 Hz** over 70 ms (Q about 3), -8 dB. 0.13 s. | Pressing a thumb into slime or a peeled grape. |
| **IV** `merge_crunch` | squish with a bite | The tier III body, 15% lower. Plus **5 crunch grains** (noise 2 to 6 kHz, 3 ms each) in the first 60 ms, random gaps, -6 dB. 0.15 s. | Biting a crisp apple slice or pressing honeycomb. |
| **V** `merge_thock` | a deep keycap thock | Sine **140 Hz**, decay 80 ms. Plus a 1.1 kHz resonance (Q about 10), decay 20 ms, -8 dB. Plus a 2 ms click at the start. 0.11 s. This is the "thocky" keycap of section 13, on purpose: one sound family across the deck and the garden. | A thick keycap bottoming out on a desk mat. |
| **Clear** `merge_clear` | the release | The thock, plus the hatch's shard scatter (12 grains over 300 ms), plus a soft rising sine 300 to 600 Hz over 180 ms at -14 dB. 0.4 s. | |
| **Land** (touch-up) `land` | soft and dry | Keep, but add a 2 ms tack (noise, 2 to 5 kHz, -16 dB) at the start so a land has an edge to feel with the tick. | |

Mix: these sit at today's merge level (0.56 before the burst reduction). The existing "more merges at once = each
quieter" rule (`.68^mergeBurst`) stays, so a big chain is a texture, not a wall.

**Order to build:** the device test of section 0; the `Haptics` module, the cap and the setting; deck patterns on the
existing sounds (Spencer can feel it the same day); then the sound test (hatch set + merge set, 13.4 A) for Spencer's
ears; then the hatch ritual; then the new merge sounds if he picks them.

---

## 3. The world is too small

Spencer has now said it twice, the second time after my "do not rescale, make it feel bigger" answer. That answer
was right about rescaling and too timid about the rest: I parked the real fix behind "if it still feels small".
He is telling me it does. So here are the three options, and a recommendation.

**The facts:** the walkable island is about **228 x 176 studs** (`HollowWorldLayout`: Width 228, Depth 176, centred
(4, -2)); my earlier note said 185 x 175, which was the land, not the floor. At 16 studs a second it is crossed
corner to corner in about 18 s. There are four stations, the park, the race and the nest on it: it is full.

### Option A: make it feel bigger (approved, being built)

Lower camera, zoom cap, haze, four far islets, three sightline breaks, small ground detail, the walk-speed test.
**Cost:** small, days. **What it does:** the same ground reads as a bigger place. **What it does not do:** add one
stud to walk on. If Spencer's complaint is "I run out of places to go", A alone cannot answer it. Keep building it:
it is cheap and both other options need it anyway.

### Option B: add a second place, joined by a bridge (recommended)

**What:** a second, smaller island, lower and quieter than the first, reached by a long footbridge over open sky.
It is where the ASMR things of V3 section 13 live. That section's own blocker is "a spot that clears the race route
and the parks"; the main island has no such spot. One build answers both asks.

- **Where:** off the **west edge**, the far side from the arrival dais at (96, 66), so the walk there passes through
  the hub and the bridge is the last thing you find. Bridge head on the main island at about **(-108, y, 5)**, past
  the west stream crossing (`WestBridge` at (-83, 35)) and the west lamp (-70, -3) `[check]` with the island session
  that the rail and ground there can take a gate: flat ground, no cliff face, clear of find spots.
- **The bridge:** **45 studs long, 7 wide**, rope-and-plank, a slight sag, dropping **6 studs** to the far end (about
  8 degrees, walkable). Rails on both sides. It sways a little in the big breath (W3 row 1). The planks get the
  section 13 "creaky" footstep: the bridge is the first ASMR thing. About 3 s of walking with nothing but sky under
  you, which is what makes a world feel big.
- **The islet:** about **110 x 80 studs**, centred about **(-208, y - 6, 0)**. Being lower, you see it from the main
  island's west rail, and from it you look back up at the whole garden from outside: the first time the player sees
  how big their home is.
- **What lives there** (three small rooms, each hidden from the next by a tree clump):
  1. **The keycap path** (13.2 item 1): a curved walkway of about 24 big keycaps in three patches (clicky, thocky,
     creamy), from the bridge foot to the middle.
  2. **The crunch patch and pop pad** (items 2 and 3): a bed of crisp leaves about 12 x 8 studs and a pop sheet beside
     it, with a bench.
  3. **The quiet end:** a small pond or lookout at the far tip with one bench facing back at the main island, and
     nothing to do there. Every chill-out world has one spot that is only for standing in.
  Plus: 4 to 6 new find spots (a reason to cross for players who do not care about toys), 2 lamps, Dewdrop trees.
  No station, no shop, nothing sold, no prompts beyond the toys. Matte, textured, low-saturation like the rest.
- **Size of the change:** about **+20% ground** `[check]`, and the longest walk in the world goes from about 290
  studs to about 400 (arrival dais to the quiet end), across a bridge and out of sight of where you started.
- **Cost: large, but all new work, nothing redone.**
  - Art (island session, Blender): the islet, the bridge, about 8 props. Phone budget `[check]`: aim under 20k
    triangles and 6 new textures.
  - Code: the walk map and safe-ground sweep cover a second region (`GardenWalkability`, `IslandGround`,
    `sweep_island_edges.py`); the bounds ring and fall catch around it (`IslandBounds`); the single rectangle that
    pets and the camera clamp to (`Width` / `Depth` / `FloorCenter`) becomes two regions and a bridge strip; pets must
    follow across the bridge (the planner's grid) `[check]` this is the riskiest piece; move the far islet of
    option A that sits on the west bearing; leaves, Dewdrops and lamps extended by list.
  - The ASMR toys themselves are section 13 slices B and C, already scoped.
  - Rough size: 5 to 7 build slices. Nothing on the main island moves, so nothing that works today can break
    from it; it can sit behind a flag on the beta until it is good.
- **A cheap proof first:** before any art, greybox it on the beta: a plain 45-stud bridge and a flat 110 x 80 slab
  with three tree clumps, walkable by the player only (no pets yet). Half a day. Spencer walks it and says whether
  this is the "bigger" he means. If it is, the art starts; if not, we have lost half a day.

### Option C: a true rescale

**What it means.** Take 1.3x as the example (island about 296 x 229).

- If the **world mesh is scaled up**: every prop grows too. The arch goes from about 14 studs to 18, paths from 6
  wide to 8. The player and pets stay the same size, so the world reads as **chunkier and emptier**, not bigger, and
  every texture gets 30% blurrier. This makes the "everything is the same grain" problem worse.
- If instead **things are pushed apart at their current size**, that is not a rescale: it is re-authoring the whole
  island in Blender, which is more work than option B and still adds nothing to do.
- Either way, every number tied to a place moves: `HollowWorldLayout` (spawn, hub, four stations, rest daises,
  bridges, lamps), `WorldV7Data`, `ParkLayout` and every piece of park equipment, the Dash course, its pad and its
  queue ring, find spots, the nest spot and its blocked region, `IslandBounds` walls, the safe-ground sweep, the walk
  map grid, leaf and Dewdrop spots, camera offsets, prompt and billboard distances, and every spec that pins a
  coordinate. The race gets 30% longer, so pet speeds or race times and any saved bests change `[check]` whether best
  times are saved.
- **Cost: very large, about two to three times option B,** and all of it is re-doing things that work, with a real
  chance of breaking the race, the park or pet walking on the live game. At the end there is the same content,
  further apart, with longer walks between the same four stations.

### Recommendation: B, with A carrying on underneath

In plain words: **scaling up makes the same garden emptier; adding a place makes the world bigger.** A rescale spends
the most work, risks the most, and adds nothing to do. A second island spends less, breaks nothing, gives the ASMR
toys the home they need, and gives the player the two things that make a world feel large: somewhere they cannot see
from where they stand, and a walk to get there.

What I need from Spencer:

1. **Yes or no to B**, starting with the half-day greybox on the beta.
2. If yes: **west edge** as proposed, or does he have a side in mind?
3. A working name. Mine is "the Hush" (the quiet island); his call.

If after B it still feels small, the answer is the same again (a third place, another bearing), never the rescale.

---

## 4. Captures and checks I want back

- **Haptics:** the device test results of section 0, as a table: device, vibrates (y / n), strengths felt (how many),
  shortest clean tick, lag.
- **Sound test:** one WAV per recipe and variant, plus a 20 s strip of a full hatch (touched) and a 20 s strip of a
  deck chain II > III > IV > V > clear, for Spencer's ears first, then mine.
- **Hatch:** a phone clip of three hatches in a row (first, streak 2, streak 3), one Rare, one skipped, and one with
  hands off. A still of each crack stage.
- **Deck:** a log of haptic starts over a 60 s busy round (to prove the cap: never more than 6 in a second).
- **World:** the greybox walk: a clip from the hub over the bridge to the far tip, and a still looking back.
