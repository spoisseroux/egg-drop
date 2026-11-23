# Garden life round 3 and the nest remodel: build plan (Opus, 2026-11-23)

Look: `GARDEN-LIFE-NEST-LOOK.md` (Fable) in this folder, textures in `look/` (from `scripts/draw_garden_life_r3_textures.py`). QA items **L1, L2, L3, O1, O2** (`FEEDBACK.md`). Branch `worktree-agent-af5a9249c2b60c9a8`, fast-forwarded to `feat/egg-drop-arcade-polish` (41a85d1). Offline baseline: `python scripts/run_dash_server_specs.py <repo>/build/luau-cli/luau.exe` exits 0 on this tree (the worktree has no `build/`; the main checkout's luau is used).

**Coordinator decisions applied:** the nest moves to the plaza at Fable's spot A `(-17.5, y, -2.5)`, fallback B if Studio shows A blocked. "Napping egg" replaces "Sleepy egg" everywhere players read it. Leaves never fall inside covered places (the rotunda and any other roofed spot), which changes how the leaf emitters are placed (section L2).

## 0. Gates, unchanged

Nothing in this plan reaches live 96451847774961, and no new switch is added:

| Part | Gate (all beta 107705084891479 or Studio only) |
|---|---|
| Butterflies, hand-off glows, leaves, birds | `GardenLife.mount`: `Alive.ceiling("life")` (FeatureFlags.AliveLife + place) and the `life` switch; level 2 never builds |
| Area fireflies (texture, size) | AeroAdditions: `Aero.ceiling` + the garden hour on (as today) |
| Nest model, position, sign | `NestClient.mount`: `Onboard.ceiling()` and `Onboard.on("nest")` |
| Copy | `onb3.*` strings are read only by the onboarding v3 modules above |
| `LifeArt` (new, data only) | pure table, read by the gated modules |

The server is untouched: `NestHost` / `NestState` have no nest position (the nest is drawn only on its owner's client; claim and tuck never check distance), so the move is client only. `LifeSpots.lua` is unchanged too: its `Crowns` stay for the Dewdrops, and the leaves no longer read crowns.

## 1. One table for every new texture: `src/shared/LifeArt.lua` (new)

Studio is busy, so the build ships without the new ids and swaps them in one place after upload.

```lua
-- key = {file = "look/<name>.png", id = nil | "rbxassetid://...", fallback = <an already uploaded id or engine texture>}
LifeArt.Files = { butterflyAmber=..., butterflyAmberM=..., (8 butterfly), fireflyDot, leafA, leafB,
  birdWingEmber, birdWingSlate, birdWingMoss, birdTail, birdBreast,
  nestTwigs, nestFringe, strawBed, strawWisps, nestSign }   -- 21 entries
function LifeArt.id(key)      -- id, else fallback; never nil, never ""
function LifeArt.pending()    -- keys still on their fallback (the publish gate)
```

Fallbacks keep every build drawable and recognisable: butterflies use today's `ButterflyWing(-M)` (tinted white, so they look plain until the swap), bird wings and tail today's `BirdWing`, the breast none (its decal is not created while pending: the plain body colour), leaves `Life.PetalTexture`, the firefly dot `sparkles_main.dds`, nest twigs today's `weave`, fringe and wisps today's `leaves`, straw bed none (the disc's colour), sign today's `flag`. Pending entries are listed by `LifeArt.pending()`; the PLAY-BUILD checklist for the beta publish requires it to be empty (`scripts/LifeArt.spec.lua` prints the pending keys and has one case that fails when `LIFEART_RELEASE=1` and any are pending).

WorldAero (shared) reads `LifeArt.id("fireflyDot")` for `Fireflies.Texture`, so the swap is one edit.

## 2. L1 Butterflies (`LifeSim.lua`, `GardenLife.lua`)

**LifeSim**
- `Sim.Butterfly`: speed .8 to **.65**, bob .06 in step with the flap + .15 at .4 Hz, wobble **12 at .5 Hz**; new `flapHz {2.2, 1.6}` by level, `glideEvery {1.6, 3.2}`, `glideFor {.6, 1.1}`, `envelope .25`, `glideSink .25`, `climb .6`, `glideAngle 28`. The `leave*` fields and the "leave" mode go (night is the hand-off now).
- Each butterfly carries its glide schedule from the butterflies' own `Random` (`glideAt`, `glideUntil`), drawn at spawn and after each glide, so the same seed still gives the same garden.
- `Sim.butterflyFlap(b, now, level)` is **one continuous angle**: `φ = 22 + 38 sin(2π f t) e`, `e` the smoothstepped envelope (1 flapping, 0 gliding, .25 s each way), and in a glide the wings ease to 28 through the same envelope (`φ = 28 + (flap - 28) e`). Resting: `62 + 14 sin(2π .25 t)`. Landing uses the flight formula. `flip` and `held` are deleted, and so is the 2-step swap in `GardenLife:step`.
- `Sim.butterflyRoot` adds the glide sink (smoothstep down over the glide, back up over .6 s) and the new bob and wobble.
- `Sim.butterflyParts(root, phi)`: hinge x .05 to **.04**, half-span .35 to **.28** (plates .56 x .67).

**Day and night (Fable 1, "they become fireflies")**
- `Butterflies:step(now, dt, world, patches, cap, still, daylight)`: the last argument becomes the garden hour's **daylight number** (nil with the hour off = day). Fly while daylight > `Sim.ButterflyDay` **.30**; spawn only while > `Sim.ButterflySpawn` **.34**. Birds and bubbles keep `Sim.day` (.7). GardenLife stores the raw daylight next to `self.day` at each Poll (2 s; the blend moves about .017 in that time).
- Crossing under .30: if daylight is still ≥ **.24**, each live one gets `handAt = now + 1.5 * rank` (rank by colour slot, slot 1 first) and runs the hand-off: 0 to 1.5 s wings and body fade 0 to 1 while the glow comes up (size .2 to .9, image transparency 1 to .1, smoothstep); 1.5 to 5 s a firefly (no wings, speed .65 to .25, rising to 1.5 to 2 studs over `world.ground(x, z)`), the glow pulsing .1 to .55 every 1.8 s; 5 to 6 s the glow fades; removed at 6 s. Under .24 (an `/hour at` jump, a late join): wings fade in .5 s, no glow, removed.
- Every spawn fades its wings in over 1.2 s (decal transparency 1 to 0); no reverse effect at dawn.
- Sim returns per butterfly `{wing = 0..1, body = 0..1, glow = nil | {size, transparency}}` so GardenLife only writes.

**GardenLife**
- Pool unchanged in count (4 x 3 parts). Each slot gets its own textures (`butterflyAmber`, `Chalk`, `Dusk`, `Meadow`, and each `-m` mirror), decal `Color3` white; `Life.WingColours` goes. Sizes: body .08, .08, .40 (#2A2018), wings .56, .67, .02.
- One glow per slot, built at enable: a BillboardGui on the body part, `Enabled` false by day, ImageLabel `fireflyDot`, `ImageColor3` #E8FF8A, `LightInfluence` 0, `Brightness` 2, `MaxDistance` 110, `AlwaysOnTop` false. No PointLight.
- Decal and glow writes at **10 Hz**, only on change (epsilon .01), cached per slot as the Dewdrops do.
- `world.ground` (new field) is the shared `HollowWorldLayout.groundY` that the Dewdrops already use; `world.groundY` (the bubbles' floor) is left as it is so the bubbles do not change.

**Area fireflies (`src/shared/WorldAero.lua`, `src/client/AeroAdditions.lua`)**: `Fireflies.Texture = LifeArt.id("fireflyDot")`, `Size` .35 to **.6**; counts, areas and ramp untouched. AeroAdditions needs no code change (it reads `Values.Texture` and `Values.Size`); its comment line is updated.

**Budget.** Butterflies 4 / 2 / 0 alive, 12 parts and 4 glows at most. Glows at the hand-off: at most 4 / 2 for 10.5 s while the area ramp is under .32, so peak fireflies 4 + 4 = 8 at level 0, 2 + 2 = 4 at level 1 (under the 12 / 6 caps). Reduced Motion: no butterflies, no hand-off, no area fireflies (unchanged).

## 3. L2 Falling leaves, replacing the petal bursts (`LifeSim.lua`, `GardenLife.lua`)

**Deleted:** `Sim.Petals`, `petalRate`, `PetalPeak/Calm/Burst/BurstAt/Rearm`, `Life:pick`, `Life.PetalReach`, `self.picked`, the crown anchors and `Life.PetalHeading/Drag/Sink`. `Sim.Caps.petals` becomes **28 / 14 / 0** (key kept so `counts()` and the perf probe keep their field; renamed `leaves` in `counts()` with `petals` kept as an alias for one build).

**The covered-place rule changes the emitter placement.** One 72 x 72 box cannot leave a hole, and a leaf drifts 8 to 40 studs downwind over its life, so a spawn just outside the rotunda still ends under its roof. Instead:
- Three small anchors (Block 4, 2, 4, see-through), one per emitter (leaf A, leaf B, petal), `Shape` Box, `ShapeStyle` Volume, `EmissionDirection` Bottom, `LockedToPart` false.
- `Sim.Leaves:step(now, dt, gust, cap, level)` decides how many of each to emit (rate 2.4 / 1.2 a second x (1 + .5 g); shares 55 / 30 / 15 drawn from its own `Random`; live list with each kind's longest life, 12 / 12 / 10 s, so the cap is exact; the fraction carries; at most one emit per emitter per step, the rest carries).
- For each emit, `Sim.leafSpot(random, centre, world)` draws a point uniform in the **72 x 72 square round the player** (the camera when there is no character), at `ground(x, z) + 11 ± 1` (per point, so hills and dips are right, better than one cell's ground), and returns nil when the point is off the island's ground grid or when **the leaf's drift path would cross a covered place**: the segment from the point to `point + Wind.Direction * Leaf.reach` (18 studs: a calm life's drift, 8.7, plus one full gust, 9.1) passes within `cover.r + 2` (the sway) of a covered footprint. A nil spot skips that emit (the carry is spent), so density elsewhere stays Fable's one leaf per 185 square studs and the covered place and its upwind strip go quiet.
- GardenLife moves that emitter's anchor to the spot in the step's one `BulkMoveTo`, then `Emit(1)` after the move (as bubbles do today).
- **Covered places** (`Sim.Leaf.cover`, data in LifeSim): the rotunda roof, centre (-60, 50) from `HollowWorldLayout.Landmarks.Rotunda` and the v7 manifest (`W7_Rotunda__palette` 15 x 15, top 30.2), radius 8. Candidates to confirm before publish (Studio is busy now): the Cave (-7, -101), the aqueduct arches, any station canopy. A read-only Studio probe (`scripts/probe_leaf_cover.luau`, run later through `execute_luau`, no edits, no save) casts up from the walk map ground on a 2-stud grid over the island and lists cells with non-foliage geometry under 25 studs above the ground; clusters become `cover` rows. Until then the table holds the rotunda alone.

**Emitter properties (Fable 2):** textures `leafA`, `leafB`, today's `petal.png`; colours white, white, petal by crown colour (lime #FFF6C2, pink #FFB8D6, read at Poll as today); sizes, lifetimes, Speed .3 to .6, Drag .5, SpreadAngle 20, Rotation 0 to 360, RotSpeed -45 to 45, Squash (0, 0) (.25, -.35) (.5, .05) (.75, -.35) (1, 0), Transparency (0, 1) (.08, .1) (.88, .1) (1, 1), LightInfluence 1, LightEmission 0, FacingCamera.
- `Acceleration` on all three, written at **4 Hz**: `Wind.Direction * (.25 + .9 g) + cross * .3 sin(2π t / 7) + (0, -.45, 0)`, `g = Wind.at(player, now)`, `cross` the direction turned 90 on the ground (pure: `Sim.leafWind(g, t)`).

| | Level 0 | Level 1 | Level 2 | Reduced Motion |
|---|---|---|---|---|
| Emits a second | 2.4 x (1 + .5 g) | 1.2 x (1 + .5 g) | 0 | 0 |
| Alive cap | 28 | 14 | 0 | 0 |
| Emitters / anchors | 3 / 3 | 3 / 3 | none | 3 built, idle, cleared |
| Step | 30 Hz | 15 Hz | | |

Parked: cleared (as today). A menu: they keep falling. Night: they fall (LightInfluence 1 dims them).

## 4. L3 Birds (`LifeSim.lua`, `GardenLife.lua`)

**Parts, 8 a bird (24 at most; was 18):** body Ball 1.05 (+ `birdBreast` decal on Front, Color3 = breast), head Ball .68 at `H = root * (0, .37, -.35) * headTurn`, beak Block .17 corner first off `H`, two eye Balls .14 (#14110F, Reflectance .2) off `H`, two wing plates .04 x .75 x .55 (`birdWing<Name>` on Left and Right, Color3 white), tail plate .46 x .68 x .02 (`birdTail` Front and Back, Color3 = tail). The eye discs and `Life.BirdEye` go. `Sim.birdParts(root, wings, flick, phi, head, tau)` returns 8 frames in pool order; wing chains are Fable's (perched `(±.53, -.02, .15)`, yaw ∓12, tuck -55; flying `(±.37, .11, .04)`, `±φ`, `(±.37, 0, 0)`, `±90`). `Sim.Bird.lift` .56 to **.50**.
- Looks by perch index % 3: Ember, Slate, Moss (Fable's table). At landing GardenLife writes the body, head, beak colours, the breast and tail decal `Color3`, and the wing decal `Texture` (a swap of an already loaded asset). `Life.BirdColours` is replaced.

**Motion (all smoothstepped):**
- Hop .16 high in .18 s; 40% of hops are a pair .12 s apart (`bird.hops` queue from the birds' `Random`).
- Tail τ 20 to 2 to 20 over .16 s on every landing and hop.
- Head: every .8 to 2.5 s a snap in .12 s to yaw ±25 to 50 (30% with a roll ±15), held between (`bird.head = {from, to, at}`).
- Body turns as today but always with a hop.
- Flight (landing and leaving): bounding, two beats `φ = 15 + 50 sin(2π 5.5 t)` (.36 s), then the perched wing pose for .22 s with the root dipping .12; level 1 beats at 3.5 Hz (.57 s). `Sim.birdFlap(flip, held)` is replaced by `Sim.birdWing(bird, now, level)` returning `("fly", φ)` or `("perch", 0)`.
- Hop wing flick 25 to **15**.
- Reduced Motion: on the crown, folded, head straight, tail at rest, still (unchanged). Night unchanged.

## 5. O2 The nest remodel and the move (`src/client/NestClient.lua`)

**Position.** `Client.Spot = Vector3.new(-17.5, 4.07, -2.5)` (walk map ground; the raycast still refines it within `GroundSlack` 1), `Client.Facing = Vector3.new(-30, 4.07, -4)` (root -Z at the plaza's middle). `Client.FallbackSpot = Vector3.new(-22.5, 4.07, 5.5)` is recorded beside it (not used by code); moving is one edit. `Client.BearSpot` (2.2, 0, -1.4), `Client.EggBase` .64. `PromptAt` (0, 1, -2.6) unchanged. Everything that follows the nest already reads `place3D()` (the trail, `clientUI.nestPlace`, the coach mark, BearNeeds), so nothing else moves. The header comment about the spawn being 10 studs away is replaced.

**Model, 21 parts (`Client.parts()`):** mound (Cylinder up, .42 x 3.5, #3A2616, `nestTwigs` Texture on the four curved faces at 2.4 / 1.2, **CastShadow on, this part only**), 8 rim rolls (1.30 x .66, radii 1.42 / 1.50, y .56 / .62, tipped ±7, colours #6B4A2C, #5A3D24, #7D5A38 in turn, `nestTwigs`, `OffsetStudsU = .37k`), straw bed (Cylinder up .30 x 2.36 at y .55, #B8974F, `strawBed` on the top cap: with the axis turned up by +90 about Z the top cap is the **Right** face; a `[check]` puts it on both caps if it lands wrong), 6 fringe plates (1.9 x 1.05 x .04 at a = 15 + 60k, r 1.62, y .78, Back face outward, tipped 22 outward, yaw ±8; `nestFringe` Front and Back), 3 straw tufts (1.3 x .62 x .04 at a = 40 + 120k, r 1.05, y .98, tipped 15; `strawWisps`), sign post (Block .14 x 1.5 x .14 at (-1.95, .75, -.95), #6B4A2B, Wood), sign board (1.3 x .8 x .08 at (-1.95, 1.45, -1.03), yaw -20 so its Front turns toward the egg, tipped back 6, #A47E50, Wood, `nestSign` on Front). Parts keep `inert()`; `Material` is SmoothPlastic except the sign's Wood. Cushion, flag and leaves parts go; `Client.Assets.weave/flag/leaves` go.
- **The sign's words:** a SurfaceGui on the board's Front (PixelsPerStud 50, LightInfluence 1), one TextLabel over x .34 to .97, y .14 to .86, ink #3B2A1A, the Kit's strong face, TextScaled, `UITextSizeConstraint` 22, wrapped. Text `onb3.nest.sign` with `{pet}` = the name of the pet stored at land (`view.pet`), written in `set()` only when the view's pet changes. The name comes from a new dep `petName(id)` (init builds it from `Pets.byId`, as its other `petName` helpers do; nil or unknown: `onb3.nest.signPlain` "Your egg"). This dep is shared with the quick-fix's explain line (section 7).
- The drop, the halo, the Zzz, tuck in and hatch are unchanged; the egg lands on the straw at .64.

**AeroFalls.spec** pins the old nest at (86, 4.33, 66) in the firefly keep list: it reads `NestClient.Spot` instead (the nearest firefly area, East (43, -16), is 62 studs from A).

**Spot A in Studio (later, read-only):** `scripts/probe_nest_spot.luau` for `execute_luau`: a ring of 16 rays at r 2.6 and heights .5, 1.5, 2.5 round A, and the prompt point (about (-20.1, -2.8)) cast down: clear means no hit but the marble. If blocked, slide along the rim (12.6 from (-30, -4), z in -7 to 1) else B, then rerun the pure clearance spec below.

## 6. O1 The words (`src/shared/UICopy.lua`, `onb3`)

Text values are mine; keys that need new wiring are the quick-fix's (section 7). "Napping egg" replaces "Sleepy egg"; never "ready", "growing" or "sleepy" for the egg.

| Key | New text |
|---|---|
| `tip.nest` | `{pet}'s egg is napping. Hatch it later for a gift.` |
| `need.nest` | `Tuck in {pet}'s egg.` |
| `need.egg` | `{pet}'s egg is ready to hatch!` |
| `nest.title` | `Napping egg` |
| `nest.hours` / `nest.minutes` | `Hatches in {hours} h` / `Hatches in {minutes} min` |
| `nest.ready` | `Hatch me!` |
| `nest.tucked` | `Sleep tight. It naps while you're away.` |
| `nest.next` | `A new egg is napping. Come back in {hours} hours.` (needs `{hours}` passed: wiring) |
| `nest.chipHours` / `nest.chipMinutes` | `Egg {hours} h` / `Egg {minutes} min` |
| `nest.got` | `{item} from the napping egg!` (Fable did not list it; the old one says Sleepy) |
| `notify` / `notifyPlain` | `{pet}'s egg is ready to hatch!` / `Your egg is ready to hatch!` |
| new `nest.sign` / `nest.signPlain` | `{pet}'s egg` / `Your egg` |
| new, the explainer (Fable `nest.how`) | `{pet}'s egg naps for {hours} hours. Come back to hatch a gift.` |
| new, the first tuck-in (Fable `nest.tuckedFirst`) | `Tucked in! Come back in {hours} hours to hatch a gift.` |
| new, the chip when hatchable | `Hatch egg!` |

Still saying "growing": `week.line` and `new.line`; see question 4. `{hours}` is always `Nest.Hours` (8), never typed.

Before publish: `python scripts/export_localization_csv.py`, `python scripts/sync_localization.py`, and the counts in the PLAY-BUILD entry.

## 7. Working beside the quick-fix branch (`worktree-agent-a8953522b60d4b3f1`, `QUICK-FIX-PLAN.md` O1)

It owns the key **wiring** in NestClient (a `Client.Copy` role table, a pure `Client.explain(view, now, firstEgg)`, the label's second line, the first tuck-in hold and toast, the chip's AccessibleLabel, NestClient.spec moving literal English to `UICopy.get`). I own the model, the position and the text. To keep the merge clean:

1. **Order:** the quick batch lands on `feat/egg-drop-arcade-polish` first; I rebase on it before touching `UICopy.lua`, `NestClient.lua` or `NestClient.spec.lua`. Garden life (sections 2 to 4) does not depend on it and is built first.
2. **Key names: theirs.** Their `onb3.nest.explain` = Fable's `nest.how`, `firstTuck` = `tuckedFirst`, `explainPlain` = the no-name fallback. If their `explainTucked` / `explainReady` survive, they get the same sentence (Fable has one explainer). I add only `nest.sign`, `nest.signPlain` and, if they have not, `nest.chipReady`.
3. **Behaviour from Fable section 5, which their plan left open:** the explainer is the label's second line **until the first hatch (`n == 0`), at any distance the label shows**; after that the "Inside:" line within 8 studs. First tuck-in: 6 s hold and a rail toast. Chip: "Hatch egg!" when hatchable, AccessibleLabel = the explainer. `nest.next` takes `{hours}`. I will send them this list; anything not in their landing I add after the rebase as a separate small commit.
4. **Hunks:** my NestClient edits stay in the constants block, `Client.parts()`, the part loop in `draw()`, the sign (a new `Client:paintSign()` called from `set()`), and the header. I do not touch `paint()`, `say()`, the chip builder or `Client.clock`/`chipText`. The shared `petName(id)` dep: whoever lands first adds it to init's mount call; the other uses it.
5. Their G3 proposal (Dewdrop size and crowns) touches the Fruit sections of `LifeSim`/`GardenLife`/`LifeSpots`; I stay out of the Fruit, Grove and Loose code.

## 8. Specs

All offline in `python scripts/run_dash_server_specs.py` (LifeSim, GardenLife, NestClient are already in `CLIENT`; `LifeArt` is shared and joins `SPECS`; `AeroFalls` stays opt-in via `DASH_SPECS`). No Studio-only ZZSpecs are needed; Studio work is captures and the two read-only probes.

- **LifeSim.spec** (petal cases replaced, butterfly and bird cases rewritten):
  - caps 28 / 14 / 0 leaves, others as before;
  - leaves: rate 2.4 and 1.2 x (1 + .5 g); the cap exact across the three kinds over 120 s of gusts; shares within ±5% of 55 / 30 / 15 over 2,000 seeded emits; at most one emit per kind a step; the same seed gives the same emits;
  - `leafSpot`: inside the 72 square at ground + 10 to 12; nil off the island grid; nil for every point whose 18-stud downwind path passes within 10 studs of the rotunda (a sweep of points round it), never nil 12 studs upwind-side clear; `leafWind` 0.7 calm and 3.3 at a full gust (terminal speeds with Drag .5), the sway's sign flips each 3.5 s;
  - butterflies: no wing jump over 30 degrees between 1/30 s samples across flap, glide and land, and under 45 at 15 Hz / 1.6 Hz (the "no snap" test; today's swap is 75); glide every 1.6 to 3.2 s for .6 to 1.1 s; rest φ in 48 to 76; speed .65; parts at .04 / .28;
  - night: fly over .30, spawn over .34; the hand-off in slot order 1.5 s apart, wings 0 to 1 by 1.5 s, glow peak .9 studs, removed at 6 s; under .24 fade in .5 s with no glow; glows alive never over 4 / 2; dawn spawns fade in over 1.2 s; nil daylight is day;
  - birds: 8 frames, the head at (0, .37, -.35), eyes and beak follow a head turn; hop .16 in .18 s; pairs 40% ±8% over a seeded run; tail τ 20 to 2 to 20 in .16 s; head snap .12 s then held; bounding flight two beats then .22 s tucked with a .12 dip; level 1 at 3.5 Hz; lift .50; Reduced Motion still, head straight.
- **GardenLife.spec**: pools 3 x 8 and 4 x 3 + 4 glows, decal faces and white Color3 for each slot's own texture key (via `LifeArt.id`), glow properties, `Enabled` false by day; the hand-off seen through the parts (decal transparency written at 10 Hz, only on change); three leaf anchors with Fable's emitter properties; Emit counts never over the cap at levels 0 and 1; Acceleration written at 4 Hz; a covered-place spot emits nothing; leaves cleared when parked, none with Reduced Motion or at level 2; bird landing writes the look (colours, wing texture); `counts()` adds `leaves` and `glows`.
- **NestClient.spec** (after the quick-fix rebase): 21 parts by name, inert, CastShadow only on the mound; at A facing the plaza's middle; `nestPlace` 2.6 studs toward (-30, -4); the sign's SurfaceGui text for a named pet and the plain fallback; textures on the named faces; EggBase .64; the old ten-part case replaced.
- **New `NestSpot.spec`** (pure): A (and B, and any slid spot) keeps Fable's clearances from the stations (Journal, Eggs, Customize, ToyLawn), the Dash course and pad (`DashCourse`), the arrival route (`HollowWorldLayout.Routes.ArrivalToHub`), the flower patches (2.6 + 1), and the firefly areas.
- **UICopy.spec**: no `onb3` nest string says "Sleepy", "sleepy", "growing" or "Ready"; the new keys exist; `LocalizationFit.spec` covers widths.
- **LifeArt.spec**: 21 keys, each file exists in `look/`, each has an id or a fallback, `LifeArt.id` never returns nil or ""; prints `pending()`; fails on pending only with `LIFEART_RELEASE=1`.
- **AeroFalls.spec**: the nest keep point from `NestClient.Spot`.

## 9. Upload list (later, Studio MCP `upload_image`, Spencer's account)

From `artifacts/qa-2026-11-23-beta12/look/` (re-run `python scripts/draw_garden_life_r3_textures.py` first and confirm the files are byte-identical). 21 files; the four `preview-*.png` are not uploaded.

| Files | LifeArt key |
|---|---|
| `butterfly-amber.png`, `-amber-m`, `-chalk`, `-chalk-m`, `-dusk`, `-dusk-m`, `-meadow`, `-meadow-m` | `butterflyAmber`, `butterflyAmberM`, ... |
| `firefly-dot.png` | `fireflyDot` |
| `leaf-a.png`, `leaf-b.png` | `leafA`, `leafB` |
| `bird-wing-ember.png`, `-slate`, `-moss`, `bird-tail.png`, `bird-breast.png` | `birdWingEmber`, `birdWingSlate`, `birdWingMoss`, `birdTail`, `birdBreast` |
| `nest-twigs.png`, `nest-fringe.png`, `straw-bed.png`, `straw-wisps.png`, `nest-sign.png` | `nestTwigs`, `nestFringe`, `strawBed`, `strawWisps`, `nestSign` |

After upload: write the 21 ids into `LifeArt.Files`, `LifeArt.pending()` empty, specs green, commit. Retired (leave the assets, drop the references): `butterfly-wing(-m)`, `bird-eye`, `bird-wing`, `nest-weave`, `nest-flag`, `nest-leaves`.

## 10. Order of work and evidence

1. `LifeArt` + its spec. 2. Butterflies and the hand-off, fireflies texture (LifeSim, GardenLife, WorldAero). 3. Leaves. 4. Birds. 5. Rebase on the quick batch. 6. Nest model, position, sign. 7. Copy text. 8. Full offline run, code review, fixes. 9. When Studio is free (coordinator): the two probes, uploads, id swap, the captures in Fable section 6, `get counts` at levels 0 and 1 at the hand-off peak and with leaves. Each step is its own commit; `V3-TEST-PASS.md` gets the rows when it reaches the beta.

## 11. Risks

- The upwind no-fall strip by the rotunda reads as a gap (about 3 missing leaves in a 15 x 18 stud strip); acceptable, and the rule Spencer asked for.
- Per-emit anchor moves: three anchors at under 4 Hz in the step's existing `BulkMoveTo`; no new connection.
- Bird wing texture swaps at landing: the three wing assets are all loaded after the first few landings; a first landing may show the plate blank for a frame.
- The nest at the plaza is non-colliding and owner-only: other players' pets (server-side) can walk through the spot (see question 3).

## Questions for the architect

1. **Leaf placement.** Per-emit spawn points round the player with an upwind drift capsule (18 studs) against a `cover` list, instead of Fable's single 72 x 72 box. Agree, and is skipping the emit (not resampling) right?
2. **Covered places beyond the rotunda.** Ship with the rotunda only and fill the rest from the read-only Studio probe before publish, or hold the leaves until the probe has run?
3. **Pets through the nest.** The plaza is busy and the nest does not collide. Add the nest's 2.6-stud footprint to the pets' avoid list (server, behind `Onboard.ceiling`), or accept pets walking through the twigs on the owner's screen?
4. **Copy outside Fable's table.** `nest.got` ("from the napping egg"), `week.line` and `new.line` (both say "growing"): change them now with my placeholders, or send them to Fable first?
5. **Order with the quick batch.** I build garden life first and rebase before the nest and copy; or should the nest copy wait entirely for the quick batch to merge, and should `petName(id)` live in that branch?
