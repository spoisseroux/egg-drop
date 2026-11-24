# Garden life, beta (14): build plan (Opus, 2026-11-23, step 1 of the review-driven build)

Spec: Fable's `WORLD-AND-NEST-LOOK.md` (Spencer: "sure build it"), sections 1 (W3), 6 (Q5) and 7 (D2 / B5). Plus **B2**
(no fireflies at night), routed here by the coordinator from the bug builder's `BUGFIX-PLAN.md` section B2 (branch
`worktree-agent-a77aa87743a9295b1`), and that plan's B5 diagnosis (taken as input, adopted where noted).

**Scope:** client ambient life on the beta place only. Not here: the nest, D1 / Q1 / Q2, the race line (F2), W4, sound.
**Not touched:** AeroWorld, AeroFalls, AeroKit, AmbientAudio, WorldAero, Nest*, Dash*, onboarding, TomorrowStrip, Kit*.
I only *read* `WorldAeroKit` (data) and copy `AeroKit.crownFrame`'s three lines of maths; I read `WorldAero.Look.Textures.Ripple`.
**Plan only:** no `src` changes in this step.

Nothing here has been seen in Studio. `[probe]` marks a read-only Studio check to run before or during the build.

---

## 0. Where things go (architecture)

| Module | Kind | What | New / changed |
|---|---|---|---|
| `src/client/Wind.lua` | pure | the big breath schedule: `Wind.breath(position, t)`, `Wind.blow(position, t) = max(gust, breath)`, `Wind.breathNumber(t)` | changed |
| `src/client/LifeSim.lua` | pure | Q5 leaf numbers, sheet and skitter; Dewdrop kit stems, chance, rest, breath drops, notice, nudge, snack timeline; **night fireflies** (B2) | changed |
| `src/client/LifeSceneSim.lua` | pure | W3 maths: dapple drift and fade, koi paths, ripple, flock schedule and pose, dragonfly hover/dart, lamp order and times, shooting-star schedule | **new** |
| `src/client/GardenLife.lua` | instances | owns the one Heartbeat and the one `BulkMoveTo`; leaf sheet + skitter emitters; firefly glow pool; heart mote; mounts `LifeScene` and `LifePet` and steps them | changed |
| `src/client/LifeScene.lua` | instances | W3 parts (dapple, koi, ripples, flock, dragonflies, lamp halos, star beam); returns parts/frames into GardenLife's move | **new** |
| `src/client/LifePet.lua` | instances (pet visual) | my own pet's Dewdrop snack (notice, trot, nibbles, hop, content face) and the big-breath look-up; a presentation layer over the server sample | **new** |
| `src/client/RoomView.lua` | | two hook calls: `self.lifePetDrive` after `PetFollow.activity`, `self.lifePetPose` after `pet:update` | changed (2 lines + guards) |
| `src/client/PetExpression.lua` | | `visual.contentUntil` -> `"content"` | changed (1 line) |
| `src/client/WindClient.lua` | | crowns and movers read `Wind.blow` (so they answer the breath) | changed |
| `src/client/WorldMotion.lua` | | the arch chimes' own pose (Fable row 2) | changed |
| `src/shared/GroundDressing.lua` | generated data | litter, lawn patches, path fray plates (W3 row 7) | **new** |
| `scripts/build_ground_dressing.py` | generator | writes the above from `WorldAeroKit`, `world-v7-walk.json` surface rows, stations, course, pad, finds, nest | **new** |
| `src/client/WorldDressingClient.lua` | instances | draws the GroundDressing plates (static, every budget level), same 4 Hz cull | changed |
| `src/shared/LifeArt.lua` | data | rows for the new textures (stand-ins until uploaded) | changed |
| `scripts/draw_garden_life_r4_textures.py` | drawing | the new textures (section 9) into `artifacts/qa-2026-11-23-beta14/look/` | **new** |
| `src/client/init.client.lua` | wiring | GardenLife deps: `ownPet`, `petFree`, `notice`; RoomView hooks | changed |
| `src/shared/Alive.lua`, `src/shared/FeatureFlags.lua` | switch | new Alive feature **`scene`** (`AliveScene`, key `alive_scene`) | changed |

**Why a new module pair for W3:** `GardenLife.lua` is 871 lines; the W3 additions are about as many again. `LifeScene` is
mounted *by* GardenLife and stepped from its stepper with the same gates (park, budget, Reduced Motion, `world`), and it
hands back `{parts, frames}` for the one `BulkMoveTo`. No second Heartbeat. `LifeScene*` and `LifePet` match the offline
runner's `Life*.lua` bundling pattern, so they run offline with no runner change.

**Switches.**
- Q5, D2 / B5, B2 change systems that already sit behind Alive **`life`**: they stay there.
- The W3 additions (breath consumers outside life, chimes, dapple, koi, flock, lamps, star, dragonflies, ground plates)
  go behind a **new Alive feature `scene`** so Spencer can kill them on the beta without losing round-3 life:
  `Alive.Features += "scene"`, `FlagNames.scene = "AliveScene"`, `FeatureFlags.AliveScene = true`. AliveConfig publishes it
  with no code change (it loops `Alive.Features`); ConfigService key `alive_scene` (missing = on); `/alive scene off`.
  `LifeScene` runs only when both `life` and `scene` are on (it lives inside GardenLife's stepper).
- `WorldMotion` chimes: `scene` on (read once per bind and on `Alive.changed("scene")`); off = today's sway.
- Ground plates: `scene` on; off = no plates (WorldDressingClient watches the attribute).
- The pet snack: behind `life` (see question A3).

**Common rules** (Fable, unchanged): every new part `Anchored`, `CanCollide/CanQuery/CanTouch` false, `CastShadow` false,
`Massless`, parked at `Life.Hidden`, never re-parented or resized while on. Level 2 and Reduced Motion: none of the new
motion (ground plates and the dapple's static shade are the exceptions, see the rows). Parked (a hatch, out of Room mode,
my own race): everything moving hidden in one move, as `Life:park` today.

---

## 1. Q5: leaves blowing, with texture

**Files:** `LifeSim.lua` (`Sim.Leaf`, `Sim.Caps`, `Leaves:step`), `GardenLife.lua` (`Life.Leaves`, `leafEmitter`, step),
`LifeArt.lua` (`leafSheet`), the draw script.

**Numbers (Fable section 6):**

| `Sim.Leaf` / caps | now | new |
|---|---|---|
| `rate` (level 0 / 1) | 2.4 / 1.2 | **4.0 / 2.0** |
| `boost` | .5 | **1.5** |
| breath factor | | **x3** while `Wind.breath > 0` at the player (the whole 10.5 s), new key `breathRate = 3` |
| `Caps.leaves` | 28 / 14 / 0 | **44 / 22 / 0** |
| `lean`, `gust`, `sway` | .25, .9, .3 | **.45, 1.3, .35** |
| RotSpeed | ±45 | **±70** |
| `share` | .55 / .30 / .15 (A, B, petal) | **.90 / .10** (sheet, petal); the sheet's four cells equally likely: 22.5% each |
| `reach`, `side` | 16, 2 | **re-derived** (below) |
| lifetime, fall, drag, speed, spawn square, height, size keys | | unchanged |

**Emitters (cap stays 3):** `Life.Leaves` becomes `{LifeLeafSheet (leafSheet), LifeLeafPetal (unchanged),
LifeLeafSkitter (leafSheet)}`.
- Flipbook: `FlipbookLayout = Grid2x2`, `FlipbookStartRandom = true`, `FlipbookFramerate = NumberRange.new(0)`,
  `FlipbookMode = Loop`. `[probe]` a leaf keeps one cell for its whole life (10 s watch of one leaf). If it flips:
  Fable's fallback, two leaf emitters (A + C, B + D as 1 x 2 sheets `leaf-sheet-ac.png`, `leaf-sheet-bd.png`, 192 x 96) and
  **no skitter** (the cap stays 3). Both sheets are drawn either way so the fallback is a data change.
- `Leaves:step` kinds become 1 sheet, 2 petal; kind 3 (skitter) is stepped separately (below).

**The skitter emitter** (`Sim.Skitter`, new):
- Runs only while `g = Wind.blow(centre, now) > .5`. Spawn square as the leaves, at `groundY + .12`, refused under cover
  (`Sim.leafCovered` with its own short reach: `skitterReach = 5 * 3 = 15`, a 5 studs/s leaf for 3 s, drag ignored, so
  conservative; `side` 1).
- Emitter: `Speed 3 to 5`, `EmissionDirection` along the wind (the anchor turned `CFrame.lookAt(at, at + Wind.Direction)`,
  `EmissionDirection = Front`), `SpreadAngle (12, 0)` (flat), `Acceleration` zero, `Drag 1.2`, `Lifetime 2 to 3`,
  `RotSpeed ±220`, same size keys as the sheet, `Squash` keys `{0,0},{.2,-.5},{.35,0},{.6,-.5},{.75,0},{1,0}`,
  `Transparency` keys `{0,1},{.1,.1},{.75,.1},{1,1}`, `Orientation FacingCamera`.
- Rate **6 / 3** a second; alive cap **14 / 7** on top of the falling cap (its own `live` list, longest life 3).
- `[probe]` they do not visibly slide through kerbs, the nest, the pool; if they do, `Lifetime 1.8`.

**`reach` re-derivation (must run before the build is reviewed):** `LifeSim.spec`'s drift run (`Sim.leafDrift` through
a 12 s life, 4,000 starts over 3,000 s, dial 1 and 1.5) re-run with the new `lean / gust / sway` **and the breath**
(`Sim.leafWind` takes `Wind.blow`, so a breath inside a life is in the sample: the run window is widened to 3 breath
periods, about 1,000 s, and the start times are forced to include 20 starts in each breath's first 8 s).
- Fable expects about 22 without the breath. With a 10.5 s breath at `g = 1` the terminal downwind speed is
  `(lean + gust) / (drag ln 2) = 1.75 / .347 ≈ 5 studs/s` for about 6 s, so a breath-hit leaf may go **30 to 40 studs**.
  That grows every roof's refusal zone (more leaves skipped near the rotunda, colonnades, bridge arch).
- **Option (question A1):** clamp the *falling* leaves' gust term in a breath to the normal-gust envelope (the breath
  boosts their *rate* and turns on the skitter, but `leafWind` uses `Wind.gust`, not `blow`). Then reach stays about 22
  and the spec stays as today. I recommend this: the breath still reads as "lots of leaves at once" and the skitter
  carries the push.
- The spec asserts the derived pair fits and is not padded by 2 or more (as today), and prints the numbers.

**Edge cases.**
- Reduced Motion, level 2: no falling or skittering leaves (unchanged). Litter plates stay (section 4 row 7).
- Level 1: rates and caps halved; skitter 3 / 7.
- Deck round, hatch, my own race: parked, `Clear()` on all three emitters (as today).
- Another player's race live: leaves keep falling (the course is not a leaf rule today; skitter spawns on the ground, so
  add the course line (`Sim.Keep.course` 4) to the skitter spot rule while `self.live`).
- Two players: leaves are per client (random seeded per client) as today; the breath is shared, so both see the burst.
- Phone: no separate cap (budget levels only), as today. 44 + 14 = 58 particles at most, 3 draws.

**Specs (offline, `LifeSim.spec`, `GardenLife.spec`).** New rates and caps per level; the cap is never passed with the
breath x3 for its whole length; skitter emits only while `g > .5`, never under cover, never on the course while a race
is live, respects 14 / 7; the reach derivation (above); `GardenLife` makes exactly 3 leaf emitters, the sheet with
`Grid2x2`, the skitter's Acceleration zero; leaf kinds 1 and 2 only from `Leaves:step`.

---

## 2. D2 / B5: the Dewdrops

### 2a. Hanging inside the crowns (B5a)

**Files:** `LifeSim.lua` (`Sim.kitCrowns`, `Sim.fruitStems`, `Sim.Fruit`), `GardenLife.lua` (`places`, `stepFruit`).

**Crowns at runtime, not hardcoded.** The grove reads `LifeSpots.Crowns` today (the v7 blossom clumps, generated before
the Aero kit). New (adopting BUGFIX-PLAN B5 idea 1):
- `Sim.kitCrowns(kit)`: from `require(Shared.WorldAeroKit)` at enable, every `crowns[i]` whose mesh's `kind` is
  `foliage_blossom` (the lime-able ones: 7 blossom trees + Blossom Point, 8 today), sorted by tree name (a stable index:
  the gust seeds depend on it). For each: `cframe, size, pivot` by `AeroKit.crownFrame`'s maths (copied pure: centre =
  `pivot + yaw * (pivotToCentre * scale)`, size = `mesh.size * scale`, frame yawed by `crown.yaw` and `Ry(pi)`),
  `tree` name. The other session's re-export regenerates `WorldAeroKit.lua`; every client reads the same module, so the
  grove stays the same on every client.
- Fallback to `LifeSpots.Crowns` when `WorldAeroKit` fails to load or has no blossom crowns (`warn` once).
- Read on enable and again on `Life.Poll` when `Aero.trees()` changes (cheap: 8 rows).

**Stem rule on the kit shape.** Each crown is modelled as an ellipsoid in its own yawed frame (semi-axes `size / 2`).
- Start from Fable's numbers, measured from the crown's **top**: `down` **.62** of the height, `out` **.30** of the width,
  `hang` **.50** (studs, the new 1.5-tall image: stem tip to image centre).
- Guard (BUGFIX-PLAN idea 2): the stem tip is pulled in so it lies inside the ellipsoid at `stemIn` **.82** of its radius
  at that height and angle (handles the long-and-narrow kit shapes: a 9.0 x 6.9 blob at Tree_05). Data keys
  `F.down, F.out, F.hang, F.stemIn`, all tunable by Fable without code.
- `[probe]` the top third of each fruit is hidden on the three most-seen lime trees (plaza, arrival path, bridge). The
  probe (`scripts/probe_dewdrop_crowns.luau`) clones each kit crown with `CanQuery = true` into a scratch folder and
  raycasts up from each stem's fruit top: reports the foliage underside height above the stem tip per stem. Kit parts are
  `CanQuery = false`, so a runtime raycast is not possible; the probe gives per-mesh `down` overrides if one number does
  not fit (`F.meshDown[meshName]`). Run it after the other session's crown reshape lands.
- If the reshaped crowns are see-through cards with no lower mass: Fable's fallback, 2 a crown from the lowest solid
  branch points (needs the island session to export them; question C2).

**Follow the sway** (BUGFIX-PLAN idea 3). Kit crowns turn up to 4 + 1.5 degrees about the trunk top (WindClient); a
fixed stem slides off the leaves. At enable, `GardenLife` finds the live kit part for each grove crown (the `AeroKit`
folder under `EggDropLounge`, a part with `WorldDressing = "crown"` whose `WorldPivot` matches the crown's pivot within .05)
and keeps `rest:Inverse()`. Hanging fruit is drawn at `part.CFrame * rest:Inverse() * stem` while that part exists and
`level == 0`; a falling fruit keeps the shared stem (the let-go is shared; the drawn start differs by under .4 stud).
Re-found on `Life.Poll` if the part is gone (AeroWorld rebuilds the kit on a switch). Reduced Motion: static stems (the
crowns are at rest). Level 1: static stems too; WindClient still sways crowns at 15 Hz, and the ~0.2-stud slip at the
stem is accepted there.

**Look.** `dewdrop-stem.png` (section 9): the fruit as today plus a 2 px `#5A4A2A` stem to the top edge; image 1.1 x **1.5**
studs (`Life.FruitSize`), the fruit itself unchanged in size. `ImageColor3` **#E6E6DC**. `[probe]` no highlight brighter
than the Bear's in one frame (Fable).

### 2b. More fall; breath drops

- `F.chance` .35 -> **.5**; `F.rest` 18 -> **30**.
- **The breath always counts as a strong gust:** the grove adds breath candidates. Breath `b` at crown `i`: the let-go is
  the first 1/60 s on the breath's rise where `Wind.breath >= dropAt` (always reached: peak 1). Seed `b * 16 + i` with a
  separate salt range (17 to 19) so breath and gust rolls never collide; chance `F.chance`; same landing rules and the same
  slot `HOLD` rule (a slot that fell in a gust within `HOLD` before does not fall again). Plan ids `slot..":b"..b`.
- `Grove:dropsAt` merges gust and breath candidates by let-go time before the `HOLD` pass. Pure, shared, every client.
- The loose cap stays 3 / 2.

### 2c. The snack moment (B5b / D2)

**Fable's `[check]` answered: the pet's roam target cannot be set from the client.** The garden pet is server-planned:
`GardenState:decide` / `:wander` choose every target (within 4.1 studs of the owner's anchor, inside the 19-stud leash,
`Layout.StrollSpeed` 3), publish a path in the `GardenState` snapshot, and every client draws `Activity.sample` of it each
frame (`PetFollow.activity`, called from `RoomView`). There is no client roam input.

**But a client presentation layer is possible and has precedent:** `DashClient:drive` and `ParkClient:drive` already own
the pet's `visual.origin` on the owner's client while they run. So the plan of record is a **client detour layered over the
server sample** (owner's own pet, owner's client only, as the bat is today):

| Step | Rule | Numbers |
|---|---|---|
| Notice | A drawn fruit reaches its rest within **12** flat studs of my pet's *drawn* origin; the pet is free (below); my last snack over **90 s** ago. Checked on the fruit's landing (not the 2 s poll: `Loose:step` calls `notice(loose)` once at `t5`) and again every `poll` 2 s while it rests. | |
| Go | turn to it (.3 s, yaw eased), pause with `visual.careHeadPitch = -.15` and `"curious"` (.4 s), trot | trot speed **3.5** studs/s (a little over `StrollSpeed`), gait from distance (PetFollow's stride maths), arrive within **.9** of the fruit |
| Eat | three nibbles at .35 s each | head dip 9 degrees (SnackEating's nod), fruit scale 1 / .72 / .45 / 0, label squash .9 x 1.1 on each bite; bite cue name from Fable's sound note (`dewdrop_nibble`, silent until it exists) |
| Glad | hop + content face + one heart | origin lift `.35 * 4u(1-u)` over .3 s; `visual.contentUntil = now + 1.5`; one heart mote rises 1 stud over .8 s |
| Back | trot back to the **live** server sample, then hand the origin back | blend weight eases 1 to 0 over the last 1.5 studs |

**How the layer works** (`LifePet.drive(visual, actor, now, dt)`, called by RoomView right after `PetFollow.activity`):
`visual.origin = sample + w * (detour - sample)` where `sample` is what `PetFollow.activity` just wrote and `w` eases 0 -> 1
over the turn and pause, stays 1 to the end of Glad, then the return path is planned from the fruit to the live sample
each frame. Because the blend is against the *live* sample, the server's small wanders round the still owner do not
matter. `LifePet.pose(visual, dt)` (after `pet:update`, the SnackEating pattern: restore, re-pose at zero dt, then the head
dip) does the nibble pose.

**"Free"** (all must hold, checked every frame of the detour; any failure aborts):
`actor.mode == "Room"`, `actor.behavior` in `rest | follow` with the owner still (root speed under .6 for 1 s, RoomView's
`ownerStillSince`) or `actor.action == "wanderPause" | "settle"`; no `actor.care`, `actor.pairId` (greeting), `actor.dash`,
`actor.park`; not focusing (`roomView.focusing`), no menu (`clientUI.anyModalOpen`), no need bubble up
(`petFree` dep from init: NeedBubble's enabled state), no Stat snack eating (`clientUI.snacks` busy), not queued or
racing (DashClient `held()` or queued), no hatch; the fruit within 16 studs of the owner (leash 19 - margin 3); and the
server sample within **8** studs of the fruit.

**Abort:** ease `w` to 0 over .35 s from wherever the pet is (a quick trot back), restore the pose, cancel the heart, the
fruit stays where it is (if eaten past one bite it fades with `quick`). The 90 s cooldown still counts.

**Fallback if the architect rejects the overlay (question A2):** Fable's: notice reach **6**; on its last roll the fruit's
heading is biased toward my pet by up to 40 degrees (a client-only re-plan of `p4` for *this client's drawn copy*, the
shared plan untouched: `Sim.fruitTowards(loose, pet)`), and the eat plays in place (head dip, hop, heart), no position
change. The `LifePet.pose` half is the same in both.

**Others:** other players' pets keep today's bat at 3 studs on each viewer's client. Showing other pets eating needs the
server to know (question A4).

**The player's nudge:** while a drawn fruit rests and my root is within **1.6** flat studs: `Sim.fruitNudge(loose, root,
heading, now, world)` moves it **2** studs along my heading (shortened in .5 steps to the first spot passing
`fruitGround` + `fruitClear`; none: no nudge), one bounce .25 high over .25 s, a half turn; `t6` pushed past the bounce;
then the snack's notice is re-checked at once (so you can roll one to your pet). Once a second at most per fruit.

**Reduced Motion:** fruit hangs, nothing falls: no snack, no nudge (unchanged). **Level 1:** the snack runs (it is one
pet), the heart mote too. **Level 2:** GardenLife is torn down, `LifePet` releases the pet at once.

**Edge cases.** Deck round or hatch mid-snack: park aborts it the same frame (origin handed back, pose restored before
the deck draws). Respawn or teleport: the pet's sample jumps > 8 from the fruit: abort. The fruit fades (`t6`) while the
pet trots: abort at `t6 - 1`; the rest is 30 s so this is rare. Two fruits land: the nearer wins, one at a time. A pet
model rebuild (`rigRevision` changes, a hat): finish without the pose (SnackEating's rule). `/hour` jumps: no effect.
The nest pill rule (pet within 6 of the nest hides the pill) reads `visual.origin`: fine, it sees the drawn pet.

**Specs.** `LifeSim.spec`: kit crowns sorted and stable; every stem inside its ellipsoid at `stemIn`, below the centre;
the same 8 trees; breath candidates fall on every client the same (pure), never twice in `HOLD`, salt never collides;
chance .5 and rest 30; nudge rules (2 studs, shortened, refused on water / course / find / kerb); `notice` once on landing.
New `LifePet.spec` (offline, a fake visual table): the blend reaches the fruit within .9; aborts on each "free" rule and
eases back over .35 s; the cooldown; the content face time; nothing written while not free; never touches another pet.
`GardenLife.spec`: `notice` is called with my pet only; never while parked; the heart mote is one part, hidden after .8 s.
Studio-only (`scripts/LifePetStudio.spec.lua`, copied to ZZSpecs): the real RoomView hook order (drive after activity,
pose after update) with a real pet visual.

---

## 3. B2: fireflies at night

**Root cause** (BUGFIX-PLAN B2, confirmed): fireflies exist only as a 6 s hand-off from live butterflies at the moment
dusk starts; nothing spawns after (`LifeSim.lua:335`, `:352`). Separately, the Aero layer's area fireflies
(`AeroAdditions`, `WorldAero.Fireflies`: 5 fixed areas, 12 alive) switch an area **off while the camera is within
`CameraKeepOut + Reach` of its box**, so near them you see none, and they are only on the finds lawns and the stream bank.

**Plan (differs from BUGFIX-PLAN in one way: a separate population, not stretched butterfly slots).** Butterfly slots are
tied to the four wing files; fireflies are just glows.
- `Sim.Fireflies` (new, pure) with `Sim.Caps.fireflies = {8, 4, 0}` and
  `Sim.Firefly = {spawnGap = 1.5, fadeIn = 1.2, fadeOut = 2, fadeGap = .8, reach = 40, ring = {6, 18}, low = 1.5, high = 3,
  speed = .25, wander = 2.5, pulse = 1.8, lit = .1, dim = .55, size = .9}`.
- **Count by daylight** (the garden hour's, shared): wanted = `cap * ramp(d)`, `ramp = clamp((.34 - d) / (.34 - .20), 0, 1)`.
  So they start through dusk (golden .55 -> night .12 blends over 120 s), are at full count by .20, and at dawn (night ->
  dawn .5 over 90 s) the wanted count falls and the extra ones fade (staggered `fadeGap`, `fadeOut` 2 s). Hour off
  (live): daylight nil, none.
- **Where:** each spawn picks, in order of preference, a flower patch (`WorldDressing.Flowers`) or a water-edge point
  (`WorldV7Data.wet` box edges, 1.5 studs in from the bank, sampled every 4 studs at enable) within `reach` 40 of the
  camera and not used; else a point on a ring 6 to 18 studs round the player on safe ground (`IslandBounds.safeCell`).
  `Sim.clear` applies (camera 6, stations 8, pad, course while live). 1.5 to 3 studs over the ground, wandering 2.5 studs
  round the spot at .25 studs/s.
- **The butterfly hand-off stays** and becomes seamless: at `handGone` a handed-off butterfly is not removed but
  *adopted* by `Sim.Fireflies` at its position (counts toward the cap). Under `.24` a butterfly hands off at once instead
  of fading (so a player who arrives at night still sees glows).
- **Instances:** a pool of 8 anchor parts (`LifeFirefly1..8`, .2 cube, invisible), each with one BillboardGui
  (`fireflyDot`, `#E8FF8A`, size .9 studs, `LightInfluence 0`, `Brightness 2`, `MaxDistance 110`), the butterfly glow's
  build reused. Positions written at **15 Hz** (level 1: all at the step rate), transparency only on change (`changed`
  helper). No PointLight.
- **The Aero area fireflies:** not touched (Aero layer). Question C3: keep both, or have the island session drop the
  camera keep-out now that a player-centred population exists.
- **Diagnostics** (BUGFIX-PLAN item 6): `Players.LocalPlayer:SetAttribute("AliveLevel", level)` once per change from
  `GardenLife:step`, so a phone session shows whether it is at level 2 (where no garden life shows at all).

**Edge cases.** `/hour at` jump day -> deep night: spawns at once, 1.5 s apart. Night -> day: fades. Respawn or teleport
over `Sim.Drop` 120: dropped, refilled near the new camera. Parked: hidden, forgotten. Reduced Motion: none (as
butterflies). Level 1: 4. Level 2: none. Two players: per client (positions are per client by design; the count follows
the shared daylight).

**Specs (offline).** `LifeSim.spec`: at daylight .2 from an empty list, glows appear 1.5 s apart up to the cap and stay
past 6 s; none at .5; the count follows the ramp; dawn fades them (staggered) and removes them; a handed-off butterfly is
adopted, not removed; under .24 a butterfly hands off at once; level 2 cap 0; a spot is a patch, a bank point, or the
ring, in that order, never under `Sim.clear`. `GardenLife.spec`: with `daylight` .2, after 10 s the firefly pool has the
cap enabled; parked hides them all; the `AliveLevel` attribute writes once per change.

---

## 4. W3: alive yet calm

Rows in Fable's build order. "Hz" is the write rate; GardenLife steps at 30 (level 0) or 15 (level 1).

### Row 1. The big breath (shared)

**File:** `Wind.lua` (pure), consumers below.
- Breath slot **300 s**, jitter **±30**: `Wind.breathStart(b) = b * 300 + (hash(b, 21) * 2 - 1) * 30`, so every gap
  between consecutive starts is inside Fable's 240 to 360 s (a ±60 jitter would allow 180 to 420).
- Envelope: smoothstep 0 -> 1 over **2.5 s**, hold **3**, smoothstep out over **5** (10.5 s). It is a front like the gusts:
  `Wind.breath(position, t)` uses `Wind.localTime` (14 studs/s across the island), so it visibly travels.
- `Wind.blow(position, t) = max(Wind.gust, Wind.breath)` (0 to 1, times the dial as `gust` is). `Wind.at` (sway things)
  becomes `breeze + (1 - breeze) * max(rawGust, breath)`. `Wind.gust` is left as it is (AmbientAudio reads it; another
  session owns that file, question C1).
- **Consumers:** leaves x3 rate + skitter (section 1); Dewdrop sway at `swayGust` (via `Wind.at`) and breath drops (2b);
  crowns and flags, pennants, chimes (`WindClient` reads `Wind.blow` / `Wind.at`); birds: on the breath's arrival at a
  sitting bird, one hop pair + a wing flick (`Birds:breathe(now)`, once per breath per bird); my pet looks up for 1.2 s
  (`LifePet`: `careHeadPitch` -.25 eased in .2, held, out .3; only if the pet is free and not snacking: the hook exists,
  `careHeadPitch`, which `PetCarePose.set` resets every frame).
- No UI, no reward. Reduced Motion: nothing answers it (each consumer's own RM rule).
- **Specs (`Wind.spec`):** gaps all inside 240 to 360 over 100 breaths; envelope 2.5 / 3 / 5 exact; the front's delay
  along the wind; `blow >= gust` always; `at` unchanged when no breath; two clients with the same time agree.

### Row 2. The arch chimes swing

**What they are:** `W7_Chime_1..5__palette`, separate parts by the arrival (centres about (86 to 87, 14, 55 to 56)), each
already a `WorldMotion` `sway` mover (±7 degrees, 2.6 to 3.5 s, gust gain 2.5). Fable sees them hang still: `[probe]`
whether they exist under `EggDropLounge.World` with `WorldMotion = "sway"` and a `WorldPivot` after the island re-export
(they may now be hidden or merged, or the Aero layer's hidden list may include them).
- **File:** `WorldMotion.lua`. With `scene` on, a mover whose region starts `Chime_` gets its own pose:
  `angle = (3 + 11 * g) * sin(2 * pi * .45 * t + k * 1.3)` degrees, turning about the axis across the wind
  (`Side`), at its hanging point, so it swings along `Wind.Direction`; `g = WindClient:moverGust(entry)` (now `blow`).
  Written at **15 Hz** (a per-entry sub-rate), only within **70** studs of the camera; level 1: **8 Hz**; Reduced Motion:
  rest (as today). Off: today's sway.
- **Saturation x .75:** the colour is in the palette texture of a merged material; not mine (question C2, the island
  session). If they are plain-coloured MeshParts, `Color` lerped toward its own grey by .25 at bind.
- If they turn out merged into the arch: skip, and ask the island session to re-export them as five parts.
- **Specs:** `WorldMotion` added to the offline runner's client list: the chime pose at g 0 and 1 (3 and 14 degrees), the
  axis across the wind, the 70-stud gate, off = today's pose exactly.

### Row 3. Dapple under the trees

**Files:** `LifeSceneSim.lua`, `LifeScene.lua`.
- A pool of **6** plates (level 1: 3), 9 x .05 x 9, `Transparency 1` with a `Decal` on Top: `dapple.png`, `Color3`
  **#1E2A16**. Placed under the 6 crowns nearest the camera (all kit crowns, plus the Hatch Tree: `Sim.kitCrowns` with every
  kind), centred on the crown's pivot projected to `groundY + .055` (heights in section 4 row 7).
- Decal transparency: **.72** at daylight >= .45, easing to **1** at .30 and under (`.72 + .28 * smooth((.45 - d) / .15)`);
  hour off: .72.
- Drift: centre `+ Wind.Direction * (.35 * sin(2 pi t / 9) + .5 * g)`, turn `±4 * sin(2 pi t / 13)` degrees about Y; t is
  server time + a per-crown phase (`hash`). **10 Hz.** Re-pick the 6 nearest every 1 s; a plate moving to a new crown
  fades out .3 s and in .3 s (no pop).
- Reduced Motion: plates stay as **static shade** (no drift). Level 2: none (GardenLife gone; question B1).
- `[probe]` reads as shade, not a sticker; else .80.

### Row 4. Koi in the pool

- **Pool:** the walk map's `Water_Pool_Falls` box: centre (64.5, 3.2, -66.0), 27 x 24, surface y **3.2**
  (`WorldAero.Look.PoolTop` agrees). Koi ellipse: 60% of the half extents (8.1 x 7.2), **moved away from the falls' foot
  and the two pool rocks** (`WorldAeroKit.rocks` kind `pool` at (65.8, -68.9) and (68.1, -63.9)): the generator check in
  the spec rejects a path passing within 1.2 of a rock. `[probe]` and question C2: the island session confirms centre,
  size and surface after its pool map change; the numbers live in one table `LifeSceneSim.Pool`.
- **3 koi** (level 1: 2): plate 1.3 x .02 x .5, Decal Top `koi-a/b/c.png`, at surface **- .25**. Figure of eight (a
  Lissajous `x = a sin(wt + p)`, `z = b sin(2wt + p) / 2` in the ellipse's frame), path speed **.5** studs/s (w from the
  path length), each koi its own phase; yaw along the velocity plus a tail sway `±8 * sin(2 pi 1.1 t)` degrees. 15 Hz.
- **Rise:** every **9 to 15 s** (per-client Random) one koi's ring: a ripple plate (pool of **3**, Decal Top, the uploaded
  `Ripple` texture `rbxassetid://123065684226119`, no new image) at the surface + .02, size .4 -> 1.6, transparency .3 -> 1
  over 1.4 s.
- **Shy:** player root within **3** studs of the pool's bank (ellipse distance under 1 + 3 / radius): the ellipse centre
  eases toward the far side by up to 40% of the radius, path speed **1.2** while moving; back over 4 s after.
- Water see-through: `[probe]` they read under the surface. Else Fable's fallback: plates at surface **+ .02**, Decal
  transparency **.35**, colours unchanged (a shape under the water).
- Reduced Motion: none. Level 1: 2. Two players: koi follow the server time, so the same place on every client, except
  the shy offset (local).

### Row 5. A far flock

- Schedule (server time, shared): flock slot **120 s**, jitter ±30 (gaps 60 to 180; Fable says 90 to 150: jitter **±15**
  keeps every gap inside 90 to 150). Only when daylight > **.7** at its start (hour off: always).
- Path: a shallow arc 130 to 170 studs from the island's middle (0, 0), 45 to 60 up, bearing and arc from the flock's hash;
  **9** studs/s, about 25 s in view (225 studs of arc), 5 birds in a loose V (spacing 2.5, a per-bird hash wobble ±.6).
- Each bird: 2 wing plates .9 x .35 x .02, plain `#3B3A40` (no texture), `SmoothPlastic`, flapping
  `phi = 25 * sin(2 pi 2.6 t + k)` degrees about the bird's long axis. **10 parts**, 15 Hz, hidden between flocks.
- Level 1: 3 birds (6 parts). Reduced Motion: none.

### Row 6. Lamps one by one; a shooting star

**What the lamps are today:** one merged mesh, `W7_LampOrbs__glow_warm` (140 tris spanning 141 x 97 studs), Neon, a
`WorldMotion` `pulse`; `AeroWorld:paintGlow` sets **one colour for every lamp at once** (the garden hour's `GlowWarm`). So
per-lamp lighting cannot come from that mesh.
- **Plan:** per-lamp halos on top. `scripts/build_lamp_spots.py` (new) reads the LampOrbs mesh's vertices from the v7
  source the asset build uses and clusters them into lamp centres -> `src/shared/LampSpots.lua` (generated). If the source
  is not readable offline, a `[probe]` in Studio prints the orb centres (the mesh is `CanQuery` true? if so, a downward ray
  grid over its bounds). Expect 5 to 7 lamps (140 tris).
- Each lamp: one Attachment on one shared invisible anchor part, one BillboardGui (`fireflyDot` tinted **#FFC96A**, 2.2
  studs, `LightInfluence 0`), and a **PointLight** (Range 10, Brightness 0 -> 1.2, `#FFC96A`, Shadows false) on the
  **4 nearest** lamps only (level 1: none).
- Order: by distance from the plaza's middle (-30, 4). Times on the shared clock: `t0` = when the garden hour's daylight
  falls through **.45** (solved from `GardenHour.phase`'s golden -> night blend), lamp `i` at `t0 + .35 i`, each easing
  0 -> 1 over .8 s; dawn: through .45 rising, `.15 i` apart. So every client lights the same lamp at the same moment.
- **The merged orbs:** they still change colour all at once (AeroWorld). Question C2: the island session either keeps
  the orb mesh dim until the halos have run (one property in its hour paint), or re-exports the orbs as separate parts.
- **Shooting star:** once a night (hour number = floor((t + offset) / 3600)), at a hashed time in the middle third of
  night (s in 3120 to 3360), **3 streaks 6 to 9 s apart**. One anchor part with two Attachments and **one Beam** (reused
  per streak; Fable's "2 Beams" is not needed): length 14, width .25, `#FFF4D6`, `LightEmission 1`, `FaceCamera true`,
  `Transparency` sequence `{0,1},{.15,0},{1,1}` moved along the streak so the tail fades; 0.7 s each. Placed 200 studs
  from the camera in a bearing within ±40 degrees of its look, 35 to 50 degrees up (timing shared; placement per client
  so it is seen). Reduced Motion: none. Level 1: yes (one beam, 2 s a night).
- Lamps under Reduced Motion: halos and lights still come on (they are light, not motion) but all at once at .45.

### Row 7. Texture on the ground (static)

**Where they live:** a new generated data module `src/shared/GroundDressing.lua` (not `WorldDressing.lua`: that one is
generated by `build_world_v7_dressing.py` and says do not edit), written by `scripts/build_ground_dressing.py`, and drawn
by **`WorldDressingClient`** (a second build beside the flower patches, the same flat-on-the-ground-plane plates, the same
4 Hz cull at 90 / 150 studs). Not GardenLife: they must show at **every budget level** and under Reduced Motion, and
GardenLife is torn down at level 2.

| | Count | Size | Texture | Look | Placement rule (generator) |
|---|---|---|---|---|---|
| a. leaf litter | 8 | 3 x 3 | `litter.png` | Decal `Transparency .15` | under the 8 largest kit crowns (by footprint), offset 1 to 2 studs downwind (hash) |
| b. lawn patches | 10 | 7 to 11 across | `lawn-patch-a/b.png` | Decal `Color3` #2E7A34 (a) / #4C9A45 (b), `Transparency .55` | on grass cells (`g`/`G` in `world-v7-walk.json` surface rows) with all cells within the plate's radius grass, spaced 14+ apart, in the most-seen lawns (arrival lawn, plaza ring, spring meadow) |
| c. path fray | 12 | 4 x 1.5 | `path-fray.png` | Decal `Transparency 0` | along the dirt path's edge (cells `R` beside `g`/`G`), long side along the edge, on the arrival path and round the plaza |

- **Clear rules** (as the Dewdrop rest spots): off the Dash course line (4) and pad (R 4.0 + 2 for the new rope ring), find
  spots (3), park kerbs (+2), stations (4.9, the flower rule), the nest's blocked region (read from the Nest module at
  generation; the nest builder is moving it: question B3), water (`wet` boxes + 1).
- **Heights** to avoid z-fighting where plates overlap: patches **.040**, path fray **.045**, litter **.050**, dapple
  **.055** (moving), flowers .06 (today).
- Beta only: `Alive.on("scene")`; the live place never builds them (the ceiling).
- **Specs:** offline `GroundDressing.spec` (data only): counts, sizes, every plate passes every clear rule against the
  *live* modules (DashCourse, FindSpots, ParkLayout, Nest spot, stations), so a later move of any of them fails the spec
  and asks for a regenerate. Studio-only: `WorldDressingClient` builds 30 plates with the right Decals (scripts/, copied to
  ZZSpecs).

### Row 8. Dragonflies over the water

- **2** by day (daylight > .7; level 1: 1), each a body spindle .35 long (`#3F6F78`, Sphere SpecialMesh on a block, the
  butterfly body's build) and two wing plates .5 x .14 x .01 at `Transparency .55` (plain `#C9D6D8`, no texture): **6 parts**.
- Home: the falls pool and the lily pool (`Water_Pool_Lily` (13.5, -7.5), 21 x 15) and the stream boxes within 60 studs
  of the camera; never more than one per water box.
- Motion: hover .8 to 2 s (a ±.05 bob, wings swapping between two angles ±12 degrees every frame at **15 Hz**: the blur),
  then a straight dart 3 to 5 studs in .35 s (ease out) to a point 1 to 1.6 studs over the water inside the box (inset 1);
  yaw turns at the start of a dart. Written at the step rate (30 / 15).
- Reduced Motion: none.

**Do not add** (Fable): more particles, more glow, more saturation, anything faster than about 1 Hz at mid distance. The
dragonfly wing swap and the far flock's flap are the two fast loops, both small or far.

---

## 5. Budgets

**Parts** (new, level 0 / level 1):

| What | L0 | L1 | Written |
|---|---|---|---|
| fireflies (anchor + billboard) | 8 | 4 | 15 Hz, transparency on change |
| heart mote | 1 | 1 | during a snack |
| dapple plates | 6 | 3 | 10 Hz |
| koi + ripples | 3 + 3 | 2 + 3 | 15 Hz |
| far flock | 10 | 6 | 15 Hz, only during a flock |
| dragonflies | 6 | 3 | 30 / 15 Hz |
| lamp anchor (+ ~6 attachments, billboards, 4 lights) | 1 | 1 | on change only (dusk, dawn) |
| star anchor (+ 2 attachments, 1 beam) | 1 | 1 | 2 s a night |
| ground plates (static) | ~30 | ~30 | never |
| **total** | **~69** | **~55** | |

Leaves: 3 emitters as today (sheet, petal, skitter replace A, B, petal); up to 58 particles (44 + 14) at level 0, 29 at
level 1 (was 28 / 14). Bubbles unchanged. Dewdrop pool unchanged (16). **No new emitters.**

**CFrame writes a second** (level 0, worst case: a flock in view): fireflies 8 x 15 + dapple 6 x 10 + koi 6 x 15 + flock
10 x 15 + dragonflies 6 x 30 = **600** (about 20 a frame at 30 Hz), in GardenLife's single `BulkMoveTo`. Today's life is
about 40 parts at 30 Hz (birds 30, butterflies 12) = up to ~1,200 a second; this roughly adds half. Level 1 is about 250.

**Draws** (roughly one per visible decal plate or billboard): +~30 static plates (culled at 90 studs on a phone), +6
dapple, +6 koi/ripple, +8 firefly billboards at night, +~6 lamp halos at night, +16 for the flock and dragonflies.
`[probe]` `AlivePerfProbe.lua` extended: the frame p75 on the beta with everything at level 0 and with `scene` off, on
Spencer's phone (AliveBudget's 40 ms is the line).

**Textures:** section 9 (11 new images, about 0.6 MB uncompressed together).

---

## 6. Cross-cutting edge cases

| Case | Behaviour |
|---|---|
| Deck round (board Mode not Room) | `Life:park`: every moving part hidden in one move, emitters cleared, snack aborted, fireflies forgotten. Ground plates stay (static). Lamps keep their state. |
| Hatch | the same park (`WindClient.hatching`). |
| My own race | park (as today). Queued: the snack is not "free"; a running snack aborts. |
| Another player's race live | no loose fruit drawn (today); skitter spot avoids the course; the rest unchanged. |
| Reduced Motion | none of the new motion; ground plates and static dapple stay; lamps light all at once. |
| Budget level 1 | the halved counts above, 15 Hz stepping, no crown-following stems, no PointLights. |
| Budget level 2 | GardenLife torn down (no fireflies, scene, snack); ground plates stay. `AliveLevel` attribute says so. |
| Phone | no separate caps (budget levels only, as GardenLife today); ground plates cull at 90 (the flower rule). |
| Two players | breath, fruit falls, lamps, star timing and flock timing are pure functions of server time: the same everywhere. The snack, nudge, koi shy offset, firefly positions and leaves are per client. |
| `/hour at` jumps | fireflies, dapple fade, lamps and day gates read the daylight every `Life.Poll` (2 s) and ease; a lamp jump past its whole sequence sets the end state at once. |
| Switches | `/alive scene off`: LifeScene parts hidden and destroyed with their folder, chimes back to today, ground plates removed. `/alive life off`: everything in GardenLife gone (as today). |
| A step that throws | GardenLife's `fail` (as today) takes LifeScene and LifePet down with it; LifePet hands the pet back first (it cannot throw past that). |

---

## 7. Order of work (each a commit; offline specs green after each)

1. **Wind breath** + `Wind.spec`; `WindClient` reads `blow`.
2. **B2 fireflies** (LifeSim + GardenLife pool + `AliveLevel`) + specs.
3. **Q5 leaves** (numbers, sheet, skitter, reach derivation; question A1 decides the breath term) + specs + textures drawn.
4. **D2 / B5 hang** (kit crowns, stem rule, sway follow, image) + specs; probe after the crown reshape lands.
5. **D2 fall** (chance, rest, breath drops, nudge) + specs.
6. **D2 snack** (`LifePet`, RoomView hooks, PetExpression, init deps) + specs.
7. **`scene` switch**, `LifeScene` / `LifeSceneSim` skeleton, then rows 3, 4, 5, 8, 6 (dapple, koi, flock, dragonflies,
   lamps + star) + specs.
8. **Chimes** (WorldMotion) + spec (WorldMotion added to the runner).
9. **Ground plates** (generator, data, WorldDressingClient) + specs.
10. LifeArt rows, `check_life_art.py` covering the new folder; `V3-TEST-PASS.md` rows; TODO.

Offline: `python scripts/run_dash_server_specs.py "C:/Users/skunk/Documents/Development/egg-drop/build/luau-cli/luau.exe"`
(`LifeSim`, `GardenLife`, `Wind` are default; `LifeScene*`, `LifePet` bundle by the `Life*.lua` pattern; add
`"LifeSceneSim", "LifeScene", "LifePet", "GroundDressing", "WorldMotion", "WindClient"` to `CLIENT`). `luau.exe` is never
committed. Studio-only specs in `scripts/` (`LifePetStudio.spec.lua`, `GroundDressingStudio.spec.lua`) copied to ZZSpecs
later. Probes: `probe_dewdrop_crowns.luau`, `probe_life_scene.luau` (chimes present and moving, pool water see-through,
lamp centres, flipbook cell stays).

---

## 8. Risks

1. **The pet detour is the only change that moves a pet off its server path.** Anything else that reads
   `visual.origin` (click target, need bubble anchor, nest pill rule, PetLookAt) sees the drawn pet; anything that reads
   the snapshot (greetings, catch-up, the leash) sees the server pet, up to ~12 studs apart for ~10 s. Mitigated by the
   strict "free" rule and abort; fallback ready (A2).
2. **Breath and leaf reach:** a breath can carry falling leaves 30+ studs; without the A1 clamp, roofs refuse many more
   spawns near the rotunda and colonnades.
3. **Crowns are being reshaped now.** Stems are data-driven and re-read, but `down` / `stemIn` need one probe after the
   reshape; until then fruit may still float on some trees.
4. **Flipbook cell stability** is unverified; the fallback costs the skitter.
5. **Lamps:** the merged orb mesh lighting all at once undercuts "one by one" unless the island session helps (C2).
6. **Koi visibility** depends on the pool water the island session is repainting now.
7. **Perf on Spencer's phone:** if it already sits at level 2 (B2's diagnostic), none of garden life shows; the
   `AliveLevel` attribute is the first thing to read on the beta.
8. **Two writers:** chimes are WorldMotion's (I change WorldMotion, not GardenLife, so one writer). Crowns stay
   WindClient's; fruit only reads their CFrame. Pet origin: LifePet writes only after `PetFollow.activity` and only while
   it holds the pet; DashClient / ParkClient `drive` win (LifePet is not called when they drive).
9. **The ground generator** depends on modules other builders are changing (nest spot, Dash pad ring); the spec against
   the live modules catches drift, but someone must re-run the generator.

---

## 9. New textures (script-drawn, `scripts/draw_garden_life_r4_textures.py`, numpy + Pillow, fixed seeds; output
`artifacts/qa-2026-11-23-beta14/look/`; uploads later via Studio MCP `upload_image`, ids into `LifeArt`)

| File | Size | For | Notes |
|---|---|---|---|
| `leaf-sheet.png` | 192 x 192 | leaf + skitter emitter | 2 x 2 cells of 96: A broad #5E8F3A, B willow #7C7A3A -> #7A5A30, C lime heart saw-tooth #8FA83E / midrib #C9D08A, D dry curl #A8762E / #5C3D1C; shade half 12% darker, 2 px rim on the shade side only |
| `leaf-sheet-ac.png`, `leaf-sheet-bd.png` | 192 x 96 each | the flipbook fallback only | uploaded only if needed |
| `dewdrop-stem.png` | 192 x 262 | Dewdrop billboard | today's 192 x 224 fruit + a 2 px #5A4A2A stem to the top edge (1.1 x 1.5 studs) |
| `dapple.png` | 256 x 256 | dapple plates | soft dark blobs with light gaps, alpha, tinted #1E2A16 by the Decal |
| `koi-a.png`, `koi-b.png`, `koi-c.png` | 128 x 48 each | koi plates | from above, no outline: muted orange-and-white, pale gold, slate |
| `litter.png` | 256 x 256 | litter plates | the four leaf shapes at rest, scattered, alpha |
| `lawn-patch-a.png`, `lawn-patch-b.png` | 256 x 256 each | lawn patches | soft-edged mown / clover texture, grey value, alpha; tinted by the Decal |
| `path-fray.png` | 256 x 96 | path edge plates | dirt breaking into grass tufts along the long side, alpha |

Reused, no new image: `fireflyDot` (fireflies, lamp halos), the uploaded pool `Ripple`, the Stat Snacks atlas heart icon
for the mote (or `heart-mote.png` 64 x 64 if Fable wants a softer one: question B4). Flock, dragonfly and star: no texture.

---

## 10. Questions for the architect

- **A1.** Falling leaves in a breath: clamp their wind term to `Wind.gust` (reach stays ~22, recommended) or let the
  breath push them (reach 30 to 40, more refusals near roofs)?
- **A2.** The pet snack: approve the **client presentation detour** over the server sample (DashClient / ParkClient
  precedent), or take Fable's in-place fallback (reach 6, roll toward the pet, no movement)?
- **A3.** Put the snack behind its own Alive feature (`snack`) so Spencer can kill the pet change alone, or keep it under
  `life`? And is one new feature `scene` for W3 right (versus everything under `life`)?
- **A4.** Other players' pets eating needs the server to mark a fruit eaten (shared grove on the server). Leave for later?
- **A5.** `Wind.blow` as a new function (consumers opt in; AmbientAudio's rustle does not swell in a breath) versus
  folding the breath into `Wind.gust` (everything answers, including the rustle, but every gust-derived number and spec
  shifts). I recommend opt-in.
- **A6.** Fireflies: a separate `Sim.Fireflies` population (my plan) versus BUGFIX-PLAN's stretched butterfly slots?

## 11. Questions for Fable / the island session (not blocking the start)

- **B1.** Dapple at budget level 2 (GardenLife gone): none, or move the static shade into WorldDressingClient too?
- **B2.** Koi: falls pool (Fable's) or the lily pool by the plaza (13.5, -7.5), seen far more often?
- **B3.** Ground plates around the nest: wait for the nest builder's final spot (E1 / E2) before generating.
- **B4.** Heart mote: the Stat atlas heart, tinted pink, or a new soft heart?
- **C1.** AmbientAudio (other session): should the rustle follow the breath (`Wind.blow`)?
- **C2.** Island session: chimes present and separate after the re-export; their saturation x .75; pool centre, size,
  surface and see-through; LampOrbs dim until the halos run (or separate orbs); lowest solid branch points if the crowns
  become cards.
- **C3.** Aero area fireflies: keep alongside the new population, and drop their camera keep-out?

---

## 12. As built (2026-11-24), architect r1 "GO WITH CHANGES" applied

Branch `worktree-agent-a25638addc7cc4aa6` (rebased onto feat 6b23b91, after the Hush and nest/race line merges). Offline runner green (60 specs). Code review r1 fixes applied (walk-back checks, fruit size until upload, release on teardown). Nothing seen in
Studio. Architect answers: A1 clamp (falling leaves read `Wind.gust` only; the breath raises the rate x3 and runs the
scud; `LifeSim.spec` replaces `Wind.breath/blow/swayAt` with a thrower during the drift run); A2 detour approved, notice
reach **8**, abort when the drawn pet is 8+ studs from its server spot, built last; A3 new Alive features **`scene`** and
**`snack`**; A5 opt-in, `Wind.at` untouched, the breath-aware sway is `Wind.swayAt`, read only with `scene` on (WindClient,
hanging Dewdrops); A6 a separate firefly population (8 / 4 / 0), adopting butterflies at hand-off.

| Item | Where | Differs from the plan |
|---|---|---|
| Big breath | `Wind.breath / blow / swayAt / breathStart / breathEnvelope` (slot 300 +-30, 2.5 / 3 / 5) | none |
| Q5 leaves | `Sim.Leaf` (4 / 2, boost 1.5, x3 breath, caps 44 / 22, lean .45, gust 1.3, sway .35, rot 70), `Sim.Skitters` (6 / 3, cap 14 / 7, own 15-stud cover reach), GardenLife emitters sheet / petal / scud | **reach 24, side 2** (23.1 / 1.5 measured); the sheet's flipbook grid is only set once `leafSheet` is uploaded |
| B5 hang | `Sim.kitCrowns` (WorldAeroKit via `AeroKit.crownFrame`, called directly: no side effects), ellipsoid stems (.62 / .30 / .50, stemIn .82), sway-follow by pivot match (static otherwise), `#E6E6DC`, 1.1 x 1.5 | fallback LifeSpots + one warning |
| D2 fall | chance .5, rest 30, breath drops (salts 17 / 18, plan n = -(b+1), HOLD shared), `Sim.fruitNudge`, `notice` hook | none |
| D2 snack | `LifePet` (Alive `snack`), RoomView `lifePetDrive` / `lifePetPose`, `PetExpression` `contentUntil`, init guard (a throw drops it) | heart = the Stat atlas heart decal tinted #F4A9C4; nibble cue `dewdrop_nibble` not wired (waits for Fable's sound) |
| B2 fireflies | `Sim.Fireflies` + GardenLife pool, `AliveLevel` attribute | none |
| W3 scene | `LifeSceneSim` (pure) + `LifeScene` (parts in GardenLife's folder and move) | koi plate .5 x 1.3 along travel, texture portrait 48 x 128 (Fable said 128 x 48); one star Beam (not 2); lamp halos use `fireflyDot` tinted |
| Chimes | `WorldMotion` (Chime_k movers, scene on) | saturation x .75 not done (island session) |
| Ground plates | `scripts/build_ground_dressing.py` -> `GroundDressing.lua`; `WorldDressingClient` | runtime y from `HollowWorldLayout.groundY` (stored y as fallback) |
| Birds | `Birds:breathe` (a hop pair once a breath) | none |
| The Hush | GardenLife `quiet()` dep (`clientUI.hush:inHush()`): no new leaves, bubbles, birds; fireflies fade | added at the coordinator's request |

**Live safety specs:** `GardenLife` ceiling false -> no mount; `LifePet` with the snack ceiling false or the switch off
writes nothing; `WorldMotion` on the live place keeps today's sway; `WorldDressingClient` builds zero plates on live;
`PetExpression` content only with `contentUntil` (only LifePet sets it).

**Specs:** offline `Wind`, `LifeSim`, `GardenLife`, `LifeSceneSim`, `LifeScene`, `LifePet`, `WorldMotion`, `GroundDressing`;
Studio only (not run) `scripts/GardenLifeStudio.spec.lua`, probe `scripts/probe_life_scene.luau`; `WindClient.spec` mock
keeps `scene` off.

**Textures to upload** (`artifacts/qa-2026-11-23-beta14/look/`, gate `python scripts/check_life_art.py r4`): leaf-sheet
192x192, leaf-sheet-ac / -bd 192x96 (fallback only), dewdrop-stem 192x262, dapple 256x256, koi-a / b / c 48x128,
litter 256x256, lawn-patch-a / b 256x256, path-fray 256x96. Until uploaded: the sheet is today's leaf A, the fruit
today's dewdrop; dapple, koi, litter, lawn and fray build nothing.

**Unverified (Studio):** a sheet leaf keeps its cell in flight; the reach vs Drag in the engine; crown underside vs
`down` on the reshaped crowns (probe); chimes are separate movers; koi decal orientation and the pool's see-through;
lamp halo heights (orbs at y 9 assumed) and the merged orbs lighting at once; dapple overdraw on a phone; the pet
detour's look next to the need bubble, the nest pill and click targets; `careHeadPitch` sign for "looks up".
