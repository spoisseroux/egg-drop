# World plan: places, wayfinding, onboarding, Aero (Fable, 2026-11-22)

**Scoping only; nothing built or approved.** From code, the walk map and five stills; nothing run in Studio. Every coordinate (x, z), distance (route studs; seconds at 16 studs/s) and sightline is an estimate to raycast and walk on a phone. Spawn is (96, 66), facing the hub (-30, 4).

> **Measured on the built garden (Opus, 2026-11-22, server raycasts).** Interim pad (74, 38): flat, y 4.6, all 113 points ground. Dash Meadow start (76, -8): ground at y 4.1 and up, but 19 of 197 points within 8 studs are `W7_Rocks__cliff_rock` (up to y 15.9), so move the start a few studs west and re-measure. Straight line from there to (40, 2): 60 points, no gap, no step over .1 stud. Sightlines, trees over the camera and every other coordinate are still unmeasured. The Dash page must not promise Stars while `garden_dash_prizes` is off.

## 1. What's wrong today

- **Dash sits in the doorway:** gate and start hoop under the arrival arch, 19 studs from spawn, on the path every newcomer walks.
- **The avatar is the view.** `countdown.jpg`: avatar centre, arch pillar across the left third, pets hidden. `gate-card.jpg`: the card covers the pet.
- **Trees cross the camera** (`hurdle.jpg`); name tags overlap; pale hoops vanish against pale marble.
- **No place has a face.** `StationAttract` knows the hub stations and the park gate. Dash, finds and ASMR have no landmark; the grove park hides behind the hub.
- **Nothing tells you.** The `garden` tour and `How.Order` never mention Dash; only the park has a coach line.
- **The east lawn** (20..80, -30..15) is empty but for the Bubble Spring.

## 2. A place for each

| Activity | Region | From spawn | Seen from spawn | Conflicts | Landmark |
|---|---|---|---|---|---|
| Pocket Deck | Hub plaza (-30, 4), as now | 144, 9 s | Path leads there | Dash skirts the plaza | A giant handheld on a plinth, eggs falling on its screen |
| Pet Park, arrival | (36, 66), as now | 45, 3 s | Yes, left of the arch | None once Dash moves | The slide and star-orb gateway (exist) |
| Pet Park, grove | (-38, -46), as now | 195, 12 s | No | None | A paw kite on a tall pole above the hub roofs |
| Garden Dash | **Dash Meadow**: start (76, -8), west along z = -9 | 100, 6 s | Yes with a tall mark, right over open lawn | Bubble Spring (52, 3), tree (72, -22), rock (69, 8) | A striped start arch with a flag balloon bobbing above |
| Garden finds | Lawns: south (56..88, 70..80), east (20..45, -25..-12), west (-100..-75, 8..35), grove edge (-85..-60, -55..-30) | 20 to 200 | The sparkle | 6 studs from kerbs, course, ASMR | A four-point sparkle that twinkles harder as you near |
| Keycap path | (86, 70) curving to (58, 74), the park's east gate | 15, 1 s | Yes, beside the dais | Finds spots | Fourteen candy-coloured keys you can't not step on |
| Pop pad | (57, 9), by the Bubble Spring | 80, 5 s | From the meadow path | Spring rests (49.5, 14), (54.5, 14) | A bubble sheet under the spring's real bubbles |
| Squish bench | (56, 22) | 70, 4 s | From the side path | Old course (x = 44), 12 away | A wobbling jelly block on a bench |
| Crunch patch | Under the tree at (-12, 33) [check kind] | 130, 8 s | From the bridge | Course, 12 away | Gold leaves that puff when a pet runs through |
| Tug (later) | (-64, -42), west of the grove park | 215, 13 s | No | Grove finds | A rope with two flags on a mat |
| Treasure Hunt (later) | Rally stone (-88, 22) | 205, 13 s | No | Dash finish (-84, -10) | A map stone with a spinning star |

**Dash start, two options**

- **A. Keep the course, move the people.** Gate, sign and gather pad go to a paddock at (74, 38), 12 studs off the line; the start hoop shows only while a race gathers or runs. S, data only. The race still crosses the doorway.
- **B. New start (recommended).** Start (76, -8), 36 studs west over open lawn, joining today's line near d = 7600 (38, 1.5), before the stones fork. Drops the doorway and the tree stretch; about 182 studs against 220. Rerun `build_dash_course.py`, re-derive pars, repeat the race evidence. M, no world export. A covers the beta meanwhile.

**Camera rules:** follow the pet, never the avatar (the owner waits on the gather pad, hidden locally); 14 back, 9 up, 25 degrees down [P]; a crown or pillar between camera and pet fades to 75% clear; the gate card opens over a side-on course shot, in the lower third; other pets' tags only within 12 studs.

## 3. Wayfinding

- **Fingerposts** at the first fork (60, 50) and the hub: icon arms (paw, flag, sparkle, keycap, handheld), no words.
- **"Things to do"**: a Pocket menu tile and the same board by the arch (88, 60). Rows show live state ("Race: 2 of 8", "2 finds waiting") and **Show me**, which lays paw prints to the place for 20 s.
- **StationAttract:** new places join `StationAttractData` with the same ranges (beckon 40, invite 14, marker 18). One beckon at a time (nearest unlearned), none while a coach line shows.

## 4. Onboarding

**Order.** Round one: nothing. After the Bear, first egg and the existing tour:

| # | Trigger | Where | Copy |
|---|---|---|---|
| 1 | Tour closed, standing still | Rail | "Pet Park" / "{pet} wants to play. Follow the paw sign." |
| 2 | First play date done, or second visit | Ticket | "Garden Dash" / "Race your pet. It's free!" [Show me] |
| 3 | First find within 20 studs | Rail | "Something sparkles" / "Walk {pet} over to sniff it." |
| 4 | Within 14 studs of the keys | Label, once | "Keycap path" / "Step on the keys." |
| 5 | Any new place, returning player | "New" dot plus one ticket | "New in the garden" / "{name} is open." |

- **Tour:** one added card: "Things to do" / "Find every game in Things to do."
- **How it works `dash`** (add to `How.Order`): a "Your pet runs. You help." b "Tap Jump at each hoop." c "Hold Dash to zoom. Let go to rest." d "Two Stars a race, five races a day."
- **How it works `finds`:** a "Sparkles hide on the lawn." b "Your pet sniffs them out for Smarts."
- **Quests:** daily "Run one Garden Dash", "Sniff out 2 finds"; weekly "Finish 5 races"; each with Show me.
- **First-race helper** (looks only): Just for Fun preselected; "Tap Jump now!" at the first hoop, "Hold Dash!" on the first straight; three hints, gone after one clean jump.
- **Caps:** each once ever (new `coachMask` bits); one line at a time on the rail; two intros a session, five minutes apart. Returning players get row 5 once per new thing.
- **Never interrupt:** a deck round, hatch reveal, greeting shot, open menu or card, race, play date, petting, purchase, or a moving player.
- **Strings:** whole sentences with `{pet}`, `{name}`, `{count}`; no joined fragments or idioms; three-word titles, lines under 60 characters; in `UICopy` for the export.

## 5. Frutiger Aero

Shared palette: sky top #2F9BEF, horizon #BFE9FF, cloud #FFFFFF with shade #D6ECFA, grass #5FCB3F and #2FA84F, water #3CC8F0 over #1689D6, glass #CFF4FF, aqua #19C2C9, lime #A6E22E, blossom #FF9FC8 (accent only), marble #F4F7FA, sun #FFD23F, ink #24304F.

| | Light: Clear Morning | Medium: Dewy Glass (recommended) | Full: Sky Lagoon |
|---|---|---|---|
| Sky and light | Blue sky, white clouds. ClockTime 10.5, Brightness 2.6, OutdoorAmbient #9FC4E6, Atmosphere density .28, colour #CFEFFF, haze 1.2; bloom .35; saturation +.12 | Same | Same, plus aurora ribbons |
| Water | Recolour, 35% clear | Plus two caustic layers, ripples, reflectance .25 | Plus lagoon pools, koi |
| Glass and stations | None | Glass dome on Eggs, gloss lips, rounded signs like the menus, dew glints | Glass rails, pod stations, pale stone for warm rock |
| Cost | S to M; no export if clouds recolour in code [check] | M to L; export only if grass colour is baked [check] | L+, full export |
| Store art | Re-audit thumbnails | New captures | Everything, icon too |

Medium, with Light first behind a flag. The Bear reads white, so grass stays mid-value and paths stay dirt: pale pets never stand on pale ground.

## 6. Alive steps 5 to 7 on the map

| Thing | Where | Cap |
|---|---|---|
| Petals | Pink crowns on the west bank (-20..-5, 25..40) and hub | 3 emitters, 24 petals |
| Bubbles | Rise from the Bubble Spring; drift near the camera | 8; none over a prompt |
| Birds | Arch top, bridge posts, rotunda (-60, 50); never stations or a live Dash arch | 3 |
| Butterflies | Arrival park flowers, lawn (45..60, 20..35), ToyLawn edge | 4 |
| Sway | Bushes, then leaf tufts, then five shared crowns | 16 bushes, 60 parts on phones |
| Fish | Pool under the bridge | 2 |
| Residents | Picnic (34, 46), park swings, spring rests, Dash Meadow onlookers | 3 alone, 0 at 4 real pets |

## 7. Build order

| Slice | Size | World export |
|---|---|---|
| 1. Dash: option A on beta, camera rules, helper | M | No |
| 2. Things to do, fingerposts, attract entries, onboarding copy | M | No |
| 3. Dash Meadow (option B), start arch and balloon | M + art | No |
| 4. Garden finds on the four lawns | S | No |
| 5. Aero Light | S to M | No [check] |
| 6. Keycap path and crunch patch (after the sound test) | M + art | No |
| 7. Alive 5: petals, bubbles, birds, butterflies | M | No |
| 8. Aero Medium, pop pad, squish bench | L | Maybe |
| 9. Crowns sway; residents; Tug, Treasure Hunt | L | **Yes** (crowns) |

## 8. Spencer's picks (2026-11-22)

"Medium, rework the environment a bit to be more frutiger / 1 easy measure / 2 somewhere else? / 4 make a different shade of green? Or a different red? / 5 board as in pocket deck? Menu only / 6 shorter ig"

1. Dash start: read as **east meadow** (option B).
2. Keycap path: **not beside spawn**; Fable picks another spot.
3. Aero: **Medium**, and rework the environment a bit to read as Frutiger Aero (shapes stay, no landscape swap).
4. Pink trees change: a different green, or a different red; Fable picks, shown to Spencer in captures.
5. Things to do: **menu only**, no board in the world.
6. Race: **shorter**.

## 9. Medium, exact (Fable, 2026-11-22)

Proposal from code and three dusk captures; nothing run. Capture every value with the Bear and Bunny on grass, path and marble.

**How.** A `WorldAero` table shaped like `WorldDusk`, picked by one flag in `Art.lighting` and `Clock.dusk`. Surface values go on the clones in `Art.meshes`, by the name after `__`. Matte surfaces are white parts under a SurfaceAppearance: only `SurfaceAppearance.Color` moves them, and it multiplies, so it can darken or shift, never brighten. Good: grass and path stay mid-value under pale pets.

| Surface | In code |
|---|---|
| grass | SA.Color #F0FFD6 |
| meadow | SA.Color #E4FFC8 |
| foliage | SA.Color #E6FFE0 |
| dirt_path, pebble_bed, bark | unchanged (#FFFFFF) |
| cliff_rock, boulder_rock | SA.Color #E2EAF0 (cooler, 8% darker) |
| marble, marble_smooth | colour can't move (textured MeshPart) [check]; Reflectance .06 and .12 |
| trim | Reflectance .18 |
| water_stream, water_pool, Landmarks water | stays opaque (it sorted through pet heads); Reflectance .22 |
| FlowSkin stream / pool / landmark | Color3 #3CC8F0 at .42 / #7FE0FF at .5 / #7FE0FF at .5 |
| FlowGlint | Color3 #FFFFFF at .6 |
| fall beams, splash, mist | #DDF6FF, #F4FCFF, #E9F8FF |
| glow_warm, glow_aqua | #FFE08A, #4FE6FF |
| glow_pink | #C4F060 |
| cloud (backdrop and water), foam | #FFFFFF |
| bubble | #DEF3FF, Transparency .55, Reflectance .2 |

**Light.** Hour 10.5, Daylight .9. Brightness 2.4, ExposureCompensation 0, Ambient #8C9AA8, OutdoorAmbient #9FC4E6, ColorShift_Top #FFF6E0, ColorShift_Bottom #BFE4FF, EnvironmentDiffuseScale .4, EnvironmentSpecularScale .2 (pets depend on it), ShadowSoftness .5. Atmosphere: Density .28, Offset .1, Haze 1.2, Glare .2, Color #CFEFFF, Decay #8FCBF5. Grade: Contrast .05, Saturation .12, Tint #F6FBFF. **Bloom .18, Size 20, Threshold 1.3**, not section 5's .35: marble haloed at .28 in the 11-13 QA. SunRays .03, .5. Sky: day faces, sun at 12, no stars; if not near #2F9BEF, new painted faces (an upload, not an export). `Clouds` under Terrain: Cover .5, Density .3, #FFFFFF [check on a phone].

**Trees: a different green (recommended), lime #8FD63F.** The alternative is coral red #F2545B. Lime is the palette's accent, splits these crowns from the dark foliage and leaves pink and white to the pets; red beside green pulls the eye off them. Cost: pink can't multiply to green, so the three blossom parts drop the SurfaceAppearance and TextureID and become flat Fabric #8FD63F. Red is a tint (SA.Color #FF7078) and keeps the leaf texture. Capture both; if flat lime reads cheap, ship red until the export. Petals follow the crown.

**Additions, in slice order**

| Slice | Thing | Cap |
|---|---|---|
| 5 | Everything above, behind the flag | |
| 7 | Bubbles | 8 (section 6) |
| 7 | Dew glints: sparkle emitters on four lawns, size .25 | 4 emitters, 24 live |
| 8 | Gloss lips: white ring, Reflectance .35, on each station rim | 6 |
| 8 | Rounded signs: #CFF4FF glass at .25, corner 16, ink #24304F icon, no words | 6 |
| 8 | Glass dome on Eggs: Glass #CFF4FF, Transparency .7, Reflectance .15, no collide, query or shadow, too small to stand in [check sorting] | 1 |

**Keycap path.** From (58, 26) curving north-west to (40, 42), ending at the picnic (34, 46); region x 38..60, z 24..44; fourteen keys over about 28 studs; roughly 60 studs and 4 s from spawn. One ASMR corner with the squish bench (56, 22) and pop pad (57, 9), off the arrival line, 35 studs from Dash Meadow. Unmeasured: flatness, crowns over the camera, finds, the interim pad (74, 38).

**Re-export later (slice 9, with split crowns):** a textured lime blossom map; marble map down to #E6ECF2 so pale pets read on the plaza; `FLAT` cloud and foam back to white, `PALETTE_SATURATION` 1.0. Store art is re-audited when the flag goes on.
