# Eggs station split: scope (Opus, island session, 2026-11-24)

For EGG-CORNER-BUILD-PLAN 6.2. Not built; waiting for the coordinator's go.

## What is there today

- The Eggs station is already its own set of Blender objects, one per material: `Stations_EggNest__marble` (174 tris),
  `__marble_smooth` (60), `__trim` (32), `__gold` (116), `__egg` (144), `__foliage` (36), plus
  `Anim__Station_EggNest_Glow_Halo__glow_warm` (24). Centre (-30.3, 5.2, -10.95).
- `build_world_v7_chunks.classify` folds them into the island-wide `W7_Stations__<mat>` parts (marble 1,414 tris,
  marble_smooth 978, trim 200, palette 2,068 where egg and gold land, foliage 36) shared with every other station;
  marble, marble_smooth and trim collide. The halo is its own `W7_NestHalo__glow_warm` already (hideable by name today,
  as is `W7_Stations__foliage`, which is only the Eggs station's).
- Floor: probed in the import .blend: the plaza paving is whole under the dais (49 of 49 rays within r 3.5 hit
  `Architecture_Plaza__*`). No hole to fill.
- Collision: the colliding station meshes get their precise collision from the native checkpoint
  (`assets/world/WorldAssetsNative.rbxm`, promoted deliberately, hash-bound by `world_native_collision.py`). Rojo cannot
  carry collision geometry, so any change to those meshes means a new native checkpoint.
- **Blocker for any re-export:** the native checkpoint is already stale on feat: beta 14's 2f60802 changed
  `world-dressing-import.json` without re-promoting it, and `world_native_collision.py --check` refuses ("no canonical
  outputs may be written"). Whoever re-exports must first re-promote that checkpoint as it is today.

## Option A: split in the island export (the plan's recommendation)

What changes:
1. `classify`: `Stations_EggNest_*` -> region `EggStation`, groups `EggStation__<mat>` (collide as today); the halo moves
   from `NestHalo` into it (keep its `pulse` anim). About 8 lines.
2. Re-run the chunk build, the island export (`build_world_v7_assets.py`: pending upload, Open Cloud FBX upload of the
   changed meshes, readback, `--confirm-upload`), regenerate `WorldV7Data`, `WorldAssets.rbxmx`.
3. Re-promote the native checkpoint: in Studio, import the new meshes with precise collision, save
   `WorldAssetsNative.rbxm`, record the promotion (`retexture_world_native.py`-style manifest entry), `--check` green.
4. Probe the plaza collision (walk the station footprint, pets' walk map unchanged: the dais was walkable before).

Live risk: the look is meant to be identical, but every `W7_Stations__*` mesh id changes and the native checkpoint is
rebuilt, so the next live publish carries new collision for all six stations. A bad bake (Box fidelity slipping in, a
missing proxy) would show on live as stations you walk through or snag on. It is checkable in Studio before any live
publish, and `world_native_collision.py` binds it.
Cost: about half a day with Studio for the bake and checks; one FBX upload; first the stale-checkpoint re-promotion.

## Option B: beta-only kit swap (no island change)

The Aero kit adds copies of the four shared meshes without the station (`Stations__marble`, `__marble_smooth`,
`__trim`, `__palette`; about 4,500 tris, uploaded once), and on the beta the **server** creates them with
`AssetService:CreateMeshPartAsync(..., Precise)` (runtime collision, so no native checkpoint), turns the originals'
`CanCollide`/`CanQuery` off and hides them; `W7_Stations__foliage` and `W7_NestHalo__glow_warm` are simply hidden.
Live is untouched byte for byte (the island export, its manifest and the checkpoint do not move).
Live risk: none. Beta risk: runtime collision bake at server start (a few hundred ms), and the swap logic in the egg
corner's server code. Cost: about the same as A for me (kit pipeline exists), but it must be redone (as A) when the egg
corner goes live, and the beta then differs from live in station collision.

## Recommendation

**A**, after the stale checkpoint is re-promoted, because the egg corner will go live eventually and A is what live
needs; the look on live is unchanged and the new checkpoint can be verified in Studio before any live publish. If the
beta needs the corner sooner than a checkpoint promotion can happen, B is the safe bridge (live untouched).

Questions for the coordinator / Spencer: who re-promotes the stale checkpoint (it touches the live file's world), and
is A acceptable given it changes every station's mesh ids on the next live publish?
