# Island edge sweep (offline, stage 1)

`python scripts/sweep_island_edges.py` over `assets/world/world-v7-walk.json`, flood-filled from the arrival dais (96, 66). Flagged: reached cells above y 10 (FloorTop + 6), or more than 3 studs outside the perimeter ring. Walk pass: a rise of up to 2 studs per stud (MaxSlopeAngle 89: slope alone never stops it). Jump pass: also jumps of up to 7 studs to a cell up to 2 studs away, from a cell with a run-up. Walls: the 122 perimeter boxes and the CaveBlocker (padded 0.5 stud), then again with the 18 `IslandBounds` top-ups.

**Limits.** One render-surface height per 1-stud cell: not collision. Roofs hide floors (the rotunda), and rails, crowns, collision boxes and gaps under a stud are invisible to it; Roblox floor detection on steep faces is worse than this model, so the jump pass over-reports on purpose. Every spot is a candidate for the Studio play test, not proof.

## Summary

| pass | reached | high cells | above y 16 | outside cells |
|---|---|---|---|---|
| walk before | 36811 | 7723 | 6026 | 2692 |
| jump before | 41130 | 8189 | 6425 | 4676 |
| walk after | 25525 | 517 | 1 | 0 |
| jump after | 40717 | 8159 | 6420 | 4676 |

## Walking (before the top-ups)

The climbable lines the walls answer:

| kind | centre (x, z) | cells | max y | above y 16 | codes | main foot (x, z, y) |
|---|---|---|---|---|---|---|
| high | 32.1, -66.2 | 7214 | 56.1 | 6026 | G2564 M518 R1911 W283 g1938 | 100, 11, 5.8 |
| high | -57.0, 45.4 | 508 | 14.3 | 0 | G19 M235 R11 g243 | -43, 44, 6.1 |
| outside | 106.0, -68.6 | 2692 | 55.66 | 2279 | G221 M72 R305 g2094 | 100, 11, 5.8 |

## Walking, with the top-ups

What is left is the rotunda terrace (legitimate, must stay reachable; the map sees its roof, not its floor) and any small rock shelves listed here: check them in Studio.

| kind | centre (x, z) | cells | max y | above y 16 | codes | main foot (x, z, y) |
|---|---|---|---|---|---|---|
| high | -57.0, 45.4 | 508 | 14.3 | 0 | G19 M235 R11 g243 | -43, 44, 6.1 |
| high | 80.4, -68.4 | 8 | 16.04 | 1 | M2 g6 | 79, -66, 5.76 |

## Jumping, with the top-ups (pessimistic: Studio candidates, not walled)

Chained full jumps up cliff faces. The jump feet are in the JSON (`passes['jump after'].spots[].feet`): drive a test avatar at each from the low side, jumping, as the doc's stage 2 says.

| kind | centre (x, z) | cells | max y | above y 16 | codes | main foot (x, z, y) |
|---|---|---|---|---|---|---|
| high | 29.2, -66.4 | 7599 | 60.14 | 6420 | G2818 M556 R1992 W283 g1950 | 79, -14, 5.06 |
| high | -57.0, 45.4 | 508 | 14.3 | 0 | G19 M235 R11 g243 | -40, 40, 5.24 |
| high | -33.0, 37.0 | 3 | 12.78 | 0 | T3 | -33, 38, 5.57 |
| high | -97.0, -16.3 | 3 | 14.48 | 0 | T3 | -97, -15, 4.0 |
| outside | 106.0, -68.6 | 2692 | 55.66 | 2279 | G221 M72 R305 g2094 | 79, -14, 5.06 |
| outside | -79.9, -83.3 | 1907 | 36.36 | 866 | G373 R509 g1025 | -37, -69, 4.38 |
| outside | -5.3, 59.2 | 75 | 4.3 | 0 | M10 P3 W62 | -9, 59, 4.0 |

## The top-ups (src/shared/IslandBounds.lua)

| id | from (x, z) | to (x, z) | base y | top y | ground under | nearest keep-out |
|---|---|---|---|---|---|---|
| east_ledge | 92, 9.5 | 98.5, 9.5 | 3.4 | 21 | 4.48..11.98 | dash Main d=0 at 26.58 |
| east_ramp | 98.5, 9.5 | 99.5, 22.5 | 3 | 21 | 4.1..11.98 | dash Main d=0 at 31.76 |
| east_shelf | 99.5, 22.5 | 113.5, 23 | 3 | 21 | 4.01..12.03 | dash Main d=0 at 41.07 |
| west_ramp | -84, -34 | -74.5, -47 | -0.8 | 21 | 0.27..11.65 | find spot 20 at 5.06 |
| pool_bowl | 57.5, -81.5 | 69.5, -81.5 | 3 | 30 | 4.01..21.91 | find spot 11 at 58.64 |
| spur_neck_west | 1, -101 | 9, -91 | 3.1 | 21 | 4.11..12.5 | park kerb (-38, -46) at 51.42 |
| spur_west_1 | 9, -91 | 11.5, -84 | 3.5 | 21 | 4.51..6.31 | park kerb (-38, -46) at 48.23 |
| spur_west_2 | 11.5, -84 | 11.5, -72 | 3.8 | 21 | 4.88..5.82 | station CreekNook at 40.39 |
| spur_west_3 | 11.5, -72 | 8.5, -64 | 3.6 | 21 | 4.62..6.39 | station CreekNook at 31.89 |
| spur_west_4 | 8.5, -64 | 6, -55 | 3.6 | 21 | 4.61..5.85 | station CreekNook at 22.56 |
| spur_west_5 | 6, -55 | 6, -47 | 3.5 | 21 | 4.57..5.75 | station CreekNook at 14.87 |
| spur_west_6 | 6, -47 | 9, -38 | 3.5 | 21 | 4.56..8.28 | station CreekNook at 9.43 |
| spur_tip_west | 9, -38 | 13.5, -33 | 3.6 | 21 | 4.61..8.28 | station CreekNook at 9.43 |
| spur_tip | 13.5, -33 | 21.5, -33 | 3.3 | 21 | 4.38..6.29 | station CreekNook at 12.5 |
| spur_tip_east | 21.5, -33 | 26.5, -38.5 | 3.3 | 21 | 4.35..5.43 | station CreekNook at 20.5 |
| spur_east_1 | 26.5, -38.5 | 26.5, -58 | 3.3 | 21 | 4.35..6.28 | find spot 11 at 24.3 |
| spur_east_2 | 26.5, -58 | 30, -66 | 3.5 | 21 | 4.57..6.35 | station CreekNook at 35.71 |
| spur_east_3 | 30, -66 | 30.5, -86 | 3.4 | 21 | 4.42..11.28 | station CreekNook at 43.93 |

Wall checks: all pass. Of 154 must-reach points (Dash points and pad, find spots, stations, park centres), 154 are reached walking with the top-ups.

## Ring boxes within a jump of the ground beside them

34 perimeter boxes (and the CaveBlocker, which the cave roof buries by design) stand lower than a jump above the ground next to them, all on the mountains. They are holes only for someone already up there; the top-ups keep walkers off the mountains and the safe-spot return catches anyone who still gets out. Listed in the JSON (`buriedRingBoxes`) for the Studio rim walk.

Safe ground for the return: 21135 one-stud cells (`src/shared/IslandGround.lua`). Heat map: `edge-sweep.png` (red: walkable high after the top-ups, orange: jump-only, purple: walkable before only, blue: ring boxes, green: top-ups).
