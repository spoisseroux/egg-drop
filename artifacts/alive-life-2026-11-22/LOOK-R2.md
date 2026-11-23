# Garden life, round 2 look (Fable, 2026-11-22)

From the round 1 Studio captures (`round1/`). This replaces LOOK.md sections 1 (parts, poses, wing colours), 2 (parts) and the petal and bubble numbers named below; every motion beat, colour table and "Never" line not named here stands. The four new PNGs were drawn and checked as mock sprites at 16 to 180 px on sky, grass, lime and dark foliage (`python scripts/draw_life_textures.py --preview DIR`); **none has been seen in Studio**, so I review captures again before publish.

Common: `Anchored`, no collide/query/touch/shadow, SmoothPlastic, forward -Z, up +Y, degrees. A "decal plate" is a Block with `Transparency 1` carrying Decals (a Decal still draws on a fully transparent part). Decals: `Transparency 0`, `ZIndex 1`. On side faces (Front/Back/Left/Right) a Decal is upright (image top = part +Y) and reads unmirrored from outside; every plate below uses side faces only, so nothing depends on Top/Bottom mapping.

## What the captures show

| Thing | Capture | Verdict |
|---|---|---|
| Bird | bird-close, bird-wide | Wing is a 0.62 square slab the body's own blue, covering half the ball: reads as a box stuck on a ball. Eye is 0.30, ink on blue (low contrast) and half hidden by the slab: a dark hole. Beak is the only bird cue and is 0.18 tall. Agree with the lead. |
| Butterfly | butterfly-a, -b | Two plain rectangles hinged on a line; no lobes, no pattern, body invisible. Reads as a folded card. Agree. |
| Bubbles | bubbles-wide, bubble-close | Good: ring, crescent and rim all read, the scene shows through. Keep the texture and the alpha. |
| Petals | petals-1 | Not noticeable: 0.35 studs is 2 to 3 px at this range, they are pale lime on a lime crown, and at Speed 1 to 2.5 with Drag .4 they travel about 5 studs, so they never leave the 8 stud crown. Agree, and the cause is travel as much as size. |

## 1. Bird: 5 parts

| # | Part | Shape | Size | Offset from root | Colour / decal |
|---|---|---|---|---|---|
| 1 | Body | Ball | 1.2, 1.2, 1.2 | 0, 0, 0 | body |
| 2 | Eyes | Cylinder (axis = part X) | 1.18, 0.46, 0.46 | 0, 0.14, -0.20 | part #161C38; Decal `bird-eye.png` on **Left and Right** (the two round caps), Color3 #FFFFFF |
| 3 | Beak | Wedge, thin edge forward | 0.34, 0.26, 0.42 | 0, -0.02, -0.72 | beak |
| 4 | Wing R | decal plate | 0.04, 0.66, 0.46 | poses below | Decal `bird-wing.png` on **Left and Right**, Color3 = wing |
| 5 | Wing L | decal plate | 0.04, 0.66, 0.46 | poses below | the same |

- **Eye:** 0.46 across (was 0.30), 38% of the body height. The cap decal is a cream rim, ink pupil and a white top glint; the rim is what separates the eye from a blue or coral body. The caps stand 0.01 (rear edge) to 0.20 (front edge) proud, so from the front the bird shows two dark bumps at eye height. If the decal does not clip to the round cap, drop it: the bare ink disc at this size still reads.
- **Wing texture** is tip-down (image bottom = part -Y) and left-right symmetric, so the same file is right on both faces of both wings. White and grey: `Decal.Color3` sets the colour.
- **Perched** (wing tip points back and down, plate turned to follow the ball): right `CFrame.new(0.60, -0.06, 0.13) * Angles(0, -12, 0) * Angles(-55, 0, 0)`; left `CFrame.new(-0.60, -0.06, 0.13) * Angles(0, 12, 0) * Angles(-55, 0, 0)`. The wing now covers about a third of the flank, behind the eye, not over it.
- **Flying**, flap angle φ (tip points outward): right `CFrame.new(0.42, 0.12, 0.05) * Angles(0, 0, φ) * CFrame.new(0.33, 0, 0) * Angles(0, 0, 90)`; left `CFrame.new(-0.42, 0.12, 0.05) * Angles(0, 0, -φ) * CFrame.new(-0.33, 0, 0) * Angles(0, 0, -90)`. Round 1 used +90 on both, which points the left tip inward. Poses φ = +50 and φ = -20, swapped at 7.5 Hz as before.
- **Hop wing flick:** from the perched pose, an extra `Angles(0, 0, ±25)` applied before the yaw, 0.12 s.
- [check] if the wing tip points up/forward when perched, the image is upside down on that face: turn the plate 180 about its X.

| Colourway | Body | Wing (Decal.Color3), darker than round 1 | Beak |
|---|---|---|---|
| Tide | #2A6BE0 | #173F9E (was #1E4FB8) | #FF9F1C |
| Coral | #FF7C6B | #C93F3A (was #E2574C) | #FFD23F |
| Sun | #FFD23F | #E08A10 (was #F2A91E) | #FF7A1A |

## 2. Butterfly: 3 parts

| # | Part | Shape | Size | Offset | Colour / decal |
|---|---|---|---|---|---|
| 1 | Body | Block | 0.10, 0.10, 0.50 | 0, 0, 0 | ink #24304F |
| 2 | Wing R | decal plate, thin in **Z** | 0.70, 0.84, 0.02 | `CFrame.new(0.05, 0.03, 0) * Angles(0, 0, φ) * CFrame.new(0.35, 0, 0) * Angles(-90, 0, 0)` | Back face `butterfly-wing.png`, Front face `butterfly-wing-m.png` |
| 3 | Wing L | decal plate, thin in **Z** | 0.70, 0.84, 0.02 | `CFrame.new(-0.05, 0.03, 0) * Angles(0, 0, -φ) * CFrame.new(-0.35, 0, 0) * Angles(-90, 0, 0)` | Back face `butterfly-wing-m.png`, Front face `butterfly-wing.png` |

- The plate is built standing (so its Front/Back faces are upright) and the last `Angles(-90, 0, 0)` lays it flat: image top becomes forward, the Back face becomes the upper side.
- `butterfly-wing.png` has the wing root at the image's left edge and the larger fore wing at the top; `-m` is its mirror. **Pass test, one look in Studio: on all four faces the dark root touches the body and the larger lobe is forward.** If a face fails, swap that face's file for the other one.
- Span is 1.5 studs (was 1.25), wings 0.84 long (was 0.56): rounded two-lobe silhouette, near-black border and veins, tinted field and edge dots.
- `Decal.Color3` = the wing colour from LOOK.md section 2 (Rose #FF327A, Citrus #FFCC00, Iris #7A35F0, Tide #0A4FD0), unchanged. The texture's black stays black under any tint.
- Flap poses, rest poses, height, heading: unchanged (φ = +60 / -15 at 7.5 Hz; rest 70 to 20 at 0.5 Hz).

## 3. Petals

| Property | Round 1 | Round 2 |
|---|---|---|
| Size | 0 → 0.20, 0.10 → 0.35 (±0.07), 1 → 0.30 (±0.05) | 0 → 0.40, 0.10 → 0.68 (±0.12), 1 → 0.60 (±0.10): 0.56 to 0.80 studs |
| Rate at a full gust (`Sim.PetalPeak`) | 3 a second per crown | 7 a second per crown |
| Gust burst | none | `Emit(6)` once per crown when its wind first passes 0.6; re-arms when it falls below 0.3 |
| Live cap (`Caps.petals`) | 24, 12, 0 | 40, 20, 0 |
| Lifetime (`Sim.PetalLife` = the max) | 4.5 to 5.5 | 5 to 6.5 |
| Speed / Drag | 1 to 2.5 / 0.4 (about 5 studs of travel) | 3.5 to 6 / 0.25 (12 to 19 studs downwind, clear of the crown) |
| Acceleration | 0, 0, 0 | 0, -0.5, 0 (they sink to grass height over the life) |
| SpreadAngle | 35, 35 | 25, 25 |
| Emitter box | crown size, `Volume` | crown size, `ShapeStyle = Surface` (they start on the crown's skin, not hidden inside it) |
| RotSpeed | -70 to 70 | -120 to 120 |
| LightInfluence | 1 | 0.5 (not dark in tree shade; Brightness 1, LightEmission 0 stay) |

Result: a full gust of 4 s puts about 28 + 6 petals off each crown, trailing 12 to 19 studs downwind as a visible streamer, never more than 40 alive.

Colours by slot (texture and tint method unchanged):

| Crown state | Slot 1 | Slot 2 | Slot 3 |
|---|---|---|---|
| Lime crowns | #FFF6C2 cream | #FFE66B yellow | #F4FFD0 pale lime |
| Pink crowns | #FFB8D6 | #FF8FBF | #FFE3EE |

Round 1's lime set was all pale lime, the crown's own hue; cream and yellow separate from crown, grass and sky. "Never" changes: petal maximum 0.85 studs (was 0.45).

## 4. Bubbles: two fixed emitters, yes

Two emitters on two anchors is fine, and is the right fix: `Size` is never written after creation.

| Emitter | `Size` | Share of spawns |
|---|---|---|
| BubblesSmall | `NumberSequence.new(0.62)` | 60% |
| BubblesLarge | `NumberSequence.new(0.95)` | 40% |

Pick per spawn with the bubbles' own `Random`; move only the chosen anchor to the spot and `Emit(1)` on it. Everything else is identical on both (texture, transparency curve, speed, lifetime 9, RotSpeed), and they share the one live cap (8, 4, 0) and the 3 s cadence. No look change: the captures are right as they are.

## 5. Uploads needed

`assets/life/bird-eye.png` (64x64), `bird-wing.png` (128x184), `butterfly-wing.png` and `butterfly-wing-m.png` (160x192). All script-drawn by `scripts/draw_life_textures.py`; `petal.png` and `bubble.png` come out byte-identical.

**Captures wanted for round 3:** each bird colourway perched, side-on and front-on, close and at 30 studs; one flying frame per flap pose; all four butterflies from above and from below (wings up); petals at the peak of a gust with lime and with pink crowns, from 40 studs; one small and one large bubble in the same frame.

## Uploaded (Opus, 2026-11-22)

- `assets/life/bird-eye.png` -> `rbxassetid://127417519256529`
- `assets/life/bird-wing.png` -> `rbxassetid://81512459364906`
- `assets/life/butterfly-wing.png` -> `rbxassetid://108754043011076`
- `assets/life/butterfly-wing-m.png` -> `rbxassetid://95949019207820`
