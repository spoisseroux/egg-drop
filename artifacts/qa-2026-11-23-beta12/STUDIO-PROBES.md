# Studio probes for garden life + nest (Opus, 2026-11-23)

Run read-only in a Studio Play session (Server) on feat after the island re-export merge (8cb84d4). Characters and `IslandBounds` excluded; transparent parts skipped.

## Nest spot (probe_nest_spot)

- **Spot A (-17.5, -2.5): clear all round** (16 rays at .5/1.5/2.5 up, r 2.6). Ground 4.06 on `W7_Architecture__marble` (walk map 4.00).
- Facing (-30, -4) (Fable): prompt at (-20.1, -2.8) on `W7_Architecture__marble`, y 4.09. **Use this.**
- Facing (-30, 4) (HollowWorldLayout's plaza centre): prompt at (-19.8, -1.3) on `W7_Architecture__trim`, y 4.20 (a raised trim strip).
- Spot B (-22.5, 5.5) is also clear.

## Leaf cover (probe_leaf_cover, raw)

1188 covered cells in 83 clusters. Most are mountain rock overhangs and balustrade rails (1-2 cells) that players never stand under. Clusters that matter on walkable ground (3+ cells, under a roof):

| Where | Centre (x, z) | r | Cells | Hit |
|---|---|---|---|---|
| Rotunda roof | (-60.0, 50.0) | 8.2 | 45 | `W7_Rotunda__palette` |
| Rotunda columns/edge | (-46.0, 26.0) | 3.8 | 2 | `W7_Rotunda__marble` |
| Arch / pavilion by the plaza | (5.0, 20.6) | 14.8 | 29 | `W7_Architecture__palette` |
| Arch side | (-6.0, 24.7) | 3.4 | 3 | `W7_Architecture__palette` |
| West colonnade | (-36.4, -25.1) | 11.8 | 9 | `W7_Architecture__trim` |
| Station roof | (-46.0, -8.7) | 3.4 | 3 | `W7_Stations__wood_plank` |
| East colonnade | (85.0, 57.4) | 8.4 | 10 | `W7_Architecture__trim` |
| Aqueduct | (44.6, -99.9) | 8.7 | 14 | `W7_Aqueduct__palette` |
| Cave / rock overhang (north-west) | (-31.8, -109.4) | 17.6 | 73 | `W7_Rocks__grass` |
| Rock overhang (north) | (9.1, -122.9) | 10.7 | 46 | `W7_Rocks__grass` |

Note: the rotunda is at (-60, 50) r 8.2, not where `LifeSim.LeafCover` guessed. The full raw list is in the session transcript; keep only clusters whose centre is on `IslandBounds.safeCell` ground.
