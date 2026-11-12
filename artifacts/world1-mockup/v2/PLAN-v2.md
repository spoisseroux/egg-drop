# World 1 mockup v2: "Chime Cove"

Status: **mockup for review, 2026-11-12.** Answers Spencer's review of v1. Nothing is in the game, nothing was committed, Studio was not touched. `environment.blend` and its `hero_garden` / `dark_garden` collections were never opened. The palette is our own.

- Scene: `assets/art-source/environment/world1-mockup-v2.blend` (v1 is untouched)
- Textures: `assets/art-source/environment/textures/v2/` (15 PNGs, `generate_textures_v2.py`, `_contact-sheet.png`)
- Renders, scripts, numbers: this folder. `stats.json` holds every coordinate and count quoted below.

Rebuilding with `build_world_v2.py` overwrites the .blend. Once Spencer moves things by hand, the .blend is the source.

## What changed from v1

| Review note | v2 |
|---|---|
| "Too square, same thing as before" | New layout from scratch. The floor is a two-lobed kidney shape defined in polar form, with no rectangle and no cliff ring. A cove bites in from the south, a spit sticks out west, a peninsula carries the spawn south-east. |
| "Too big" | Floor is 27,700 sq studs against v1's 48,200, so 57%. It spans about 191 x 152 studs at its widest. |
| "A bit too desaturated" | Lush green grass, clear blue water, warm blue sky. Standard view transform, less bloom. |
| "Textures too noisy, everything blends" | Every texture is close to one flat colour with large soft variation. The terrain uses one neutral tile multiplied by vertex colour. Rock is warm sandy grey, not lavender. |
| Rock walls should read as shapes | Walls are made of about 60 big faceted rock forms with grass caps, in two overlapping rows at different heights (15 to 45 studs), over a sloped terrain core. |
| Clean path edges | Paths are separate ribbon meshes with their own texture, so the edge against grass is a clean line. |

## Map (north is up)

```
                 rock walls (tall behind the falls, lower to the west)
            . - ~ ~ ^ ^ ^ ^ - . _       _ . - ^ ^ ^ ^ ~ - .
        .^    Glow Grotto     spur      Tumble Falls       ^.
      ^        (notch)        +egg       falls pool          ^
     (   trees     path        |    stream                    )  walls end,
 Blossom                       |  stepping stones   trees    )   stacks step
 Point  ---- workbench HATCH care     \                      )   into the sea
  (spit)      bench  [HUB]  bench    lily pool    Bubble
     (  picnic   toy lawn     nook      |  bridge  Spring    .
      \      ramp                       |      \   meadow   /
       \  KNOLL +                      /  picnic  `--path--. Chime Arch
        \ Pinwheel   beach    COVE    /                      * spawn
         ` - . _ _ . - '   (sea)   ` - . _ _ _ _ _ . - '
                         open sea, sea stacks, far peaks
```

- **West lobe:** the hub. Hatch Tree with the stations in a ring around one plaza.
- **East lobe:** arrival. Spawn on the peninsula tip, Chime Arch, then the path curves past the Bubble Spring meadow to the one bridge.
- **Between them:** the stream. It leaves the falls pool, winds south-west, widens into the lily pool (with an islet), passes under the bridge and steps down the beach into the cove.
- **North:** rock walls. A low rock spur reaches from the wall into the garden and separates the falls basin from the hub side. The Wobble Egg sits on its tip.
- **South-west:** the knoll with the Pinwheel, reached by a grassy ramp. It overlooks the cove.
- **South and west:** open to the sea, with a sandy beach in the cove and low shore stones elsewhere.

## Landmarks

| Landmark | World X, Z | Note |
|---|---|---|
| Chime Arch | 85, 57.5 | Spawn gate, turned square to the path. Frames the first view. |
| Hatch Tree | -36, -18 | Centre of the hub. |
| Tumble Falls | wall foot at 73, -73 | Two-step fall into the falls pool. |
| Glow Grotto | mouth at -6.5, -93.5 | A real notch through the wall, roofed by big rocks, with crystals. |
| Pinwheel Knoll | -60, 50 | 9 studs high, ramp facing the hub. Players only. |
| Wobble Egg | 17, -45 | On the spur tip, visible from the hub. |
| Bubble Spring | 52, 3 | Rest meadow beside the arrival path. |
| Blossom Point | -100, -15 | West spit with one large blossom tree. |
| The Cove | about -5, 60 | Beach where the stream meets the sea. New in v2. |

Dropped from v1: Hopstones and Lookout Ledge, the east terraces, Cloud Pavilion, the swing, Rim Falls.

## Station coordinates (all new, all placeholders)

| Station | World X, Z |
|---|---|
| Hub plaza centre | -30, -4 |
| Egg spot (nest stone) | -31, -11 |
| Care machine | -17, -15 |
| Deck workbench | -46, -9 |
| Benches | -43, 5 and -17, 5 |
| Toy lawn | -30, 17 |
| Picnic tables | -58, 12 and 34, 46 |
| Creek nook (rest cushion) | 1, -33 |
| Spring rest spots | 49.5, 14 and 54.5, 14 |
| Spring basin | 52, 3 |
| Bridge (spans X, stream runs along Z) | 4, 21 |
| Spawn | 96, 66 |
| Spare pads | -48, -22 and -13, -4 |
| Lamps | 70, 50 / 30, 33 / -9, 23 / -12, -44 / -70, -3 / 50, -10 / -22, 38 |

Every station sits at exactly floor height. Stations are within about 20 studs of the plaza centre, apart from the picnic tables, the nook and the spring.

## Pets walk the ground only

- Pet-walkable area is about **22,700 sq studs** (82% of the floor): dry lawn inside the rim, flat at every station and rolling by less than 1 stud elsewhere.
- Not for pets: the knoll and its ramp, the rock spur, the stream and both pools, the beach below the lawn line, and the grotto notch. These need blocked or wet regions like today's `PetBlocks` and `GardenWetRegion`.
- There is one crossing between the lobes: the bridge at (4, 21). The stepping stones near the falls are for players.
- The sea sits 4 studs below the lawn. The south and west edges are open, so they need invisible walls along the rim for players and pets.

## Size and travel

- Floor area: 27,700 sq studs, 57% of v1.
- Spawn to the edge of the hub plaza along the path: 142 studs, about **9 seconds** at 16 studs per second. That is just under the 10 to 15 second target. Reaching the plaza centre takes about 10 seconds.
- Scale references are unchanged: 5.5-stud avatars, Bear scaled to 2.3 studs.

## Textures (v2 set)

`ground_soft` (neutral terrain tile), `grass`, `meadow`, `dirt_path`, `cliff_rock`, `boulder_rock`, `sand_pebble`, `water`, `waterfall`, `wood_plank`, `bark`, `foliage`, `foliage_blossom`, `stone_tile` (all 128 px), `far_peak` (64 px). All seamless.

The terrain is a single mesh with one material. Grass, sand and stone are vertex colours, which Roblox supports on meshes, so there are no per-triangle material seams. Blends are soft over one 3-stud cell.

## Triangles

| Collection | Triangles |
|---|---|
| Ground | 12,686 |
| Props | 6,950 |
| Walls_Rocks | 6,440 |
| Distant | 5,980 |
| Landmarks | 4,296 |
| Stations | 1,902 |
| Water | 1,354 |
| **World total (without REF)** | **39,608** |

v1 was 71,150. Unique mesh data is 27.9k triangles.

## Building it for real

The v1 plan still applies (shared origin at Roblox (0, 4, 0), chunked terrain, kit pieces placed from a table, simple colliders, flat tagged water sheets, unlit far scenery). Differences for v2:

- Terrain chunks need only one texture each, because colour is in the vertices. Splitting by material is no longer needed.
- The wall forms are instances of nine rock meshes, so they are cheap. Collide against a few invisible wedges behind them, not the rocks.
- Wet and blocked regions follow curves, so they become polylines with a width or a small set of rotated boxes.
- The sea is close and visible everywhere, so it deserves a gentle animated texture.

## Files

`01-overview.png`, `02-spawn-view.png`, `03-hub-stations.png`, `04-landmark-tumble-falls.png`, `05-distant-view.png`, `06-scale-bear-avatar.png`, `07-landmark-glow-grotto.png`, `08-cove-beach.png`, `09-top-down-map.png`, `10-knoll-pinwheel.png`, `11-chime-arch.png`, `12-compare-overview-v1-left-v2-right.png`, `13-compare-map-v1-left-v2-right.png` (same camera and same map scale as v1), `build_world_v2.py`, `render_views_v2.py`, `world_lib.py` (helpers generated from the v1 script), `stats.json`.

```
blender --factory-startup -b --python assets/art-source/environment/textures/v2/generate_textures_v2.py
blender --factory-startup -b --python artifacts/world1-mockup/v2/build_world_v2.py
blender --factory-startup -b assets/art-source/environment/world1-mockup-v2.blend --python artifacts/world1-mockup/v2/render_views_v2.py
```

## Not verified

- No FBX export or Studio import. Vertex-colour terrain and texture look in Roblox are untested.
- Pet walkability is my own height and rim test, not `GardenWalkability` or the path planner.
- Bloom is added after rendering. Night lighting was not tried.
- Tree, bush and flower scatter is procedural and not hand-checked for every spot.
- The grotto is a short notch with a dark liner, not an interior.
