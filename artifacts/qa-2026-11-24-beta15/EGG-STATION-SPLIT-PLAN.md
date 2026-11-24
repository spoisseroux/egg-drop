# Eggs station split: build plan (Opus, island session, 2026-11-24)

Architect GO on the split (EGG-CORNER-BUILD-PLAN 6.2) with conditions: one re-export (WorldV7Data regenerated once),
look and collision unchanged on live, live captures and a collision probe before any live publish carries it.
Branch `claude/eggs-station-split` from feat efc846c. No publish.

## Done offline (this branch)

- `build_world_v7_chunks.classify`: `Stations_EggNest*` -> region `EggsStation`, groups `EggsStation__<mat>` (collide as
  today); the halo (`Anim__Station_EggNest_Glow_Halo`) joins as `EggsStation__glow_warm` (anim `pulse`).
- Walk map: `EggsStation` parts are ray-cast like Stations and report as `W7_Stations`; the surface map skips the halo as it
  skipped `NestHalo`. Result: `world-v7-walk.json` byte-identical.
- Chunk build: 103 parts (was 99), 66,844 triangles (unchanged). Changed: `W7_Stations__marble` 1414 -> 1236,
  `__marble_smooth` 978 -> 924, `__palette` 2068 -> 1808, `__trim` 200 -> 168. Added: `W7_EggsStation__marble` 178,
  `__marble_smooth` 54, `__trim` 32 (all collide), `__palette` 260, `__foliage` 36, `__glow_warm` 24 (pulse). Dropped:
  `W7_NestHalo__glow_warm`, `W7_Stations__foliage`. No other mesh hash moved. `world-v7-declutter.fbx` holds the 10.

## Studio steps (ask the coordinator first)

1. Upload `world-v7-declutter.fbx` (Open Cloud Model); `InsertService:LoadAsset` readback in Edit (destroyed, never
   parented) -> `upload-readback.json` (assetId, operationId, checkpoint {fbxSha256, manifestSha256, previousMeshIds of
   the 4 changed}, parts [{name, meshId, meshSize}]), the lamp-3 format.
2. `world-v7-studio-import.json`: the 10 new ids and raw sizes, the 2 dropped removed.
3. `python scripts/build_world_v7_assets.py --stage-native-rebuild artifacts/qa-2026-11-24-beta15/eggs-split/staged
   --confirm-upload upload-readback.json` -> staged XML, Lua, pending only (canonical untouched).
4. Native rebuild in Studio Edit on the mounted canonical `ServerStorage.WorldAssets` (native pack, Rojo from this
   branch): the 4 changed parts `ApplyMesh(AssetService:CreateMeshPartAsync(newId, {CollisionFidelity = its own}))`; the 6
   new parts created the same way, every property copied from the staged XML (CFrame, Size, Material, TextureID / SA,
   CanCollide, CastShadow, attributes, CollisionFidelity), parented where the staged XML puts them; the 2 dropped removed.
   `SerializationService:SerializeInstancesAsync({WorldAssets})`, base64 out in chunks, decoded to
   `artifacts/qa-2026-11-24-beta15/eggs-split/WorldAssetsNative-eggs-split.rbxm`. Place never saved.
5. `promote_native_eggs_split.py` (from the lamp-3 promoter): refuses unless, against the current canonical pack, exactly
   the 4 changed names changed MeshId to the readback ids, exactly the 6 names were added and the 2 removed, every other
   MeshPart's PhysicalConfigData is byte-identical, the staged XML differs from canonical only in those 10 parts, and the
   staged Lua differs only in their part entries. `--write` copies the staged files, replaces the native pack and
   re-signs the proof (inputs re-hashed: this also re-binds `world-dressing-import.json`, stale since 2f60802 changed
   it, after checking the staged outputs carry nothing else from that change). `world_native_collision.py --check` green.
6. Collision probe in Studio Edit (deserialized round trip): rays down on a grid over the station footprint and every
   other station's footprint, old pack vs new: identical hits and heights; the station's steps still hit.
7. Live look: captures of the plaza from three fixed cameras, old pack vs new, should match pixel-close.

## Risks

- The native rebuild is a hand step; the promoter's byte checks are the guard (only the 10 parts may differ).
- `world-dressing-import.json`'s stale binding: re-signing must not hide a real difference; the staged XML/Lua diffs
  are checked to hold only the split's parts.
- Live: every other part's collision buffer is byte-identical by construction (checked); the station and the four
  shared Stations meshes get new buffers from Studio's precise bake (probed).
