# World flicker (z-fight) fix, 2026-11-14

Nothing committed. Studio: Edit only (one `InsertService:LoadAsset(137445970081645)` read, destroyed after). Play was
not started, collision was not rebuilt, the place was not saved or changed.

## Where the fix lives

The import `.blend` (`assets/art-source/environment/world1-mockup-v7-import.blend`) is never saved: every world fix is
a function in `scripts/build_world_v7_chunks.py` applied to the import chunks before the merge. New: `coplanar_fixes()`
(last step of `qa_fixes`). Faces are picked by their Roblox-space bounds (asserted to match exactly one face), not by index.

Blender used: `C:\Users\skunk\AppData\Local\Programs\Blender Foundation\Blender 5.2 LTS\blender.exe` (background).

## Changed MeshParts (uploaded Model asset 137445970081645, from `assets/world/world-v7-declutter.fbx`)

| MeshPart | Old MeshId | New MeshId | TextureID |
|---|---|---|---|
| `W7_Aqueduct__marble` | 80925985769359 | 134674012771308 | rbxassetid://138678016112158 |
| `W7_Aqueduct__palette` | 137122026931778 | 98639394875591 | rbxassetid://99161618321835 |
| `W7_Architecture__marble` | 126675685987379 | 111525815070510 | rbxassetid://138678016112158 |
| `W7_Architecture__palette` | 124132320944588 | 124151858233608 | rbxassetid://99161618321835 |
| `W7_Architecture__trim` | 119807124727588 | 119298517720818 | rbxassetid://133573568684057 |
| `W7_Water__water_stream` | 131731608849590 | 73086328279317 | rbxassetid://70661948546201 |

TextureIDs are unchanged (read from the rebuilt `WorldAssets.rbxmx`; the uploaded FBX carries no textures).
`W7_Aqueduct__marble_smooth` did not need to change (the water moved instead), so six meshes, not seven.
Manifest diff: only these six entries differ (hash; `W7_Architecture__trim` top 13.90 -> 13.92,
`W7_Aqueduct__marble` 0.02 deeper). `WorldAssets.rbxmx`: only these six MeshParts differ (170 parts, same names).

## Fix per kind

| Where (Roblox) | Problem | Fix |
|---|---|---|
| Colonnade entablature, y 13.0..14.48, 3 spans | trim / gold / marble caps of neighbouring spans coplanar at the 2 joints | middle span (18 faces) lifted 0.02 |
| Same | 3 gold caps faced into the strip, so they were same-facing with the trim top / marble underside | turned outward (hidden contact faces now oppose) |
| High spring y 52.0 | channel water underside in the basin disc underside's plane (7.35 sq) | water underside raised 0.02 into the water |
| High spring y 52.2 | 2 gold diamonds on slab undersides (0.63 each) | gold nudged 0.02 outward (down) |
| High spring y 51.65..51.70 | 3 post faces dipped 0.05 into the wall face below | post face bottoms raised to 51.71 (shrink) |
| Sky-falls channel y 2.1..4.0 | 3 wall posts coplanar with the wall face (0.56 each) | posts 0.02 proud of the wall |
| Sky-falls channel y 2.15 | pier top coplanar with floor strip (1.76, both lifted by the earlier `aqueduct_bed` fix) | pier top lowered to 2.13 (pebble bed is 2.10) |
| Sky-falls channel | 2 pier sides in the wall plane (0.11 each) | pier sides inset 0.02 |

## Scan (`scripts/scan_world_v7_coplanar.py -- "Colonnade|Aqueduct" --detail`)

The scan gained `--fixed`: it applies the chunk script's declutter + `qa_fixes` in memory first, so it reports what the
merged meshes really contain (the raw scan also listed pairs earlier fixes already removed).

| Run | Same-facing pairs | Output |
|---|---|---|
| Before, raw import chunks | 38 | `flicker-scan-before.txt` |
| Before, with declutter + earlier fixes (`--fixed`) | 28 | `flicker-scan-before-fixed.txt` |
| After (`--fixed`) | **0** | `flicker-scan-after.txt` |

## Flow followed

1. `blender -b <import blend> --python scripts/build_world_v7_chunks.py` -> `world-v7.fbx`, `world-v7-declutter.fbx`
   (the six changed meshes), `world-v7-manifest.json`, `world-v7-walk.json`, `world-v7-pending.json`.
2. Uploaded `world-v7-declutter.fbx` (operation be0e51bc-2a9b-4775-9c3a-be8c8a6abeb5, Approved).
3. Read MeshId / MeshSize with `LoadAsset` in Edit, wrote them into `world-v7-studio-import.json` (still one line).
4. Deleted `world-v7-pending.json`, ran `python scripts/build_world_v7_assets.py` -> `WorldAssets.rbxmx`, `WorldV7Data.lua`.

## Left over

1. **Not seen in the engine.** No render, no Play. The coordinator still has to mount the new `WorldAssets`, rebuild
   collision if wanted, and look at the colonnade joints, the high spring and the sky-falls channel.
2. **196 same-facing pairs remain in other structures**, outside the 38-pair scope (wide scan, default pattern,
   `flicker-scan-after-all-structures.txt`). Largest by area: Stairs marble (14 faces, 17.9 sq), Rotunda marble (5, 12.9),
   MarbleArch marble (2, 11.5), Bridge marble (10, 5.6), Balustrades marble (147 faces, 4.5 sq in total), PocketDeck
   kiosk cream / aqua glow (2.05), Landmarks gold / marble (1.8). Not fixed here.
3. 0.02 studs is the offset asked for; at long camera range depth precision can still shimmer on the colonnade joints.
   If it does, raise the lift in `coplanar_fixes` (one constant per fix) and re-upload.
4. `world-v7-walk.json` `grid` and `surface` changed slightly with the re-merge (other keys identical).
5. The lifted span leaves a 0.02 gap over its column capitals and the nudged posts a 0.02 crack at their edges: below
   anything visible at play distance, but they are real.
6. New MeshSizes differ from the old ones (the Open Cloud import rescales each upload by its largest part); they are
   only used as `InitialSize`, authored sizes come from the manifest.
7. Localization, TODO beyond one line, specs: untouched. No spec was run.
