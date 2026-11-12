# World 1 mockup: "Chime Rim Garden"

Status: **mockup for review, 2026-11-12.** Nothing here is in the game. Nothing was committed, and Roblox Studio was not touched.

- Scene: `assets/art-source/environment/world1-mockup.blend`
- Textures: `assets/art-source/environment/textures/` (14 PNGs and `generate_textures.py`)
- Renders and scripts: this folder

The scene is built entirely by `build_world.py`. Rebuilding overwrites the .blend, so once Spencer starts moving things by hand, treat the .blend as the source and stop re-running the script (or save his edits under a new name).

## Concept

A small garden cupped in a horseshoe of lavender cliffs, open on the south and west to a bright sea. You arrive through a rock arch hung with chimes on the southern tip, and the first thing you see through it is the whole world: the spring, the Hatch Tree, a waterfall on the left, a pinwheel on the right, and snow peaks over the cliff tops.

The ground rolls. The cliffs are broken up by boulders at the foot, crags growing out of the face and rocks on the skyline. Past the rim there are sea stacks, foothills, peaks and clouds, so it reads as a place inside a bigger world.

Everything is original. The layout was derived from our own greybox footprint and the station positions in our code. `environment.blend` and its `hero_garden` / `dark_garden` collections were never opened, imported or measured, and the old Fable kit FBXs were not used either.

## Map (north is up, 1 unit = 1 stud)

The playable floor is the greybox footprint: about 241 x 200 studs, world X -131..110, Z -75..125.

```
            N  cliffs 30-50 studs tall, peaks behind
   +---------------------------------------------------+
   | Tumble Falls      Glow Grotto (cave)      Pinwheel|
   |   Mirror Pond        |brook               Lookout |
   |   (islet)   trees    |          orchard   (high   |  E
 W |                 workbench  HATCH  care     terrace)|  cliffs
sea| Lookout Ledge       TREE + egg nest  nook  picnic |
   | + Wobble Egg   picnic   plaza   bridge            |
   | Hopstones   west       toy lawn  lily pool  ramp  |
   |  ^  ^  ^    bridge                       Cloud    |
   |   west creek          spring loop        Pavilion |
   |      \       Blossom Hill      Sun Meadow (open)  |
   |       \      (swing)   Bubble Spring              |
   +--Rim Falls---------- CHIME ARCH ------------------+
                          spawn pad
            S  open sea, sea stacks, far peaks
```

- **Hub (centre):** flat plaza around the Hatch Tree. Paths fan out to the falls, the grotto, the west bridge, the terraces and the spawn.
- **North-west:** Mirror Pond under Tumble Falls. The west creek leaves the pond, runs south under the west bridge and pours off the rim.
- **North:** Glow Grotto in the cliff. The hub brook starts inside it, runs past the hub under two small bridges and ends in the lily pool.
- **East:** two grassy terraces against the cliff, reached by sculpted ramps. Players only.
- **West bank:** Hopstones climbing to the Lookout Ledge. Players only.
- **South:** Bubble Spring meadow, Blossom Hill to the south-west, the open Sun Meadow to the south-east, and the Chime Arch promontory with the spawn pad.

## Landmarks and why each is fun

| Landmark | Where (X, Z) | Why |
|---|---|---|
| **Chime Arch** | -10, 109 | The spawn gate. It frames the first view, and five pastel chimes hang under it that can ring when you run through. |
| **Hatch Tree** | -3.4, -10.9 | The heart of the hub, kept where the code already puts it. Bigger and rounder, with blossom puffs and the hanging lantern. |
| **Tumble Falls and Mirror Pond** | -85, -88 / -85, -45 | A two-step waterfall that lands on a boulder shelf, then drops into the pond. The pond has an islet with one blossom tree. |
| **Glow Grotto** | 10, -80 | A cave mouth ringed with boulders and glowing aqua and pink crystals. It is the natural door to a future second world. |
| **Pinwheel Lookout** | 97, -56 | A giant paper pinwheel on the high terrace. It should spin in game, and it is visible from the whole garden, so it works as a compass. |
| **Hopstones, Lookout Ledge, Wobble Egg** | -117, 20..64 / -120, 6 | A jump climb up five stone pillars. The reward at the top is a giant speckled egg-shaped boulder and the best sea view. |
| **Bubble Spring** | -14, 99 | The spring basin with glossy floating bubbles, the most Frutiger Aero spot in the garden. Bubbles could pop and respawn. |
| **Blossom Hill** | -48, 80 | The one real hill, with a big pink tree and a swing. |
| **Rim Falls** | about -85, 128 | The creek pouring off the edge into the sea. Mostly seen from the bridge and from above. |
| **Cloud Pavilion** | 97, 31 | A domed rest spot on the low terrace, replacing the greybox rest-nook roof. Placeholder shape. |

## Station positions

All positions are read from `src/server/LoungeArt.lua`, `src/shared/GardenLayout.lua` and `src/shared/HollowWorldLayout.lua`, and are unchanged except the spawn.

| Station | World X, Z | In the mockup |
|---|---|---|
| Egg spot (hatch nest) | 0, -5 | Nest stone with a placeholder egg |
| Care machine | 11, -6.3 | Placeholder capsule machine on a stone pad |
| Deck workbench | -11, -6.3 | Placeholder bench with awning on a stone pad |
| Benches | -11.8, 12.6 and 11.8, 12.6 | Placeholder benches |
| Toy lawn | -2, 12.5..17.5 | Flowered lawn with a ball, blocks and a ring |
| Picnic tables | -34, 24 and 38, -28 | Placeholder tables on pads |
| Creek nook | 26, -15.5 | Rest cushion beside a mossy boulder |
| Spring meadow rest spots | -12.5, 87 and -7.5, 87 | Two cushions |
| Spring basin | -14, 99 | Bubble Spring |
| Bridges | 17.6, -9.4 / 20.5, 22 / -83, 35 | Plank bridges, flat decks, spanning X |
| Lamps | the seven `HollowWorldLayout.Lamps` points | Placeholder orb lamps |
| Spare pads | -21, 3 / -17, -17 / 9, -17 | Empty stone pads for future machines |
| **Spawn** | **-10, 121** | Moved about 16 studs south of the greybox spawn (-10, 105), so players start outside the arch |

`layout-check.json` confirms every station sits on ground at exactly floor height (flat within 3 studs), and that no path crosses water except at the bridges.

## Scale

- 1 Blender unit = 1 stud. Blender (x, y, z) = Roblox (X, -Z, Y - 4). The Blender origin is Roblox (0, 4, 0), which is the current floor top under the hub.
- REF collection: three 5.5-stud block avatars and four Bears.
- The Bear is imported from `assets/garden-babies/bear.fbx` with wings and charms removed. Its body is 1.48 units tall in the FBX. I scaled it by 1.555 to match the 2.3 studs in the brief. If the game's real garden scale differs, the REF bears are the only thing to change.
- Cliffs are 30 to 50 studs tall. Terraces are 8 and 16 studs. Hopstones rise 3.5 studs per step to a 21-stud ledge, the same as the greybox. Ramps are about 25 to 30 degrees at their steepest.
- Rolling ground is at most about 3 studs, with Blossom Hill about 7. Every station, rest spot and the whole hub (27-stud radius) is flattened to floor height, so today's flat-floor pet logic keeps working there.

## Textures

All generated by `textures/generate_textures.py` from tileable noise. All are seamless. `_contact-sheet.png` shows each one tiled 2 x 2.

| File | Size | Use |
|---|---|---|
| `grass.png` | 128 | Main ground, cliff tops |
| `meadow.png` | 128 | Flowered lawns (spring, toy lawn, Sun Meadow, Blossom Hill) |
| `dirt_path.png` | 128 | Paths and hub plaza |
| `cliff_rock.png` | 128 | Cliff walls, rim skirt, crags, arch, hopstones |
| `boulder_rock.png` | 128 | Loose boulders |
| `sand_pebble.png` | 128 | Shores and stream beds |
| `water.png` | 128 | Pond, creek, brook, sea |
| `waterfall.png` | 128 | Falls (scroll V in game) |
| `wood_plank.png`, `bark.png` | 128 | Bridges, furniture, trunks |
| `foliage.png`, `foliage_blossom.png` | 128 | Tree and bush canopies |
| `stone_tile.png` | 128 | Station pads, basin, spawn pad |
| `far_peak.png` | 64 | Distant mountains |

Ground UVs are planar at 16 studs per tile (8 px per stud). Cliffs are 26 studs per tile. Steep ground faces get a vertical projection so rock never smears. Vertex colours carry soft shading and tint, and Roblox supports them on meshes.

## What is placeholder

- Every object with `PLACEHOLDER` in its name: care machine, workbench, benches, picnic tables, toys, cushions, nest stone and egg, spawn pad, Cloud Pavilion, swing.
- Lamps, bridges and stepping stones are simple stand-ins.
- Boulder and crag scatter on the walls is procedural. A few crags still read as stuck on rather than grown from the face and need hand placement.
- Ground material edges (grass to sand to rock) are per-triangle and jagged. That is in keeping with the retro look, but the shorelines want a hand pass.
- The grotto is a recess in the wall, not a real interior.
- The avatar is a block dummy.
- Bloom in the renders is added after rendering by `render_views.py`, standing in for a Roblox BloomEffect. The sky is a gradient, not a skybox texture.

## Triangle budget

From `stats.json`:

| Collection | Triangles |
|---|---|
| Ground (terrain 20.2k, paths, plaza) | 22,844 |
| Walls_Rocks (cliff band, rim skirt, about 265 boulders and crags) | 20,876 |
| Props (trees, bushes, flowers, lamps, bridges) | 10,794 |
| Distant (mountains, foothills, sea stacks, clouds) | 6,840 |
| Landmarks | 5,914 |
| Stations | 2,056 |
| Water | 1,826 |
| **World total (without REF)** | **71,150** |
| REF (bears and avatars) | 5,688 |

That is under the 120k target with room to spare. Unique mesh data is only 45.6k triangles, because boulders, trees, bushes, flowers and lamps are instances of a small kit: 14 rock meshes, 3 trees, 2 bushes, 2 flower patches.

## Building it for real and importing to Roblox

1. **Shared origin.** Keep the mockup's origin: every chunk is exported with its transform applied and its pivot at the Blender origin, so in Studio every MeshPart goes to the same CFrame, (0, 4, 0), and they line up without nudging. FBX export uses the same axes as the pets (forward -Z, up Y).
2. **Chunks.** Split the terrain into a 4 x 4 grid of roughly 64-stud tiles (about 1,300 triangles each), and split each tile by material into grass, meadow, sand and rock pieces, because a MeshPart takes one texture. The cliff band splits into about eight wall segments plus cap pieces. Each piece stays far below the 20,000-triangle import limit, and chunks stream in and cull well on phones.
3. **Kit pieces.** Import each boulder, tree, bush, flower patch and lamp once and place copies from a small Luau table generated from the .blend (name, CFrame, scale). This is the same approach `LoungeGreyboxArt.lua` uses for its tables. Reused meshes cost almost no extra memory.
4. **Textures.** Upload the PNGs once. Use `SurfaceAppearance` or a plain `TextureID` per MeshPart. Roblox always filters textures, so the look is soft Dreamcast or GameCube rather than hard PSX pixels. That matches the renders, which also use filtered sampling.
5. **Collision.** Do not use the render meshes for collision.
   - Terrain chunks: `CollisionFidelity = PreciseConvexDecomposition`, or a lower-resolution copy of the height grid used as an invisible collider.
   - Cliffs: a few invisible box or wedge walls, as the greybox does today. Keep the invisible walls along the south and west rim, since the rim stones are only knee high.
   - Boulders: `Hull`. Trees: one cylinder for the trunk, canopy non-colliding. Flowers, bushes, foam, clouds and far scenery: `CanCollide`, `CanQuery` and `CanTouch` all off.
6. **Pets stay on the ground.** Keep the existing rule and tables:
   - Terraces, both ramps, the Hopstones and the Lookout Ledge stay in `PetBlocks`. Their footprints match the greybox closely, but the organic edges mean the rectangles should be re-measured.
   - Pet Y currently assumes a flat floor (`GardenLayout.FloorY`). Outside the flattened areas the ground now rises up to about 3 studs, so pets need a ground height. The simplest route is to bake the height function to a small grid module (for example 4-stud cells) that `GardenWalkability` and the mover sample. A downward raycast against the terrain collider also works. Until that exists, pets must stay inside the flat hub, spring and nook areas, or the hills must be flattened.
7. **Water.** Keep flat, non-colliding sheets tagged `GardenWetRegion`, as now. The pond, creek, brook and lily pool are organic shapes, so the wet regions become a handful of rectangles or a polyline with a width, rather than two boxes. All three bridges keep their current positions and span X over water running along Z. Waterfalls are meshes with a scrolling texture. The sea is one large unlit disc at Y = -40.
8. **Sky and distance.** Mountains, foothills, sea stacks and clouds are unlit, non-colliding meshes with baked vertex-colour shading. Add `Atmosphere` haze, a soft `BloomEffect` and a slight `ColorCorrection` to get the airy look. The day/night cycle will need tint variants or a little light response on these meshes, since their shading is baked.
9. **Animation hooks for later.** Pinwheel rotor spin, chime sway and sound, bubble bob and pop, waterfall scroll, crystal pulse.

## Files in this folder

- `build_world.py`: builds the .blend headless.
- `render_views.py`: renders the cameras and adds the bloom.
- `check_layout.py`, `layout-check.json`: height and path sanity check.
- `stats.json`: triangle counts.
- `01-overview.png`, `02-spawn-view.png`, `03-hub-stations.png`, `04-landmark-tumble-falls.png`, `05-distant-mountains.png`, `06-scale-bear-avatar.png`, `07-landmark-glow-grotto.png`, `08-landmark-chime-arch.png`, `09-top-down-map.png`, `10-pinwheel-terrace.png`, `11-hopstones-wobble-egg.png`.

Commands (background Blender only, never the live session):

```
blender --factory-startup -b --python assets/art-source/environment/textures/generate_textures.py
blender --factory-startup -b --python artifacts/world1-mockup/build_world.py
blender --factory-startup -b assets/art-source/environment/world1-mockup.blend --python artifacts/world1-mockup/render_views.py
```

## Not verified

- Nothing was exported to FBX or imported into Studio. Roblox triangle counts, texture look and vertex-colour behaviour are untested.
- Pet walkability was not run through `GardenWalkability` or `GardenPathPlanner`. Only heights at stations and along paths were checked.
- The renders are EEVEE with post bloom. In-engine lighting will differ.
- The spawn position in the live place was not confirmed. The greybox spawn (-10, 105) was used as the reference.
- Night lighting was not tried.
