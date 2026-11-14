# Remaining world overlaps — plan for architect review

Status: plan only. Implementation waits for coordinator's architect GO. Authorized: repair geometry and prepare/import an unpublished build; no publish, Play, commits, source-blend saves or file deletion. This lane owns world tooling/generated world outputs only; coordinator owns Studio/import and other agents own runtime changes.

## Goal and baseline

Remove the remaining **196 same-facing candidate pairs across 14 chunk-pair groups**, preserving v634's colonnade/aqueduct repairs, silhouette, walkability, material mapping and UV appearance. Baseline: `artifacts/qa-prep-2026-11-14/world-overlap-summary.json` and detailed scan, 58.57 square studs total; stairs/rotunda/arch/bridge contribute 81.9%. No whole-structure offsets.

## Proposed geometry repair

1. Inspect exact candidate polygons from the current `declutter + qa_fixes` result. The scan rounds planes to 0.01 and normals to 0.01: **confirm coplanarity and positive polygon intersection before editing**. Record genuinely separate, merely near-plane candidates as explicit exclusions, with measured distances and rendering evidence. Do not force the scanner count to zero by hiding output.
2. Add `remaining_coplanar_fixes(sources)` after existing `coplanar_fixes`, without changing earlier v634 helpers. Use a bounded allowlist of the 14 baseline chunk-pair groups, plus asserted world-space bounds, expected candidate counts and preflight face geometry. Pick geometry by chunk/bounds/normal signature, never persistent face indices. Abort on an unexpected candidate rather than repairing unrelated scenery.
3. Prefer **planar seam union / clipping** over lifting surfaces. For equal-material coplanar surfaces, retain one surface in the intersection and trim the overlapping area out of its partner. Process deterministic geometry order, rebuilding only affected faces into convex fragments/triangles. This keeps the visible union and all original surface heights, and handles adjoining box caps without a blanket structure offset. Interpolate original per-corner UVs and colors on inserted vertices; preserve material and smooth state. Verify winding, finite coordinates, positive areas and unchanged visible union area within tolerance. Bound repair to proven coplanar intersections, not proximity alone.
4. For layered different-material details, keep the intentional overlay and cut its footprint from the background plane: kiosk aqua screens over cream housing, landmark gold over marble, EggNest trim over marble, CareCradle gold over cream. Inspect underlying connectivity first; do not remove an entire large background face or invert a normal to evade the scan. Where clipping would expose a missing sidewall or a near-plane pair is real but not coplanar, use an explicitly measured local join/sidewall repair and report that exceptional change for review.

| Group(s) | Pairs | Intended treatment / inspection |
|---|---:|---|
| Stairs marble | 14 | Clip tread/landing top/underside and adjoining side overlaps; preserve tread elevations and riser edges. |
| Rotunda marble | 5 | Union floor/landing cap seam and column/capital underside seams; avoid opening the floor. |
| MarbleArch marble | 2 | Trim redundant overlapping base undersides; inspect from below as well as garden view. |
| Bridge marble | 10 | Trim deck/post top and side-wall intersections; retain rail/post silhouette and deck height. |
| Balustrades marble | 147 | Union repeated small rail/post cap intersections; prioritize continuity over shaving the whole railing. |
| Kiosk cream/aqua; cream/cream | 2 + 4 | Intentional screen layer retained, housing clipped; local housing seams merged. |
| Landmarks gold/marble; marble/marble | 2 + 2 | Keep gold detail, clip substrate; union base underside seams. |
| EggNest smooth/smooth; marble/smooth; marble/trim | 2 + 2 + 1 | Inspect counter/support/trim joins; preserve machine silhouette and top height. |
| Edging marble | 1 | Clip the local curb segment join; retain v634 deduplication/caps. |
| CareCradle cream/gold | 2 | Preserve gold detail; cut its exact footprint only. |

## Tooling and outputs

- `scripts/build_world_v7_chunks.py`: bounded repair, preflight assertions and change summary; preserve existing hash-based differential export and no-save behavior.
- `scripts/scan_world_v7_coplanar.py`: retain the legacy candidate scan for before/after comparability; add strict measured confirmation / machine-readable records if needed. Do not silently change old scan tolerance or call near-plane candidates fixed.
- `scripts/world_overlap_*.py`: background-only diagnostics/render/diff helpers as needed, no interactive Blender control. Artifacts under this folder: baseline/after scans, polygon evidence, repair/exclusion ledger, same-camera before/after actual-geometry renders and metadata diff.
- Background Blender regeneration produces the existing world FBX/manifest/walk/pending outputs. Coordinator handles asset uploads, MeshIds, WorldAssets rebuild and Studio collision/TextureID restoration.

## Verification and cases

| Case | Required result |
|---|---|
| Exact coplanar intersecting faces | Only one surface owns each positive-area intersection; original visible surface union retained. |
| Shared boundary / zero-area contact | No geometry changed. |
| Near-plane candidate from coarse scanner | Measured/reported; no automatic clipping. Repair only if separately justified. |
| Different material layer | Overlay survives with its original appearance; substrate clipped without a visible hole. |
| UV or vertex-color seam | New corners interpolate original data; no texture stretch or palette change. |
| Fragment sliver/degenerate triangle | Reject or merge within a declared tolerance; no NaN, inverted face or unbounded triangle growth. |
| Existing v634 fix regions | Zero confirmed overlaps remain; previous cap/side tweaks retained. |
| Unrelated chunks | Hash/mesh geometry unchanged. Unexpected output changes block upload until explained. |

Checks after implementation: Python compile; background Blender assertions; full legacy and strict before/after scans; target **zero confirmed same-facing overlaps** in scope, with honest exclusions; original versus output area/bounds/material/triangle counts; deterministic repeated generation without source-blend save; manifests and walk-data diff (ground/path/bridge heights must stay unchanged or be explained). Render stairs, rotunda, arch, bridge, balustrade joins and all affected stations from matching oblique and close seam cameras, including undersides where repaired. Astra reviews actual geometry renders; Blender still images do not prove the absence of Studio depth flicker.

Coordinator's later unpublished Studio verification: mount only reviewed assets; rebuild precise collision for changed solid meshes; restore TextureID after ApplyMesh; inspect seams from multiple distances and verify source-place identity. No publish or Play in this lane.

## Risks and boundaries

- Planar clipping must support existing concave polygons: triangulate or decompose for intersection/difference first, preserve convex output and UV provenance. Algorithm tests need containment, partial overlap, shared-edge and repeated-overlap cases rather than a test mirroring one scene fixture.
- Coarse scan can misclassify sloped nearby faces; strict plane tests gate edits. Equal-surface union must not change collision topography, and open underside surfaces must remain visually closed.
- Mesh index/order changes can alter hashes or split bins; explain every affected generated MeshPart before upload. Preserve object/material identities and TRI_CAP=9000.
- The generator writes palette/walk/FBX/manifest/pending even when only geometry changes. Snapshot old outputs first and do not run other asset generators concurrently. Existing pending MeshIds are not proof of new geometry; no upload/build promotion until reviewed.
- Rojo can crash on watched-file deletion. Do not delete pending/generated files; coordinator will manage a safe no-delete state transition. Never save the import `.blend` or overwrite any user's live Blender session.
- No save schema, economy, localization, runtime, Blip or TODO edits in this lane. This geometric repair is independent of QA acceptance and does not establish launch readiness.

## Reviewed near-plane extension

Coordinator required all genuine near-parallel duplicate coverage to be handled too. Measured baseline: 54 exact pairs and 142 separated by up to .009534 studs, **all** with signed-distance variation <=.0001 across both polygons (none crossed). Systems Sol architect GO WITH CHANGES: project foreground footprint onto background's original plane and trim there; preserve material owner and original geometry heights/UVs. Gate gap <=.012, consistent same-facing oriented normals and variation <=.0001; do not process crossing/slanted planes automatically. Choose outwardmost equal-material face; preserve gold/trim/glow detail precedence. Ledger records both signed-distance ranges and owner. Sidewalls belonging to the original solid assemblies remain; inspect near/far/grazing renders for missing connectors/slits rather than claiming a single projected coverage check proves closure. No blanket offsets or exclusions.
