# Round 6 build plan: the cave, the path, the terrace (Opus, 2026-11-25)

Goal: Spencer's beta (25) notes. "the cave entrance is way too smal", "a lot of missing faces or inverted normals ... messy geometry", "the race entrance ... kinda blends in", "everything feels a little too small". Look brief: `DEN-ROUND6-LOOK.md` (Fable). Audit: `audit/AUDIT.md`.

## Pipeline facts that shape the order

- The den, path and terrace art are procedural (`scripts/build_world_finish_art.py`, `world_finish_den.py`, `world_finish_path.py`, `world_finish_terrace.py`). They run in background Blender on the island preview blend, export one FBX per slice, are uploaded through Open Cloud and read back in Studio. `build_world_finish_pack.py` then writes `assets/world/WorldFinish.rbxmx` and `src/server/WorldFinishData.lua`.
- The den's room, its mouth and the path's cut are carved out of the island by `scripts/cliff_den_sculpt.py` (`DEN`, `MOUTH`, `PATH_CTRL`). That is the beta island export: `build_world_v7_chunks.py --beta` and `build_world_v7_collision.py --beta`. The colliding island tiles inside the den region (den grown 2.5, under y 18) were split into visual-only `CDRegion` pieces. `CliffDenData.lua` holds the exact collision boxes and anchors. `WorldBeta.rbxm` was built in Studio Edit from those outputs and is bound by `world_beta_pack.py --check`.
- So a bigger room, mouth or path cut means a new beta island carve, a new `WorldBeta.rbxm` and new `CliffDenData`. Fixing geometry inside the current shapes does not.

## Slices

| Slice | What | Touches the island carve? | Ships in |
|---|---|---|---|
| **A. Clean geometry** | Path steps rebuilt as one welded stair solid per flight (sides, back, sunk .5, consistent winding); the path wall and terrace face welded into closed skirted shells (no cards, slivers or shards; cell size held); tread, grass and foot sheets skirted; the den's flaps (dome over the gate, grass flaps in the collar, brow seam) removed. A new `scripts/check_world_finish_mesh.py` gate: 0 flipped edges on every part; 0 open edges on solids (steps, wall, face, stones, stakes); open edges on sheets and the shell only along their buried skirt. Pack: `RenderFidelity` Precise on the shells and wall. Remove the stale second `ServerStorage.WorldFinish` in the beta place. | No | beta (26) |
| **B. The race gate** | The Garden Dash gate in the den rebuilt to Fable section 4 from parts in code (`PlayDen`/`DenGreybox`): 9 x 9 clear, teal posts with cream bands, a checker banner, a coral pennant, seven bulbs and one PointLight, a "Garden Dash" sign (UICopy, localised), a checker start mat, paw stones re-laid toward it. Same prompt and race logic; only the model. | No | beta (26) |
| **C. The mouth and the bigger den** | `MOUTH` to x -16..2, crown 15.2 (11 clear, 8.5 at the shoulders, rough arch); `DEN` to 36 x 24, wall 10, peak 17 (15 if under 5 of rock remains below the terrace). Re-carve the island (`--beta`), rebuild the collision and `WorldBeta.rbxm` in Studio, regenerate `CliffDenData`. Den slice rebuilt round the new room: rock arch collar with buttresses and brow, timber props, hung sign, two lanterns x 1.4. The PlayDen's timber door frame goes; props x 1.25 and re-spaced; lantern range 18. | **Yes** | beta (27) |
| **D. Wider path** | Path 9 wide (12 at the turn), flights rise 1.0 / tread 1.7, back wall 5 to 8, lip stones and stakes per Fable section 2, the route and slope unchanged. Carved in the same island re-export as C. | **Yes** (with C) | beta (27) |
| **E. Terrace props** | Lookout slab 10 x 7, log bench 8, tree 18, outcrops 7; Top Lawn toy frames x 1.25 (swing bar 7.0), seats and slots pet-sized. | No | beta (27), or (26) if A goes fast |

Order: A and B first, since they need no island re-export and fix the "messy" and "blends in" notes in days, not a week. Then C + D together as one island re-export, with E alongside.

## Edge cases

| Case | Expected |
|---|---|
| A save that stood inside the den or on the path at logout (C, D) | Spawns on the lawn as today (`Tier` evacuation); the new boxes only widen the walkable area |
| Pets on the wider path (D) | `TierPets` lanes follow `PATH_CTRL` samples and the new width; probe "pets climb 4/4" must still pass |
| Live | Untouched: WorldFinish, WorldBeta and CliffDenData are beta-only (`launch.project.json` never mounts them) |
| Phones | Budgets per Fable section 3.8; Precise fidelity costs memory, not triangles; Hub p75 compared with the Studio profiler |
| Race gate when Dash is off | The gate hides as today; the start mat and paw line hide with it |

## Not in this round

The island chunks outside the den region; the garden; the den's interior features (card table, notice board: only rescaled); the Top Lawn circle and fetch radius.

## Tests

- Offline: the spec runner (91), `build_world_finish_pack.py --check`, `world_beta_pack.py --check`, the new mesh check at zeros, `check_world_finish_den.py` / `check_world_finish_path.py`, Rojo build.
- Studio (beta place): readback, Fable's camera list at noon and night, the Top Lawn sweep, pets climb 4/4, a walk through the mouth abreast with a second avatar (clone), the gate's prompt, the console showing only the known lines.
- Fable reviews the captures against section 5.
