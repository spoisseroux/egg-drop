# Aero + Juice brief (beta 36, 2026-11-26)

Fable, for Opus, on Spencer's beta (36) notes. Looks and feel only: no rule, radius, odds, payout or save changes; all behind the existing switches (Alive "asmr", Levels juice, Reduced Motion, AliveBudget).

## 0. Research, in my words

- **Suika-likes**: the pleasure is physical: a soft pop, the new ball arriving slightly too big and shoving its neighbours, chains that reshuffle the box. Calm music, no clock ([Wikipedia](https://en.wikipedia.org/wiki/Suika_Game), [Destructoid](https://www.destructoid.com/suika-game-has-me-raging-about-watermelons/); commentary, no postmortem found).
- **Candy Crush**: sound rewards good moves; each cascade step repeats the cue a semitone higher; a praise word scales with the cascade ([Game Developer](https://www.gamedeveloper.com/audio/why-candy-crush-saga-is-so-engaging-an-audio-breakdown)).
- **Juice theory**: one input, several redundant reactions; but if everything is loud, nothing reads ([Aalborg thesis](https://projekter.aau.dk/projekter/files/260041471/MASTER_of_Juiciness__1_.pdf), [Designing Sound](https://designingsound.org/2017/11/19/sunday-sound-thought-96-juicy/)).
- **Do not copy**: fruit, candy, their praise words, voice, fonts or frames, life timers, "out of moves" upsells, near-miss teasing. Our bones are right (`BoardAudio.ChainSemitones`, `DeckMergeJolt`, `Haptics.mergePattern`); this pass adds **contrast and layers**, not volume.

## 1. Default ball palette: "Aero Glass"

**Decision: stay in the pixel style.** The 64-wide `JellyLCD` is the handheld's identity and its span budget is proven; the gloss goes in the shader.

New `aero` ramps replace `vivid` for `smileys` and `marbles` (ids, names, colour words unchanged). Two optional ramp fields, `rim` and `spec`; themes without them render as today.

| Tier | Word | body (base) | light (highlight) | deep (shade) | rim (bounce) | spec |
|---|---|---|---|---|---|---|
| I | blue | `#22B8F2` | `#A6ECFF` | `#0B74D1` | `#5FE3FF` | `#FFFFFF` |
| II | orange | `#FFB52A` | `#FFEFA3` | `#EC7A0E` | `#FFD866` | `#FFFFFF` |
| III | green | `#2FCB5A` | `#C4FF9A` | `#0E8F45` | `#7CF08A` | `#FFFFFF` |
| IV | pink | `#FF6FA8` | `#FFD3E6` | `#D8327E` | `#FFA3C8` | `#FFFFFF` |
| V | violet | `#7D5CF0` | `#D6CBFF` | `#4426C2` | `#A893FF` | `#FFFFFF` |

Ink stays `#15102B` (4.1:1 on violet, 7:1 or better on the rest).

**Bubble treatment (shader, per ball):**
1. Vertical gradient: `light`-lerped body in the top 35%, `body` in the middle, `deep` in the bottom 25% (3 bands; no dither on tiers I and II).
2. Specular: a 2x1 px `spec` bar upper-left (3x2 on tiers IV and V) plus one separate 1 px dot below-right of it. The two-part glint is the "wet glass" read.
3. Bounce crescent: a 1 px `rim` arc along the lower-right inner edge, tiers III to V only (replaces today's rim light).
4. No outline. Bloom stays, using `body`.
5. Over `SimplifyAbove`, drop 3, then the dot of 2.

**Before / after.** Today's `vivid` is five neon candies at similar value; blue `#2E8BFF` and violet `#A66BFF` sit 5 ΔE apart under simulated deuteranopia, 8 under protanopia (Machado matrices, CIELAB). Aero Glass moves blue to aqua, orange to sun-gold, green to leaf, pink to lotus, and makes violet the darkest. Worst pairs after: 34 deutan (blue/violet), 22 protan (orange/green), 14 tritan (blue/green: tiers I and III, twice the radius apart). L* runs 70, 79, 72, 66, 50. Size circles and faces stay the non-colour cue. Simulated only. Gate: a BallThemes spec asserting 20 ΔE or more between any pair under deutan and protan.

## 2. Pocket Deck juice pass

**P1. Merge, the core hit** (`JellyLCD`, `FieldEffects`, `BoardAudio`, `Haptics`).

| Beat | Time | What |
|---|---|---|
| Anticipation | -60 ms to 0 | The two balls squash 8% toward each other. |
| Impact frame | 0 to 33 ms | Result ball drawn solid `light`; a 1 px `spec` cross at the contact point. Tiers IV and V: hold the *presentation* 40 ms (never the simulation). |
| Overshoot | 0 to 260 ms | Keep `MergePop` 0.10, then a damped wobble: 1.10, 0.96, 1.02, 1.0. |
| Ring | existing | Tiers IV and V get a second ring, 60 ms late, 60% alpha. |
| Beads | 0 to 450 ms | The 6 fragment slots become round glass beads in `light`, with gravity. Tier V and clears: 12 (hard cap). |
| Neighbour nudge | 0 to 120 ms | Balls within 1.5 r get a 1 px face-only bump away (the shiver path; max 6). |
| Shake | existing | `Jolt.Kick` unchanged (16 px peak, +12% a chain step). Do not raise it. |

Sound, three layers at most. **Body**: `merge_bubble` on tiers I to III, `merge_jelly` on IV and V, pitched down by tier (1.12, 1.0, 0.92, 0.84, 0.76). **Sparkle**: new `merge_glass_tick` (3 variants, gain .18), chain 2 and up. **Sub**: new `merge_thump` (gain .35), tiers IV, V and clears. Chains keep `ChainSemitones` (0, 2, 4, 5, 7, 9, 11, 12); past chain 8 hold the octave and play the sparkle an octave up. Per play: speed 0.97 to 1.03, gain ±1 dB, no variant twice running. Duck music 2 dB for 250 ms on tier V and clears only.

Haptics: add `drop` (Small, .15, 12 ms, priority 1) and `land` (Small, .25, 18 ms, priority 2), own board only, inside the existing gate.

**P2. Combo escalation.** Chain 3: the well's top inner shadow tints to the merged tier's `light` for 300 ms. Chain 4: a column of 4 beads rises up both banks. Chain 5 and up: one praise word punches in over the well for 600 ms (`PunchScale` 1.45, like "+N"); original words through UICopy, e.g. "Bubbly!", "Fizzy!", "Sky high!". Chain 7 and up: one white light sweep across the faceplate (the plate's own gloss overlay, alpha to its `max` for 400 ms). Nothing stacks above a clear.

**P3. Drop and land.** The held ball breathes (±3% scale, 1.6 s). On release: 6% stretch along velocity for 80 ms. On first contact: 10% squash, 140 ms recovery, 2 dust beads, the `land` cue pitched by tier, the `land` buzz. Aim dots drift along the path at 6 px/s.

**P4. Idle life.** Add to the blinks: a spec twinkle (the bar shifts 1 px and back; one ball every 1.2 to 2.5 s); the matching ball's bloom pulses ±15% at 0.8 Hz; after 5 s idle one bubble rises in the well every 2 s (max 3).

**P5. UI reactivity ("more digital, more moving").** On the Toy Shell cards; effects sit under text at 10% alpha or less, or on borders.
- **Rolling counters**: score and Stars roll digit by digit, 250 ms a change, 600 ms at most, `count_blip` every 60 ms at most. The real value is set at once for screen readers.
- **Caustics**: one original 256 px tiling light-net (script-drawn), scrolling 8 px/s at 6% alpha on card backs and the well.
- **Scanline**: a 2 px bright line down the LCD glass every 7 s, 5% alpha.
- **Glints**: a 45-degree white sweep (300 ms) on a button's appear and release; the idle primary button sweeps every 6 s.
- **Press**: 0.94 scale in 60 ms, back through 1.04 in 140 ms; `menu` cue +2 semitones on release.
- **Goal chips** pop 1.0, 1.25, 1.0 with a tick on progress.

**Phone budget (hard).** Pools only, no Instances per event (as `FieldEffects`). At most 0.6 ms and 40 property writes a frame on a mid phone; at most 12 beads, 8 bubbles, 3 scrolling textures, 6 one-shot voices. AliveBudget level 1: no caustics, no idle bubbles, single ring. Level 2: body sound, overshoot and haptics only. Reduced Motion: no shake, hit-stop, sweeps or scrolls; counters jump; sound, haptics and slow colour tints stay. Ship gate: a 600x360 capture at chain 7, every ball edge and the fill line readable.

## 3. Hatch screens: Aero colour system

Replace `HatchRarityCue.Stage` and the warm lights in `RevealStage` (`#FFE9C4`, `#FFE2A8`, `#FFF2D6`, `Stage.Light.glow`). The orange sunburst goes; the Bear (Common) gets sky.

| Tier | Name | core | edge | ray | floor | deep | pattern | motion |
|---|---|---|---|---|---|---|---|---|
| Common / Neutral | Sky | `#C9F1FF` | `#2FA8F0` | `#FFFFFF` | `#F4FFFF` | `#0E5FB8` | bubbles | rays still; 6 bubbles rise 20 px/s |
| Uncommon | Meadow | `#E4FF9E` | `#2DBE4E` | `#F6FFC8` | `#FBFFDC` | `#0B7A3A` | bubbles, dew glints | rays 18 deg/s; 10 bubbles |
| Rare | Aurora | `#C4F6FF` | `#7D5CF0` | `#FF9AE0` | `#FFEAF9` | `#2E1C9A` | diamonds | rays 12 deg/s, aqua-to-pink sweep 4 s; 16 bubbles, 12 sparkles |

`Look.back` to `backDeep`: Common `#D9F4FF` to `#58B8F2`; Uncommon `#DFFFB0` to `#2DBE4E`; Rare `#D9CCFF` to `#5340D8`.

- **Rays**: 12 soft white shafts from top-centre (sun through water), 10 to 18% alpha, not a burst behind the pet. One warm lens glint (`#FFE58A`, 24 px, 30% alpha) keeps it sunny. Spencer rejected a "sad blue-ish" teal on v850: this must read as saturated midday sky, never grey-teal. Check on a phone.
- **Horizon**: a glossy grass arc (`#7BE04A` to `#2DBE4E`, 1 px white highlight) across the bottom 18% on Common and Uncommon; Rare gets a glass floor.
- **Bubbles**: 1 px white rim, 2 px spec, 8 to 28 px, 35% alpha, rising with a 6 px sway; they pop at the burst.
- **Egg-type accent** (bubble rims and confetti only): companion `#FFE58A`, stat `#FF9A5C`, toy `#FF6FA8`, material `#B9C6FF`, feature `#7CF08A`, hue rainbow, name `#FFFFFF`.
- **Plates**: white glass at 85%, `#0E0F12` ink. Gold `#FFC14D` for Stars only.
- **Reduced Motion**: still rays and bubbles.

## 4. The onboarding 3D crack

**Remove first (Spencer):**
- The glow disc behind the Welcome deck's 3D egg (`V2.Deck.glow`, `glowIdle`, `glowFinal`) and the Neon `Core` showing through the garden egg before the pop. I could not tell from code which one he means; confirm in Studio and remove both. The core may flash only inside the pop.
- The lit crack seam on the Welcome deck egg. The UI egg stays whole (hop, wobble, pips, tuck); all cracking is 3D.
- CrackFx's cream ring. Keep its pill and ghost hand.

**Cracks on the shell, not on the screen.** Three script-drawn stages of the Companion Egg colour map, swapped through `TextureID` (works at runtime; SurfaceAppearance does not), each fading in over 90 ms on a duplicate shell at +0.5% scale. Fallback: today's CrackFx polylines.

**Per tap** (three taps; no timer shown; hand at 3 s, auto at 7 s, as now):

| ms | Tap 1 | Tap 2 | Tap 3 |
|---|---|---|---|
| -40 to 0 | egg dips 3%, widens 2% | dips 4% | dips 5% and holds |
| 0 | `crack1` + new `tap_knuckle`; buzz `crack1` | `crack2` + `tap_knuckle`; buzz `crack2` | `creakLong`; buzz `creak_long` |
| 0 to 90 | stage 1 grows from the tap point | stage 2 forks; a thin cream light leak along the seam (a line, 25% alpha) | stage 3 rings the egg |
| 0 to 400 | rock 10 deg, damped, 2 cycles | rock 14 deg, 3 cycles | shell flex: scale 1.00 to 1.08, 5 Hz rising to 9 Hz over 250 ms |
| 30 to 500 | 4 shell crumbs (3D, 0.04 to 0.08 studs) fall and bounce once, each a `flake` | 6 crumbs; `creak` under at 40% | 3 crumbs skitter |
| after | camera 3% closer | camera 3% closer; ambience ducks 3 dB | the pop |

**The pop.** 80 ms of near silence first (everything ducks 6 dB). Then in one frame: `asmr_pop`, the `rarity_common` sting, new `shell_scatter` (a dry clatter tail, 0.6 s); the Bear's own cue 120 ms later. The top shell flies up 3 studs; 12 to 16 pieces arc out and land with `flake` ticks (5 voiced). White flash, 120 ms at 35% alpha. Buzz `pop` (major). Camera: 0.15 stud kick back, FOV 40 to 44, settling to 42 over 400 ms; hold 600 ms on the Bear's first blink before the card. Then 2 to 4 late flakes and the `exhale`.

**New takes** (`synth_asmr.py`, original): `tap_knuckle` a/b/c (dry fingernail on shell, 40 ms), `shell_scatter` a/b, `crumb_bounce` a/b/c, `asmr_crack3` a/b (thicker, for stage 3). `HatchAsmr` variation rules apply. Existing ids cover the rest.

**Reduced Motion:** no camera moves, rock, flex or flash; stages swap; 3 crumbs (`ReducedFlakes`); all sound and buzz stay.

## 5. Weekly world reskins

**What exists.** "Weekly" in code is `WeeklyShelf` (three discounted items by week number) and the weekly quests; I found no world rotation in `src/shared` or `src/server`. So yes: reskins first.

**A reskin is a values table**, like `WorldDusk`: a pure `WorldWeek` module keyed by `Shelf.week(now) % #Weeks`, applied as deltas over the four garden-hour phases through the one Lighting writer (HollowClock, AeroWorld). Same week for everyone; no server state or saves.

- **Cheap (values):** sky and cloud tint, Atmosphere colour and haze, grade tint, foliage and grass `Tint`, `glow_warm` lamps, balloon and bunting colours, water tint, particle colours.
- **Medium:** one prop set a week (6 to 10 placements of 1 or 2 meshes), a music layer over the base bed.
- **Costly (not a reskin):** terrain, layout, new sky art, collidables.

| Week | Name | Sky / haze | Foliage tint | Lamps; balloons | Prop | Music layer |
|---|---|---|---|---|---|---|
| 1 | Bluebell Morning | `#CFEFFF` / `#8FCBF5` (today's Aero) | `#E6FFE0` | `#FFC96A`; aqua, white | bluebell clumps | none |
| 2 | Sherbet Skies | `#FFE4EC` / `#FFB8A8` | `#F2FFD0` | `#FFB3DA`; peach, mint | paper pinwheels | marimba |
| 3 | Dewdrop Meadow | `#D8FFF0` / `#9FE8C8` | `#D6FFC0` | `#C8FFD9`; lime, white | glass dew beads | soft bells |
| 4 | Lantern Glow | `#FFE9C0` / `#FFC078` | `#F6F0C4` | `#FFD27A`; amber, cream | paper lanterns | warm pad |
| 5 | Bubble Tide | `#C4F2FF` / `#6FD0F0` | `#DFFFF0` | `#8FD2FF`; aqua, lilac | more drifting bubbles | water chimes |
| 6 | Starlit Lilac | `#E4DCFF` / `#A893FF` | `#E8F0FF` | `#C4B5FF`; lilac, silver | hanging paper stars | celesta |

Surroundings stay matte (ambient-realism rule): tints move at most 12% from baseline; run the pale-pet washout check on every phase.

**Rotation.** Rolls Monday 05:00 UTC with the shelf week, 12 s cross-fade; a sign by the gate names the week. No countdown, nothing earned only then: every week returns in six.

## 6. "Only this week" items

Recommendation: do not sell anything as "only this week". For 7 to 12 year olds that is scarcity pressure, the pattern the kids rule exists to stop, and it punishes the child who was away that week. Do a **featured item of the week** instead: one wearable or ball theme matching the world reskin, spotlighted on the shelf, that stays in the regular shop afterwards or returns on a stated rotation, with copy that says so ("Back in six weeks"). That keeps the weekly freshness without the fear of missing out.

**Build order:** palette, hatch colours, onboarding removals (S each); crack stages and sounds, deck P1+P3, P5 (M each); P2+P4 (S); `WorldWeek` weeks 1 to 3 (M). Each lands on the beta with its switch and a V3-TEST-PASS row.
