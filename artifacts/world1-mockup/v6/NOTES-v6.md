# World 1 mockup v6: trimmed trees, green Hatch Tree, redesigned stations

Status: **mockup for review and hand-cleaning, 2026-11-12.** Nothing is in the game, nothing was committed, Studio was not touched. `environment.blend` and its `hero_garden` / `dark_garden` collections were never opened. All designs are original.

- World: `assets/art-source/environment/world1-mockup-v6.blend` (v1 to v5 untouched)
- Station source files: `assets/art-source/stations/v2/` (nine .blend files, listed below)
- Textures: the v5 set, `assets/art-source/environment/textures/v5/`. v6 needed no new textures.
- This folder: world renders, `stations/` (18 station renders), `build_world_v6.py`, `build_stations_v2.py`, `stations_v2.py` (the shared station definitions), `render_views_v6.py`, `world_lib.py`, `stats.json`, `stations.json`, `water-check.json`

**Do not re-run `build_world_v6.py` or `build_stations_v2.py` after hand edits. They overwrite the .blend files.**

Layout, paths and station coordinates are unchanged from v5.

## 1. Triangles

| | v5 | v6 |
|---|---|---|
| Total without scale references | 80,412 | **72,770** |
| Island only (no islets, far islands, clouds) | 65,110 | 58,648 |

By collection in v6: Architecture 17,112; Ground 12,968; Props 10,640; Distant 10,398; Stations 5,472; Walls_Rocks 4,740; Sky_Islets 3,724; Landmarks 3,562; Underside 2,948; Water 1,206.

The target was "near 70k"; v6 is about 2,800 over. Where the saving came from:

- Trees: about 310 triangles each, down from about 560. Five or six clumps instead of eight, no under-skirts, three roots.
- Water and bed sheets rebuilt on 3-stud cells.
- Fewer flower patches (32) and cloud-floor clouds (34).
- Lighter balusters.

The new stations cost about 2,700 more than the old placeholders. If the count must go under 70k, the cheapest cuts left are the seven lamps (146 each), the three nap daises (360 each) and the far backdrop.

## 2. Trees

- Canopy shading is now per vertex and smooth, running from dark undersides to lighter tops, so the facets no longer band. The painted leaf texture and deep greens are kept.
- **Hatch Tree:** the pink blossom puffs are removed. It is all green foliage. Render: `05-hatch-tree.png`.

## 3. Stations

I read `src/server/LoungeArt.lua`, `src/shared/GardenLayout.lua`, `src/shared/HollowWorldLayout.lua`, `CARE-CARRY-MACHINE.md`, `CARE-MACHINE-ART.md` and the hand-off docs. There is no fruit or feeding station in the code today, so none was made.

Every station file has: one collection named after the station holding the named parts, origin on the ground at the station centre, front facing -Y, identity transforms, 1 unit = 1 stud. A `Preview_Only` collection holds a grass disc, a 5.5-stud avatar, a 2.3-stud bear-sized block, lights and two cameras; delete it freely.

| Station file | Purpose in the game | Where it is in code | v6 world position (X, Z) | What changed | Triangles |
|---|---|---|---|---|---|
| `CareCradle.blend` | The "Care machine": dock a pet on the cushion, restyle hue and charm, "Open companions" | `LoungeArt.lua` Journal station (`id = "Journal"`, title "Care machine"); cradle spec in `CARE-CARRY-MACHINE.md` | -17, -15 | Was a blue dome. Now a round marble dais with a carved egg-and-leaf band, a teal pedestal with a cream rim and a sage cushion with two paw marks, a marble arch with a three-piece mobile (the middle orb glows), a gauge post with a glowing care bar and amber dial, and a lectern with the green journal. | 1,100 |
| `EggNest.blend` | The egg spot under the Hatch Tree: "Browse eggs" | `LoungeArt.lua` `HatchTop` and the `Eggs` sign and `BrowseEggs` prompt | -31, -11 | Was a flat stone with an egg. Now three round marble steps with a carved band, a gold nest cup with leaf tips, the striped egg, a warm glow halo, and a small marble sign stele with a gold egg emblem. | 586 |
| `PocketDeckKiosk.blend` | The "Deck workbench": "Style deck" | `LoungeArt.lua` Customize station (`id = "Customize"`) | -46, -9 | Unchanged from v5, now also exported as a source file. It is still one mesh, not split into parts. | 984 |
| `ToyLawn.blend` | Toys the pets chase and play with | `GardenLayout.Toy`, `ToyWest`, `ToyEast`, `Lawn` | -30, 18.5 | Was a ball, three boxes and a ring. Now a marble toy chest with gold bands and an open wooden lid, a striped ball, stacking rings on a gold post, and three pastel blocks. | 564 |
| `NapDais.blend` | Rest anchors where pets nap | `GardenLayout.RestAnchors` (`creek_nook`, `spring_meadow_west`, `spring_meadow_east`) | 1, -33 / 49.5, 14 / 54.5, 14 | Was a plain cushion. Now a low marble dais with a paw-and-star band, a plump cushion with a gold button, and a small star lamp. The file holds the pink one; the world also uses lilac and mint. | 360 |
| `Bench.blend` | Seating by the plaza | `LoungeArt.lua` `GardenBench` | -43, 5 / -17, 5 | Marble end supports with gold caps, wooden slat seat and back. | 156 |
| `PicnicTable.blend` | Picnic tables | `LoungeArt.lua` `PicnicTop` | -58, 12 / 34, 46 | Marble trestles and seat blocks, wooden top and benches, a gold edge. | 144 |
| `ArrivalDais.blend` | Spawn pad inside the Chime Arch | greybox spawn (`scripts/GardenGreybox.lua`) | 96, 66 | Tiered marble disc with a zig-zag ring, a glowing aqua centre and a gold star. | 234 |
| `Lamp.blend` | Path lamps | `HollowWorldLayout.Lamps` (positions are the v2 mockup's, not the code's) | seven, see `stats.json` | Was a bark post. Now a fluted marble post with a gold cap and finial and a warm orb. | 146 |

Soft glow: the care cradle, egg nest and kiosk each have a small warm point light in the world file and in their station file, plus their emissive parts.

Station renders are in `stations/`: `<Station>-front.png` and `<Station>-three-quarter.png`.

Not redesigned: the Bubble Spring basin and the rotunda (landmarks, already marble), the stepping stones, and the two empty "future" pads.

## 4. World renders

`01-overview`, `02-spawn-view`, `03-hub`, `04-hub-stations-wide`, `05-hatch-tree`, `06-trees`, `07-toy-lawn-benches`, `08-top-down-map`, `09-side-floating`, `10-marble-plaza`, `11-arch-and-arrival-dais`, `12-pool-and-nap-dais`, `40-compare-overview-v5-left-v6-right`, `41-compare-hub-v5-left-v6-right`.

v6 renders a shorter set than v5. The other v5 cameras are still in the file.

## Checks

- Water check (`water-check.json`): 230 objects including all 22 trees, 0 overlaps remain.
- Station files (`stations.json`): every part has an identity transform, and each station's lowest point is at or just below the ground.
- In the world file, rotation and scale are applied on everything except the linked-duplicate vegetation and the REF objects, as before.

## Rough spots for the hand pass

- The care cradle is small next to the colonnade, because it keeps the old machine's footprint. The cushion top is 2 studs up, which may be high for a 2.3-stud pet to read well from a distance.
- The care cushion and egg are very pale; they may want more colour.
- The kiosk is a single mesh.
- Bench and picnic table are simple.
- The station preview avatars are block dummies.
- Carried over from v5: a slight sandy dip outside the water kerbs, and small gaps where the stream kerb meets each pool kerb.

## Not verified

- No FBX export or Studio import.
- The cradle was not checked against the dock datum, prompt offset or carry poses in `CARE-CARRY-MACHINE.md`.
- No station was checked for avatar reach or pet pathing.
- Night lighting was not tried.
