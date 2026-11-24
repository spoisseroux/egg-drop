# Sleepy Nest landmark: build plan (Opus, island session, 2026-11-24)

Spec: `NEST-LANDMARK-LOOK.md` (Fable). Branch `claude/nest-landmark` from feat 7e68213. The egg machine's pipeline:
Blender script from code (no AI mesh, no samples), one numpy-painted 512 px texture, Fable renders before export, one
FBX uploaded as a Model through a gate that writes the template and its data. Ask before Studio. No publish.

## Pieces

| Script / file | What |
|---|---|
| `scripts/build_nest_landmark.py` | Background Blender, `--factory-startup`. Builds the 5 meshes in nest-local Roblox studs (origin on the ground at the bowl's centre, **front -Z**, +X west, as `NestClient`), writes `assets/world/nest-landmark/nest-landmark.fbx` + `nest-landmark-manifest.json`; `--render` writes Fable's renders (front, three-quarter, path mouth x empty / tucked / ready, plus one beside the machine at scale) to `artifacts/qa-2026-11-24-beta16/nest-landmark/`. Asserts the triangle cap and outward winding. |
| `scripts/draw_nest_landmark_texture.py` | The 512 atlas (bowl stoneware with band moons and dots, tide line, chips; leaf; collar lobe; feet green; twig bark; straw; crook; moon paper with sunflower edge; cord; quilt; mat coil) and a 64 px roughness map in the same layout (bowl .8, blanket .9, the rest .85). |
| `scripts/nest_landmark_assets.py` | The gate, the machine's: `record` (readback after upload), `--confirm` writes `assets/world/NestLandmark.rbxmx` + `src/shared/NestLandmarkData.lua`, `--check`. Binds FBX and manifest by hash; nested `.gitattributes` keeps its JSON LF. |

## Template contract (for the code side)

Model `NestLandmark`, every part placed nest-local (CFrame relative to the origin, the import's pi turn baked in):

| Part | Mesh | Collision | Finish | Pivot (data module) |
|---|---|---|---|---|
| `Body` | feet, bowl, band, collar, woven nest + twig ends, straw bed with the egg dent, crook, sign rope loops, pet mat | none (CanCollide/CanQuery false) | SurfaceAppearance (atlas, roughness map) | origin |
| `Awning` | 3 leaves from the crook's apex, back half only | none | SurfaceAppearance | `awning` = the crook's apex (sway about it) |
| `Moon` | crescent + cord | none | TextureID on SmoothPlastic, so `Color` can lift it at dusk / ready | `moon` = the crook tip, the cord's top (sway about it); `moonLight` = the crescent's centre |
| `BlanketDraped` | over the egg's front and sides to 45%, spills 0.5 over the front rim | none | SurfaceAppearance | `blanketEdge` = its lower front edge (unrolls from it: scale Y .2 to 1) |
| `BlanketFolded` | 1.1 x 0.8 x 0.35 on the rim at (-1.5, 2.75, -1.1) | none | SurfaceAppearance | its centre |
| `Collider` | a plain Part (no mesh), the bowl and nest: 4.8 x 2.75 x 4.8 at y 1.375 | Box, CanCollide | Transparency 1 | n/a |

- **Pivot without WorldPivotData:** `Collider` is the Model's `PrimaryPart` (a Ref, which Rojo writes) with `PivotOffset` =
  its own CFrame inverse, so `Model:GetPivot()` is the origin and `PivotTo(spot)` places it. No code fix-up needed.
- Why a `Collider` and not box collision on `Body` (the machine's way): the body's bounds include the crook (6.6 up) and
  the pet mat (out to -3.1, -2.0), so its box would wall the Bear's mat and stand 6.6 high. The spec's open item
  ("raise the collision box to 4.4 if standing in the nest looks bad") becomes one number.
- Egg: today's code egg at 1.3 (not in this template). The data gives `eggBase` 2.15 and the bed's dent centre.
- Data module `NestLandmarkData`: assetId, model, names, size, front (0, 0, -1), pivots (above), eggBase, dent,
  moonLight, sign (centre, tilt) and the rope loops, mat (centre, radius), bearSpot (-2.9, 0, -2.0), triangles.
- Coordinates match the spec's root-local table, so `NestClient` constants (pill 5.2, prompt -3.5, pin 8.2) stay theirs.

## Budget

Body about 2,900, Awning about 200, Moon about 150, BlanketDraped about 420, BlanketFolded about 150: about 3,800 in
the template; with the code egg (cap 320) and code parts (60) under 4,400. The script asserts 5,000.

## Not in this slice

Wiring (`NestClient`, `Nest.Block`/`Front`, the switch, motion, states, light move): the code side. Studio (upload,
readback, placement captures): after the coordinator's go.

## Risks

- Twig ends and the woven ring are geometry: winding checked by an assert (no back faces from the front), as the dial.
- SurfaceAppearance cannot be parented at runtime: authored on the template (the machine's lesson).
- The moon is the one TextureID part: its roughness is the material's, not the map's.
