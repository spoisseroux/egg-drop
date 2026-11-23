# Garden hour review R1 (Fable, 2026-11-23)

**Verdict: GO for the private beta, with the four value fixes below.** Not yet a GO for live: see "Still owed".

Reviewed: `garden-hour/night.jpg`, `night-bear.jpg`, `golden.jpg`, `dawn.jpg` against day (`4-nest-chip-bubble-G.jpg`, `lime-mapped.jpg`). Luminance figures are 8-bit samples from those JPEGs (small patches, one desktop capture each), so treat them as plus or minus 10.

## What I saw

| Phase | Reads as | Measured | Call |
|---|---|---|---|
| Night | Bright blue night, lawn still green, lamps on, arch and dais clear. The garden is fully playable. | Lawn 89 to 94 (floor 90), arch 158, sky 69, rock 53 to 60 | Pass |
| Night Bear | **Face is readable**: eyes, nose, mouth and muzzle line all clear. But the head glows cyan and clips. | Forehead and lit cheek 238 to 240 with green at 254 (cap 232); shaded cheek 198; muzzle 152 (46 under the cheek, pass); eyes 76 to 92 (target 60); blush R minus B is about -80, so it reads lavender, not pink | Fail on cheek cap and blush. Fix 1 |
| Golden | Warm peach garden, the strongest phase. Rocks go sand-tan, sky corner goes near-white. | Lawn 94, arch 179, dais 162, rock 149, sky 246 | Pass. Fix 2 and 3 |
| Dawn | Too close to day: cooler and a little dimmer, no warmth. A player will not notice it is dawn. | Lawn 83, sunlit arch 238, rock 89, sky 195 | Pass for beta. Fix 4 |

## Fixes (exact values)

1. **Night, pet glow:** cap the `PetMaterials.nightGlow` ramp at **.6** (it is .93 at daylight .12). This is the cap section 3 of the look already allows. Do not lower night Brightness or ExposureCompensation: the lawn sits right on its floor of 90.
2. **Golden, EnvironmentDiffuseScale: .25 becomes .2.** Settled: the white-Bear ceiling wins. There is no Bear close-up at golden to prove .25 is safe, and .2 makes the value the same in all four phases, so it no longer lerps. `GardenHour.lua` line 39. Golden Brightness stays 2.6.
3. **Golden, Atmosphere Glare: .45 becomes .30.** The sky corner is at 246 and loses its pink.
4. **Dawn, make it its own phase:** Atmosphere Color #CFF2F0 becomes **#FFE0D0**; Haze 1.5 becomes **1.8**; Grade TintColor #FFF6F0 becomes **#FFEEE2**; ExposureCompensation .04 becomes **0** (sunlit white stone is at 238). Brightness stays 1.6.

Day: no change.

## Not judged from these captures

- Fireflies and stars: none are visible in either night shot, so I cannot say they work. One night capture at the falls pool and one looking up, please.
- Golden and dawn Bear: no close-up, so the cheek test is unmeasured there.
- The night eye reading (76 to 92) is likely the glow lifting the eye shapes; re-measure after fix 1.

## Still owed before live (section 8 of the look)

- Night Bear re-capture after fix 1: cheek 232 or under, blush R minus B at least 25, eyes 60 or under.
- Bear close-up at golden and dawn; Bunny and the darkest coat in all four phases.
- The middle of each of the four blends, and the sun and moon handoff, checked for a pop.
- Phone captures of each phase.

Context only: the owner `/hour` commands show as chat bubbles in the captures. Not a lighting issue and not my call.
