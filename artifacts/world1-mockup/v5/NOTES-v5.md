# World 1 mockup v5: polish on v4

Status: **mockup for review and hand-cleaning, 2026-11-12.** Nothing is in the game, nothing was committed, Studio was not touched. `environment.blend` and its `hero_garden` / `dark_garden` collections were never opened. All designs are original.

- Scene: `assets/art-source/environment/world1-mockup-v5.blend` (v1 to v4 untouched)
- Textures: `assets/art-source/environment/textures/v5/` (19 PNGs, 256 px max, `generate_textures_v5.py`)
- This folder: 29 renders, `build_world_v5.py`, `render_views_v5.py`, `world_lib.py`, `stats.json`, `water-check.json`

**Do not re-run `build_world_v5.py` after hand edits. It overwrites the .blend.** Layout, paths and station coordinates are unchanged from v4.

## What changed

1. **Trees.**
   - Three new tree meshes (`Tree_Round`, `Tree_Tall`, `Tree_Blossom`): six to eight canopy clumps each, with a darker skirt under the big clumps for depth, two visible branches, a flared trunk base and four roots.
   - New painted leaf texture, deeper greens, dark undersides and lighter tops through vertex colour.
   - Blossom trees use a softer, less magenta pink with a couple of green leaf clumps showing.
   - The 22 garden trees and the Blossom Point tree are linked duplicates of these three meshes. Trees on the small floating islets use the old light meshes (`TreeLite_*`) to save triangles. The Hatch Tree keeps its shape and gets the new texture and shading.
2. **Flat water beds.** The terrain is now cut out along the kerb line, and one level pebble floor (`Ground_WaterBed`, 1.9 studs below the lawn) and one level water sheet fill the whole channel. There is no terrain geometry under the water any more, so no bumps. Close-ups: `21-closeup-pool-bed.png`, `22-closeup-stream-bed.png`.
3. **Pocket Deck workbench.** In the game this station is the "Deck workbench" with the "Style deck" action, where players restyle their handheld. The new `Station_PocketDeckWorkbench` is a marble-and-wood kiosk on the same spot and footprint (5.4 x 2.5 counter at waist height):
   - a big handheld-device sign with a glowing screen, cross pad, gold and pink buttons and two round ears (our own shape);
   - marble counter legs, wood top, a carved zig-zag band on the front;
   - a small deck propped on the counter, three paint pots and a sticker sheet;
   - two slim columns, a wood beam, two warm lanterns and a soft warm light.
   Renders: `23-workbench-front.png`, `24-workbench-side.png`.
4. **Statues.** The plush statues, the egg statues (including the one in the rotunda) and the urns now use `marble_smooth.png`: polished, soft veining, no block seams. Their pedestals are smooth too. Block seams remain on walls, steps, columns, kerbs and plaza paving.

## Triangles

| | v4 | v5 |
|---|---|---|
| Total without REF | 66,926 | **80,412** |
| Island only | 51,624 | 65,110 |

The increase is almost all trees (about 560 triangles each instead of about 110) plus the two flat sheets. Unique mesh data is 65k. If that is too heavy for phones, dropping the under-skirts or using the light trees beyond the hub would recover about 8k.

Water check (`water-check.json`): 214 objects including all 22 trees, 0 overlaps remain.

## Rough spots for the hand pass

- Just outside the kerb the lawn dips slightly and shows a sandy fringe in places.
- Small sand corners show where the stream kerb meets each pool kerb.
- The statue close-up of the plush figure is from behind; the statues face the spawn side of the arch.
- The big handheld sign is a flat board about a third of a stud thick.
- Tree canopies are still clusters of faceted blobs, not leaf cards.

## Not verified

- No FBX export or Studio import.
- The workbench was not checked against the in-game prompt offset or avatar reach.
- Night lighting was not tried.

## New renders

`20-closeup-trees`, `21-closeup-pool-bed`, `22-closeup-stream-bed`, `23-workbench-front`, `24-workbench-side`, `25-statue-bear`, `26-statue-eggs`, `27-statue-rotunda-egg`, `28-compare-overview-v4-left-v5-right`, `29-compare-map-v4-left-v5-right`. Views 01 to 19 are the same cameras as v4.
