# Garden life: look numbers (Fable, 2026-11-22)

For `GardenLife.lua` / `LifeSim.lua` (`ALIVE-LIFE-BUILD-PLAN-2026-11-22.md`). Based on the beta captures (`artifacts/aero-2026-11-22/lime.jpg`, `bear-new-light.jpg`, `artifacts/finds-2026-11-22/sparkle.jpg`) and a contrast pass on the palette. **Nothing here was seen in Studio**; every value is a start to tune from real captures, which I review before publish. Textures were drawn and checked on grass, sky, marble and dark foliage at 20 to 128 px.
Common to every part: `Anchored`, no collide/query/touch/shadow, `SmoothPlastic`, Reflectance 0, Transparency 0 unless stated. No Neon, no Glass, no lights. Offsets are from an invisible root CFrame; forward is -Z, up is +Y. Angles in degrees.

## 1. Bird ("Pip-bird"): 5 parts, one ball with a beak

About half a Bear tall (1.2 studs against 2.5), 2.4 studs across with wings out.

| # | Part | Shape | Size | Offset from root | Colour |
|---|---|---|---|---|---|
| 1 | Body | Ball | 1.2, 1.2, 1.2 | 0, 0, 0 | body |
| 2 | Eyes | Cylinder (axis = part X, runs through the head) | 1.20, 0.30, 0.30 | 0, 0.12, -0.14 | ink #24304F |
| 3 | Beak | Wedge, thin edge forward | 0.26, 0.18, 0.34 | 0, -0.02, -0.68 | beak |
| 4 | Wing L | Block | 0.10, 0.62, 0.62 | see poses | wing |
| 5 | Wing R | Block | 0.10, 0.62, 0.62 | see poses | wing |

- **Eyes are one part.** The cylinder ends show as two round ink buttons, one each side, standing 0.01 to 0.10 proud of the ball. That frees the fifth part for a second wing. [check: if the back half of each disc looks sunk, lengthen to 1.24.]
- **Beak** [check]: an unrotated WedgePart should have its thin edge at -Z; if it points backwards, turn it 180 about Y.
- **Perched wings** (folded slabs on the flanks): `CFrame.new(±0.56, -0.04, 0.12) * Angles(-20, 0, 0)`.
- **Flying wings**, flap angle φ: right `CFrame.new(0.40, 0.10, 0.05) * Angles(0, 0, φ) * CFrame.new(0.31, 0, 0) * Angles(0, 0, 90)`; left the mirror: `CFrame.new(-0.40, 0.10, 0.05) * Angles(0, 0, -φ) * CFrame.new(-0.31, 0, 0) * Angles(0, 0, 90)`.
- **Perch height:** root sits 0.56 above the perch point (the ball sinks 0.04; no legs).

| Colourway | Body | Wing | Beak | Why |
|---|---|---|---|---|
| Tide | #2A6BE0 | #1E4FB8 | #FF9F1C | 4.6:1 on marble, 1.65 on sky; deeper than the sky so it never melts into it |
| Coral | #FF7C6B | #E2574C | #FFD23F | opposite hue to sky and grass |
| Sun | #FFD23F | #F2A91E | #FF7A1A | 4.5:1 on dark foliage, 2.1 on sky; weakest on marble, the wing shade carries it |

Pick by perch index (`perchIndex % 3`), so a perch always has the same bird. No white, green, pink or lime birds: white and pink belong to the pets, green and lime vanish.

**Motion**

| Beat | Numbers |
|---|---|
| Flap (arc in and out) | Two poses, not a sine: φ = +55 and φ = -25, swap every 2 steps at 30 Hz, every step at 15 Hz (7.5 Hz either way). A sine at 30 Hz stutters |
| Arc in (0.8 s) | Starts 9 to 12 studs out and 4 to 6 up; body pitched nose-down 15, levelling over the last 0.2 s |
| Landing squash (no resize) | Root dips 0.12 and pitches forward 12 in 0.10 s, back in 0.15 s; wings snap to the perched pose on touch |
| Hop on chirp | Up 0.35 studs, 0.22 s, parabola; lands with a 0.06 dip for 0.08 s. Both wings flick out 25 (roll about Z at the perched pose) for 0.12 s. This replaces the brief's tail flick: no part left for a tail |
| Idle | Yaw turns of 20 to 45, one every 2.5 to 5 s, each done in 0.15 s (snappy, like a real bird). No bobbing loop |
| Arc out (1.2 s) | Crouch 0.10 for 0.08 s first; rises 5 to 7 studs, away from the player |
| Reduced Motion | Appears on the perch already folded; no hop, no turns; removed without an arc |

## 2. Butterfly: 3 parts

Toy-sized on purpose (1.25 studs across): a true-scale butterfly is 2 px on a phone.

| # | Part | Shape | Size | Offset | Colour |
|---|---|---|---|---|---|
| 1 | Body | Block | 0.10, 0.10, 0.46 | 0, 0, 0 | ink #24304F |
| 2 | Wing L | Block | 0.60, 0.04, 0.56 | `CFrame.new(-0.05, 0.03, 0) * Angles(0, 0, -φ) * CFrame.new(-0.30, 0, 0)` | wing |
| 3 | Wing R | Block | 0.60, 0.04, 0.56 | `CFrame.new(0.05, 0.03, 0) * Angles(0, 0, φ) * CFrame.new(0.30, 0, 0)` | wing |

Plain colour, no Decal this slice (a wing is 10 to 25 px wide; a pattern would be mud).

| Wing | Hex | Jar | On grass #5FCB3F | On sky #2F9BEF |
|---|---|---|---|---|
| Rose | #FF327A | as the jar | 1.7:1, opposite hue | 1.2:1, opposite hue |
| Citrus | #FFCC00 | as the jar | 1.4:1 | 2.0:1 |
| Iris | #7A35F0 | deepened from #9350FF | 2.8:1 | 2.0:1 |
| Tide | #0A4FD0 | deepened from #008DFF | 3.3:1 | 2.3:1 |

The Tide jar's own blue is 1.13:1 against the sky, so it is deepened; Iris likewise. Rose and Citrus lean on hue more than value; the ink body gives all four a dark centre. One of each colour while four are alive.

| Beat | Numbers |
|---|---|
| Flap in flight | Two poses, φ = +60 and φ = -15, swapped at 7.5 Hz as the bird (this overrides the brief's 9 Hz, which aliases at 30 Hz) |
| Height | 1.2 to 2.4 studs above the ground; bob ±0.25 studs at 1.3 Hz on top of the wander |
| Heading | Faces its travel direction, with a ±20 yaw wobble at 0.8 Hz; body pitched nose-up 10 |
| Rest (2 to 4 s) | Root 0.35 above the ground (flower-top height); wings open and close slowly between φ = 70 and φ = 20 at 0.5 Hz (a sine is fine here) |

## 3. Bubbles: the texture on a billboard, not a Ball part

**Choice:** one invisible anchor Part per bubble (Ball 0.2, Transparency 1, moved by the one `BulkMoveTo`) carrying a `BillboardGui` with one `ImageLabel` of `assets/life/bubble.png`.

**Why not a Ball part:** a ball at any transparency that still shows (.55 in `WORLD-PLAN` 9) lays a pale disc over whatever is behind it, and the Bear is white: that is the white blob. Glass also stops other transparent things drawing behind it (water skin, petals, dew). The texture is 3.5% opaque in the middle and puts its weight in the ring, the crescent and the rainbow rim, which is what says "soap".

| Property | Value |
|---|---|
| Diameter | 0.5 to 1.1 studs: 60% of spawns 0.5 to 0.75, 40% 0.75 to 1.1. `BillboardGui.Size = UDim2.fromScale(d, d)` |
| ImageColor3 / ImageTransparency | #FFFFFF / 0.10 |
| BillboardGui | `LightInfluence 0`, `Brightness 1`, `AlwaysOnTop false`, `MaxDistance 90`, `ClipsDescendants false`, `Active false` |
| Fade | In over 0.4 s (transparency 1 to 0.10), out over the last 0.3 s. No pop flash, no scale change |
| Wobble | Sideways ±0.15 studs at 0.6 Hz, own phase, on top of the plan's rise and drift |

Fallback only if the image is not uploaded yet: Ball, SmoothPlastic, #DEF3FF, Transparency 0.80, Reflectance 0.25. Never ship both at once.

## 4. Petals

Texture `assets/life/petal.png`: white with a grey rim and vein, so `ParticleEmitter.Color` tints it. One flat colour per emitter (no gradient over life), assigned by emitter slot:

| Crown state | Slot 1 | Slot 2 | Slot 3 |
|---|---|---|---|
| Aero on, lime crowns #8FD63F | #EFFFC4 | #C8F26A | #FFF3A6 |
| Aero off, pink crowns | #FFB8D6 | #FF9FC8 | #FFD9E8 |

Lime petals are paler than the crown on purpose: crown lime on grass is 1.2:1 and disappears; #EFFFC4 is 2.0 on grass, 2.8 on sky, 6.2 on dark foliage. Never pure white (#FFFFFF reads as pet fur or a UI sparkle).

| Property | Value |
|---|---|
| Size | 0.28 to 0.42 studs. `NumberSequence`: 0 → 0.20, 0.10 → 0.35 (envelope 0.07), 1 → 0.30 (envelope 0.05) |
| Transparency | 0 → 1, 0.08 → 0.05, 0.75 → 0.05, 1 → 1 |
| Rotation / RotSpeed | 0 to 360 / -70 to 70 degrees a second |
| Squash (fakes a tumble) [check] | 0 → 0, 0.2 → -0.5, 0.4 → 0.1, 0.6 → -0.5, 0.8 → 0.1, 1 → -0.3 |
| Light | `LightEmission 0`, `LightInfluence 1`, `Brightness 1` |
| Other | `Orientation FacingCamera`, `ZOffset 0`, `Speed` 1 to 2.5, `SpreadAngle` 35, 35, `Lifetime` 4.5 to 5.5 |

## 5. Never

- No white or near-white shape wider than 12 px over the pet or the screen centre: no opaque bubble, no white petal, no white bird.
- No Neon, no Glass, no PointLight, no `LightEmission` above 0, nothing that crosses the bloom threshold (1.3).
- No green, lime or aqua creature; no sky-blue #2F9BEF to #3FB2F2 wing or body.
- No outline, Highlight or SelectionBox on any of it; no name tags, no prompts.
- No resize per step (poses only), no continuous bob on a perched bird, no flap faster than 7.5 Hz.
- No petal larger than 0.45 studs, no bubble larger than 1.1, no butterfly lower than 0.3 above the ground.
- Nothing fades in nearer than 6 studs to the camera; a bubble that drifts inside 4 studs fades out in 0.3 s instead of filling the screen.
- Nothing at night that glows: bubbles and butterflies are day only, and birds and petals take the scene light as they are.

**Review captures wanted:** bear on grass with a bubble passing in front and behind; each bird colourway on the arch top against sky, and on a bridge post; all four butterflies over a flower patch at about 25 studs on the phone viewport; petals in a gust with Aero on and off; one frame with everything live at 40 studs.

## Uploaded (Opus, 2026-11-22)

- `assets/life/petal.png` -> `rbxassetid://112974880714881`
- `assets/life/bubble.png` -> `rbxassetid://77828632873187`
