# World pass: lime trees, wind, fruit, waterfall, edges, garden hour (Fable, 2026-11-22)

A scope. **Nothing here is approved or built.** Spencer, 2026-11-22: "we also need to make the lime trees more textured, trees should blow in wind? Have fruit ? The waterfall needs a big rework too, should we prevent players from going up the mountains and off the island etc? ... And should we add like a 1hr day night cycle?"

Looked at: `artifacts/world-pass-2026-11-22/` (4), `artifacts/aero-2026-11-22/` (5), `artifacts/alive-life-2026-11-22/round2/` (8). Read: WORLD-PLAN 5, 6, 9; ALIVE-BRIEF B5 and 3; ALIVE-SAFETY 3 and 4; `WorldAero`, `HollowClock`, `WorldDusk`, `LoungeWorldV7Art`, `Lounge`, `world-v7-walk.json`, `world-v7-manifest.json`, `build_world_v7_*.py`. Nothing was run. `[check]` marks what Opus must confirm in Studio.

All art below is our own (script-drawn textures, our Blender). No outside assets are needed, so nothing to confirm under V3-SCOPE 12.9. No AI art or audio.

**What "export" means here.** The island is baked from Blender: `build_world_v7_chunks.py` merges it into 90 meshes and writes `world-v7-walk.json`; `build_world_v7_assets.py` writes `WorldV7Data`. Changing a mesh shape, splitting a mesh, vertex colours or collision means a re-export, mesh uploads through the proof gate, and the precise-collision rebuild in Edit (TODO W1 note). Colours, textures, beams, particles, invisible parts and light are runtime or a texture upload. **Blocker for any export:** the pipeline scripts still hold uncommitted edits (`build_world_v7_assets.py`, `_chunks.py`, `_collision.py`, `world_native_collision.py`); commit or shelve first (ALIVE-SAFETY 3).

---

## 1. Lime trees, more texture

In `lime-tree.jpg` and `lime.jpg` the lime crowns are one flat colour with only face shading. Beside the dark crowns (which carry a leaf texture) they read as unfinished clay. All lime crowns are one merged part, `W7_Vegetation__foliage_blossom`, 2,020 triangles.

| | What | Cost | Export |
|---|---|---|---|
| **A. Drawn lime leaf map** | A script-drawn 256 px leaf map made lime from the start (base #8FD63F, clump shade #6FBF2E, sun flecks #C4F060, a few #E8FFB0 gloss dots), on a new SurfaceAppearance for the blossom part. Uses the UVs the pink map used. Nothing multiplies, so "pink cannot multiply to green" no longer applies | S; one texture upload; SurfaceAppearance must be authored in the asset file, not at runtime `[check]` | No |
| B. Vertex-colour shading | Bake light tops (#B8F060) and dark undersides (#5FAE2A) into the crown vertices; keeps the flat lime part | M | Yes |
| C. Clumped crowns | Rebuild each crown as 3 to 5 overlapping puffs with a gloss rim, shared across trees | L | Yes |

**Pick: A now, then B and C together inside the one re-export (section 2).** A alone removes the clay look. Keep the map soft and low-contrast: the dark crowns are already busy (see `petals-burst.jpg`), and lime is the accent, not the subject. If A's map tiles badly on the old UVs, fall back to B early.

## 2. Trees in the wind

Crowns cannot sway today: the dark crowns are one part (3,660 triangles) and the lime crowns another. Moving either moves every tree at once.

- **What moves:** crowns only. Trunks, `W7_Trunks` collision, perches and the Hatch Tree's prompt never move. Crowns already have no collision and no query.
- **How:** ALIVE-SAFETY option A2. Five shared crown meshes (3 dark, 2 lime), about 24 crown parts for 31 trees plus the Hatch Tree, clumping twos and threes. Each pivots at the crown base (trunk top). `WorldMotion.sway` pivots at the part top today, so it needs a base-pivot mode. Followers of `Wind.at`: rest 1.2 degrees, gust peak 4, lean 1.5 downwind, own period 3.4 to 4.6 s (ALIVE-BRIEF section 3).
- **Budget:** inside ALIVE-SAFETY 4: 0.4 ms p95, 30 Hz, one `BulkMoveTo`. Phones: nearest 12 crowns within 120 studs (bushes keep 16, total under 60). Scene: at most +10 draws, +1,500 triangles, +0 shadow draws.
- **Shadows:** moving crowns cast none. Add one soft drawn shadow decal under each tree (32 decals, static) so trees don't float `[check against real shadows]`.
- **Birds** perched on a crown read the same `Wind`, or they hover.
- **Waits on the export:** yes. Until then the gust still reads on trees through the lime leaves that blow off them (B4, already running) and the bushes.

**Pick: A2, size L, in the one re-export with 1B and 1C and the waterfall shapes.** One export, one proof gate, one collision rebuild. Not ALIVE-SAFETY's option C (tufts) as a stopgap: it adds draws now and is thrown away later.

## 3. Fruit

**Yes, small and for looks only.** Working name **Dewdrops**: glossy round fruit the size of a pet's paw (0.7 studs), sun yellow #FFD23F with a white gloss dot and a lime leaf cap. Yellow reads on lime and on dark green, and keeps pink and white for the pets. Lime crowns only, so the lime trees become "the fruit trees".

- **On the tree:** 2 or 3 per lime crown, 16 at most on screen. Plain Ball parts, no mesh, so no export. After the split (section 2) they ride the crown; before it they hang still.
- **In a gust:** at a strong gust peak (strength over .8), one fruit on the nearest lime tree lets go, bounces twice (scripted, not physics) and rolls a short way downwind. Seeded from the gust number, so everyone sees the same fruit fall with no remote. At most 3 loose at once; each fades after 20 s and regrows on the tree 60 s later.
- **Pets:** a pet within 6 studs trots over, sniffs, and bats it once (one new idle beat). Your own avatar walking through it nudges it.
- **Economy:** nothing. No Stars, XP, odds, finds or currency from fruit, and no tapping reward (same rule as V3-SCOPE 13.3). No remotes, so nothing to spam.
- **Later, only as a proposal:** a fallen Dewdrop could be the picture for an existing Garden find or Stat snack, replacing its art, not adding a source.
- **Never:** over a station prompt, on the Dash route, or loose during a race.

Cost: S for fruit and falling, M with the pet beat. Client only, behind its own flag. Reduced Motion: fruit hangs, none fall.

## 4. Waterfall rework

Tumble Falls today (`waterfall.jpg`): upper sheet (81, 52, -81) to (80, 22, -80), 8.4 to 9.6 wide; lower sheet (74, 22, -74) to (73, 3, -73), 11.4 to 12.6 wide; one flat beam per sheet; splash and mist emitters on two foam boxes.

**What's wrong**
- Two flat rectangles with ruler-straight sides: it reads as a blue curtain, not water.
- Even vertical stripes at one speed: no depth, no white.
- The water starts at a hard edge under the aqueduct: no lip, no spill.
- The ledge at y 22 is a flat step: no foam roll, no splash, the lower sheet just begins.
- Sheet, pool and stream are one blue: no white water where it lands.
- No rocks break the fall, and the sheets float in front of the cliff with gaps at the sides.
- The pool is a perfect marble ring with a still surface: no rings, no foam edge.
- Mist and splash don't show at capture distance.

**Target: a glassy Aero cascade.** Clear aqua glass over deep blue, bright white where it breaks, a soft mist with a faint rainbow by day.

| # | Layer | Numbers | Where it's made |
|---|---|---|---|
| 1 | Back sheet | Today's meshes, opaque, deep #1689D6. In the export: sides tapered and wavy, bowed out 1.5 studs | Runtime colour now; shape in export |
| 2 | Flow strands | 3 beams per tier in the sheet's plane, .15 / .3 / .45 studs in front; widths 4, 3, 2.5; scroll 1.0, 1.4, 1.9; #3CC8F0 and #7FE0FF at .35 to .5 | Runtime |
| 3 | White ribbons | 2 thin beams per tier, .8 wide, #FFFFFF at .25, scroll 2.4, offset from centre so they wander | Runtime |
| 4 | Lip rolls | A white foam roll at the top lip and the ledge, 10 and 12 studs long, .9 thick | Runtime capsules now; export later |
| 5 | Impact foam | Existing foam boxes. Splash 14 a second at the ledge, 22 at the pool; size .45 to .12 (as now) | Runtime |
| 6 | Pool rings | 3 rings from the impact point, 4 to 9 studs across over 2 s, fading; plus a foam edge skin on the pool rim | Runtime (`HollowAmbience` ring parts) |
| 7 | Mist | 2 emitters, 4 a second each, size 3 to 8, #E9F8FF at .8, rising 6 studs | Runtime |
| 8 | Rainbow | One arc beam in the mist, 14 studs wide, transparency .82, day only | Runtime; a drawn 256 px strip, upload |
| 9 | Glints | Sparkles at the ledge and lip, 6 a second, size .25 | Runtime |
| 10 | Rocks | 3 wet boulders splitting the lower fall, 2 flanking, 2 in the pool, darker #7E8C98; about 400 triangles, with collision | Export |
| 11 | Sound | Keep `waterfall_loop` at .22 (Spencer asked for quieter world sound three times). Add a soft patter only within 12 studs, at .08 | Runtime; our own or already-held audio |

**Budget:** today 2 beams and 4 emitters. After: 12 beams, 7 emitters, at most 70 live particles, 5 ring and roll parts, +8 draws at worst, +400 triangles (rocks). Phones: drop layer 3 and the glints, halve the rates. Reduced Motion: beams and particles still, as `WorldMotion` does now. Sky Falls at the south edge takes layers 2, 3 and 7 only.

**Two steps.** Step 1, runtime only (M): layers 1 (colour), 2 to 9 and 11; capture from the same camera as `waterfall.jpg` plus from the pool edge and from the hub. Step 2, in the one re-export (part of L): sheet shapes, lip meshes, rocks, a broken pool rim.

## 5. Keeping players on the island

**What exists.** A ring of 122 invisible wall boxes follows the rim (`PerimeterWall`, each 15 to 22 studs tall, standing on the ground it follows, up to y 64 on the peaks); a `CaveBlocker` at (-7, 11.5, -101); a `FallCatch` plane at y -166 that returns a fallen player to the arrival dais (`Lounge.watchFallCatch`). Today's quick test: NE and W mountains not climbed (max y 8), SE edge stopped at a rail. So the answer to "should we prevent it" is yes, and it is mostly done; what's missing is proof that it holds everywhere.

**Recommendation**
- **Walls, not pushes.** Keep invisible walls. No "bonk" push and no position clamping: both fight a phone thumbstick and feel like lag. A wall you slide along is calm.
- **Mountains off-limits for now.** Where the sweep finds a climbable line, add a wall box along the foot of that slope, 16 studs tall, not on the cliff top (a wall on top means players already got up).
- **Gentle return.** Keep FallCatch, but return the player to their last safe ground spot (sampled once a second while standing on walkable ground), not always the arrival dais, behind a .3 s white cloud fade. Raise the plane to about y -90, below Sky Falls' foot at -68, so the fall lasts about a second.
- **Walls block players only.** Own collision group, no query, so pets, Dash racers, balls, petals and the camera ignore them.

**The sweep (automated, two stages)**
1. **Offline, from `world-v7-walk.json`.** Flood-fill the 2-stud height grid (132 x 115) from the arrival dais (96, 66). A step is allowed if the rise is at most 7.5 studs (a full jump) and it doesn't cross a wall box. Flag every reached cell that is on `W7_Rocks`, above y 16, outside the ring, or within 2 studs of a gap between wall boxes. Output a heat-map PNG and a list of suspect cells. Pessimistic on purpose: it finds candidates, not proof.
2. **In Studio, in a play test.** For each suspect cell, place a test avatar at the nearest safe neighbour and drive it at the cell on 8 headings, jumping, for 3 s each. Log max y, final position and whether it passed a wall or reached FallCatch. Then walk the whole rim at 4-stud steps pushing outward. Anything that gets above y 16 on rock or outside the ring is a real hole. Rerun after every export.

**Must stay reachable:** arrival dais (96, 66); Eggs (-31, -11); Journal (-17, -15); the hub; rotunda (-60, 50) and its stairs; the bridge; both banks of the stream; Tumble Falls pool edge (72, -72); Bubble Spring; the park and picnic (34, 46); the four finds lawns; the keycap path region (x 38..60, z 24..44); Dash Meadow and every Dash checkpoint.

**Not trapping pets or the Dash:** pets walk the planner's surface grid, not physics, and the walls are outside their collision group. Add to the `WorldRoutes` spec: every Dash checkpoint, find spot, station approach and pet rest spot is at least 4 studs from any wall box, and the flood-fill still reaches all of them.

Size: S for the sweep and wall top-ups (runtime boxes in `WorldV7Data`, no mesh export), S for the gentle return.

## 6. One-hour day and night

**Why it is locked today.** Not a bug or a phone problem. In the 2026-11-13 batch (W1) Spencer chose "Day/night cycle OFF for now: lock to dusk" to match his dusk mood reference, and textures, clouds and light were retuned for that one light. `FeatureFlags.DayNight=false` has held since (pinned by the LaunchFlags spec). Two more facts: the old cycle followed the real 24-hour clock, so an evening player only ever saw night; and the Aero look now sits over the clock as a fixed 10.5 morning (`Clock.look`), where full daylight already washed pale pets until Brightness came down to 1.85.

**Recommendation: yes, as a "garden hour", on the beta first.** The hour runs on server time (`GetServerTimeNow() % 3600`), so everyone in every server sees the same sky with no remote, and nobody is stuck in the dark.

| Phase | Minutes | Look |
|---|---|---|
| Dawn | 6 | Aqua and peach, lamps fade out |
| Day | 34 | Today's Aero Medium, unchanged; the hero look |
| Golden hour | 8 | Spencer's approved dusk (`WorldDusk`), pink clouds; his 11-13 mood comes back twice an hour instead of being lost |
| Night | 12 | "Glass night": deep blue, bright moon, stars, aqua rim light |

- **Night is never dark.** Floor: Brightness 1.1, OutdoorAmbient about #6E86C8, grass no darker than mid-value. Pale pets read well on darker ground; the risk is dark pets, so capture the darkest coat too. The pets' existing night glow (PLAY-BUILD, "brighter at night") keys to the garden hour instead of the real clock.
- **Lamps and fireflies.** The existing lamps and `glow_warm` come up over 20 s at golden hour. Fireflies: one drawn 32 px dot, 12 alive at most, on the four lawns and the stream bank, none within 6 studs of the camera. Rainbow, bubbles and dew glints are day only; fruit and petals keep going.
- **How:** three value tables in one shape (`WorldAero`, `WorldDusk`, a new `WorldNight`); the clock lerps light, atmosphere, grade and the surface tints once a second. Sky faces can't crossfade: swap them under the thickest haze of each change `[check]`. Bloom never above .18.
- **Reduced Motion:** the hour still turns (it is slow); no fireflies.
- **Night finds:** Book entries tied to real night (`BookCatalog`, SYSTEMS-SCOPE 8 #9) should move to the garden hour so every timezone can earn them. Opus to check save and fairness effects first.

Size: M to L, no export; uploads for night sky faces if we paint them. Flag `DayNight` stays the switch, with the LaunchFlags spec updated only when Spencer approves live.

**Store art audit, when it goes live:** icon and Home tiles stay daytime Aero (the look that sells). Carousel: keep the day hero first, add one golden-hour and one night capture. Description: one line that the garden turns from day to night every hour, inside the 950-character limit. Ads: no change until new captures exist; any spend change needs Spencer's go. Record "listing audited" in PLAY-BUILD as usual.

## 7. Order, sizes, questions

| # | Piece | Size | Export | Needs |
|---|---|---|---|---|
| 1 | Edge sweep, wall top-ups, gentle return | S | No | |
| 2 | Lime leaf map (1A) | S | No (texture upload) | Capture for Spencer |
| 3 | Waterfall step 1 (runtime layers) | M | No | Captures from three spots |
| 4 | Garden hour on the beta | M to L | No | Question 3, 4 |
| 5 | Dewdrop fruit | S to M | No | Question 1 |
| 6 | One world re-export: split shared crowns with sway (2), crown shading and clumps (1B, 1C), waterfall shapes and rocks (4 step 2), plus WORLD-PLAN slice 9's marble and cloud fixes | L | Yes | Pipeline edits committed; sweep rerun after |

Pieces 1 to 5 are independent and each sits behind its own flag. Every piece ends with captures of the Bear and Bunny in frame, on a phone as well.

**Questions for Spencer**
1. **Fruit: looks only, or something pets eat?** Recommend looks only for now (falls in a gust, pets bat it). Feeding touches Stat snacks and the economy.
2. **Mountains: fully off-limits, or one lookout you can climb to later?** Recommend off-limits now; a lookout is a nice later place, built on purpose with a path.
3. **Garden hour split: 34 minutes day, 8 golden, 12 night, 6 dawn, same for everyone?** Recommend yes, beta first.
4. **Move night-only Book finds from the real clock to the garden hour?** Recommend yes, after Opus checks it.
5. **OK to do one world re-export after the runtime pieces land?** Recommend yes: it is the only way to get swaying crowns, shaped falls and rocks, and it folds in slice 9.

## Architect check (Opus, 2026-11-22; wins over the text above)

- **Export blocker:** five tracked pipeline files (incl. `world_native_collision_test.py`) edited 2026-11-20, calling ~11 untracked `scripts/world_path_*.py` from 2026-11-14: the parked grove path reroute. Not ours: park it on a wip branch with its untracked files (Spencer's OK), never discard.
- **Lime map:** no new SurfaceAppearance: `AeroWorld.paintCrown` already writes `TextureID=""`; write the uploaded lime map id there (runtime, Aero ceiling and switch, restore path). Also textures the islet blossoms (same material).
- **Sway:** `WorldMotion` already has `WorldPivot`; `WindClient` already sways bushes from the base (phone 16 within 120 studs): crowns join as a second kind under that cap. The re-export must add split crowns as an extra group shown only behind the ceiling (live keeps merged crowns). 32 shadow decals would be 32 draws: over budget.
- **Fruit:** client-only, seeded from `Wind.hash`. Pets move on the server (`GardenState`), so no trot-over: an in-place bat when fruit lands within reach. Keep off `FindSpots`, the Dash course and the park kerb; must not look like the Hue Egg fruit item.
- **Waterfall 1:** client layers in the Aero additions (today's falls are server-built, also on live); rings are new code; measure overdraw at the pool edge on a phone. Step 2 rocks with collision need the pets' walk grid rebuilt.
- **Edges:** wall top-ups in a hand-written module behind a ceiling (not WorldV7Data, which needs the blocked generator); no collision group; safe spot recorded only when not anchored, not seated, on ground tiles, and not moved by the server in the last 2 s. Raising FallCatch breaks the `GardenGreyboxWorld` spec (y < -150).
- **Garden hour: L, risky as written.** `DayNight` is a build flag that changes live (server sky, `LaunchFlags` spec): needs its own gate (beta place + server switch) like Aero. Under Aero `Clock.look` pins 10.5, so the look must follow the hour. Two daylight values must agree; under .3 pets turn sleepy with glowing faces, about 12 minutes of every hour: Spencer's call. Clock updates every 5 s. Night Book find: one shared garden-hour module the server's `Book.isNight` reads (same save bit).
- **Order:** parked path decision, lime map, edge sweep and safe spot, waterfall client layers, fruit, garden hour (own gate), one re-export with gated split crowns.
