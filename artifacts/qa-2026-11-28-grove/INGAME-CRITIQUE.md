# Hidden Grove: critique of the first in-game captures

Fable, 2026-11-28. Read from `studio/ingame-hub-day.jpg`, `ingame-wide-day.jpg`, `ingame-sungate-day.jpg`, `ingame-hub-night.jpg`, against `mockup-*.png` and `build/build-*.png`.

Two parts: what the art pack changed (built, in this commit, needs re-upload) and the runtime values for the implementer (nothing in `src/` was touched). Nothing here was seen in Studio: the art was checked in Blender renders only, so every runtime number below is a first value to capture and judge, not a verified look.

## Verdict on the five reads

| # | Read | Verdict |
|---|---|---|
| 1 | Stone goes sky-blue and icy | Agreed. The cause is the bake, and the fix is the bake. The tile was already cool (mean #CFD9E0, blue-grey cracks) and WorldAero's haze and blue sky light pushed it the rest of the way. Rebaked warm. Part colour cannot fix it (see below). |
| 2 | Vine curtains read as floating green squares | Agreed, and it was two faults: flat cards up to 6.4 studs wide, and hung 3 studs clear of the lip on a drop longer than the stratum under it, so the next tread cut them off square. Rebuilt as strands. |
| 3 | God rays almost invisible | Agreed. The strand texture covers about a quarter of the card, so at .8 clear the shaft added about 5 percent. New texture and numbers below. |
| 4 | The underside still hangs over the moat; does the bank seal it? | **No, the uploaded bank did not seal it, for three measured reasons.** Fixed in the mesh; the underside is now in `hides`. Details below. |
| 5 | Anything else | Two real mesh bugs found (holes), lanterns too small to read, and notes on banding, falls, moat and night. |

## What changed in the art pack

Rebuilt with `scripts/build_world_grove.py`. 44,849 triangles on screen (budget 45,000), 28 meshes, 18 instances, 40 groups, largest mesh 3,744. No mesh was added, removed or renamed. Two runs give a byte-identical manifest.

### Re-upload exactly these

Meshes (11 of 28):

| Mesh | Why |
|---|---|
| `GV_Bank__stone` | the plinth; faces turned the right way out (2,880 to 3,168 triangles; size and centre changed) |
| `GV_Moat__water` | inner edge follows the corrected bank ring (same count and size) |
| `GV_Tier1__stone`, `GV_Tier2__stone`, `GV_Tier3__stone` | block tone and foot shading in the vertex colours; block offsets corrected |
| `GV_Tier1__moss`, `GV_Tier2__moss`, `GV_Tier3__moss` | same block offsets: no tread turns face down now |
| `GV_Dressing__leaf` | lip ferns and vine strands (1,776 to 3,744 triangles) |
| `GV_Glow__glow` | larger lanterns |
| `GV_Props__paint` | lantern hangers follow the larger lanterns (2,272 to 2,260) |

Until the new upload's readback is recorded, `python scripts/build_world_grove_assets.py --check` answers `REFUSED: grove.fbx is not the uploaded file`. That is the gate doing its job (the manifest passes its contract); the committed `GroveKit` and `WorldGrove` still describe the old upload.

Unchanged (same hash, keep the uploaded ones): `GV_Falls__fall`, `GV_Rocks__stone`, `GV_LedgeTrees__leaf`, `GV_Far_1..8__leaf`, all six `GV_Giant_*`.

Textures:

| File | State |
|---|---|
| `tex/grove-stone.png` | **changed**, re-upload |
| `tex/grove-ray.png` | **new**, upload (256 x 1024, white with alpha) |
| `grove-moss.png`, `grove-bark.png`, `grove-leaf.png` | unchanged |

Manifest data that changed with them: every changed mesh's `size`, `center`, `hash`; `lanterns` (same 86, new positions and radii); `rays` (wider); `hides` (three more names); `keeps` (now empty); `moat` (`bankTopY` -4, new `shoulderY` -6.5 and `cliffFootY` -5); `textures.ray`; `totals`. `instances`, `falls`, `bubbles`, `sunGate`, `opening` and `canopyBottomY` are identical.

### 1. Stone

- Tile mean went from #CFD9E0 to #E2DED1: warm white base, cream patches over about twice the area, a few cool patches kept so it is not beige, cracks from blue-grey #667D94 to neutral #666366 and a third wider, hairlines stronger.
- The tier walls now carry vertex colours: each riser block has its own tone (up to 6 percent down, slightly warm) and a soft shadow at its foot (#E6E3DE at the foot to white at the top). The ring casts no shadows, so this is what gives the strata any form. It also breaks the flat banding.
- Brightness: the tile itself is about 3 percent brighter than before; the vertex shading takes about 8 percent off the tier walls, so they net about 5 percent down, in exchange for form. If that reads darker in game, say so and I lift the foot shade.

### 2. Vines and ferns

- 48 bundles of three strands (144 strands). Each strand is a three-sided tube, .4 to .55 studs thick at the top and tapering to a point, with three pointed leaves. It starts on the tread behind the edge, bends over it, and lies .55 studs off the rock face.
- Each strand ends above the foot of its own stratum (45 to 92 percent of that stratum's height, at most 22 studs), and its points are taken from the wall mesh itself, so none floats and none is cut by a tread.
- Ferns went from 100 scattered over the ledges (mostly hidden from the lawn) to 60 along the lips, a little larger, where they break the wall's top edge.
- No alpha. The crown vines on the giants were left alone: they read as thin lines in the captures.

### 4. The island's foot

Measured in Blender against the island FBX:

- The island's rim cliffs end at Roblox Y -5.0 all the way round (-4.0 in a few places). The uploaded bank's top ring was at Y -8.8 and 3 to 7 studs inside the edge. That left an open slot 3.8 studs high right round the island.
- On the uploaded bank, 243 of the 772 island-side triangles above the water (31 percent of that area) were inside out. In game a mesh is single-sided, so they were holes. These are the cyan triangles at the waterline in `ingame-wide-day.jpg`: the water plane seen through the bank.
- At one bearing (Roblox +Z side, about 270 degrees in the builder's angles) the bank's top ring collapsed to the centre of the island.
- `W7_Underside__cliff_rock` runs from Y -0.2 down to Y -120 and stands 2 to 5 studs outside the island's edge at the top. That grey cone is what the wide capture shows; the bank was mostly inside it.

The bank is now a plinth:

- a flat cap at Y -4.0, from 14 studs in under the island out to 3 studs inside its edge. It sits 1 stud above the cliff feet and inside the cliff shell (least cover over any cap vertex: .72 studs; the builder asserts it);
- a shoulder at Y -6.5, at least 1.5 studs past the island's edge, 1.5 studs below the cliff feet. No sight line passes under the cliffs: it meets the cap or the shoulder slope first;
- then down to the bed as before. Cap and shoulder are tinted moss green in the vertex colours, so the island stands on a mossed limestone foot.

`build/build-skirt.png`, `build-skirtb.png` and `build-cove.png` look at the foot from the moat, from above and across a cove from the lawn. A check render (`--void-check`, the back of every single-sided mesh in a flat colour) found no back face from six cameras.

`hides` now lists `W7_Underside__bark`, `W7_Underside__cliff_rock` and `W7_Underside__foliage`.

**Not verified:** that the island holds up in game without its underside. The Blender renders (which never had it) show the island's own cliffs whole down to Y -5, but they are not the Studio parts. After the bind, orbit the island's rim once at lawn height and once from the moat. If a gap shows, put `W7_Underside__cliff_rock` back (drop it from the hide list) and tell me where; the plinth is still the better foot with it in place.

### 5. Other mesh fixes

- **Treads turned face down.** The wall block offsets were meant to run plus or minus 1.2 studs and ran -3.6 to +1.2 (a noise range read wrong). On the uploaded tiers 24 moss tread triangles came out narrower than nothing and faced down (a few on the bank too): thin see-through slivers along some strata. Corrected; the builder now asserts no terrain triangle faces down.
- **Lanterns.** A 1 stud ball is a dot at 150 studs, which is why the night capture shows almost none. String lanterns are now 1.8 studs in radius, posts and decks 2.2, bridge lanterns 1.6. Same triangles.

## Runtime values for the implementer

### A. Stone material and colour

| Property | Now | Set |
|---|---|---|
| Part `Color` on every textured `GV_` mesh | white | **white, no change** |
| `Material` on meshes with texture `stone` | Plastic (256) | `Enum.Material.Concrete` (816), in `xml_part` of `scripts/build_world_grove_assets.py` |
| `Material` on `moss`, `leaf`, `bark` | Plastic | no change unless a capture shows sheen |
| `Reflectance` | 0 | 0 |

- A part colour tint is not a lever here. I expect a MeshPart's `Color` to do nothing to an opaque `TextureID`; the tinting is in the vertex colours, which do multiply. If Studio shows otherwise, still leave it white.
- Concrete is for matte, not for colour, and it is the second-order fix. Check it on `GV_Tier1__stone` at ClockTime 10.5 against Plastic before committing: keep it only if the wall loses the sky sheen and the material's own grain does not fight the drawn cracks. If it does, stay on Plastic.
- Do not touch the Atmosphere. If the walls still read blue after the rebake, tell me: the next step is in the bake (base toward #F7F0E0), not in Lighting.
- Night: no value change asked. The warmer tile takes some of the periwinkle out under the #5A6FB8 atmosphere. The walls will still be the brightest thing at night, which matches "not darker"; judge it again once the larger lanterns are in.

### B. God rays (`Light.Ray` in `src/client/GroveLight.lua`)

| Field | Now | Set |
|---|---|---|
| `texture` | `Values.Waterfall.Textures.Strand` | the uploaded `grove-ray.png` (`textures.ray.color` once the readback carries it) |
| `length` (`Beam.TextureLength`) | 60 | **140** (`textures.ray.studsPerTile`) |
| `emission` (`Beam.LightEmission`) | 1 | **.7** |
| `LightInfluence` | 0 | 0 |
| `speed` (`Beam.TextureSpeed`) | .035 | **.015** (the same drift in studs as today: .035 x 60 / 140). The shaft must never look like it flows: a tile should take a minute or more |
| `day` | #FFF2D2 | #FFF2D2 |
| `night` | #9FE8FF | #9FE8FF |
| `Beam.Width0` / `Width1` | data `w0` / `w1` (5 to 9 / 9 to 16) | data, unchanged code: now 7.6 to 10.9 at the canopy, 15.1 to 21.8 at the lawn |
| `Segments`, `FaceCamera`, `TextureMode` | 1, true, Wrap | no change |

Transparency, replacing the flat `clear` .8 with `edge` .12. `Attachment0` is the canopy end. At weight 1:

| Key (along the beam) | Day | Night |
|---|---|---|
| 0 | 1 | 1 |
| .10 | **.52** | .71 |
| .55 | **.60** | .76 |
| .86 | **.82** | .89 |
| 1 | 1 | 1 |

At weight `w` each value is `1 - (1 - value) * w`, as `Light.rayClear` does today.

- Why these: the new texture's mean alpha is .37 and its brightest band .92. At .52 clear the shaft adds about 18 percent on average and 44 percent in its brightest band under the canopy; at the lawn end about 7 and 17 percent. The old set added about 5 percent everywhere.
- The foot key is what protects the lawn. If the grass under a ray's foot goes white, raise the .86 key to .9 before touching anything else. If the shafts vanish against the pale walls, lower `emission` toward .5 (more veil, less glow) before lowering the transparency.
- The texture: image Y runs along the beam and tiles; X runs across it with clear edges. Same convention as `water-strand.png`.

### C. Underside

- `hides` now carries the three `W7_Underside__*` names, so no code change if the hide list comes from the data.
- `scripts/Grove.spec.lua:128` asserts `W7_Underside__cliff_rock` is not hidden, and line 463 uses it as the kept backdrop piece. Both need to follow.
- The comment in `src/shared/Grove.lua` and ARCH-REVIEW-GROVE point 2 ("keep the underside until a bank seals the band") are now answered by the plinth.

### D. Lanterns

- `lanterns` in the data moved and grew. If `GroveWorld.lanternKind` matches lanterns by position, rebind from the new manifest; nothing else changes.

## Left as it is, on purpose

- **Crowns.** In the mockup they are rounder. In game the faceted clumps match the island's own trees, and the canopy opening is approved. No budget left for more triangles there (each crown triangle counts three times).
- **Moss lines on the walls.** Still thin lime lines from the lawn. They are the tread lips seen edge on. The vertex shading and the vines break them up; a thicker moss cap would need triangles the budget does not have.
- **Gorge falls.** Flat pale sheets in the captures. The moving Beam layer is the runtime's and only runs at level 0 off touch devices; judge it in motion before changing the mesh.
- **Moat colour.** It read the same blue as the walls. With warm walls it should separate without a change. If it still merges, the pool look's colour is the lever, not the mesh.
- **Bark.** Light and a little chalky in the haze. A deeper bake is one texture upload if wanted; held back because the direction says not darker.
