# World finish art: den, cliff path, terrace (Opus, 2026-11-25)

Fable's brief: `WORLD-FINISH-LOOK.md` (this folder), art lanes C, D, E. Branch `feat/world-finish-art` (from
`feat/egg-drop-arcade-polish` deb3b183). The code lanes (pets go up, the Top Lawn) are another agent's, on
`feat/world-finish-code`. Beta only; live (`launch.project.json`) unchanged.

## How the art gets in (all slices)

| Step | What |
|---|---|
| Model and bake | `scripts/build_world_finish_art.py <slice>` in background Blender on the beta island preview blend (`scripts/world_finish_scene.py` says how to make it). Everything from code: loops and rings round the collision room, Voronoi scoops, value noise, voxel-remeshed rock masses; colour and normal maps baked in Cycles (position, AO, high-to-low normals) and painted in numpy. No generated art, no outside assets. |
| Outputs | `assets/world/world-finish/world-finish-<slice>.fbx` (one Open Cloud Model per slice), `world-finish-<slice>.json` (manifest: parts, looks, placements, what they hide), `textures/*.png`. Review renders in `art/`. |
| Upload | Open Cloud `POST /assets/v1/assets` (Model for the FBX, images for the maps), polled to done. |
| Readback (Studio) | `world_finish_readback.luau` (this folder): `InsertService:LoadAsset` each model in Edit, prints `[{name, meshId, meshSize}]`, destroys the model unparented. Nothing saved. |
| Pack | `scripts/build_world_finish_pack.py --confirm <readback.json>` writes `assets/world/WorldFinish.rbxmx` (Folder of MeshPart templates, SurfaceAppearance authored in the file: runtime code cannot parent one) and `src/shared/WorldFinishData.lua` (placements). `--check` binds the rbxmx to the manifests and readback. Mounted at `ServerStorage.WorldFinish` by `default.project.json` only. |
| Runtime | `src/server/WorldFinishMount.lua`. `world(world)`: called by `LoungeWorldV7Art.meshes` right after `CliffDenSwap.apply` when the sculpt is in ("den" mode); all or nothing per slice: if every template is in the pack it destroys the pack parts the slice replaces (copying their attributes to the re-cut copies), clones the fixed parts and kit instances into the world clone (before the attribute loop), and builds the slice's extra collision boxes with `CliffDenSwap.boxes`. `dressDen(model)` / `dressTier(model)`: called by DenHost / TierHost right after `GreyboxRows.build`; hide greybox visuals the art replaces (Transparency 1, collision kept) and add meshes to that model (so they come and go with the switch). No pack, no art: today's beta exactly. Live never has the pack (and never the sculpt). |

All art parts: Anchored, CanCollide false, CanQuery false, CanTouch false, names `W7F_...` (CameraClamp's "W7" world
test), no new lights except the four lanterns' existing PointLights. Collision stays the server boxes
(`CliffDenData.collision`) plus the slice's own boxes (buttresses; later the path's lip stones).

## Slice C, the den (plan)

| Piece | How | Budget |
|---|---|---|
| `W7F_Den__shell` | Loop of columns round the collision room's plan (0.9 apart, the mouth's span included), rows from 0.6 under the floor to 12.2, a 9-ring dome to 16.2, the mouth cut out of the front wall and extruded 4.1 studs as the collar (ends behind the timber frame at z -97.4). One welded surface, normals in. Offset 0.35 outside the collision face, Voronoi scoops (4.4-stud cells) push 0 to 0.5 more; clamped to -0.28 / +0.98 at body height. Ledge 0.3 proud at y 9.4 along the back (over the back lanterns at 8.0, which hang 0.8 under it). Alcoves 0.65 deep behind the Dash gate (west wall) and the Bay5 crate (east wall). | 3,822 tris; one 1024 colour + 1024 normal |
| Shell bake | Colour from 3D noise at the baked texel positions: base #7A6A5C, bedding lines #6A5B4E every 1.2 to 2, hairline cracks (sparse, under 0.15 wide), damp band #54483E 1.5 over the floor, soot over the four lanterns, AO at 60%. Normal from a 3x denser high mesh (scoops + mid-frequency rock). Roughness flat 0.9 (SurfaceAppearance with the matte roughness/metalness maps). | walls ~22 px/stud |
| `W7F_Den__floor` | Grid over the room grown 1.2 (under the skirt) and the mouth's floor; dished 0.1; an earth threshold at 4.46 over the live marble sill (it collides at 4.4). 512 packed-earth tile, 6 studs a repeat. | 472 tris |
| `W7F_DenMouth__cliff_rock` | Two buttresses and the brow: 12 rock masses, voxel-remeshed, Voronoi-faceted, decimated; kept out of the opening, the timber frame, the lawn and the room. Island cliff rock map and density, Aero-tinted like the island. Two collision boxes (`mouthBoxes`). | 2,357 tris |
| `W7F_DenApron__dirt_path` | Worn earth at 4.97 over the greybox apron slabs (their collision stays, hidden), rolling into the lawn over a broken edge 0.4 to 1.6; six stones on its lawn side. | ~500 tris |
| Lantern | Iron cage (#3A3028) + four panes (Neon #C9772E, half hidden by a crossbar band); replaces each `W7D_Lantern<i>` box in place (its PointLight stays). | 142 tris |
| Crystal | One six-sided shard with a clean slanted break, Neon #C98A3C at transparency .25, no light; clusters at the mouth's feet and in each alcove. | 28 tris |
| Flat stone | One worn stone; the eight paw stones (#8A8378, sunk 0.1), stones pressed into the floor by the mouth and bays, apron edge stones, crystal rubble. | 40 tris |
| Re-cuts | `W7F_Region__cliff_rock` (the pack's visual region rock less 8 faces that poke into the new shell) and `W7F_Crystals__glow_pink` (the grotto crystals less the clusters at the mouth's feet, which paint lime). Both visual only. | |

## Results (2026-11-25)

| Slice | Commit | Built | Checks | Reviews |
|---|---|---|---|---|
| C den | f373abd0, a0818f2a | Shell as two welded halves (Fable R1 9, the brief's fallback): 3,822 tris, 1024 colour + normal each, walls 27 to 28 px/stud (outside rock ~15). Floor 520 tris, 512 tile. Mouth surround (6 rounded masses) 2,331. Apron 344. Lantern 142 (cage + panes), crystal 28, flat stone 40. Re-cuts: region rock, grotto crystals, lawn and ground over the mouth's floor; tile 2016 overlaid (stays invisible, colliding). Buttress and brow boxes. | `check_world_finish_den.py`: 0 rays escape except through the opening; walls -0.15 / +0.98 at body height; floor -0.09 / +0.09 off the threshold. 10 of 13,500 interior rays still meet island skin over head height (11.2 to 14.7). | Architect: 6 blockers applied (W7_F_ names for Aero, re-cuts under the pack part's own name, version tie to CliffDenData, targets resolved first, the dress gated on the World attribute, pcall'd hooks). Fable R1: GO WITH FIXES, 12 applied (round masses, brow over the lintel, local lantern shelves, deeper scoops, short hairlines, AO floor, two halves, warmer #7E6B58 / #6B5240, rounded pilaster, apron edge and stones, crystals at transparency .4). Code review: no blockers, 6 fixes applied. |
| D path | 46f0d7e3 | New art 4,820 tris (tread 112, grass 110, cut 2,234, foot 164, steps 400, fin and notch boulders 1,800); kit: 5 lip stones (80 each), stake (10). 11 lip stones (colliding, replacing the lip boxes), 8 stakes, 7 rope spans, 9 boulders, 8 tufts. Steps within 0.54 of the ramp. Re-cuts carry the den's (requires den). | `check_world_finish_path.py` PASS: nothing over the tread at body height. | Fable D1: GO WITH FIXES, applied 1 (re-cuts), 3 (facets), 4 (nosing, fronts, wear), 5 (fin as a 3-lobed cluster with its own boxes), 6, 7 (outer skirt), 8, 9, 10 (in part). Not done: 2 (darker lower face: island material, needs its own part). |
| E terrace | ca332951 + this | Cap 1,248, face 728, tongues 46, earth 14, outcrops 1,293, slab 30 (3,359); log 36, trunk 48; an Aero kit crown in game. TierHost dress. Requires path. | Park circle (0, 5) r 13 clear by construction. | Fable E1: GO WITH FIXES; applied 1 (varied rim), 5 (lip groups), 6 (distinct outcrops), 8 (trunk flare). Code review: no blockers; trunk box and crown all-or-nothing applied. |

Deviations to tell Fable: the ledge is at y 9.4, not 7.5 (the back lanterns' centres are at 8.0 in `CliffDenData`; 7.5 would
put the ledge through them). The front wall wraps the live marble posts as a pilaster 1.0 into the room (x -15.6..1.6):
the posts stand 0.8 inside the collision room and collide, so the drawn rock follows them, not the box.
