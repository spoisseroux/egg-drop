# Eggs station split: build plan (Opus, island session, 2026-11-24)

Architect GO on the split (EGG-CORNER-BUILD-PLAN 6.2) with conditions: one re-export (WorldV7Data regenerated once),
look and collision unchanged on live, live captures and a collision probe before any live publish carries it.
Branch `claude/eggs-station-split` from feat efc846c. No publish.

## Done offline (this branch)

- `build_world_v7_chunks.classify`: `Stations_EggNest*` -> region `EggsStation`, groups `EggsStation__<mat>` (collide as
  today); the halo (`Anim__Station_EggNest_Glow_Halo`) is named `EggsStation__glow_warm` but keeps region `NestHalo`
  (architect: motion is picked by region, so live keeps its pulse).
- Fable's placement rulings R2 asked to split `Station_BenchWest`, both `Statue_Egg` and `Pad_Future_B` too. They are
  already gone from the game: the 2026-11-13 declutter (`world-v7-declutter.json`) deleted `Plaza_Ornament_09` / `_10`
  (the egg statues at (-42, 9.5) and (-18, 9.5)), `Pad_Future_B`, and both benches' seat slats and supports (all a bench
  is); the export makes no part for any of them and the live walk map shows bare ground there. Nothing to split.
- Walk map: `EggsStation` parts are ray-cast like Stations and report as `W7_Stations`; the surface map skips the halo as it
  skipped `NestHalo`. Result: `world-v7-walk.json` byte-identical.
- Chunk build: 103 parts (was 99), 66,844 triangles (unchanged). Changed: `W7_Stations__marble` 1414 -> 1236,
  `__marble_smooth` 978 -> 924, `__palette` 2068 -> 1808, `__trim` 200 -> 168. Added: `W7_EggsStation__marble` 178,
  `__marble_smooth` 54, `__trim` 32 (all collide), `__palette` 260, `__foliage` 36, `__glow_warm` 24 (pulse). Dropped:
  `W7_NestHalo__glow_warm`, `W7_Stations__foliage`. No other mesh hash moved. `world-v7-declutter.fbx` holds the 10.

## Architect review (2026-11-24): sound, with changes (applied or planned below)

- Halo keeps region `NestHalo` (applied). `EggsStation__foliage` and `__glow_warm` are renames (same geometry hash as
  `Stations__foliage` / `NestHalo__glow_warm`): rename them in the pack and keep their mesh ids and raw sizes; only the
  4 changed and 4 truly new parts take uploaded ids. New parts: clone a sibling, then `ApplyMesh`.
- Promoter asserts: MeshParts and descendants +4, SurfaceAppearances unchanged; every MeshPart property matches the staged
  XML by name; SA children exact; no attributes or tags; parent `WorldV7`; a real Precise collision buffer on the 3 new
  colliding parts; the 2 renamed keep their bytes; XML compared by part name (referents shift), Lua by meaning
  (incl. `motion`); changed input hashes exactly manifest, pending, studio-import, both FBXs and dressing-import.
- Dressing re-sign: proven a no-op (feat's inputs regenerate the canonical XML and Lua identically, line endings apart).
- Probes: sideways rays at several heights (risers, stele, cup), a character blockcast, a Play walk up the steps;
  0.05 stud tolerance on the 4 rebuilt Stations meshes, exact elsewhere; captures at a frozen ClockTime incl. a close-up
  of the station's seam with the plaza; the halo pulses in Play. Live also gains 4 draw calls.

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

## Studio pass (2026-11-24, Studio 53800d7d, Edit and Play, place not saved, Rojo not used)

- Upload: `world-v7-declutter.fbx` -> Model 118362972104444 (operation 1cfa104d-...), readback in Edit
  (`eggs-split/upload-readback.json`). The 2 renames keep their live ids (this upload's copies recorded, unused).
- Staged with `--stage-native-rebuild`; staged XML/Lua differ from canonical only in the 10 parts (Lua by meaning:
  halo keeps region NestHalo and its pulse; meshParts 99 -> 103).
- Native rebuild on an unparented clone of `ServerStorage.WorldAssets` (the place's own tree untouched): 4 ApplyMesh,
  4 new parts cloned from their sibling + ApplyMesh, 2 renamed; every property checked against the staged XML.
  Export 326,424 bytes, sha 49973794..., out through the Studio log (`WorldAssetsNative-eggs-split.rbxm`).
- Promoter (`eggs-split/promote_native_eggs_split.py`, evidence `native-promotion.json`): counts +4/+4/0, 165 collision
  buffers byte-identical, 197 untouched instances identical apart from engine noise (float32 placement rounding, the
  engine-only SurfaceAppearance TexturePackContent this Studio adds, cached mass fields on the one unchanged-buffer
  part); proof inputs moving exactly the six expected. `world_native_collision.py --check` PASS.
- Collision (round trip deserialized from the export): 21,452 rays down, 1,344 sideways, 841 character blockcasts.
  Station: no holes; the steps now match the Blender surface exactly (4.350 vs 4.35), where the old shared bake floated
  0.08-0.10 above and bulged 0.5 stud past the top riser. Elsewhere one 5x5 stud patch near (-17, -13): the re-baked
  shared Stations marble reads up to 0.17 below the surface (91 of ~2,700 samples at 0.1 grid; the old bake was right).
  Over the 0.05 tolerance; precise decomposition of a different mesh, not fixable by settings. Flagged for the walk test.
- Play (pack and data swapped in, then restored byte-exact): a character climbs the station from W, S and E to its top
  (4.88) on both packs and stops at the same spots (the nest); the halo pulses.
- Captures at ClockTime 14, old vs new (`eggs-split/captures/`): overview, station, seam close-up. Differences are edge
  shimmer across the whole frame (untouched stairs and roots too) and the animated lantern glow.
