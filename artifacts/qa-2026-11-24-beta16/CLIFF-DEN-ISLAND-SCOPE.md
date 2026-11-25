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
