# Cliff path / Play Den blockout: Studio probe R1 (2026-11-24, Studio 53800d7d, Edit only)

Place 96451847774961 in Edit; not saved, nothing published, Rojo not used, StreamingEnabled false throughout.

## Upload and readback

- `world-v7-beta.fbx` -> Model **97626448020165**; `world-v7-beta-collision.fbx` -> Model **118642606557048** (both
  Approved). Readback (`InsertService:LoadAsset`, destroyed, never parented): all 22 meshes, ids in
  `upload-readback.json` (pack stamp `05ed5063532d23bd`). Raw sizes are the manifest sizes x 7.847 (visual) and x 32.01
  (collision), same axis order.
- The native pack was built in memory (unparented): each part a clone of its live template (the part it replaces;
  new parts from `W7_Rocks__cliff_rock`, `W7_Ground__dirt_path`, `W7_Landmarks__palette`, `W7C_Ground_12`),
  `ApplyMesh(CreateMeshPartAsync(id, {CollisionFidelity = Precise if colliding else Box}))`, Size = manifest, CFrame =
  centre turned pi about Y. `ApplyMesh` clears `TextureID`: restored from the template. Material, colour,
  transparency, DoubleSided, CastShadow, RenderFidelity and the SurfaceAppearance then match the template on all 22.
- **Not exported, not mounted**: the collision below fails.

## Collision probes (the live colliders less the 15 hidden, plus the pack's colliders: 102 parts, in a temporary
`workspace.ZZCliffDenProbe`, destroyed after)

| Probe | Result |
|---|---|
| Safe cells (599), ray down from floor + 3 | **96 off the floor**: 32 hit `W7C_CD_Ground_27` 0.7 to 2.7 high (apron, z -96), 1 `W7_CD_Landmarks__cliff_rock`; **63 hit nothing** (holes). The rest 4.12 to 4.24. |
| Apron top surface (ray from y 60) | **94 cells** hit `W7C_CD_Ground_27` at 10 to 12.8: a sloping hull over the apron. |
| Headroom in the room (ray up from floor + .5) | **min 0.64** (at (3, -103)): 20 cells under `W7_CD_Landmarks__cliff_rock`, 8 under `W7_CD_Rocks__cliff_rock`, 1 `W7_CD_PlayDen__cliff_rock` below floor + 7. |
| Bay roofs | Bays 1 to 4 within .2 of the data; **Bay 5 7.31** (data 12.33). |
| Path (49 centre-line samples) | Ground within .7 except the arrival (**-4.98**); **6 obstructions**: samples 9 to 11 under `W7C_CD_Ground_27` (13 to 14 over a 9 path), 45 `W7C_CD_CliffPath` (26 over 25.1), 47 and 48 `W7_CD_CliffPath__cliff_rock` (32: the notch rocks' hull spans the notch). |
| Den walls (216 sideways rays from the room's middle) | **0 holes.** |
| Terrace footprint (collidable ground) | max 29.28 at s 36 (the notch rock), else under the floor. |

## Why

Roblox bakes a colliding mesh into a limited set of convex hulls, and a single-sided surface gets solid volume behind
it. On the live island that volume is rock; the beta carves a room and a shelf right behind those surfaces. So the
island-wide carved rock meshes keep hulls inside the room, and ground tiles 27/28/36, which now hold both the cliff top
and the den's floor (two sheets 22 studs apart), bake hulls bridging them (the apron slope and the holes). The offline
ray check (Blender, exact triangles) cannot see this.

## Proposed fix (needs a plan review before building)

1. The den's floor, the mouth's floor and the apron become their own flat collision part(s), never merged into the
   32-stud ground tiles; the changed tiles keep only their own sheet.
2. Inside a box around the den, the path and the terrace's edge, the carved colliding visual meshes (`Rocks`,
   `Landmarks` cliff rock and grass, `PlayDen` and `CliffPath` rock) split off a non-colliding visual piece; that
   region's collision comes from small invisible cell meshes (about 6 studs) cut from the same surfaces, so no hull is
   larger than a cell. The rest of each mesh keeps colliding as today.
3. The same Studio probes above become the gate before the pack is exported (every row green).
