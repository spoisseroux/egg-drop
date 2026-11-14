# World seams and second-park clearing — unpublished

Implemented by Sol 6.1 High, 14 November 2026. Coordinator owns asset upload, Studio mounting, collision rebuilding and Play verification. **No publish, no Play, no commits, no source-blend saves, no file deletion in this lane. WorldAssets was rebuilt only after matching the new upload readback and its geometry checkpoint.**

## Results

- Original legacy scanner, unchanged thresholds/pattern: **196 → 0 same-facing pairs**, full built-structure scan. Raw before: `../qa-prep-2026-11-14/world-overlap-scan.txt`; raw after: `scan-after.log` (239 chunks, 43,997 planes). Existing v634 colonnade/aqueduct fixes still run before these repairs.
- Measured preflight: **54 exact coplanar + 142 near-parallel pairs**, maximum gap 0.009534 studs. All 142 had <=0.0001 variation in signed gap across every vertex of both polygons; none required a crossing-plane exception. All 196 were repaired; **no blanket near-plane exclusions**.
- Duplicate footprints are clipped from the background surface; intentional gold/trim/glow detail has priority, otherwise the outwardmost face owns the overlap. Original surface heights, silhouettes and UVs remain. No assembly offsets. Sequential current fragments handle multiple/contained overlaps. Original solid sidewalls remain.
- Polygon containment/partial/shared-edge/triple-ownership cases pass; 29,250 boundary/interior footprint witnesses pass; mesh validation, winding/finite coordinates and fragment area accounting pass. Source faces have one UVMap, one CORNER FLOAT_COLOR `Col`, no authored custom normals; all modified faces are flat shaded. UV/color corners are interpolated with separate vertices. `repair-ledger.json` records exact geometry identities, signed-gap ranges, owner/background, kept area and attributes. `near-plane-measurements.json` records independent preflight.
- Approved clearing: whole `Tree_02_tall`, `Tree_03_blossom`, `Bush_06`, `Bush_09`, `Bush_22`, for the park at Roblox (-38,-46). Trunks and canopies removed together using original-object face records, not bounding-box chopping. `vegetation-survey.json` records the original material bounds. No rocks or other trees removed.
- **99 merged mesh names before and after. 11 changed, 88 unchanged.** Bounds, materials, collision classification, regions and animation metadata are identical; hashes/triangle counts change. Total 66,910 → 66,844 triangles; largest resulting chunk 5,612 triangles, below 9,000. Palette byte-identical. Walk/perimeter/wet/blocked metadata unchanged except **2 coarse grid + 7 surface cells at the removed trunks**, now exposing existing ground (4.66–4.80). No stairs/bridge/path height change. See `generated-metadata-diff.json`.

## Export ready for coordinator

Differential upload: **`assets/world/world-v7-declutter.fbx`**. Full world export: `assets/world/world-v7.fbx`. Pending ledger: `assets/world/world-v7-pending.json` (retained; no deletion).

| Changed MeshPart | Cause |
|---|---|
| W7_Architecture__marble | Arch underside + local edging join |
| W7_Balustrades__marble | Rail/post cap and side seams |
| W7_Bridge__marble | Deck/post tops and sidewall seams |
| W7_Landmarks__marble | Gold detail substrate and base undersides |
| W7_Rotunda__marble | Rotunda + stairs overlaps |
| W7_Stations__marble | EggNest layer seam |
| W7_Stations__marble_smooth | EggNest supports/counter joins |
| W7_Stations__palette | Kiosk housing/screen and CareCradle detail joins |
| W7_Trunks__bark | Two approved complete tree trunks |
| W7_Vegetation__foliage | Tall tree canopy + three approved bushes |
| W7_Vegetation__foliage_blossom | Blossom tree canopy |

Upload reviewed differential FBX; map returned MeshIds/MeshSizes to exactly those names in the import JSON. **Then** rebuild generated WorldAssets/WorldV7Data using reviewed mapping, preserving the pending baseline safely. Existing MeshIds do not represent new geometry. Rebuild precise collision for changed solid meshes and restore TextureID after ApplyMesh; verify intended place before any Studio mutation. Do not publish.

**Upload/integration update:** coordinator uploaded model **97399181362990**, operation **25c9378b-cc5f-418f-8663-1dc9b3a348fd**. `studio-upload-readback.json` records all 11 names/MeshIds/raw sizes, FBX/manifest SHA256 and previous MeshIds. The checkpoint was recorded after upload while the exported files remained unchanged; its provenance note does not claim a pre-upload digest. Canonical import changes are exactly these 11 rows and all new IDs differ from the previous IDs. New WorldAssets/WorldV7Data generated successfully; pending retained. Coordinator reports 8 changed solid meshes rebuilt with precise collision, positions/sizes/textures restored, without place save or publish. Live visual/collision acceptance remains separate.

**No-delete upload promotion:** `build_world_v7_assets.py --confirm-upload artifacts/world-overlaps-2026-11-14/studio-upload-readback.json` calls `world_overlap_upload.py`. Complete proof validates before atomic pending replacement: exact names/no duplicates/extras/omissions; positive decimal IDs, finite positive three raw sizes; exact canonical row match; old IDs refused; model/operation provenance; exact FBX/manifest SHA256; current geometry hash. Every later run rechecks all bindings and **aborts before any runtime output** if a changed mesh is unconfirmed; unconfirmed added parts are withheld. A new merge invalidates the old checkpoint. Twelve negative/valid/idempotence tests pass in `world_overlap_upload_test.py`, including an actual-builder stale-proof fixture proving existing output bytes remain unchanged and no new ID is written. Systems Sol identified and required the abort gate: restoring only old metadata while retaining a new canonical ID was insufficient. **Final independent pipeline review: systems Sol GO**, independently reran 12/12 tests. The initial basic confirmation is superseded by this reviewed version.

## Render evidence and limits

`renders/` contains matching actual procedural-geometry before/after PNGs: stairs, rotunda, arch underside, bridge, balustrades, kiosk, EggNest, CareCradle, landmark; additional stairs/balustrades/bridge/EggNest grazing views, far structures and second-park clearing. Before includes the original vegetation; after includes the approved clearing. `arch-garden-*` shows the full arch from above the lawn; `arch-underside-isolated-*` deliberately hides all other meshes to expose the complete underside and both pillar joins (diagnostic isolation only, no geometry change). The initial arch shot was occluded and superseded by these two pairs. Blender geometry captures use actual mesh/materials, not concept art. **Astra actual-render review GO, including the replacement arch pair.** Coordinator additionally reports 648 rotunda/stairs rays, 234 hits, all old/new heights matched within 1.9e-6 studs after 8 precise collision rebuilds. Still images and ray samples do **not** establish physical-device comfort/performance or every collision route.

## Reviews and reproducible checks

**Fresh full-suite metadata correction:** pending reconciliation had made `MANIFEST.count` include the 68 appended collision tiles, so generated `meshParts=167` double-counted them when consumers added `collisionTiles`. The generator now counts actual emitted non-GroundCollision rows. `WorldV7Data.lua` changed **only** `meshParts:167→99`; all 167 part records and `collisionTiles=68` remain identical. `metadata-count-fix-proof.json` records byte-identical WorldAssets XML (also equal to current generated XML), manifest, imports, pending checkpoint, both FBXs, collision data and palette. Existing upload-binding validation passed before data-only regeneration; pipeline 12/12 tests and Python compile passed. GardenGreyboxWorld's count regression is unchanged. Coordinator owns fresh native test readback; no Studio actions in this correction lane.

- Architect: systems Sol, **GO WITH CHECKS** for the initial plan (strict all-vertex plane checks, sequential fragments, corner attribute preservation, topology/bounds evidence).
- Near-plane extension: systems Sol, **GO WITH CHANGES** (explicit foreground/material ownership; signed-gap ledger; inspect original sidewalls and grazing seams). `PLAN.md` records the extension. Source-based rendering retains the solid assemblies' side faces; no synthetic connector geometry was needed by the mesh checks. Render acceptance remains Astra's decision.
- Independent geometry code review: reports Sol GO. Independent upload-pipeline code review: systems Sol GO after the required fail-before-output correction; independently reran all 12 tests.
- Python compile of tooling passed. Background Blender `world_overlap_probe.py` passes and changes only 11 seam source chunks; unchanged-source hashes remain equal. `world_overlap_metadata.py` passes. `build_world_v7_chunks.py` runs through full export/walk generation. `scan_world_v7_coplanar.py -- 'Arch|Aqueduct|Colonn|Rotunda|Landmark|Bridge|Balustr|Station|Prop' --detail --fixed` has zero SAME/PAIR output. No scanner tolerance was loosened.
- Run generation only in a separate background Blender loading the import blend. Scripts never save that blend. Baseline copies are in `baseline/`; diagnostics/render helper paths are `scripts/world_overlap_*.py`. Keep these copies until integration is verified; no watched files are deleted.
