# Round 7 look brief: den, path and terrace leftovers (Fable, 2026-11-26)

Seen: studio-r6e 01 to 07 (beta 27, noon). Not seen: night, an avatar for scale, the path foot close up, the Top Lawn close up. Coordinates are inferred from the scripts, not measured in Studio.

## R6-CDE "Must fix": status from the captures

| # | Item | Status |
|---|---|---|
| 1 | Collar bandshell | **Fixed** (01: rock covers the collar, no see-through) |
| 2 | Reveal colour | **Open** (01: a brown band sits straight under the brow) |
| 3 | Grass flaps | **Open** (01: green triangles upper left, above the brow right, far right) |
| 4 | Shard field west of the mouth | **Open** (01, left third: tall thin cards) |
| 5 | Deck screen white | **Fixed** (01, 07: teal) |
| 6 | Floating lip stone | **Fixed**, but over-corrected: one stone left |
| 7 | Grass through the treads | **Fixed** (06) |
| 8 | Boards at the foot | **Not shown**; 01 lower left has a brown stub by the boulder: check |

## MUST (before the test pass)

1. **Pale bank, lower path** (02 and 04, behind the inner edge, about 8 wide and 9 high, flat tan about #8E8B73). Island ground standing on edge inside a hole in the wall. Target: nothing but cliff rock (#6F7D78 family) from the inner edge to 6 behind it. Change: in `recut_test` / `_recut_one`, for ground materials (`Terrain_Ground__*`) delete any face with normal Y under 0.5 within 6.0 behind the inner edge, from tread -0.25 to tread +12 (today 2.8 and +6.5). Then make the path wall span the hole: `back` at least 5 on those samples.

2. **Rock slivers in the tread** (05: three blue-grey triangles, 0.3 to 0.6 long, mid shelf). Target: zero non-dirt pixels inside the tread. Change: `in_path_cut` under-tread bound `h - .3` to `h - 1.0`, and apply it out to `w/2 + 0.5`; the grown skirt of the dirt sheet hides the deeper hole.

3. **Jagged shards above the path and west of the mouth** (02 upper right, 04 top, 01 left). Target: rock cells 5 to 7 studs, no triangle with a corner under 12 degrees, no free-standing card. Change: run the existing orphan-island sweep (now terrace only, `q[1] > 25`, 8 faces) over two more envelopes, limit 12 faces or 6 square studs: the path (0 to 10 behind the inner edge, tread to tread +14) and the mouth's west flank (x -44..-18, y 6..24, z -102..-95). Back each hole with a `rock_mass`: the R6 mass at (-36, 14, -98.5), radii (7, 8, 3), yaw 10; over the path one blob per 10 studs of hole, radii (5, 4, 2.5), standing 0.8 proud.

4. **Lip stones** (02 to 05: none on the shelves). Target: 4 to 5 on shelf 2, 3 to 4 on shelf 1, about one per 7 studs, 0.8 to 1.8 showing, sunk 0.3, none floating. Change in `lip_layout`: seat each stone straddling the edge (centre at `w/2 - 0.2`, so the tread or its bank is under it), drop the `> 3.0` sheer-drop reject there, gaps `uniform(2.5, 4.5)`, no "every fourth missing" on shelf 2. Stones may intrude 0.75 at most: the walk stays over 7.

5. **Den reveal and flaps** (R6 items 2, 3). Outer 2 studs of the reveal and jambs #6F7D78, graded to #7E6B58 over 4 studs in. Delete the grass flaps outright; do not chase them with more masses.

6. **Grass edges that read as cards.** (a) 04, 05: the path's grass strip overhangs with a dark underside line. Outer edge from `w/2 + .15` to `w/2 - .05`, plus a 0.4 skirt down. (b) 06: a green wall 3 high left of the top flight. Give that skirt the rock material, or cut the terrace grass within 1.5 of the flight.

7. **Top Lawn toys x1.25** (03, 06: the toys read small beside the 18 tree and 7-high outcrops). Swing bar 7.0, frames and worn patches x1.25, seats and slots stay pet-sized. Do it last; if the pet seat probes fail, ship without it.

## CAN WAIT

- Fin stone (03) seems to stand on a thin pale stalk: sink its lobes 0.6; confirm in Studio first.
- Den walls (07) read as smooth, slightly glossy plaster: 5 to 7 stud cells, roughness 0.9 or more, no reflectance.
- Jamb lean 8 to 10 degrees.
- Lookout slab +0.5 with a skirt.
- Deck screen is saturated teal: #BFD8D2 if it glares at night.

## Evidence wanted

Same seven cameras, noon and night, with an avatar on the path, plus the path foot (R6 item 8).
