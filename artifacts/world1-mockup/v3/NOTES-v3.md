# World 1 mockup v3: "Chime Cove", floating

Status: **mockup for review and hand-cleaning, 2026-11-12.** Nothing is in the game, nothing was committed, Studio was not touched. `environment.blend` and its `hero_garden` / `dark_garden` collections were never opened. All architecture is original, built from generic classical parts.

- Scene: `assets/art-source/environment/world1-mockup-v3.blend` (v1 and v2 untouched)
- Textures: `assets/art-source/environment/textures/v3/` (17 PNGs, `generate_textures_v3.py`, `_contact-sheet.png`)
- This folder: renders, `build_world_v3.py`, `render_views_v3.py`, `world_lib.py`, `stats.json`, `water-check.json`

**Do not re-run `build_world_v3.py` after hand edits. It overwrites the .blend.** It is kept as a record and for the numbers.

## What changed from v2

The footprint, paths and station coordinates are the same as v2 (see `../v2/PLAN-v2.md` and `stats.json`). Changes:

1. **Floating island.** The sea is gone. The island has a faceted rock underside with five lobes, the deepest about 124 studs below the lawn. Hanging roots and vines, stalactites and glowing crystals sit under it. A cloud floor lies about 240 to 300 studs below, with seven small floating islets, fourteen drifting rocks, ten hazy far islands (three with fairy-tale towers and pennants, some with ruins) and cloud banks on the horizon.
2. **Classical marble.**
   - Hub: marble plaza with a teal ring and gold star inlay, a curved colonnade behind the Hatch Tree (five standing columns with an entablature, two broken, one fallen drum), egg statues and urns.
   - Chime Arch: rebuilt as a marble arch (see 3).
   - Knoll: a rotunda with a teal dome, with the Pinwheel rising through it, and a wide marble stair up the ramp.
   - Aqueduct: an arcade along the wall top that feeds Tumble Falls, starting at a large source urn.
   - Edge: six runs of marble balustrade with gold-capped posts.
   - Also: a marble bridge, ruins at Blossom Point and by the grotto, plush-figure statues flanking the arch and on Blossom Point. Station pads, the nest stone, the spring basin and stepping stones are now marble.
3. **Chime Arch fixed.** The old arch was a tube swept along a curve, which twisted at the right foot. The new one is two box piers plus a true half-ring of clean quads, a gold keystone, a cornice and two pennants. Nothing is swept, so nothing can twist.
4. **Grass texture.** The terrain's grass faces now use `ground_grass.png`: light and dark patches plus short blade strokes at about 12% contrast, tiled every 16 studs. Sand and rock faces keep the plain tile.
5. **Waterfalls in front of the rock.**
   - Tumble Falls: a dedicated rock-face mesh sits behind the water, and the water is 0.8 to 1.4 studs in front of it at every height. Marble spout lip at the top, ledge pool in the middle with a marble lip, foam at the ledge and at the bottom. The falls pool was moved to the foot of the fall. Flanking rocks are kept clear of the water.
   - Sky Falls (new, replaces the cove cascade): the stream runs out along a marble spout and pours off the island edge, well clear of the underside, into a mist cloud.
6. **Nothing in the water.** See the check below. The lily-pool islet and its tree were removed.

## Tree-in-water check

`water-check.json`. Every vertex of every tree, bush, flower, lamp, rock, statue, urn, ruin, station and architecture object was tested (in plan view) against every visible cell of the stream and pool mesh and the Sky Falls channel.

- 218 objects checked, including all 22 trees. **0 overlaps remain.**
- At placement, 1 tree was moved off the bank (`Tree_21_blossom`, from (-84, -30) to (-76.9, -22.9)). None were dropped.
- The check found 8 bank stones touching water and removed them (`Rock_007`, `008`, `013`, `014`, `015`, `017`, `025`, `034`).
- Exempt on purpose: the bridge, the three stepping stones, the marble spout, the falls rock face and lips, the aqueduct.

## Player safety at the edge

- The open edge has a raised grass lip (about 0.65 studs), a rock skirt below it, and marble balustrades on six arcs. The gaps between balustrades have low rim stones only.
- Plan for the game: an invisible wall around the whole open edge, just outside the balustrade line and at least 12 studs tall, plus the same across the Sky Falls spout. The balustrades alone are 3 studs high, which a jumping avatar clears.
- Also add a catch volume below the island that returns anyone who falls to the spawn pad.
- Pets: the walkable area is unchanged from v2 (about 22,700 sq studs). The stair, knoll, spur, water, lip and grotto notch are not for pets.

## File organisation

Collections: `Ground`, `Underside`, `Walls_Rocks` (Wall_Crags, Rocks_Shore, Rocks_Field), `Water`, `Architecture` (Plaza, Colonnade, MarbleArch, Rotunda, Aqueduct, Balustrades, Statues_Urns, Ruins, Stairs, Bridge), `Landmarks`, `Stations`, `Props` (Trees, Bushes, Flowers, Lamps), `Sky_Islets`, `Distant`, `Sky_Lighting`, `Cameras`, `REF`.

- Every object is named for what it is. Unique meshes carry their object's name. No orphan meshes, materials or images, and no empty collections.
- **Transforms:** rotation and scale are applied on every mesh except the linked-duplicate vegetation (22 trees, 26 bushes, 46 flowers, the islet trees and the Blossom Point tree) and the REF bears and avatars. Those keep rotation and scale so that editing one tree mesh updates them all. Say if you want them baked too.
- Architecture built in place (balustrades, colonnade entablature, aqueduct, stairs) has its origin at the centre of its base. The terrain, underside, falls rock face and spouts keep their origin at the world origin.

## Triangles

| Collection | Triangles |
|---|---|
| Architecture | 15,664 |
| Ground | 12,718 |
| Distant (far islands, clouds) | 11,578 |
| Props | 6,602 |
| Walls_Rocks | 4,800 |
| Sky_Islets | 3,724 |
| Landmarks | 3,624 |
| Underside | 2,948 |
| Stations | 1,902 |
| Water | 1,134 |
| **Total without REF** | **64,694** |
| Island only (no islets or backdrop) | 49,392 |

v2 was 39,608. The balustrades are the heaviest new item.

## Known rough spots for the hand pass

- Far islands show a faint repeating pattern from their texture and read a little grey. They want a flatter material.
- A few tan sand triangles show through the falls pool surface.
- The terrain is still a 3-stud grid, so the lip and stream banks are slightly stepped.
- The marble picks up blue from the sky in shade. It may want a warmer tint.
- Bush and flower scatter is procedural.
- The colonnade entablature is straight spans between columns, not a true curve.
- Gold inlay on the plaza is a flat shape lying on the paving, not cut in.

## Not verified

- No FBX export or Studio import.
- Pet walkability is my own height and rim test, not the game's planner.
- Bloom is added after rendering. Night lighting was not tried.
- Spawn to hub is still about 9 seconds (142 studs), under the 10 to 15 second target.

## Renders

`01-overview`, `02-spawn-view`, `03-hub-stations`, `04-waterfall-tumble-falls`, `05-distant-view`, `06-scale-bear-avatar`, `07-landmark-glow-grotto`, `08-waterfall-sky-falls`, `09-top-down-map`, `10-knoll-rotunda`, `11-marble-chime-arch`, `12-underside`, `13-side-floating`, `14-marble-plaza`, `15-waterfall-tumble-falls-lower`, `16-compare-overview-v2-left-v3-right`, `17-compare-map-v2-left-v3-right`.
