# Garden hour: the light look (Fable, 2026-11-23)

World pass item 6, after the Architect check and Spencer's answers (34 day / 8 golden / 12 bright night / 6 dawn, one clock for everyone, beta first, pets stay awake). Values only; Opus builds. **Nothing here has been seen in Studio**: every number marked `[check]` is my best start and I review captures (white Bear, Bunny and the darkest coat, each phase, desktop and phone) before publish. Day and golden are existing approved tables; night and dawn are new.

## 1. The hour

`s = GetServerTimeNow() % 3600`. Each blend sits in the first seconds of the phase it leads into.

| Phase | s | Blend in | Hold | Daylight (the one shared number) |
|---|---|---|---|---|
| Dawn | 0 to 360 | 90 s from night | 270 s | .50 |
| Day | 360 to 2400 | 90 s from dawn | 1950 s | .90 (= `WorldAero.Daylight`) |
| Golden | 2400 to 2880 | 90 s from day | 390 s | .55 (= `WorldDusk.Daylight`) |
| Night | 2880 to 3600 | 120 s from golden | 600 s | .12 |

- Blend fraction `f` is smoothstepped (`f*f*(3-2f)`). Every number and Color3 lerps by `f` (RGB `Color3:Lerp`), Daylight included.
- **One daylight.** With the hour on, `Clock.sample`, `Clock.lastDaylight`, `Clock.daylight()` and the Aero look's `Daylight` all return this value. No reader keeps .9.
- Night finds (`Book.isNight`) read the phase (`s >= 2880`), not daylight, from the shared module.

## 2. Light per phase

Day is `WorldAero` unchanged. Golden is `WorldDusk` unchanged except the two marked cells.

| Property | Day | Golden | Night | Dawn |
|---|---|---|---|---|
| ClockTime | 10.5 | 16.9 | 22.5 | 7.1 |
| Brightness | 1.85 | 2.6 | 1.25 | 1.6 |
| ExposureCompensation | 0 | .08 | .10 | .04 |
| Ambient | #7C8894 | #9C8698 | #5E6A9C | #86889C |
| OutdoorAmbient | #8CAAC8 | #B89CA8 | #7890D0 | #A0B0CC |
| ColorShift_Top | #FFF6E0 | #FFD49A | #BFD4FF | #FFE2C4 |
| ColorShift_Bottom | #BFE4FF | #E6A2BE | #6FD8F0 | #A8ECF0 |
| EnvironmentDiffuseScale | .2 | **.25** `[check]` (Dusk has .35) | .2 | .2 |
| EnvironmentSpecularScale | .2 | .2 | .25 | .2 |
| ShadowSoftness | .5 | .55 | .7 | .6 |
| Atmosphere Density / Offset | .28 / .1 | .26 / .12 | .24 / .1 | .30 / .1 |
| Atmosphere Haze / Glare | 1.2 / .2 | 1.4 / .45 | .8 / 0 | 1.5 / .3 |
| Atmosphere Color | #CFEFFF | #FFD2B8 | #5A6FB8 | #CFF2F0 |
| Atmosphere Decay | #8FCBF5 | #E59CC2 | #2E3A78 | #FFC9A8 |
| Grade Brightness / Contrast / Saturation | 0 / .05 / .12 | 0 / .06 / .14 | .02 / .04 / .08 | 0 / .05 / .12 |
| Grade TintColor | #F6FBFF | #FFF1E4 | #E6EEFF | #FFF6F0 |
| Bloom Intensity / Size / Threshold | .18 / 20 / 1.3 | .12 / 16 / 1.4 | .18 / 20 / 1.2 | .15 / 18 / 1.35 |
| SunRays Intensity / Spread | .03 / .5 | .035 / .55 | 0 / .5 | .04 / .55 |
| Sky faces (stepped) | day | dusk if uploaded, else day | night | day |
| Sun / Moon angular size (stepped) | 12 / 0 | 16 / 0 | 12 / 9 | 14 / 0 |
| StarCount (stepped) | 0 | 0 | 1200 `[check]`; 0 if the night faces already carry painted stars | 0 |
| `Clouds` Color (Cover .5, Density .3 fixed) | #FFFFFF | #FFD9E4 | #8FA2D8 | #FFE6DC |
| Backdrop cloud Color (`W7_Backdrop__cloud*`) | #FFFFFF | #F6C2D8 | #7E90C8 | #FFE6DC |
| Far peaks | textured | textured | flat #56629A `[check]` | textured |

- Bloom Intensity never above .18 in any phase or blend.
- ClockTime 22.5 puts the moon where the 10.5 sun is, so night shadows fall the same way as day shadows.
- **Surface tints, water skins, crowns and marble do not change by phase.** AeroWorld still paints each item once; only the light moves. Exception: `glow_warm` Color #FFE08A by day, #FFC96A at golden, night and dawn (lerped with the blend, 9 meshes).

## 3. The white Bear rule (holds at every second of the hour)

Night floor; a value may be raised, never lowered:

| Brightness | Ambient | OutdoorAmbient | ExposureCompensation | EnvironmentDiffuseScale | Bloom Intensity | Atmosphere Density |
|---|---|---|---|---|---|---|
| >= 1.1 | >= #566090 | >= #6E86C8 | 0 to .15 | <= .2 (a ceiling: above it the muzzle goes flat, as in `bear-plan-light-washed.jpg`) | <= .18 | <= .30 |

Pass test on an 8-bit capture, Bear facing camera at 12 studs, measured in each phase and at the middle of each blend:
- Lit cheek luminance 150 to 232. Above 232 it is washed; below 150 it reads grey.
- Muzzle at least 12 below the cheek. Eyes 60 or under. Blush still pink (R minus B at least 25).
- Lawn under the Bear 90 or more at night (grass no darker than mid-value). Darkest coat: body at least 45 above its own eye shapes.
- Pet night glow (`PetMaterials.nightGlow`, .93 at daylight .12) and Neon face sparks (daylight < .35) stay on, but if the glow breaks the muzzle line, cap the glow ramp at .6. `PetFocusKey` (daylight < .5, camera within 14 studs) stays as is.
- **Pets stay awake:** with the hour on, `PetExpression.garden` ignores the night test (`Expression.Night`); deck play still dozes them. Coos follow the face, so no sleepy coos at night.

If golden fails the cheek test under the Aero surfaces (it was only ever approved on the dusk-lock garden), drop golden Brightness to 2.2 before touching anything else.

## 4. Blends

| Blend | Length | ClockTime path | Sky faces, stars, moon, peaks step at |
|---|---|---|---|
| Dawn to day | 90 s | 7.1 to 10.5 | no step (same faces) |
| Day to golden | 90 s | 10.5 to 16.9 | f = .5, only if dusk faces exist |
| Golden to night | 120 s | 16.9 to 22.5 | daylight crossing .35 (`Clock.SkyThreshold`, about f = .47) |
| Night to dawn | 90 s | 22.5 forward through 24 to 7.1 | daylight crossing .35 (about f = .57) |

- **Haze cover for the face swap:** in the two night blends add `sin(pi*f)` times +.06 Density (peak .32 at most on screen, clamp total to .34) and +.5 Haze, so the swap happens under the thickest air.
- **Sun and moon handoff** (ClockTime 18.0 and 6.0): the key light changes source and can pop `[check]`. Pinch it: Brightness multiplies by `1 - .45 * max(0, 1 - |ClockTime - handoff| / .6)`, never under 1.1.
- ClockTime always moves forward; never lerp backwards through noon.

## 5. World extras

| Extra | Day | Golden | Night | Dawn | Rule |
|---|---|---|---|---|---|
| Lamps (`HollowLamp` PointLights) | 10% | 45% | 88% | 50%, falling | existing formula `night + (day - night) * daylight`; no new code. They rise over the 90 s blend, not 20 s |
| Fireflies | 0 | 0 | 12 | 0 | spawn while daylight < .3; stop spawning above it and let the last ones fade |
| Waterfall rainbow | on | off | off | off | raise `Waterfall.RainbowDaylight` from .5 to .7 (golden is .55 and would show it) |
| Dew glints (4 lawns) | on | off | off | off | daylight > .7 |
| Birds, butterflies, bubbles (Garden life) | on | off | off | off | spawn only while daylight > .7; ones already out finish their path |
| Dewdrop fruit, petals, wind, waterfall layers | on | on | on | on | unchanged |
| Ambient audio | day bed | dusk bed | night bed | dusk bed | existing bands (> .6, >= .3, below); no change |
| Stars | 0 | 0 | 1200 | 0 | engine stars; no new parts |

**Fireflies:** one 32 px soft dot (new upload, or the glint sparkle until drawn), billboard .35 studs, Color #E8FF8A, LightEmission 1, no PointLight. 12 alive at most: 2 on each of the four finds lawns (`WorldAero.Glints` rectangles) and 4 along the stream bank. Height 1.5 to 4 studs over the ground, drift .6 studs/s, life 4 to 6 s with a 1 s fade each end, brightness pulse period 1.8 s. None within 6 studs of the camera, none over water. Budget level 1: 6. Level 2: 0. One emitter per area (5 draws).

## 6. What the client lerps, and how often

- **Lerped:** every row of section 2 not marked stepped, the shared Daylight, lamp Brightness (through Daylight), `glow_warm` Color, the handoff pinch and the haze cover.
- **Stepped once:** sky faces, StarCount, Sun and Moon size, far-peak texture, each extra's on or off.
- **Holds (3210 s of the hour):** keep the 5 s pass. Values are equal, so `AeroWorld.write` issues no setters.
- **Blends (390 s of the hour): do not use 5 s steps.** A 5 s step moves ClockTime up to .36 h and the shadows hop. Recommend a per-frame lerp capped at 20 writes a second (10 on budget level 1, 2 on level 2), running only while `f` is between 0 and 1; lamps repaint on the same tick. The clock works out `f` from `s` each tick, so a late joiner or a stalled frame lands on the right value with no catch-up.
- One writer still: the hour's blended table is what `Clock.look.paint()` writes. WorldDusk and WorldAero stay as value tables; add `WorldNight` and `WorldDawn` in the same shape.

## 7. Reduced Motion

Nothing changes but motion: same phases, same colours, same lamps, same times.
- No fireflies (as scoped). Stars stay.
- ClockTime does not sweep: it steps once per blend at the sky step point (f = .5 where there is no sky step), under the haze cover, so shadows do not slide across the lawn. Colours and brightness still lerp.
- The existing Reduced Motion rules for waterfall layers, glints and Garden life are untouched.

## 8. Captures I need before publish

Bear, Bunny and the darkest coat on the south lawn, each of the 4 holds and the middle of each of the 4 blends (8 moments), desktop and phone; one wide shot per phase from the arrival dais; one of the falls pool at golden (rainbow off) and night (fireflies, no overdraw wash).
