# Cliff path, Play Den and terrace top: island scope (Opus, island session, 2026-11-24)

For Fable's `CLIFF-PATH-AND-ARCADE-CAVE-LOOK.md` (Spencer after beta 16). Scope only; no build until the coordinator's go.
Live must stay unchanged.

## What the sculpt touches (measured in `world1-mockup-v7-import.blend`, faces whose centre is in each volume)

Volumes: the path corridor (8 studs either side of Fable's line foot -> bank -> shelf 1 -> shelf 2 -> turn -> notch,
y 3 to 34), the den (x -24..8, z -121..-96, y 3 to 22), the terrace top (its 76 x 44 footprint, y >= 27).

| Source object (exported group) | Its triangles | Path | Den | Terrace |
|---|---|---|---|---|
| Rocks_Walls__cliff_rock (`W7_Rocks__cliff_rock`, collides, precise) | 3,745 | 604 | 99 | 39 |
| Terrain_Ground__ground (`W7_Ground__ground`, no collision) | 5,517 | 213 | 98 | 3 |
| Terrain_Ground__grass (`W7_Ground__grass`, no collision) | 5,612 | 84 | 7 | 32 |
| Rocks_Walls__grass (`W7_Rocks__grass`, collides, precise) | 335 | 50 | 4 | 29 |
| Landmarks__cliff_rock (`W7_Landmarks__cliff_rock`, collides) | 1,133 | 6 | 194 | 0 |
| Landmarks__gold / teal / cave_dark / marble / trim / grass (`W7_Landmarks__*`) | small | 0-1 | 9-180 | 0 |
| Glow Grotto crystals (`W7_Crystals__glow_aqua` / `__glow_pink`) | 96 + 96 | 0 / 32 | 96 / 48 | 0 |
| Vegetation_Trees__foliage (`W7_Vegetation__foliage`) | 3,240 | 39 | 0 | 0 |
| CaveBlocker (data box) | | | 12 | |

Ground collision is not the ground mesh: it is 68 invisible 32-stud tiles (`W7C_Ground_NN`, scripts/build_world_v7_collision.py).
13 border the volumes (05, 06, 11, 12, 13, 18, 19, 20, 26, 27, 28, 35, 36; 9,680 triangles); about 8 to 10 are really cut.

## How live stays unchanged: a beta-only overlay pack, never in the live project

Live builds from `launch.project.json`, which already leaves out the beta's assets (AeroKit, EggMachine, NestLandmark).
So the sculpt is **not** a live re-export:

- The live island (`WorldAssetsNative.rbxm`, `WorldV7Data.lua`, `world-v7-walk.json`, the native checkpoint) stays
  byte-identical. No re-bake of the live Rocks collision (the Eggs split showed a re-bake moves precise collision by up
  to 0.17 elsewhere), no checkpoint re-sign, no walk-map change.
- A new beta pack, `ServerStorage.WorldBeta` (native rbxm with precise collision baked in Studio, the Eggs split's
  route), mounted in `default.project.json` only. It holds **carved copies** of the affected island parts and the **new
  sculpt parts**; the beta swaps them in by name while the tier/den switch is on.
- Why copies and not a live split: 4 of the 7 groups collide with precise collision (Rocks x2, Landmarks__cliff_rock,
  the ground tiles), and the cut adds rock that live must not have. Hiding pieces cannot make new faces.
- Cost of copies: the swapped groups are island-wide meshes (Ground x2 about 11k triangles, Rocks__cliff_rock 3.7k).
  On the beta the originals are hidden, so the drawn total grows only by the new sculpt pieces; memory holds both while
  the pack is mounted. Live pays nothing (not mounted).

## Pipeline

1. `build_world_v7_chunks.py --beta` (background Blender, blend never saved): after the usual source passes, the
   **sculpt pass**: delete source faces inside the cut volumes, then add new hand-shaped rock and earth built from
   code (swept ledge, cut back wall leaning about 20 degrees with grass benches, dry-stone bank, stone lip with gaps,
   drawn steps, the rock fin and turn pocket, the notch rocks, the den's walls and low dome and floor, the mouth jambs
   under the existing lintel, the terrace top re-graded under the floor). New pieces overlap the cut edges by about
   0.3 so no seam shows. Exports **only** the changed groups: `world-v7-beta.fbx` + `world-v7-beta-manifest.json`.
   Shared groups keep their names with a `W7_CD_` prefix (architect: Aero dresses only `W7_` names) (`W7_CD_Rocks__cliff_rock` replaces `W7_Rocks__cliff_rock`);
   new pieces are their own regions (below).
2. `build_world_v7_collision.py --beta`: the tiles under the cut rebuilt from the sculpted ground (`W7C_CD_Ground_NN`,
   the same numbers they replace) and one invisible smooth ramp along the path's walk surface (`W7C_CD_CliffPath`,
   so the drawn steps never catch a foot; no riser over 0.6).
3. Walk data for the beta: a patch of the walk grid and surface map over the changed cells, written into the beta data
   module (live's `world-v7-walk.json` untouched).
4. Gate like the egg machine and the Eggs split: upload, readback, staged native rebuild of the beta pack in Studio,
   precise collision probes, `WorldBeta.rbxm` promoted with its own proof (`world-beta-native-collision.json`).

## Names and anchors for the code side

Generated data module `src/shared/CliffDenData.lua` (nest-local is not used: everything in world studs, as WorldV7Data):

- `swap`: `{hide = {"W7_Rocks__cliff_rock", "W7_Rocks__grass", "W7_Ground__ground", "W7_Ground__grass",
  "W7_Landmarks__cliff_rock", ... , "W7C_Ground_27", ...}, show = {"W7_CD_...", "W7C_CD_Ground_27", ...}}` in pairs.
- Regions (part name prefixes in `WorldBeta`): `W7_CD_CliffPath__*` (dirt, stone lip, steps, bank, fin),
  `W7_CD_PlayDen__*` (walls, dome, floor, jambs), `W7_CD_TerraceTop__*`; invisible collision `W7C_CD_*` (the `W7C_`
  filters keep them out of floor rays). Every new name gets a `parts` entry (region, motion) in CliffDenData.
- `den`: `floorY`, the room as a convex plan polygon + `roofY(x, z)` sampled grid (16 at the middle, 11 at the walls),
  the mouth (`x1 -15`, `x2 1`, top 11, its z line), the back wall line for bays, the lintel / sign anchor (under
  `W7_Landmarks__trim`, y 10.2), four lantern anchors, the region box for bounds and pets (`PlayDen`).
- `path`: `foot` (-21.5, 4.6, -90.5), `turn` (-76, 23, -52), `arrival` (-71.5, 29, -60.6), the centre line as points
  `{x, y, z, width}` every 2 studs with true heights (pets later), and the walk surface as plan polygons with heights
  (for IslandBounds and catch-up).
- `terrace`: the regraded top (`maxGroundY` under the floor, 28) and the new balustrade gap s 26..34.
- `evacuate`: about (-27, y, -84) (Fable: the old spot is now the den's doorstep). `caveBlocker`: off on the beta (the
  den has walls); the blocker box comes from the den's back wall instead.

## Order

0. Fable's A0 (code only, the small pocket) can run now: nothing here blocks it.
1. **Grey blockout** of all three (sculpt pass with flat grey, collision, data) -> Studio walk, probes, phone camera.
   Fable's own order.
2. Art pass on the same geometry (home's cliff rock and dirt, the lip, glow-caps), Fable renders, Studio captures.

## Cost (island session)

- Blockout: sculpt pass + collision + data + gate about 1.5 to 2 days of work, one Studio pass about 3 hours (uploads,
  native rebuild of the beta pack, probes, a walk, captures).
- Art pass: about 1 day plus Fable's render rounds and one Studio pass.

## Risks

- **Cutting non-manifold island sheets.** The rock and ground are open shells, so booleans are unreliable: the cut is
  "delete inside, add overlapping new pieces". Seams and z-fighting at the overlap are the main visual risk; Fable
  reviews the blockout from the Hub and up close.
- **Precise collision of the big copies** (Rocks__cliff_rock and grass, Landmarks__cliff_rock) decomposes differently
  on the beta: probes over the whole island with the swap on, as for the Eggs split.
- **The swap at runtime** (the switch flips while players stand on the path or in the den): the code side moves them
  (the tier's evacuation) before the swap.
- **Data consumers:** IslandBounds, pets and the walk map must read the beta patch while the switch is on, or pets will
  path into the new rock. Code side.
- **One tree** (`Vegetation_Trees__foliage`, 39 triangles in the corridor): keep the path clear of it rather than swap
  the island's whole foliage mesh (3,240 triangles) `[check]` at blockout.
- **The perimeter ring:** the den stays inside it (Fable); the turn is 6+ from boxes 112 to 114. No ring rebuild.
- Memory on the beta: about 17k more triangles held (the hidden originals), none drawn twice.

## Architect review (2026-11-24): overlay right, with these changes (applied above or adopted)

- **Swap only at server start, on the beta place, never at runtime.** `LoungeWorldV7Art.meshes` replaces the parts in the
  template (`ServerStorage.WorldAssets.WorldV7`) before it clones, then sets `MeshParts`. The originals never reach
  clients; one `CliffDen` attribute set at start tells every consumer. The tier switch only opens or closes the foot
  and the notch. (A runtime swap breaks WorldMotion's bound list, EggCornerWorld's floor include list, AeroWorld's
  paint records, and anyone standing on the rock.)
- **Names:** `W7_CD_*` for carved copies and new art parts (Aero's `kind` reads only `W7_`), `W7C_CD_*` for invisible
  collision (the `W7C_` floor filters). New names carry their `parts` entries (region, motion: the crystals pulse).
- **Data contract adds:** a version stamp (hash of the live WorldV7Data and walk json, checked by a spec); the walk-grid
  patch applied inside `HollowWorldLayout`'s lookups (it freezes `Data.ground` at require); a beta `IslandGround` and new
  `Tier.BoundsRegions`; checks of the generated dressing, find spots, Dash course and AeroKit trees against the cut
  volumes with a hide list; `W7_Trunks__bark` (collides) and Aero `Tree_04_round` at (-70.4, 13, -43.9), about 8 from
  the turn, to check at blockout.
- **Native beta pack with its own proof,** not a runtime precise bake (seconds at each server start, varies by Roblox
  version, no proof). The Eggs split promoter is the route; the pack is designed as the future live split if the den
  goes live.
- **Order:** the blockout uses the final names and the server-start swap, so the art pass changes meshes only. Cost
  +0.5 day (walk patch, beta safe ground, dressing and find-spot checks, data specs). Gate probe added: spawn on the
  beta with Aero on and off, capture the cut seams with Aero's paint.

## Amendment (Play Den architect review, 2026-11-24)

- The world owns the den's closer: `LoungeWorldV7Art.collision` builds the colliding `CaveBlocker` on the NEW mouth line
  from `CliffDenData.den.mouth.blocker` when the den is in (closed by default); the code's DenHost only opens it.
- `CliffDenData.schema` (the module's shape, checked by the code) is separate from the live-world stamp (`live`) and the
  pack stamp (`version`).
- Anchors for the code: five named bays (Dash gate, Deck table, three niches) with the roof over each, the doorstep, the
  mouth pin, the notice board spot; the den floor answers ground rays; safe cells for the den floor, the mouth and the
  apron to the home Floor's edge (z -89).

## Blockout as built (2026-11-24, branch `claude/cliff-den-scope`)

Offline, not uploaded. Live untouched (`world_native_collision.py --check` PASS; the live chunk and collision builders
reproduce the committed outputs; `launch.project.json` never mounts `WorldBeta`).

Rebuild (background Blender on `world1-mockup-v7-import.blend`, never saved): `build_world_v7_chunks.py -- --beta
--beta-base` (baseline walk map = the committed live one), `build_world_v7_chunks.py -- --beta` (the sculpt:
`world-v7-beta.fbx`, `-manifest.json`, `-walk.json`, `-anchors.json`), `build_world_v7_collision.py -- --beta`
(`world-v7-beta-collision.fbx/.json`; asserts the den floor rays), then `python scripts/cliff_den_data.py`
(`src/shared/CliffDenData.lua`), `python scripts/cliff_den_checks.py`, `scripts/render_cliff_den.py`.

**Parts in the beta pack** (13 meshes, 18745 triangles; carved copies keep the live part's region and
motion):

| Part | Replaces | Triangles | Collides |
|---|---|---|---|
| `W7_CD_CliffPath__cliff_rock` | new | 1008 | yes |
| `W7_CD_CliffPath__dirt_path` | new | 298 | no |
| `W7_CD_PlayDen__cliff_rock` | new | 714 | yes |
| `W7_CD_PlayDen__dirt_path` | new | 57 | no |
| `W7_CD_Crystals__glow_aqua` | `W7_Crystals__glow_aqua` | 180 | no |
| `W7_CD_Crystals__glow_pink` | `W7_Crystals__glow_pink` | 244 | no |
| `W7_CD_Ground__grass` | `W7_Ground__grass` | 5575 | yes |
| `W7_CD_Ground__ground` | `W7_Ground__ground` | 5413 | yes |
| `W7_CD_Landmarks__cliff_rock` | `W7_Landmarks__cliff_rock` | 1071 | yes |
| `W7_CD_Landmarks__marble` | `W7_Landmarks__marble` | 140 | yes |
| `W7_CD_Landmarks__palette` | `W7_Landmarks__palette` | 194 | no |
| `W7_CD_Rocks__cliff_rock` | `W7_Rocks__cliff_rock` | 3557 | yes |
| `W7_CD_Rocks__grass` | `W7_Rocks__grass` | 294 | yes |

**Collision:** `W7C_CD_Ground_12`, `W7C_CD_Ground_18`, `W7C_CD_Ground_19`, `W7C_CD_Ground_27`, `W7C_CD_Ground_28`, `W7C_CD_Ground_36`, `W7C_CD_CliffPath`. Each `W7C_CD_Ground_NN` replaces the live `W7C_Ground_NN`; `W7C_CD_CliffPath` is the path's
smooth ramp (6 wide, 7 at the turn, 1.5 thick) under the drawn steps (which never collide).

**`CliffDenData` (schema 1 = `DenLayout.fromData`'s contract, PLAY-DEN-BUILD-PLAN section 10; pack stamp `version` 256a9b33a9a86fb0):**
- `swap` (20 pairs) and `parts` (region, collide, center, size, motion) for every shown part.
- `den` (points {x, y, z}; a spot is {at, facing}, facing a point to look toward): `floorY` 4.2, `roofY`
  12.33 (the lowest roof over a bay), `room` {min, max} [-22.0, 4.2, -119.0]..[6.0, 16.0, -100.5], `mouth`
  {x1 -14.5, x2 0.5, z -100.5, top 9.85} with `blocker` (center
  [-7.0, 7.2, -100.5], size [15.6, 6.0, 1.0]: the world's CaveBlocker; `DenHost.blockerFits` takes it);
  `bays` (by order dash, niche, deck, niche, niche): Bay1 DashGate at (-18.0, -110.0) looking at (-7.0, -106.0), roof 13.45; Bay2 Niche at (-12.0, -116.0) looking at (-12.0, -100.0), roof 13.5; Bay3 DeckTable at (-7.0, -117.0) looking at (-7.0, -100.0), roof 12.92; Bay4 Niche at (-2.0, -116.0) looking at (-2.0, -100.0), roof 13.22; Bay5 Niche at (4.0, -110.0) looking at (-7.0, -106.0), roof 12.33; `sign` at [-7.0, 8.7, -100.07] (under `W7_Landmarks__trim`);
  `board` at [3.0, 4.14, -96.0]; `pin` [-7.0, 4.2, -96.0]; `doorstep` at [-7.0, 4.6, -87.0], landing [-7.0, 4.63, -84.0],
  facing out; `lanterns`: posts at [-13.8, 4.2, -94.6] and [1.6, 4.51, -97.8], wall lamps at
  [-14.0, 8.0, -118.4] and [0.0, 8.0, -118.4]. Also `outline`, `roof` (1-stud grid), `wallY` 11, `peakY` 16, `backWallZ`.
- `path`: `foot` (-21.5, 4.6, -90.5), `turn` (-76, 23, -52), `arrival` (-71.5, 29, -60.6), the centre line as points
  `{x, y, z, width}` every 2 studs with true heights (pets later), and the walk surface as plan polygons with heights
  (for IslandBounds and catch-up).
- `terrace`: the regraded top (`maxGroundY` under the floor, 28) and the new balustrade gap s 26..34.
- `evacuate`: about (-27, y, -84) (Fable: the old spot is now the den's doorstep). `caveBlocker`: off on the beta (the
  den has walls); the blocker box comes from the den's back wall instead.

## Order

0. Fable's A0 (code only, the small pocket) can run now: nothing here blocks it.
1. **Grey blockout** of all three (sculpt pass with flat grey, collision, data) -> Studio walk, probes, phone camera.
   Fable's own order.
2. Art pass on the same geometry (home's cliff rock and dirt, the lip, glow-caps), Fable renders, Studio captures.

## Cost (island session)

- Blockout: sculpt pass + collision + data + gate about 1.5 to 2 days of work, one Studio pass about 3 hours (uploads,
  native rebuild of the beta pack, probes, a walk, captures).
- Art pass: about 1 day plus Fable's render rounds and one Studio pass.

## Risks

- **Cutting non-manifold island sheets.** The rock and ground are open shells, so booleans are unreliable: the cut is
  "delete inside, add overlapping new pieces". Seams and z-fighting at the overlap are the main visual risk; Fable
  reviews the blockout from the Hub and up close.
- **Precise collision of the big copies** (Rocks__cliff_rock and grass, Landmarks__cliff_rock) decomposes differently
  on the beta: probes over the whole island with the swap on, as for the Eggs split.
- **The swap at runtime** (the switch flips while players stand on the path or in the den): the code side moves them
  (the tier's evacuation) before the swap.
- **Data consumers:** IslandBounds, pets and the walk map must read the beta patch while the switch is on, or pets will
  path into the new rock. Code side.
- **One tree** (`Vegetation_Trees__foliage`, 39 triangles in the corridor): keep the path clear of it rather than swap
  the island's whole foliage mesh (3,240 triangles) `[check]` at blockout.
- **The perimeter ring:** the den stays inside it (Fable); the turn is 6+ from boxes 112 to 114. No ring rebuild.
- Memory on the beta: about 17k more triangles held (the hidden originals), none drawn twice.

## Architect review (2026-11-24): overlay right, with these changes (applied above or adopted)

- **Swap only at server start, on the beta place, never at runtime.** `LoungeWorldV7Art.meshes` replaces the parts in the
  template (`ServerStorage.WorldAssets.WorldV7`) before it clones, then sets `MeshParts`. The originals never reach
  clients; one `CliffDen` attribute set at start tells every consumer. The tier switch only opens or closes the foot
  and the notch. (A runtime swap breaks WorldMotion's bound list, EggCornerWorld's floor include list, AeroWorld's
  paint records, and anyone standing on the rock.)
- **Names:** `W7_CD_*` for carved copies and new art parts (Aero's `kind` reads only `W7_`), `W7C_CD_*` for invisible
  collision (the `W7C_` floor filters). New names carry their `parts` entries (region, motion: the crystals pulse).
- **Data contract adds:** a version stamp (hash of the live WorldV7Data and walk json, checked by a spec); the walk-grid
  patch applied inside `HollowWorldLayout`'s lookups (it freezes `Data.ground` at require); a beta `IslandGround` and new
  `Tier.BoundsRegions`; checks of the generated dressing, find spots, Dash course and AeroKit trees against the cut
  volumes with a hide list; `W7_Trunks__bark` (collides) and Aero `Tree_04_round` at (-70.4, 13, -43.9), about 8 from
  the turn, to check at blockout.
- **Native beta pack with its own proof,** not a runtime precise bake (seconds at each server start, varies by Roblox
  version, no proof). The Eggs split promoter is the route; the pack is designed as the future live split if the den
  goes live.
- **Order:** the blockout uses the final names and the server-start swap, so the art pass changes meshes only. Cost
  +0.5 day (walk patch, beta safe ground, dressing and find-spot checks, data specs). Gate probe added: spawn on the
  beta with Aero on and off, capture the cut seams with Aero's paint.

## Amendment (Play Den architect review, 2026-11-24)

- The world owns the den's closer: `LoungeWorldV7Art.collision` builds the colliding `CaveBlocker` on the NEW mouth line
  from `CliffDenData.den.mouth.blocker` when the den is in (closed by default); the code's DenHost only opens it.
- `CliffDenData.schema` (the module's shape, checked by the code) is separate from the live-world stamp (`live`) and the
  pack stamp (`version`).
- Anchors for the code: five named bays (Dash gate, Deck table, three niches) with the roof over each, the doorstep, the
  mouth pin, the notice board spot; the den floor answers ground rays; safe cells for the den floor, the mouth and the
  apron to the home Floor's edge (z -89).

## Blockout as built (2026-11-24, branch `claude/cliff-den-scope`)

Offline, not uploaded. Live untouched (`world_native_collision.py --check` PASS; the live chunk and collision builders
reproduce the committed outputs; `launch.project.json` never mounts `WorldBeta`).

Rebuild (background Blender on `world1-mockup-v7-import.blend`, never saved): `build_world_v7_chunks.py -- --beta
--beta-base` (baseline walk map = the committed live one), `build_world_v7_chunks.py -- --beta` (the sculpt:
`world-v7-beta.fbx`, `-manifest.json`, `-walk.json`, `-anchors.json`), `build_world_v7_collision.py -- --beta`
(`world-v7-beta-collision.fbx/.json`; asserts the den floor rays), then `python scripts/cliff_den_data.py`
(`src/shared/CliffDenData.lua`), `python scripts/cliff_den_checks.py`, `scripts/render_cliff_den.py`.

**Parts in the beta pack** (13 meshes, 18745 triangles; carved copies keep the live part's region and
motion):

| Part | Replaces | Triangles | Collides |
|---|---|---|---|
| `W7_CD_CliffPath__cliff_rock` | new | 1008 | yes |
| `W7_CD_CliffPath__dirt_path` | new | 298 | no |
| `W7_CD_PlayDen__cliff_rock` | new | 714 | yes |
| `W7_CD_PlayDen__dirt_path` | new | 57 | no |
| `W7_CD_Crystals__glow_aqua` | `W7_Crystals__glow_aqua` | 180 | no |
| `W7_CD_Crystals__glow_pink` | `W7_Crystals__glow_pink` | 244 | no |
| `W7_CD_Ground__grass` | `W7_Ground__grass` | 5575 | yes |
| `W7_CD_Ground__ground` | `W7_Ground__ground` | 5413 | yes |
| `W7_CD_Landmarks__cliff_rock` | `W7_Landmarks__cliff_rock` | 1071 | yes |
| `W7_CD_Landmarks__marble` | `W7_Landmarks__marble` | 140 | yes |
| `W7_CD_Landmarks__palette` | `W7_Landmarks__palette` | 194 | no |
| `W7_CD_Rocks__cliff_rock` | `W7_Rocks__cliff_rock` | 3557 | yes |
| `W7_CD_Rocks__grass` | `W7_Rocks__grass` | 294 | yes |

**Collision:** `W7C_CD_Ground_12`, `W7C_CD_Ground_18`, `W7C_CD_Ground_19`, `W7C_CD_Ground_27`, `W7C_CD_Ground_28`, `W7C_CD_Ground_36`, `W7C_CD_CliffPath`. Each `W7C_CD_Ground_NN` replaces the live `W7C_Ground_NN`; `W7C_CD_CliffPath` is the path's
smooth ramp (6 wide, 7 at the turn, 1.5 thick) under the drawn steps (which never collide).

**`CliffDenData` (schema 1, pack stamp `version` d984b1ca92e854bf):**
- `swap` (20 pairs) and `parts` (region, collide, center, size, motion) for every shown part.
- `den`: `floorY` 4.2, `outline`, `roof` (1-stud grid), `wallY` 11, `peakY` 16, `mouth` (x -14.5..0.5,
  top 9.85, z -100.5) with `blocker` {'center': [-7.0, 7.2, -100.5], 'size': [15.6, 6.0, 1.0], 'yaw': 0}; `bays`: Bay1 DashGate at (-18.0, -110.0), roof 13.45; Bay2 Niche at (-12.0, -116.0), roof 13.5; Bay3 DeckTable at (-7.0, -117.0), roof 12.92; Bay4 Niche at (-2.0, -116.0), roof 13.22; Bay5 Niche at (4.0, -110.0), roof 12.33;
  `doorstep` [-7.0, 4.2, -98.5], `pin` [-7.0, 12.0, -99.5], `notice` [3.0, 4.14, -96.0]; `sign` under the lintel; `lanterns`;
  `region`; `backWallZ`.
- `path`: `foot` [-20.046, 4.599999904632568, -88.387], `turn` [-76.56, 22.96, -48.51], `arrival` [-71.52, 29.0, -60.627]; `centreLine`
  every 2 studs (x, y, z, width, steps); `control`.
- `terrace` (`maxGroundY` 27, the gap s 26..34), `evacuate` [-27.0, 10.845, -84.0].
- `safe`: one-stud safe cells (rows of z, x0, x1; IslandGround's rule, 1 off the den walls): den floor, mouth, apron to z -89.
- `ground` (4-stud bare ground, pairs of i and h, 1-based as `WorldV7Data.ground.h`), `walk.grid` (2-stud) and
  `walk.surface` (1-stud) patches against the live walk map. The surface map starts at z -112, so it does not cover the
  den's back 7 studs.
- `live`: sha256 of the live `WorldV7Data.lua` and walk json (`cliff_den_data_test.py` fails on a live re-export).

**The path (re-laid after code review):** foot on the lawn, shelves along the ground's contours at about 16 degrees,
the outbound leg at t 31 to the turn and the return leg at t 25 (a full width apart: no overhang), the return leg's
steps at about 26 degrees outside the terrace footprint, arrival at (30, 22) on the garden edge through the notch.
Fin 10 x 2.4, top 28, at s 41, t 38 (beyond the lip); notch rocks top 32; lip stones 2.0 long, 1.2 to 1.8 high, gaps 1.2.

**Checks:** den floor rays (562, one stud apart, from 3 over the floor: room, mouth, apron) all hit the beta tiles at the floor; the beta's top surface over the mouth and the apron is the floor or the lawn (`cliff_den_data.py` asserts it); `CliffDen.spec` runs the real data through `DenLayout.fromData`, `DenHost.blockerFits` and the greybox (bays and safe cells inside the outline, the doorstep out of everything the close clears);
placement checks: 406 items, 9 `WorldDressing` conflicts (hide list `cliff-den/placement-checks.json`); finds, Dash
course and Aero kit clear; no island tree in the corridor or the den. `CliffDen.spec` (swap gate, all or nothing, data,
anchors, blocker, bays, safe cells) and the offline runner pass.

**Reviews:** Fable blockout R1 accepted every deviation (fixes applied: one floor at the threshold, the floor fan closed,
orphan shards removed). Code review GO WITH CHANGES, applied: the closer at the new mouth (amendment), no twist at the
hairpin, no overhanging legs, drawn steps never collide (within half a step of the ramp), pack stamp = hash of the beta
outputs, the swap gated by the tier's ceiling, a triangulation-proof tile fingerprint (vertices + area), no duplicate
outline points, `--beta` never writes the live palette.

**Play Den schema check (2026-11-24, after the rebase on feat's step A):** `den` reshaped to `DenLayout.fromData`
(was: `mouth.x0/x1`, direction `facing`s, a bare `doorstep`, `notice`, plain lantern points, `region`, no `roofY`). Two
blockout bugs found by it and fixed: the mouth's soffit reached the jambs' reach (z -95 west) under open sky, so the
lawn's top surface in front of the mouth read 9.8 (now to z -99.8, under the trim); the mouth's cut left a 2 x 2 hole east
of the east jamb and one at (-9, -94) past the floor's edge (a rock shoulder and a floor skirt under the lawn).
Note for the code side: `DenLayout.fromData`'s room floor box (room inset 1) reaches the rounded back corners: its corner
safe cells sit .05 inside the wall's arc (radius 5). `CliffDenData.safe` keeps 1 off the walls.

**The cave's bars (Studio R12: open, the den read as a cage):** on the beta the gold bars and their teal plate
(`Landmarks__gold`, `Landmarks__teal`) leave the palette for their own part, `W7_CD_CaveBars__palette` (244 triangles,
never collides, never carved: they fit the new mouth under the trim). The world hides them (Transparency 1) while
workspace `Den_open` is true and shows them again when it clears (`CliffDenSwap.bars`, from `LoungeWorldV7Art.meshes`).
Two layers in one pack, picked by `FeatureFlags.CliffDen`: true swaps the sculpt (`CliffDenData.swap`, 21 pairs,
DenLayout's room); false swaps only `CliffDenData.pocket` (the palette for `W7_CD_Pocket__palette`, the live palette
less the bars, 264 + 244 = 508 triangles, and the bars: DenLayout's pocket). No pack: the live island, bars and all.

**Left:** Studio (ask first): upload `world-v7-beta.fbx` and `world-v7-beta-collision.fbx`, readback, build the native
`WorldBeta` pack (WorldBeta.WorldV7 with every `show` part, precise collision, `Version` attribute = `CliffDenData.version`),
mount it in `default.project.json`, probes (rays, blockcasts, walk the path and the den, the phone camera at the back
wall), captures with Aero on and off. Code side: IslandBounds, pets and walk-map consumers read `ground` / `walk` /
`safe` while `workspace.CliffDen` is true; the tier switch closes the path's foot and the notch while the terrace is
closed; the zigzag and its pet blocks go; the dressing hide list. Studio sessions of the live place with
`default.project` count as allowed (the tier's rule): take live-island evidence without the pack mounted. Art pass: the
bank is a smooth skirt, the lip reads as battlements, the mouth is square (Fable).
