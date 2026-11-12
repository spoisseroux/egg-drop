# World 1 mockup v7: fixes and import preparation

Status: **ready for a first import attempt, 2026-11-12.** Nothing is in the game, nothing was committed, Studio was not touched. `environment.blend` and its `hero_garden` / `dark_garden` collections were never opened. All designs are original.

## Files

| What | Where |
|---|---|
| Hand-editable scene | `assets/art-source/environment/world1-mockup-v7.blend` |
| Import chunks (generated from the scene) | `assets/art-source/environment/world1-mockup-v7-import.blend` |
| Skyboxes | `assets/art-source/environment/sky/day/` and `sky/night/` (`Sky_Bk`, `Dn`, `Ft`, `Lf`, `Rt`, `Up`, 1024 px), `sky/_preview.png`, `sky/generate_sky.py` |
| Station sources (unchanged from v6) | `assets/art-source/stations/v2/` |
| Textures (unchanged) | `assets/art-source/environment/textures/v5/` |
| Renders, scripts, checks | this folder |

v1 to v6 are untouched. Re-running `build_world_v7.py` overwrites the scene. `export_import_chunks_v7.py` reads the scene and only writes the `-import` file, so it is safe to re-run after hand edits.

Origin and layout are the same as v6: Blender (x, y, z) = Roblox (X, -Z, Y - 4), hub plaza centre at (-30, -4).

## The six fixes

### 1. Blossom canopies re-seated
The v6 trunk stopped at a fixed height below the canopy, and the side clumps had nothing under them. Now the trunk runs up into the main clump and every low side clump gets its own branch. This applies to all three tree types and the light islet trees.

Check (`tree-check.json`): for each tree mesh, every clump must contain a trunk or branch end, or overlap a clump that does, and the wood must rise at least 0.5 studs above the lowest leaf.
- 6 tree meshes, all pass. Wood reaches 1.9 to 3.1 studs into the canopy.
- 34 tree objects use those meshes. 0 fail.

Renders: `07-blossom-trees.png`, `08-blossom-tree-from-below.png`.

### 2. Water prepared for animation
Separate meshes, each with its own material:

| Object | Material | `anim` | In Roblox |
|---|---|---|---|
| `Water_Stream`, `Water_AqueductChannel`, `Water_SkyFalls_Channel` | `water_stream` | `scrollV` | Scroll the texture downstream, about 0.15 tiles per second. The stream's UVs now follow the stream: U across, V along the flow. |
| `Water_Pool_Falls`, `Water_Pool_Lily`, `Water_TumbleFalls_LedgePool` | `water_pool` | `ripple` | No flow. A slow two-direction drift (about 0.03 tiles per second) or a gentle transparency pulse. |
| `Water_TumbleFalls_Upper`, `Water_TumbleFalls_Lower` | `waterfall_tumble` | `scrollV` | Fast scroll down the fall, about 1.2 tiles per second. V runs down the fall and tiles. A Beam with the same texture also works. |
| `Water_SkyFalls` | `waterfall_sky` | `scrollV` | About 1.4 tiles per second; fade out toward the bottom. |
| `Water_TumbleFalls_Foam_Bottom`, `_Foam_Ledge`, `Water_SkyFalls_Foam` | `foam` | `bob` | Each has its own 0..1 UV strip (U along the foam line). Bob 0.15 studs at about 2 Hz and jitter U. A ParticleEmitter can sit on top. |
| `Water_SkyFalls_Mist` | `cloud` | `bob` | Slow bob and scale pulse, or replace with particles. |

MeshParts cannot scroll a `TextureID` directly. The usual routes are a `Texture` instance on a flat part (`OffsetStudsU/V`), a `Beam`, or swapping to a small flipbook. The flat stream and pools suit `Texture`; the falls suit `Beam` or `Texture` on thin parts that follow the ribbons.

Other animatable objects carry `anim` and `anim_note` custom properties. The full list (133 objects) is in `animation.json`:
- `sway` (9): the five arch chimes (now separate objects pivoted at their hanging points), two pennants by the Sky Falls spout (new, pivoted at the hoist), the Hatch Tree lantern, the care cradle mobile.
- `pulse` (11): seven lamp orbs, egg nest halo, arrival disc, grotto crystals, underside crystals.
- `bob` (43): six spring bubbles, seven near islets with their trees (they share an `anim_group`), fourteen drifting rocks, foam.
- `drift` (61): clouds.

### 3. Fences and rim rocks pulled in
Balustrades moved from 1.1 studs outside the rim line to 1.9 studs inside it. Rim stones moved 2.6 to 4.2 studs inside and were made a little smaller.

Check (`edge-check.json`): every vertex of every balustrade and loose rock on the open side must be inside the rim line and over ground no lower than 0.45 studs below the lawn.
- 46 objects, 7,926 vertices, 0 failures. The outermost vertex is 0.31 studs inside the rim.
- Rocks on the walled (north) side sit against solid rock, not a drop, so they are not held to the rim line.

Renders: `09-edge-fence-and-rocks.png`, `10-edge-from-outside.png`.

### 4. Rotunda is enterable
- The egg statue and its pedestal are removed. The floor is clear.
- Six columns instead of eight. The clear gap between column bases is **4.1 studs** (5.2 between shafts), and the stair arrives centred on a gap.
- The floor is a flat disc 7.6 studs in radius, 0.9 studs above the knoll top, with two shallow steps (0.3 studs each) all round, so it is walkable from the stair. The dome underside is about 7.5 studs above the floor.

Renders: `05-rotunda-interior.png`, `06-rotunda-entrance.png` (with a 5.5-stud avatar inside).

### 5. Invisible collision
Collection `Invisible_Collision`. Every object has `collision=invisible` and a `note`, is hidden from renders and shown as wireframe.

| Object | What it is |
|---|---|
| `PerimeterWall` | A closed ring 1.5 studs thick. On the open edge it stands 0.4 studs outside the rim line (2.3 studs outside the balustrades), from 3 studs below the lawn to 12 above. Behind the rock walls it sits on the plateau, 15 to 17 studs above the wall top. |
| `CaveBlocker` | A 20 x 1.6 x 17 slab across the grotto mouth, just behind the gate. |
| `FallCatch` | A 1400 x 1400 x 16 volume 170 studs below the lawn, under the island's lowest point and above the cloud floor. Respawn anyone who touches it. |

The cave also has a visible barrier, `Landmark_GrottoGate`: marble posts, gold bars, a carved band and a teal egg-shaped lock plate. The crystals still show through it. Render: `13-cave-blocker.png`.

The perimeter wall is one concave mesh. In Roblox it needs to be a set of thin box parts along the same line (or a mesh with precise collision). The Sky Falls spout sticks out past the wall line, so it is closed off too.

### 6. Night and skyboxes
- Two original painted skies, generated from a direction-to-colour function so the six faces are seamless: a bright day sky with posterised cumulus and a sun glow, and a deep-blue night sky with stars, a moon and soft cloud bands. `sky/_preview.png` shows both as cross layouts.
- The scene has both worlds (`W1v7_Sky_Day`, `W1v7_Sky_Night`) and a `Lighting_Night` collection (moon, blue fill, a warm point light at each of the seven lamps and at the lantern, kiosk, cradle, egg nest, plaza, arch, bridge and rotunda, cyan lights at the arrival dais and in the grotto). It is hidden by default; `render_views_v7.py` switches it on for the night renders.
- Answer to "how does it look at night": it reads well. The plaza, stations and lamps form warm pools, the grotto glows cyan through the gate, and the cloud floor goes soft blue. Renders: `20-overview-night.png`, `21-hub-night.png`, `22-spawn-view-night.png`, `23-grotto-night.png`, `24-side-floating-night.png`, and `31-compare-overview-day-left-night-right.png`.

For Roblox night: a `Sky` with the night faces, `Lighting.ClockTime` around 0, a blue-violet `OutdoorAmbient`, `PointLight`s in the lamp orbs and stations, Neon on the glow parts. The backdrop islands and clouds are unlit with baked colour, so they need a tint at night (the Blender materials have a `NightTint` colour node for this; in Roblox use the part `Color`).

## Import preparation

`world1-mockup-v7-import.blend` holds the same geometry regrouped (`import-chunks.json` lists every chunk with its material, triangle count, bounds and `anim`):

- **249 chunks**, each with exactly one material, an identity transform and its origin at the world origin. Total 73,172 triangles; the largest chunk is 7,620. None is over 10k.
- Names are `<Category>__<material>`: `Terrain_Ground__*` (5), `Rocks_*` (6), `Architecture_*` (27), `Vegetation_*` (13), `Stations_*` (81), `Landmarks__*` (9), `Backdrop_*`, `Props__*`, and `Anim__<object>` (105) for anything that moves, kept one object each.
- `Invisible_Collision` objects are carried over. `Station_Anchors` holds one empty per station at its position and yaw.
- `stations.json`: 19 entries (12 stations and 7 lamps) with Blender location, Roblox position, yaw and a ready `CFrame.new(...) * CFrame.Angles(0, yaw, 0)` string, plus the source file for each.
- `vegetation-placements.json`: every tree, bush and flower instance (mesh, position, yaw, scale), so each mesh can be imported once and placed from a table instead of using the joined vegetation chunks.

249 is a lot of chunks. Most of that is stations split by part and material (81) and one chunk per animated object (105, of which 61 are clouds that could be merged). If fewer parts are wanted, the stations should be imported from their own source files and the cloud chunks joined.

## Triangles

73,172 without scale references (v6 was 72,770); 58,730 for the island alone. The gate, pennants, chime split and tree branches added about 900; the rotunda lost two columns and the statue.

## Checks summary

| Check | Result |
|---|---|
| Trees seated (`tree-check.json`) | 34 objects, 0 failing |
| Fences and rim rocks on solid ground (`edge-check.json`) | 46 objects, 0 failing |
| Nothing in the water (`water-check.json`) | 235 objects, 0 overlaps |
| Import chunks under 10k (`import-chunks.json`) | 249 chunks, 0 over |

## Not verified

- No FBX export and no Studio import. Chunk count, collision and texture behaviour in Roblox are untested.
- **Skybox face orientation.** The six faces are generated with a stated convention (in `generate_sky.py`), but I have not checked it against Roblox's `Sky`. If the seams do not line up in Studio, faces need rotating or swapping; the images themselves are consistent with each other.
- The night look is a Blender render. Roblox lighting will differ.
- Scroll speeds and animation notes are starting values, not tested.
- The rotunda clearance is measured from the geometry, not walked by an avatar.
- The perimeter wall was not tested against jumping or climbing.
- Pet walkability was not re-run; moving the fences in by 3 studs slightly narrows the lawn strip along the open edge.

## Renders

Day: `01-overview-day`, `02-spawn-view-day`, `03-hub-day`, `04-hub-stations-wide`, `05-rotunda-interior`, `06-rotunda-entrance`, `07-blossom-trees`, `08-blossom-tree-from-below`, `09-edge-fence-and-rocks`, `10-edge-from-outside`, `11-waterfall-tumble-falls`, `12-waterfall-sky-falls`, `13-cave-blocker`, `14-top-down-map`, `15-side-floating`, `16-sky-and-distance`.
Night: `20-overview-night`, `21-hub-night`, `22-spawn-view-night`, `23-grotto-night`, `24-side-floating-night`.
Comparisons: `30-compare-overview-v6-left-v7-right`, `31-compare-overview-day-left-night-right`.
