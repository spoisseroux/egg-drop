# World 1 mockup v4: "Chime Cove", painted and crisp

Status: **mockup for review and hand-cleaning, 2026-11-12.** Nothing is in the game, nothing was committed, Studio was not touched. `environment.blend` and its `hero_garden` / `dark_garden` collections were never opened. I could not see Spencer's reference screenshots; v4 follows the written takeaway (lighting and texture quality only). All shapes and motifs are our own.

- Scene: `assets/art-source/environment/world1-mockup-v4.blend` (v1, v2 and v3 untouched)
- Textures: `assets/art-source/environment/textures/v4/` (18 PNGs at 256 px or smaller, `generate_textures_v4.py`, `_contact-sheet.png`)
- This folder: 21 renders, `build_world_v4.py`, `render_views_v4.py`, `world_lib.py`, `stats.json`, `water-check.json`

**Do not re-run `build_world_v4.py` after hand edits. It overwrites the .blend.**

The layout, paths and station coordinates are unchanged from v3 (see `stats.json`, `../v3/NOTES-v3.md` and `../v2/PLAN-v2.md`).

## Fixes

1. **Bridge deck.** The v3 deck was built at the stream-bed height, so it sat under water. It is now a marble deck 20 x 6.6 studs with its top 0.34 studs above the lawn, a low ramp at each end, abutment blocks set into both banks, a carved zig-zag band along each side and an arch underneath. Close-up: `16-closeup-bridge.png`.
2. **Chime Arch.** The slab on top and its pennants are gone. The arch is now the two piers, the half-ring, a slim gold keystone with a small finial, and a carved band under each pier cap. Close-up: `11-marble-chime-arch.png`.
3. **Pinwheel removed.** The rotunda stays, renamed `Landmark_KnollRotunda`. The dome is closed with a gold finial, it has a carved egg-and-leaf frieze, and a large marble egg statue stands inside as the focal point.

## Look and feel

- **Colour:** deeper, richer grass green; warm-grey/olive rock; lilac-white marble; cyan-blue sky that warms to cream in a thin band at the horizon.
- **Lighting:** stronger, smaller sun for crisper shadows, brighter ambient, and far less haze on the distant islands. The post bloom is cut to a trace (threshold 0.93, strength 0.12; v3 was 0.84 and 0.32).
- **Textures (all new, painted style):**
  - `grass.png`: three passes of painted blade strokes over deep green. The terrain uses it directly on grass faces; vertex colour only tints it and fades it into sand or rock at the edges.
  - `cliff_rock.png`, `boulder_rock.png`: big drawn cracks with a dark crevice and a light bevel, finer secondary cracks, brushed mottling. Wall rocks also get olive moss streaks running down from their grass caps.
  - `marble_block.png`: ashlar blocks in running bond with dark seams and a highlight edge.
  - `marble_trim.png`: a carved trim sheet with four bands: paw prints and stars, a zig-zag "hop" band with dots, eggs and leaves, and a plain moulding. Used on the colonnade frieze, the rotunda frieze, the plaza ring, the arch piers and the bridge sides.
  - `pebble_bed.png`: painted pebbles on the stream and pool beds.
  - `water.png`: light cyan with a caustic net. The water material is now about 46% opaque with a strong sheen, so the bed shows through.
  - Also repainted: meadow, sand, path, wood, bark, both foliage tiles, waterfall.
- **Channels and pools:** a marble kerb lines both banks of the stream and rings both pools. The pools are now regular ovals so the kerb sits cleanly, and the beds were reshaped so the water reaches the kerb.

## Triangles

| Collection | Triangles |
|---|---|
| Architecture (includes the new kerbs) | 18,110 |
| Ground | 12,718 |
| Distant | 11,578 |
| Props | 6,602 |
| Walls_Rocks | 4,740 |
| Sky_Islets | 3,724 |
| Landmarks | 3,446 |
| Underside | 2,948 |
| Stations | 1,902 |
| Water | 1,158 |
| **Total without REF** | **66,926** |
| Island only | 51,624 |

v3 was 64,694. The difference is the kerbs, less the pinwheel.

## Water check

Same method as v3 (`water-check.json`): 214 objects checked including all 22 trees, **0 overlaps remain**. One tree was moved at placement and 11 bank stones were removed automatically. The kerbs, bridge, stepping stones, spout, falls rock face and aqueduct are exempt by design.

## File organisation

Same as v3, plus an `Edging` sub-collection under `Architecture` (`Edging_Stream`, `Edging_FallsPool`, `Edging_LilyPool`). Rotation and scale are applied on everything except the linked-duplicate vegetation and the REF objects. No orphan data and no empty collections.

## Known rough spots for the hand pass

- The kerb runs stop a little short where the stream meets each pool, leaving small gaps at the corners.
- The terrain is still a 3-stud grid, so the bed under the water is faceted and the shore line inside the kerb is slightly uneven.
- Stream water is now about 7 studs wide between kerbs, a little wider than v3.
- The gold keystone is a plain block.
- Marble still picks up blue from the sky in shade.
- Rock shadows read slightly blue-grey; a warmer ambient would help.
- Far islands are flat-coloured and plain.
- The trim on the plaza ring is mapped around a circle, so the zig-zag pinches slightly toward the centre.

## For Roblox later

- Textures are 256 px and tile, so they upload as they are. The trim sheet needs the UVs that are already on the meshes.
- Clear water over a pebble bed works with a semi-transparent part or mesh over the terrain. The kerbs give a clean edge for it.
- The grass tint relies on vertex colours above 1.0 at the sand edges in Blender. Roblox clamps vertex colour to 1.0, so those blends will look slightly darker there, or the edge faces should use the plain tile.

## Not verified

- No FBX export or Studio import.
- Pet walkability on the bridge ramps (0.34 studs over 2.6) was not tested in game.
- Night lighting was not tried.
- Spawn to hub is still about 9 seconds.

## Renders

`01-overview` to `15-waterfall-tumble-falls-lower` as in v3, then `16-closeup-bridge`, `17-closeup-rock-texture`, `18-closeup-clear-water`, `19-closeup-marble-trim`, `20-compare-overview-v3-left-v4-right`, `21-compare-map-v3-left-v4-right`.
