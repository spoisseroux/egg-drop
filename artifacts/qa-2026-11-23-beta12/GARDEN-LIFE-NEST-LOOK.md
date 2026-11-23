# Garden life round 3 and the nest remodel: the look (Fable, 2026-11-23)

For beta (12) QA items **L1, L2, L3, O1, O2** (`FEEDBACK.md`). Replaces the butterfly, petal and bird sections of `artifacts/alive-life-2026-11-22/LOOK.md` / `LOOK-R2.md` / `REVIEW-R2.md`, and sections 1, 2 and the wording of `artifacts/onboarding-2026-11-23/NEST-LOOK.md`. Everything not named here stands (bubbles, Dewdrops, the egg's four looks, tuck-in and hatch beats, the strip).

**The rule (Spencer, 2026-11-23):** ambient life and world dressing are *realistic and textured*, in natural, lower-saturation colours, so the saturated toy-like pets are the brightest, smoothest things on screen. Ambient motion is soft and eased: nothing snaps, pops or bursts.

Textures are script-drawn (`python scripts/draw_garden_life_r3_textures.py`, deterministic, numpy + Pillow, no outside or generated art) into `artifacts/qa-2026-11-23-beta12/look/`, and were checked only as mock sprites on grass, lime, sky, night and marble (`look/preview-*.png`). **Nothing here has been seen in Studio.** Every `[check]` is a one-look test; I review captures before publish.

Common, as before: `Anchored`, no collide/query/touch, `CastShadow` off unless said, forward -Z, up +Y, degrees. A "decal plate" is a Block at `Transparency 1` carrying Decals on side faces only. Budget levels are `AliveBudget` 0 / 1 / 2; **level 2 shows no garden life at all (unchanged)**, the nest is not garden life and always shows.

## 0. Uploads (builder)

| File (in `look/`) | Size | Roblox use |
|---|---|---|
| `butterfly-amber.png`, `-chalk`, `-dusk`, `-meadow`, and each `-m.png` mirror (8 files) | 160x192 | Decal on the wing plates, `Color3` white (full colour, no tint) |
| `firefly-dot.png` | 64x64 | ImageLabel in a BillboardGui (the hand-off glow) and `WorldAero.Fireflies.Texture` |
| `leaf-a.png`, `leaf-b.png` | 96x96 | `ParticleEmitter.Texture` |
| `bird-wing-ember.png`, `-slate`, `-moss` | 128x176 | Decal on the wing plates, `Color3` white |
| `bird-tail.png` | 96x128 | Decal on the tail plate, tinted by `Color3` |
| `bird-breast.png` | 128x128 | Decal on the body ball's Front face, tinted by `Color3` |
| `nest-twigs.png` | 256x128, tiles both ways | `Texture` on the nest mound and rim rolls |
| `nest-fringe.png` | 256x160, alpha | Decal on see-through plates round the rim |
| `straw-bed.png` | 256x256, alpha circle | Decal on the bed disc's top cap |
| `straw-wisps.png` | 192x96, alpha | Decal on see-through plates round the bed |
| `nest-sign.png` | 208x128 | Decal on the sign board's front |

The petal keeps today's `petal.png`. Retired after this lands: `butterfly-wing(-m)`, `bird-eye`, `bird-wing`, `nest-weave`, `nest-flag`, `nest-leaves`.

## 1. Butterflies (L1)

**Look.** Four believable meadow butterflies in natural colours, 20% smaller, with scale grain, veins and dusted roots: no flat hot pink.

| Slot | Name | Reads as | File |
|---|---|---|---|
| 1 | Amber | tawny orange, dark veins and border, cream edge dots | `butterfly-amber` |
| 2 | Chalk | cream white, smoky fore tip, one dark spot a wing | `butterfly-chalk` |
| 3 | Dusk | powder blue, grey margin, pale fringe | `butterfly-dusk` |
| 4 | Meadow | straw yellow, dark bars, a small rust and blue eyespot | `butterfly-meadow` |

Parts (3 each, unchanged count; 4 / 2 / 0 alive by level, unchanged):

| Part | Size | Pose | Colour / decal |
|---|---|---|---|
| Body | 0.08, 0.08, 0.40 | root | #2A2018 |
| Wing R | plate 0.56, 0.67, 0.02 | `CFrame.new(0.04, 0.03, 0) * Angles(0, 0, φ) * CFrame.new(0.28, 0, 0) * Angles(-90, 0, 0)` | Back `butterfly-X.png`, Front `butterfly-X-m.png`, Color3 #FFFFFF |
| Wing L | plate 0.56, 0.67, 0.02 | the mirror (x -0.04, -φ, x -0.28) | Back `-m`, Front plain |

Same layout as round 2 (root at the image's left edge, fore wing up), so the round 2 pass test holds: **on all four faces the dark root touches the body and the larger lobe is forward.** Span 1.2 studs (was 1.5).

**Motion: one continuous wing angle, evaluated every step. No two-pose swap, no "held" pose.**

| | Now | Round 3 |
|---|---|---|
| Flap | +60 / -15 swapped at 7.5 Hz | `φ = 22 + 38 * sin(2π * f * t) * e`, f = **2.2 Hz** (level 1: 1.6 Hz, at its 15 Hz step) |
| Glide | none | after every 1.6 to 3.2 s of flapping, wings hold a shallow V (φ = 28) for 0.6 to 1.1 s. `e` is the envelope: 1 while flapping, 0 in the glide, smoothstepped over 0.25 s each way |
| In a glide | | the root sinks 0.25 studs over the glide and climbs back over the next 0.6 s (smoothstep) |
| Bob | 0.25 at 1.3 Hz | 0.06 in time with the flap (up on the downstroke) + 0.15 at 0.4 Hz |
| Yaw wobble | 20 at 0.8 Hz | 12 at 0.5 Hz |
| Speed | 0.8 studs/s | 0.65 (leave: 2, unchanged) |
| Resting on a flower | 45 ± 25 at 0.5 Hz | wings nearly closed: `φ = 62 + 14 * sin(2π * 0.25 * t)` |

Glide timing comes from the butterflies' own `Random`. Reduced Motion: none shown (unchanged).

**Night: they become fireflies.** Today they fly off when the garden hour's daylight drops to 0.7 (the start of golden hour). Change:

- Butterflies only: fly while daylight > **0.30** (so they are out in golden light and at dawn); new ones spawn when daylight > **0.34**. Birds and bubbles keep 0.7.
- When daylight falls under 0.30 (about 65 s into the 120 s night blend, exactly where the v7 fireflies begin), the live butterflies hand off one at a time, **1.5 s apart, slot 1 first**:

| t | What |
|---|---|
| 0 to 1.5 s | Still flying. Wing decals and body `Transparency` 0 to 1 (write at 10 Hz). The glow comes up at the body: BillboardGui 0.2 to 0.9 studs square, `ImageTransparency` 1 to 0.1 (smoothstep). |
| 1.5 to 5 s | A firefly: the wings are gone, speed eases 0.65 to 0.25, it rises to 1.5 to 2 studs over the ground. Glow pulses `ImageTransparency` 0.1 to 0.55, period 1.8 s (the v7 fireflies' pulse). |
| 5 to 6 s | Glow fades to 1; the butterfly is removed. |

- Glow: one BillboardGui per butterfly body, built once, `Enabled` false by day. ImageLabel `firefly-dot.png`, `ImageColor3` **#E8FF8A**, `LightInfluence` 0, `Brightness` 2, `MaxDistance` 110, not AlwaysOnTop. No PointLight.
- **Count budget, unchanged: 12 fireflies alive at level 0, 6 at level 1, 0 at level 2.** The hand-off adds at most 4 (level 1: 2) glows for 10.5 s while the area emitters are still ramping (their ramp is 0 at 0.30 and at most 0.32 when the last glow goes), so the peak is 4 + 4 = 8 (level 1: 2 + 2 = 4). To make it a guarantee: **start a hand-off only while daylight is 0.24 or more**; under that (a `/hour at` jump, a late join) the wings just fade out in 0.5 s with no glow.
- Dawn: no reverse effect. New butterflies fade their wings in over 1.2 s (decal `Transparency` 1 to 0) once daylight passes 0.34. Use the same fade-in for every spawn.
- The v7 area fireflies: swap `Texture` to `firefly-dot.png` (the comment in `WorldAero.Fireflies` has been waiting for it) and `Size` 0.35 to 0.6. Counts, areas, ramp untouched. `[check]` at night: a soft round glow, not a four-point sparkle; if 0.6 reads as a blob, 0.45.
- Reduced Motion: no butterflies, no hand-off (and no area fireflies, as today).

## 2. Falling leaves (L2), replacing the petal bursts

**Look.** A few leaves always coming down, everywhere you look, slowly: mostly green leaves, some yellowing, an occasional pale petal. Never a puff from one tree. A gust slants them and brings a few more; it never bursts.

**How.** Delete the three crown emitters, `PetalPeak`, `PetalBurst` and the crown pick. One invisible anchor carries three emitters (emitter cap stays 3 / 3 / 0):

- Anchor: Block **72, 2, 72**, centred on the player's root, x and z snapped to an 8 stud grid, its middle 11 studs over `groundY` at that cell. Moved only when the cell changes. `EmissionDirection` Bottom, `Shape` Box, `ShapeStyle` Volume, `LockedToPart` false (leaves already falling stay where they are).
- Emitted with `Emit` against the live count, as today, so the cap is exact.

| | Leaf A | Leaf B | Petal |
|---|---|---|---|
| Share of emits | 55% | 30% | 15% |
| Texture | `leaf-a.png` (broad, fresh green) | `leaf-b.png` (narrow, olive going brown) | today's `petal.png` |
| Color | #FFFFFF | #FFFFFF | lime crowns #FFF6C2, pink crowns #FFB8D6 |
| Size (0, 0.1, 1) | 0.30, 0.46 ± 0.08, 0.42 | 0.26, 0.40 ± 0.06, 0.36 | 0.22, 0.34 ± 0.05, 0.30 |
| Lifetime | 9 to 12 s | 9 to 12 s | 8 to 10 s |

Shared by all three:

| Property | Value | Was |
|---|---|---|
| Speed | 0.3 to 0.6 | 3.5 to 6 |
| Drag | 0.5 | 0.25 |
| Acceleration | `(wind) + (0, -0.45, 0)`: settles to a 1.3 studs/s fall, about 10 studs over a life | (0, -0.5, 0) after a 6 stud/s launch |
| wind term | written at 4 Hz: `Wind.Direction * (0.25 + 0.9 * g) + cross * 0.3 * sin(2π * t / 7)`; g = `Wind.at(anchor, now)`, cross = `Wind.Direction` turned 90 on the ground. Calm: a 0.7 studs/s lean. Full gust: 3.3 studs/s. The sine is the sway. | |
| SpreadAngle | 20, 20 | 25, 25 |
| Rotation / RotSpeed | 0 to 360 / -45 to 45 | / -120 to 120 |
| Squash | 0: 0, 0.25: -0.35, 0.5: 0.05, 0.75: -0.35, 1: 0 (two slow turns a life) | five flips to -0.5 |
| Transparency | 0: 1, 0.08: 0.1, 0.88: 0.1, 1: 1 | |
| LightInfluence / LightEmission | 1 / 0 (they dim at night and in shade, like real leaves) | 0.5 / 0 |
| Orientation | FacingCamera | |

| | Level 0 | Level 1 | Level 2 | Reduced Motion |
|---|---|---|---|---|
| Emits a second (all three together) | 2.4 x (1 + 0.5 g) | 1.2 x (1 + 0.5 g) | 0 | 0 |
| Alive cap (`Caps.petals`) | **28** (was 40) | **14** (was 20) | 0 | 0 |
| Step | 30 Hz | 15 Hz | | |

That is about one leaf per 185 square studs: 5 to 9 in a phone view, none closer together than a few studs. Parked: cleared, as today. A menu: they keep falling. They fall at night too.

- Known and accepted: leaves also fall inside the rotunda and through crowns; at 0.4 studs nobody will read it. If Spencer does, the fix is a no-fall box list, not a look change.
- `[check]` Leaf A on the lawn is meant to nearly vanish against the grass and show against sky, path and marble. If the whole effect goes unnoticed, raise sizes by 25% before raising counts.

## 3. Birds (L3)

**Look.** A small round songbird, not a ball with stickers: a separate head it can cock, bead eyes, a short dark beak, folded wings with real feather rows, a tail that flicks, and a soft coloured breast. Muted natural plumage. Cute comes from proportion (head 65% of the body) and behaviour, not from big cartoon eyes.

8 parts a bird (was 6), 3 / 2 / 0 birds by level (unchanged): 24 parts at most. Root = body centre. `H` = the head frame = `root * CFrame.new(0, 0.37, -0.35) * headTurn`.

| # | Part | Shape | Size | CFrame | Colour / decal |
|---|---|---|---|---|---|
| 1 | Body | Ball | 1.05 | root | body colour. Decal `bird-breast.png` on **Front**, Color3 = breast |
| 2 | Head | Ball | 0.68 | `H` | head colour |
| 3 | Beak | Block, corner first | 0.17, 0.17, 0.17 | `H * CFrame.new(0, -0.02, -0.36) * Angles(-35.26, 0, 0) * Angles(0, 45, 0)` | beak colour |
| 4, 5 | Eyes | Ball | 0.14 | `H * CFrame.new(±0.235, 0.065, -0.22)` | #14110F, `Reflectance` 0.2 |
| 6, 7 | Wings | decal plate, thin in X | 0.04, 0.75, 0.55 | below | `bird-wing-<name>.png` on Left and Right, Color3 #FFFFFF |
| 8 | Tail | decal plate, thin in Z | 0.46, 0.68, 0.02 | `root * CFrame.new(0, -0.09, 0.40) * Angles(τ, 0, 0) * CFrame.new(0, 0, 0.29) * Angles(-90, 0, 0)`, τ = 20 at rest | `bird-tail.png` on Front and Back, Color3 = tail |

- Wings perched: right `CFrame.new(0.53, -0.02, 0.15) * Angles(0, -12, 0) * Angles(-55, 0, 0)`, left mirrored (x -0.53, yaw +12). Flying: right `CFrame.new(0.37, 0.11, 0.04) * Angles(0, 0, φ) * CFrame.new(0.37, 0, 0) * Angles(0, 0, 90)`, left mirrored (-φ, -90). The same chains as round 2, scaled.
- `Sim.Bird.lift` 0.56 to **0.50** (the body sits a hair into the crown; no legs).
- `[check]` breast decal on a Ball: a soft streaked patch on the chest. If it stretches or shows a square edge, delete it; the two-ball bird still reads. `[check]` tail: root under the rump, tip back and slightly down; if it points forward, turn the plate 180 about Y. `[check]` eyes: two beads visible from dead front and from the side.

| Name (perch index % 3) | Body | Breast (decal) | Head | Tail | Beak | Wing file |
|---|---|---|---|---|---|---|
| Ember | #EADBC2 | #D9713A | #7A6248 | #5E4A36 | #3A3028 | `bird-wing-ember` |
| Slate | #EBDCC4 | #E0A070 | #6F8FB3 | #465E7E | #2E2E33 | `bird-wing-slate` |
| Moss | #E6D788 | #A6A45E | #3F4438 | #4A5230 | #4A4038 | `bird-wing-moss` (pale wing bar) |

**Motion** (everything eased with smoothstep; nothing is a two-pose swap):

| Beat | Now | Round 3 |
|---|---|---|
| Hop | 0.35 high, 0.22 s | **0.16 high, 0.18 s**; 40% of hops are a pair, 0.12 s apart |
| Tail | none | flicks up on every landing and hop: τ 20 to 2 to 20 in 0.16 s |
| Head | none (the whole ball turned) | every 0.8 to 2.5 s the head alone snaps to a new look: yaw ± 25 to 50 in 0.12 s, and 30% of the time a cock (roll ± 15) with it. Held between. This is the cute. |
| Body turn | 20 to 45 every 2.5 to 5 s | the same, but always with a hop (birds turn by hopping) |
| Flight | +50 / -20 swapped at 7.5 Hz | bounding: two beats `φ = 15 + 50 * sin(2π * 5.5 * t)` (0.36 s), then wings tucked to the perched pose for 0.22 s while the root dips 0.12; repeat. Level 1 (15 Hz step): 3.5 Hz beats (0.57 s), same tuck |
| Hop wing flick | 25, 0.12 s | 15, 0.12 s |
| Stay, flee, landing dip | | unchanged |

Reduced Motion: just there on the crown, folded, head straight, still (unchanged). Night: unchanged (no new birds under daylight 0.7).

## 4. The nest (O2)

**Look.** A real bird's nest, scaled up: a low dark mound of woven twigs, a ragged rim with twig ends and straw sticking out at every angle, a pale straw bed with a shaded dent, the Sleepy egg nestled in it, and a small weathered wooden sign on a stake. The egg and the Bear are the only smooth, bright things in the picture. The cream cushion, the moon flag and the cartoon leaves go; the crescent moon moves onto the sign.

Root-local offsets (y from the ground), root -Z = the front, where the player stands. 21 parts (was 10), one nest, owner's client only as today.

| # | Part | Shape | Size | Offset / turn | Colour, texture |
|---|---|---|---|---|---|
| 1 | Mound | Cylinder, axis up | 0.42 thick, 3.5 across | 0, 0.21, 0 | #3A2616. `Texture` `nest-twigs.png` on the four curved faces, StudsPerTileU 2.4, V 1.2. **`CastShadow` on** (this one part), so the nest sits on the marble |
| 2-9 | Rim rolls x8 | Cylinder, axis along the ring | 1.30 long, 0.66 across | a = 22.5 + 45k: (sin a x r, y, cos a x r), axis tangent. Even k: r 1.42, y 0.56, ends tipped +7. Odd k: r 1.50, y 0.62, tipped -7 | #6B4A2C, #5A3D24, #7D5A38 in turn. `Texture` `nest-twigs.png`, 2.4 / 1.2, `OffsetStudsU` = 0.37k |
| 10 | Straw bed | Cylinder, axis up | 0.30 thick, 2.36 across | 0, 0.55, 0 (top at 0.70) | #B8974F. Decal `straw-bed.png` on the top cap |
| 11-16 | Twig fringe x6 | decal plate | 1.9, 1.05, 0.04 | a = 15 + 60k: centre (sin a x 1.62, 0.78, cos a x 1.62), facing out, top tipped 22 outward, yaw +8 / -8 in turn | `nest-fringe.png` on Front and Back |
| 17-19 | Straw tufts x3 | decal plate | 1.3, 0.62, 0.04 | a = 40 + 120k: centre (sin a x 1.05, 0.98, cos a x 1.05), facing out, top tipped 15 outward | `straw-wisps.png` on Front and Back |
| 20 | Sign post | Block | 0.14, 1.5, 0.14 | -1.95, 0.75, -0.95 | #6B4A2B, **Material Wood** |
| 21 | Sign board | Block | 1.3, 0.8, 0.08 | -1.95, 1.45, -1.03, yawed 20 toward the egg, tipped back 6 | #A47E50, Material Wood. Decal `nest-sign.png` on **Front** (the face toward root -Z) |

- **Sign words:** a SurfaceGui on the board's Front, 50 px a stud, one TextLabel over the right 62% (x 0.34 to 0.97, y 0.14 to 0.86): `nest.sign` (section 5), ink #3B2A1A, the Kit's strong face, TextScaled, max 22 px, wrapped to two lines. The burnt crescent is in the texture at the left. `LightInfluence` 1.
- **Egg:** base at (0, **0.64**, 0), 0.06 into the straw (`Client.EggBase` 0.61 to 0.64). All four looks, the halo, the Zzz, tuck in and hatch are unchanged. The new egg's drop lands on the straw.
- **The Bear's curl spot:** root-local (**2.2, 0, -1.4**) (was 1.9, -1.3: the fringe is wider). Prompt and prints end at (0, 0, -2.6), unchanged. The sign is on the other side (-X).
- `[check]` twigs on the rolls: individual twigs readable from 8 studs. If they smear, StudsPerTile 3.2 / 1.6. `[check]` fringe: from every side the outline is ragged, no straight plate edge against the sky; if a plate shows as a card edge-on, add yaw ± 15 to it. `[check]` straw bed: if the cap decal lands on the wrong cap or clips square, put it on both caps. `[check]` the mound's shadow is soft and small; if it looks like a hard disc, turn it off.

### Where: the plaza, east rim

Spencer asked for the plaza; yes. The Sleepy egg is the daily return reason and the hub is where every visit starts and ends (the egg machine is 16 studs away). The nest is drawn only on its owner's client, so "one nest" is one spot: everyone sees their own egg there, and nobody's nest is in anybody's way.

The plaza is the marble circle centred about (-30, -4), patterned ring radius about 10.2, marble out to about 14.5. Only the **east** rim is free: the Garden Dash course runs along the south and south-west rim (through (-22, 13), (-30, 13), (-40, 9), (-45, 4)), the Wardrobe closes the west, and the egg machine and Journal close the north.

| | Root | Root frame | Clear by |
|---|---|---|---|
| **A (recommended)** | `Vector3.new(-17.5, y, -2.5)`, y by raycast (walk map 4.07) | `CFrame.lookAt(root, Vector3.new(-30, y, -4))`: the front faces the plaza's middle | Journal (-17, -15) 12.5; egg machine (-31, -11) 16.0; Wardrobe 29; Dash course 16.6; the arrival path's mouth (-17, 7) 9.5; the arrival walking line 12.9; flower patches (-11.8, -3.0) 5.7 and (-13.2, -8.1) 7.1; marble edge 2.5; ring trim 2.4; lamps 31; find spots and firefly areas 50+ |
| B (if a prop blocks A) | `Vector3.new(-22.5, y, 5.5)` | `CFrame.lookAt(root, Vector3.new(-30, y, -4))` | Dash course 7.8; the arrival walking line 3.5 (1.4 past the fringe: people brush past it); marble edge 1.5; egg machine 18.6 |
| C (do not move) | (86, y, 66), as built | as built | as NEST-LOOK section 1 |

- At A a player entering from the arrival path sees the nest 9.5 studs to their right as the plaza opens; from the egg machine it is in frame across the star.
- **`[check]` before building at A: the plaza's benches, urns and egg pedestals are merged into the world mesh and I cannot read their positions.** Stand at A: there must be 2.6 studs clear all round, and the prompt point (root-local 0, 0, -2.6, world about (-20.1, -2.8)) must be open marble. If not, slide along the rim (keep 12.6 from (-30, -4), stay between z -7 and z 1), else B.
- What moving costs: the nest is no longer in the arrival frame (NEST-LOOK chose (86, 66) for that). The `{pet} is sleepy` need, the Show me trail, the HUD chip and the `tip.nest` coach mark already lead there, and the egg machine step ends beside it. Follows `Client.Spot` / `Client.Facing`: the trail, `clientUI.nestPlace`, the coach mark's label and any spec that pins (86, 66).

## 5. Nest wording (O1)

Spencer did not understand the sleeping egg. Today's copy says "Sleepy egg", "Ready in 7 h.", "Tuck in", "A new egg is growing." and never says *what it is, how long, or what you get*. One sentence fixes it, and three words carry it everywhere: **naps**, **come back**, **hatch a gift**. Never "ready", "growing" or "sleepy" for the same thing.

All in `UICopy` `onb3` (`{hours}` in the sentences is `Nest.Hours`, never a typed 8). Longest lines checked at 13 px on a 320 px wide phone with a 12 character pet name.

| Key | Now | New |
|---|---|---|
| `nest.sign` (new: the wooden sign) | | `{pet}'s egg` |
| `nest.how` (new: the explainer) | | `{pet}'s egg naps for {hours} hours. Come back to hatch a gift.` |
| `tip.nest` (coach mark) | This is {pet}'s nest. | `{pet}'s egg is napping. Hatch it later for a gift.` |
| `need.nest` | {pet} is sleepy. | `Tuck in {pet}'s egg.` |
| `nest.title` (prompt object) | Sleepy egg | `Napping egg` |
| `nest.tuck` / `nest.hatch` (prompt action) | Tuck in / Hatch | unchanged |
| `nest.hours` / `nest.minutes` (label, strip) | Ready in {hours} h. | `Hatches in {hours} h` / `Hatches in {minutes} min` |
| `nest.ready` | Ready! | `Hatch me!` |
| `nest.tuckedFirst` (new: the first tuck-in ever) | | `Tucked in! Come back in {hours} hours to hatch a gift.` |
| `nest.tucked` (every later one) | Sleep tight. It will wait for you. | `Sleep tight. It naps while you're away.` |
| `nest.next` | A new egg is growing. | `A new egg is napping. Come back in {hours} hours.` |
| `nest.chipHours` / `nest.chipMinutes` (HUD chip) | {hours} h | `Egg {hours} h` / `Egg {minutes} min` |
| chip, hatchable | Ready! | `Hatch egg!` |
| chip `AccessibleLabel` | Sleepy egg | `nest.how` |
| `need.egg`, `notify`, `notifyPlain` | ... Sleepy egg is ready ... | `{pet}'s egg is ready to hatch!` / `Your egg is ready to hatch!` |

Where the explainer shows:

1. **The label over the egg**, as a second line under the clock, **until the player's first hatch** (`n == 0`), at any distance the label shows. After that the "Inside: ..." line takes its place within 8 studs, as today.
2. **The first tuck-in:** `nest.tuckedFirst` replaces the label for **6 s** (was 4) and also goes out as a rail toast, so it is read even if the camera is on the Bear.
3. **The chip:** "Egg 7 h" names the thing; the moon icon alone did not. About 22 px wider (about 114 px; phone about 92 with the gift icon dropped, as today).

Run the localization export and sync with the build, as every publish.

## 6. Captures wanted for my review

Phone-sized (as Spencer's QA shots) unless said. Day at the day hold unless said.

- **Butterflies:** each of the four from above on a patch, close; one 6 s clip of flight showing a flap run, a glide and a landing; one resting with wings up; all four in one frame from 25 studs with a pet in shot (the pet must be the loudest thing).
- **Hand-off:** a clip from `/hour at` just before the night blend's 0.30 through 15 s: wings fading, glows rising; and a `get counts` of fireflies alive at the peak, levels 0 and 1.
- **Fireflies:** the South lawn at night with the new dot, close and from 30 studs.
- **Leaves:** a 10 s clip on the south lawn in calm and one through a gust, from player height; a still looking up at the sky and one across the plaza marble; live counts at levels 0 and 1; one at night.
- **Birds:** each of the three perched, side-on and dead front, close; one from the lawn below at 30 studs; a clip of a hop pair with the tail flick and a head cock; a clip of one arrival (bounding flight).
- **Nest:** at A from the arrival path's mouth, from the egg machine, and close from the front, the side and above; the egg at all four looks on the straw; the Bear curled beside it; the sign close enough to read, with a long pet name; the nest at night with the halo; the first tuck-in line; the chip in both states.
