# Hidden Grove art pack: build notes and critique

Fable, 2026-11-28. Built pack, not the mockup. Nothing was uploaded and Studio was not touched.

- Builder: `scripts/build_world_grove.py` (headless Blender, no .blend saved; run here on Blender 5.2.3 LTS, since `Blender 5.1` has no executable on this machine).
- Pack: `assets/world/grove/grove.fbx`, `grove-manifest.json`, `tex/grove-{stone,moss,bark,leaf}.png`.
- Renders of the built meshes with the baked textures, giants placed from the manifest's `instances`: `build-garden.png`, `build-wide.png`, `build-within.png`, `build-up.png`, `build-dusk.png` (1280x720, 48 samples). Compare with `../mockup-*.png`.
- Two runs give a byte-identical manifest. The FBX was re-imported and every mesh's triangle count, size and centre matched the manifest.

## What changed from the mockup on purpose (architect review)

| Change | Why |
|---|---|
| Names `GV_`, not `GR_` | unique to this pack |
| Moat surface at Roblox Y -26 (the mockup had -4.6) | review: at or below -25. The garden is now a mesa 30 studs over the water |
| `GV_Bank__stone` | seals the band from under the island's cliff bottoms (bank top Y -8.8; the island's lowest vertex is `W7_Rocks__cliff_rock` at Y -8.16) down to the bed and out to the first wall, so `W7_Underside__cliff_rock` can hide later. The bed is opaque under all the water |
| First wall at least 45 studs past the island's real edge | the mockup measured from an oval that the north plateau overruns by up to 48 studs. The rim here is the island's own outline (1-stud footprint of every kept island triangle), so the hollow is wider in the north |
| Far band: 8 opaque sector meshes, 534 triangles each | review: no alpha impostors |
| No alpha anywhere | crowns, ferns and vines are opaque geometry wearing the leaf tile |
| Sun gate turned to the 10.5 sun (azimuth 40.7 degrees from +X toward +Z, elevation 61.3) | the mockup's sun stood 33 degrees further south. Giants moved; the gap runs 275 to 371.5 degrees |
| Shore moss mesh dropped, lanterns in one mesh, small trunks painted | to land on exactly 40 groups |

## Against the mockup

Matches:
- The read from the lawn (`build-garden`): pale cracked limestone walls filling the middle of the frame, lime ledge lines, giants rising past the top of the screen, crowns closing overhead, lawn in full sun. Stone is the brightest large surface, as intended; nothing in the ring is darker than the island's own trees.
- The whole hollow (`build-wide`, `build-within`): three stepped tiers, four gorges with falls down all three, turquoise moat, spires in the water, tree houses with lit windows, bridges, lantern strings.
- The sky opening (`build-up`): an oval ring of crowns with the sun gate open. Nearest crown 71.7 studs from the centre; mean radii 106 x 108.

Off, in order of how much it shows:
1. **Crowns are lumpier and thinner than the mockup's.** 64-triangle clumps against the mockup's 320. From the lawn they read as separate balls with flat facets, and the underside tint is doing most of the work. The mockup's hanging vine strings under the crowns are gone over the garden (kept only on outward boughs) to protect the balloon clearance.
2. **Walls are further and plainer.** Wall one stands 47 to 60 studs past the true edge and the strata are 3 or 4 clean steps a tier. The mockup's chunky block noise on the walls is only a 1.2 stud jitter here. Moss treads read as thin green lines, not capped shelves.
3. **Ledge trees are lollipops.** Two or three balls on a five-sided stick, with painted (untextured) trunks.
4. **Tree houses are small at this distance** (about 70 studs past the rim, 20 to 45 above the lawn). They read at dusk by their windows more than by day. Three bridges, not the mockup's four or five.
5. **Bark moss is in blotches**, not "on the upper sides": a tile cannot know which way is up. On a near trunk (`build-wide`, right edge) the blotches look large.
6. **Ray cards look like planks at dusk** in the render. That is the stand-in material; the real ones are Beams. They are thinner than the mockup's by design.
7. `build-wide` is not the mockup's exact camera: the mockup's eye point is now inside giant 9, so it moved 37 studs along the rim.

## Textures (1024, colour only, tiling, drawn in numpy inside Blender)

| Set | File | Studs per tile | Texels per stud | Mean sRGB |
|---|---|---|---|---|
| stone | `grove-stone.png` | 32 | 32 | .81 .85 .88 |
| moss | `grove-moss.png` | 16 | 64 | .33 .71 .17 |
| bark | `grove-bark.png` | 24 | 42.7 | .72 .62 .39 |
| leaf | `grove-leaf.png` | 24 | 42.7 | .21 .54 .15 |

Stone walls and trunks are mapped round their own axis (whole tiles round the ring or the trunk); everything else is box-mapped at the tile's scale. Water (`GV_Moat__water`), falls, props and lanterns carry no texture: water takes the existing pool look, the rest are vertex-coloured.

## Triangles

| Mesh | Band | Triangles | Instances | Past the rim (studs) |
|---|---|---|---|---|
| GV_Bank__stone | near | 2,880 | 1 | under the island's skirt |
| GV_Moat__water | near | 288 | 1 | under the skirt |
| GV_Tier1__stone | mid | 1,152 | 1 | 47.0 |
| GV_Tier1__moss | mid | 1,440 | 1 | 47.8 |
| GV_Tier2__stone | mid | 864 | 1 | 76.3 |
| GV_Tier2__moss | mid | 1,152 | 1 | 77.5 |
| GV_Tier3__stone | mid | 864 | 1 | 110.7 |
| GV_Tier3__moss | mid | 1,152 | 1 | 112.2 |
| GV_Falls__fall | mid | 384 | 1 | 60.5 |
| GV_Rocks__stone | mid | 903 | 1 | 61.5 |
| GV_LedgeTrees__leaf | mid | 3,024 | 1 | 52.3 |
| GV_Dressing__leaf | dressing | 1,776 | 1 | 58.6 |
| GV_Props__paint | dressing | 2,272 | 1 | 43.8 |
| GV_Glow__glow | dressing | 2,080 | 1 | 44.1 |
| GV_Far_1..8__leaf | far | 534 each | 1 each | 129 to 141 |
| GV_Giant_TrunkA/B/C__bark | giant | 630 each | 3 each | roots and boughs reach to 27 inside the edge, high up |
| GV_Giant_CrownA__leaf | giant | 1,424 | 3 | overhangs up to 25 |
| GV_Giant_CrownB__leaf | giant | 1,360 | 3 | overhangs up to 30 |
| GV_Giant_CrownC__leaf | giant | 1,360 | 3 | overhangs up to 44 |

**Total on screen: 42,605 triangles** (budget 45,000), 30,537 unique. 28 meshes, 18 instances, **40 groups** (22 static + 18; budget 40). Largest mesh 3,024 (budget 10,000); far sectors 534 (budget 2,000).

Checks the builder asserts: no ring vertex over the island except crowns and boughs above Roblox Y 130 and the bank under the skirt (0 found); every mid and far mesh at least 45 studs past the edge; canopy underside over the island Y 133.3; the sun inside the gate; every ray foot on the island, 13 studs up, clear of the EggDome and the falls.

## For the runtime and upload lanes

- The dressing meshes (props 43.8, lanterns 44.1 studs) sit just inside the 45 stud line: the deck rims and lantern strings on the giants. Only mid and far are held to 45.
- `sun.verified` is false. The direction is computed, not read from Studio. Check `Lighting:GetSunDirection()` at ClockTime 10.5 against `sun.dir` before trusting the rays and the gate.
- `turnApplied` is false. The pi turn is not baked; the two CFrame recipes are in `importTurn`. Check a LookVector first.
- Lanterns are one mesh with warm and aqua vertex colours. If Neon ignores vertex colour they will all take the part colour.
- `W7_Crystals__*` and `W7_Water__waterfall_sky` hang below the island (to Y -90 and -68) and now pass through the moat surface. They are not in `hides`; the Sky Falls cut is the runtime's (review point 3).
- `canopyBottomY` is 133.3. The `high_falls` balloon top has to stay under it.

## In-game pass (later on 2026-11-28)

The pack was rebuilt after the first in-game captures: see `../INGAME-CRITIQUE.md` for what changed, what to re-upload and the runtime values. Where it differs, that file is the current one. In short:

- `grove-stone.png` rebaked warm (mean .89 .87 .82); the tier walls carry block tone and foot shading in their vertex colours.
- `GV_Bank__stone` is a plinth that meets the island's cliff feet (cap Y -4, shoulder Y -6.5); `W7_Underside__*` moved to `hides`. Its faces were inside out in places; fixed.
- Vine curtains became 144 tapered strands that lie on the rock; ferns moved to the lips (60).
- Lanterns are 1.6 to 2.2 studs in radius. Rays are 15 to 22 studs wide at the lawn, with their own texture `tex/grove-ray.png`.
- Wall block offsets corrected (no tread faces down).
- Total on screen 44,849 triangles (budget 45,000), 32,781 unique; `GV_Bank__stone` 3,168, `GV_Dressing__leaf` 3,744, `GV_Props__paint` 2,260; the rest as in the table above.
- New review renders: `build-skirt.png`, `build-skirtb.png`, `build-cove.png` (the island's foot). All `build-*.png` here are from the rebuilt pack.
