# The Hidden Grove: world framing mockup

Fable, 2026-11-28. For Spencer's morning review. Nothing here is built in Studio; the place was not touched.

Spencer: "the place [should] feel like a hidden away grove, not a floating island ... a lot of verticality and variety surrounding us in the non-playable area", then: "not darker, make it match the aero theming".

## Look at these first

| Before | After |
|---|---|
| `before-garden.png` (same camera, today's island and sky) | `mockup-garden.png` the player's usual view from the hub lawn |
| `before-wide.png`, `before-ingame-island-above.jpg` | `mockup-wide.png` the whole hollow from the sun gate |
| `before-ingame-hub.jpg`, `before-ingame-falls.jpg` | `mockup-within.png` from a tree-house deck |
| `before-ingame-night.jpg` | `mockup-dusk.png`, `mockup-garden-night.png`, `mockup-wide-night.png` |
| | `mockup-up.png` lying on the lawn, looking at the sky opening |

The `before-ingame-*` files are real captures already in the repo (22 to 24 November) and are the true current look. Studio's Edit workspace is empty (the world is built at run time, and Play was off limits), so `before-garden/wide.png` are Blender renders of the live `world-v7.fbx` from the mockup cameras; their colours are approximate. The mockups keep that island mesh untouched at true scale, with a blocky avatar and pet. Everything around it is procedural blockout and procedural materials (`source/`): no image generators, no downloads. The rays are drawn heavier than they should ship, and the mockup is an art target, not final assets.

## The concept

The garden stays exactly where it is. Instead of hanging in open sky, it becomes a sunlit terrace at the bottom of a deep green hollow.

- **Near band (0 to 45 studs past the rim): the moat.** The island edge becomes a low terrace over a luminous turquoise stream that circles the garden. The existing balustrade and perimeter wall still stop the player; they now read as a garden wall above water, not a drop into nothing. Sky Falls lands in the moat.
- **Mid band (45 to 160 studs): three cliff tiers with ledges.** Pale blue-white stone, stepped strata, each ledge capped in bright moss with ferns, small trees, stone lantern posts and hanging vine curtains. Four gorges carry waterfalls down all three tiers.
- **The giants.** Nine old trees, 165 to 205 studs tall, with buttress roots in the moat bank. Their crowns arch in over the rim and leave an oval sky opening above the lawn. One gap is left empty on the south-east: the **sun gate**, where the light comes in.
- **Set dressing for variety.** Six tree houses on round decks (cream walls, Aero-teal roofs, lit windows), rope bridges between them, lantern strings swagged from trunk to trunk, rock spires in the moat.
- **Far band (160 studs and out): the forest rim.** Rounded crowns against the same Aero sky and clouds, washed in white-blue haze.

**Safe and enclosed, but not dark.** Walls stand 120 to 170 studs high at 110 to 250 studs away, so they fill the middle of the screen from every lawn. The lawn itself stays in full sun: the opening is wider than the playable area, the stone is pale, the moss is lime, and the haze is white-blue. The darkest values in frame are the pets' eyes and the tree shade, never the surroundings.

## Lighting

Keep `WorldAero` as it is (ClockTime 10.5, Brightness 1.85, the `#CFEFFF` Atmosphere). Changes are additions:

- **Day:** sun through the sun gate. Raise `Atmosphere.Density` slightly only if the far tier needs more separation (white Bear rule caps it at .30).
- **Night (`mockup-dusk.png`):** magical-bright. Lanterns, tree-house windows, moat and falls glow; rays turn cool cyan from the moon (WorldNight already puts the moon where the 10.5 sun is, so the same ray cards work). Night ambient stays within the white Bear floors in `WorldNight`.
- **Animated god rays, cheap:**
  1. **Ray cards:** 7 to 9 `Beam`s from attachments in the canopy to the lawn, aligned to the sun, with a soft vertical-streak texture, `LightEmission` 1, transparency about .8, `TextureSpeed` .02 to .05 so the streaks drift. 9 draw calls at most; fade by `GardenHour` daylight; off under Reduced Motion and at budget level 2.
  2. **`SunRaysEffect`** up from .03 to about .08, only while the camera faces the sun gate.
  3. **Motes:** one `ParticleEmitter` per ray, 6 to 10 alive, the existing glint texture, drifting slowly up. Reuse the firefly rules at night.
  4. **Bubbles:** a few large soap bubbles on slow paths (the Bubble Spring's material), Aero's signature.

## Materials and textures (bright, crisp, matte)

Per Spencer's taste note the surroundings stay matte and textured so pets stand out; Aero gloss lives on water, glass, marble and bubbles only.

| Surface | Direction | How it is made |
|---|---|---|
| Stone | Pale blue-white limestone, crisp dark crack lines (the language of today's `cliff_rock`), warm cream patches, faint strata | Procedural in Blender (Voronoi edge + noise), baked to a 1024 tiling colour + normal + roughness set |
| Moss and grass caps | Saturated lime to emerald, blade-level speckle | Procedural noise bake; vertex-colour blend at ledge lips |
| Bark | Warm tan with long vertical ridges, moss on the upper sides | Procedural stretched noise, baked; normal map carries the ridges |
| Leaves | Clustered leaf shapes in three greens, light coming through | Hand-drawn leaf stamps scattered by script (like `lime-leaf.png`), one 1024 atlas, alpha cards only at crown edges |
| Water | The pool's teal tile and light net | Existing `pool-aero` and glint layers |

All from `scripts/` generators, as `build_world_finish_art.py` does today. Photo sources only with Spencer's OK per download; none are needed.

## What happens to the floating-island pieces

- **Sky and clouds:** kept. The sky is now seen through the opening; the six cloud meshes and far peaks (about 10,500 triangles) go.
- **Drift rocks, islets, underside:** removed; their budget pays for the ring.
- **Balloons (`DriftLanterns`):** kept, same nine. They rise through the sky opening, which now gives them somewhere to go; cap their height below the crowns.
- **Cliff edges and perimeter wall:** unchanged collision. The outer face is hidden by moat and bank.
- **The Dash:** the course runs on the island (east meadow, bridge, hub, west path), so nothing moves. The racers get a far better backdrop.
- **The hub, stations, den, park, falls:** unchanged. Tumble Falls and the aqueduct now join the north wall instead of ending in air.
- **Spawn:** the arrival dais view should look straight at a waterfall gorge.

## Performance budget (mobile first)

- Ring total: **45,000 triangles** on screen at worst, about 35,000 net new after removing the backdrop. In about **40 draw calls**: tiers as 8 merged wedge meshes, giants as 3 trunk variants and 3 crown variants instanced, one mesh each for vines, ferns, lanterns.
- Textures: four 1024 sets (stone, bark, leaf atlas, moss), shared by every ring mesh.
- No collision, no shadows cast from the far band; `CanQuery/CanTouch` off; `RenderFidelity` Performance beyond 150 studs.
- Lights: no new PointLights by day. At night lanterns are Neon only, plus the four nearest the camera lit (the balloons' rule).
- Budget levels as today: level 1 drops motes and half the rays; level 2 drops rays, vines and set dressing.

## Phased build plan

| Phase | What | Effort |
|---|---|---|
| 0 | Spencer picks: this direction, how closed the canopy is, tree houses yes or no | his review |
| 1 | Grey-box ring in Studio on the beta behind a switch (`grove`): moat, three tiers, nine trunk cylinders, crown blobs. Walk every lawn; check the sky opening, spawn view and phone framing. Design locks here | 1 to 2 days |
| 2 | Art pass: real tier meshes, trunks, crowns, the four texture sets, waterfalls and moat on the existing water system | 4 to 5 days |
| 3 | Light: ray Beams, motes, bubbles, night lanterns, `GardenHour` hookup, budget levels | 2 days |
| 4 | Set dressing: tree houses, bridges, lantern strings, vines, ferns | 2 to 3 days |
| 5 | Remove backdrop pieces, retune balloons, store thumbnails and listing audit when it goes live | 1 day |

About 10 to 13 working days. Beta first, behind its switch, with a row in `V3-TEST-PASS.md`.

## Open questions for Spencer

1. Is the canopy opening about right, or more sky?
2. Tree houses and bridges as pure scenery now; a reachable one later?
