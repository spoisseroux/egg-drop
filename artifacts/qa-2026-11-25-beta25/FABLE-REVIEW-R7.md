# Fable review: round 7 renders (2026-11-26)

Seen: all 17 r7 renders plus the four r6/r7 pairs in `extra/`. Blender only: no lamps, avatar or Roblox lighting, so colour and scale calls are provisional.

**Verdict: not a redo. Two delete-only fixes (A, B below), then upload and check in Studio.** The path is clearly better than r6.

## Per item

| # | Item | Verdict | Notes |
|---|---|---|---|
| 1 | Pale bank, lower path | **SHIP** | path/CAM-SHELF2, r7-S02: rock from the inner edge up, no tan. |
| 2 | Tread slivers | **CHECK IN STUDIO** | Tread is clean in SHELF2 and r7-TREAD; the bug never reproduced in Blender, so only capture 05 retaken proves it. |
| 3 | Shards and backing masses | **FIX (A)** | Over the path: fixed (r7-S02 vs r6-S02). West of the mouth: den/CAM-MOUTH-EAST shows a floating rock mass against the sky and four hanging thin cards, sky visible between them. |
| 4 | Lip stones | **FIX (B)**, then SHIP | Counts and rhythm are right; 0.75 over the tread is accepted, my "centre 0.2 inside" is withdrawn. One stone floats in the sky (path/CAM-SHELF2, upper left). Outer stones hang on the wall face (r7-S02, terrace/CAM-ARRIVE right). |
| 5 | Reveal and flaps | **CHECK IN STUDIO** | No brown band under the brow in MOUTH30. Three green flaps remain in r7-S01 (upper left, above the brow right, far right), smaller than r6. Colour grade needs Roblox light. |
| 6 | Grass edges | **CHECK IN STUDIO** | r7-S06: the lip by the top flight is rock, good. r7-TREAD shows the new turf skirt as a curved ridge with an orange sliver at its end near the new boulder. |
| 7 | Top Lawn toys | Not done, fine | Stays last. |

## Fixes before upload

**A. West flank orphans.** Widen the sweep envelope to x -60..-18, y 6..40, z -110..-90, limit 20 faces or 12 square studs. Delete any `rock_mass` not overlapping the cliff or another mass by at least 1.0 stud; sink the survivors 1.5 into the wall. Target from CAM-MOUTH-EAST: no sky between rock pieces, nothing free-standing.

**B. Lip stone seating.** Delete any stone with no surface within 0.5 under its centre. Outer-edge stones: centre no further out than `w/2 + 0.1`, sunk 0.4.

## Check in Studio (do not hold the upload)

- Path foot (path/CAM-FOOT): two upright brown boards about 3 high by the boulder (R6 item 8), and the inner dirt skirt reads as a flat brown ribbon up the rock. If either shows: boards deleted, skirt capped at 0.4 tall.
- path/CAM-ARRIVE: large flat dark triangles with tan-graded faces below the arrival. If seen from the walk, back them with one mass, radii (6, 5, 3).
- terrace/CAM-ARRIVE: a bare brown pole, 12 or so high, upper left. Tree without its crown, or a stray post?
- den/CAM-MOUTH-EAST: a pale plank hanging inside the mouth.
- Remaining grass flaps: if visible at noon, delete island grass faces with normal Y under 0.5 within 30 studs of the mouth, above y 20.

Evidence wanted: unchanged from the brief (seven cameras, noon and night, avatar on the path, path foot).
