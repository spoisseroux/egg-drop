# Egg Drop — 3D art handoff for v1

Written for Spencer, 11 November 2026. This lists every 3D asset v1 needs from you, how to build each one so it drops into the game cleanly, and what Claude does on the Roblox side. Track progress in [TODO.md](TODO.md) under **Garden environment** and **3D asset cleanup**.

**Order of work:** first the Blender template and the test cube (30 minutes). Then horns, claws and wings, because they're small and they prove the pipeline. Then the pet tweaks. The environment kit comes last, after Claude's greybox is approved.

---

## 1. Set up Blender once

1. **Units.** Scene Properties → Units: **Unit System = None**, **Rotation = Degrees**. One Blender unit = one Roblox stud.
2. **Axes.** Model with the character's face toward **−Y** (Blender's Front view, numpad 1) and **Z up**. That's Blender's default. Don't rotate models to "fix" Roblox's axes; the export preset handles it.
3. **Reference figures.** Keep these in a hidden collection in every file:
   - A **5.5-unit-tall** box or mannequin standing in for an R15 avatar.
   - A **1.5-unit** box for a baby's visible body height.
4. **FBX export preset.** Save it as **"Roblox"**:
   - Selected Objects only.
   - Object types: Mesh, plus Armature only when the asset is rigged.
   - Forward / Up axes as listed on Roblox's export-settings page (linked below), **Apply Scalings = FBX Units Scale**, Apply Transform on.
   - Smoothing: **Face**.
   - Leave Bake Animation off unless you're exporting an animation.

   ([Roblox Blender export settings](https://create.roblox.com/docs/art/modeling/export-requirements), [Blender page](https://create.roblox.com/docs/art/blender))
5. **Test cube.** Export a 1 × 1 × 1 cube with its origin at the bottom centre. Import it in Studio with the [3D Importer](https://create.roblox.com/docs/studio/importer), scale unit **Studs**. It must arrive at **Size 1, 1, 1** with its pivot on the floor. If it arrives at 100, the preset is wrong. Our earlier pet imports came in at 100× because of exactly this. Also export a cone pointing toward −Y: in Studio it must point the same way an inserted R15 dummy faces. If it doesn't, change the Forward axis in the preset.
6. **Before every export:** apply scale and rotation (Ctrl+A → All Transforms), recalculate normals outward, delete loose vertices, and check that every mesh has UVs.

## 2. Pivots matter: rules for each asset type

The pivot (the object origin in Blender) is where Roblox scales, rotates and attaches a mesh. The code places features, toys and pets by their pivot, so a bad pivot shows up as something floating, sinking or spinning around the wrong point.

| Asset | Where the origin goes |
|---|---|
| Pet (whole model) | On the ground, centred between the feet (`PawsOrigin`) |
| Pet body parts | Leave each part's origin at the shared pet origin, so the parts line up on import |
| Horn, claw, wing | At the **base**, where it meets the body, with the piece growing along **+Z** (horn), forward along **−Y** (claw) or outward along **+X / −X** (wing) |
| Toy | At its centre, unless it is held (Sparkler: at the bottom of the grip) |
| Prop / station / tree / lantern | Bottom centre, on the ground |
| Environment chunk | A shared world origin (0, 0, 0) for all chunks, so they snap back together in Studio |

## 3. Pets: hand tweaks on the four v1 babies

The v1 roster is **Zivvi, Ovelle, Nuum, Tikket**. Their account IDs stay `pip`, `puddle`, `orbit` and `wick` internally. Source files:
- `assets/garden-babies/garden-babies.blend` (Zivvi, Ovelle)
- `assets/garden-babies/new-five-2026-11-09/five-garden-babies.blend` (Nuum, Tikket and the retired three)

Rules that keep the hue system and code working:
- **Keep the mesh split and names.** Each pet is a set of separate single-material meshes: `Zivvi__Body`, `Zivvi__Head`, `Zivvi__EyeL`, `Zivvi__HandR`, `Zivvi__CharmDot` and so on. The game recolours each named part, so don't merge parts, rename them or add new ones without telling Claude. You can reshape anything inside a part.
- **Keep the scale.** About 1.35–1.65 studs of visible body, against the 5.5-stud avatar.
- **Keep the origin and facing:** origin between the feet, face toward −Y.
- **Keep the paint flat.** Body colour comes from the game, so leave meshes untextured (flat material) unless you want painted detail. Painted detail must be a **near-white or grayscale** colour map, because Roblox tints a texture by multiplying it ([SurfaceAppearance tinting](https://create.roblox.com/docs/art/modeling/surface-appearance)). The Gloss and Matte finishes are already separate SurfaceAppearance templates that the game applies on top.
- **Stay within the triangle budget:** under about **4,000 triangles per pet** across all its parts. Up to seven pets can be on screen at once on a phone.
- **Deliver** the updated `.blend` plus one FBX per pet. Claude re-imports, re-runs the import checks and compares old and new captures at noon and at night.

## 4. Horns, claws and wings

**How the code uses them today:** primitive spheres that the code places on each side of the pet. The size scales with the pet's **head width**, and there are **5 growth stages**. The same set fits all four pets.

**What to build:**
- **One shared set for all pets.** The code positions and scales them per pet, so don't make a version for each pet.
- **Make both left and right as separate meshes.** Roblox can't mirror a mesh with negative scale. Model the right side, then duplicate and mirror it in Blender (Ctrl+M → X, then apply). Name them `Horn_R` and `Horn_L`, `Claw_R` and `Claw_L`, `Wing_R` and `Wing_L`.
- **Build at the fully grown stage 5 size.** The code scales stages 1–4 down from it. If a stage-1 bud should look different, not just smaller, add an optional `Horn_Bud_R` / `Horn_Bud_L`.
- **Split each piece by colour role.** The base takes the pet's secondary hue and the tip is ivory, so give each its own mesh: `Horn_R_Base` + `Horn_R_Tip`, `Wing_R_Root` + `Wing_R_Fan`, `Claw_R_Base` + `Claw_R_Nail`.
- **Model at head width = 1 unit.** Current proportions:
  - Horns rise about **0.25** with a collar about 0.09 wide.
  - Claws stick out about **0.15**; there are two nails per hand.
  - Wings spread about **0.30** per side.

  Bigger is fine; tell Claude the intended stage-5 size.
- **Budget:** 200–600 triangles per piece.
- **Wings that flap:** keep the origin at the shoulder joint. Claude animates the flap in code by rotating around that pivot, so no armature is needed.

## 5. Toys

The toys are **Ball**, **Bone** and **Sparkler** (with three little spark tips that Claude animates separately, so make them separate meshes `Spark_1`–`Spark_3`). Today they're sized relative to the pet's body height: the ball is about 0.24 of it and the bone about 0.33 long. Model at body height = 1 unit, origin at the centre (the Sparkler's at the base of its grip), 300–1,000 triangles each. Colour regions can be separate meshes, or one mesh with a small colour texture. Toys aren't hue-tinted, so full-colour textures are fine.

## 6. Hub stations and props

These are code-built today from primitive Parts. Replace them in this priority order:

1. **Care machine:** pet bay, controls, screen. One model, origin at bottom centre. Keep the bay opening at least 2 × 2 × 2 studs.
2. **Hatch tree:** the landmark players hatch at.
3. **Workbench** (deck styling) and **journal stand**.
4. **Lanterns** (they glow at night), **bench**, **signpost**.
5. **Small set dressing:** a rock set (3–5 sizes), bushes, flower clumps, stepping stones.

Each prop: origin on the ground, under about 5,000 triangles, and any glowing part as its own mesh so it can use Neon or an emissive mask.

## 7. The garden environment

### The reference
`Downloads/chao-garden.zip` contains a low-poly Chao Garden OBJ with a sky box, a sea plane, a cliff ring, the garden floor, a pond and stepping pillars. Claude measured it with flat, untextured renders: [top](artifacts/garden-reference-2026-11-11/reference-layout-top.png) · [perspective](artifacts/garden-reference-2026-11-11/reference-layout-perspective.png). Use it for **layout and proportion only**. Don't import its mesh or textures; they're Sega's.

What it shows (source units → our studs at about ×0.5):
- **Floor:** a crescent-shaped grass floor about 464 × 357 → **about 230 × 180 studs** playable. Today's garden is 160 × 176.
- **Cliffs:** wrap the north and east sides and rise about 125 → **about 60 studs**, with a gap or cave in the north wall.
- **Pond:** on the west side, about 67 × 132 → **about 35 × 65 studs**, with the floor ringed by a raised lip.
- **Stepping pillars:** on the far west, 10–100 → **5–50 studs** tall. In our version these become rounded stone pillars or terraced ledges, not hexagons.
- **Beyond the rim:** a sea plane below the rim and a sky box enclosing everything.

### How the environment gets built
1. **Claude greyboxes it in Studio** (Parts and Terrain) at those proportions. It includes the hub stations, walking routes, pet rest spots and phone camera views. You and Claude walk it in Play mode and agree on it.
2. **You build the final kit in Blender**, using the greybox as your underlay. It's ready (approved 2026-11-11): open `assets/art-source/environment/garden-greybox-underlay.blend`, or append its `GreyboxUnderlay` collection into your scene (File → Append), or import `garden-greybox.obj` with the default OBJ settings. It is in studs, centred on the garden origin, with north = Blender +Y and the sea to the south (−Y). Model over it, then hide or delete the underlay before export.
3. **Claude imports it**, sets collisions, wires materials, and rebuilds the pet walking map and route data for the new ground.

### The kit to model
| Piece | Notes |
|---|---|
| Ground chunks | Split the floor into **4–8 chunks** that share one world origin. Each under 10k triangles. Bake slopes into the mesh; keep walkable slopes under about 35°. |
| Cliff wall | 3 straight variants + 1 inside corner + 1 outside corner, about 60 studs tall, overlapping so seams hide. |
| Cave mouth | One arch set into the north cliff. A shallow blocked interior is fine for v1. |
| Terraces / ledges + ramps | 2–3 levels; ramps at least 8 studs wide. |
| Pond basin + island | Basin mesh with a lip. Water is a separate flat mesh (see materials). |
| Waterfall | A curved strip mesh down a cliff face, plus a foam ring at the bottom. Claude adds scrolling texture and mist particles. |
| Creek crossing / bridge | Small bridge or stepping stones. |
| Landmark tree | One big tree, visible from anywhere in the garden. |
| Trees, bushes, rocks, flowers | Reusable, origin on the ground. |
| Sky | A painted sky (six cube faces, 1024² each) or a gradient. Sky textures go into Roblox's `Sky` object, not onto a mesh. |
| Sea plane | A large flat plane below the rim. |

### Environment rules
- **Roblox limits:** about **20,000 triangles per mesh** ([meshes](https://create.roblox.com/docs/parts/meshes)) and **1024 × 1024** maximum texture size. Larger meshes must be split.
- **Collision:** walkable chunks use **PreciseConvexDecomposition**; decorations use Box or no collision. Claude sets this, but keep walkable surfaces as clean, closed shapes.
- **Tiling vs painted materials.** For big surfaces (grass, rock, path), use **tiling materials** (MaterialVariant). For hero props, use **painted or trim-sheet textures** (SurfaceAppearance). See section 8.
- **Lighting is Roblox's.** Don't bake lighting or shadows into textures. Roblox lights everything in real time and the game has a day/night cycle. A light painted ambient-occlusion tint in the colour map is fine.

## 8. Materials and "shaders" in Roblox

Roblox has **no custom shaders**: no shader graph, no toon shading, no vertex shaders. The look comes from your models and textures plus these built-in tools:

| Tool | What it does | Use it for |
|---|---|---|
| **Built-in materials** | Plastic, SmoothPlastic, Neon (glows), Glass (see-through), ForceField (animated shimmer), Foil, Metal, Wood, Grass, Rock, Sand and others | Quick looks; Neon for lantern glows |
| **SurfaceAppearance** | PBR textures on one MeshPart: **ColorMap, NormalMap, RoughnessMap, MetalnessMap**, an **emissive mask** for glow, a **Color tint** and **alpha modes** (Overlay, Transparency, TintMask) | Pets' finishes, hero props, stations ([docs](https://create.roblox.com/docs/art/modeling/surface-appearance), [class reference](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance), [tint announcement](https://devforum.roblox.com/t/full-release-surfaceappearance-tinting/3129960)) |
| **MaterialVariant** | A reusable **tiling** PBR material, made in Studio's Material Manager and applied to any Part, MeshPart or Terrain | Grass, rock, path, cliff ([materials](https://create.roblox.com/docs/parts/materials), [custom terrain materials](https://create.roblox.com/docs/parts/custom-terrain-materials)) |
| **Texture / Decal** | An image on one face of a part. A Texture can tile and its offset can be scrolled from code. | Water flow, waterfall, signs |
| **Terrain** | Voxel ground and real **water** (waves, colour, swimmable) | Optional pond if swimming comes later |
| **Highlight** | An outline and/or fill glow around a model; only a limited number can be active at once | Selection outlines, a toon-ish outline on the focused pet |
| **Lighting effects** | Atmosphere, Clouds, Bloom, ColorCorrection, DepthOfField, SunRays, Blur, plus Future lighting with real-time shadows | Overall mood, already in use for day/night |
| **Particles / Beams / Trails** | 2D effect sprites | Waterfall mist, sparkles, fireflies |

**Making a textured material, step by step:**
1. In Blender, UV-unwrap the mesh and paint or bake a **ColorMap**, optionally plus Normal and Roughness maps. Save them as PNG, max 1024².
2. Export the mesh as FBX and import it with the 3D Importer.
3. Add a **SurfaceAppearance** inside the MeshPart and set its ColorMap, NormalMap and other maps by importing the PNGs.

For tiling materials, use **Material Manager** → new variant → assign the maps → set **StudsPerTile** (how many studs one repeat covers). Then pick it from any part's MaterialVariant property.

**Tutorials (official, with video):**
- [Environmental art curriculum](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/assemble-an-asset-library). This is the closest match to the garden workflow: greybox, asset library, then polish.
- [Develop polished assets](https://create.roblox.com/docs/tutorials/environmental-art/develop-polished-assets)
- [Assemble modular environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/modeling/assemble-modular-environments)
- [Materialize the world (Duvall Drive case study)](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/materialize-the-world)
- The Roblox Creator Hub YouTube channel has video versions of these curricula.

## 9. Roblox vs Unity, briefly

Roblox handles stylized, soft, pastel art well, as long as the look lives in the **models and textures**. Unity can add custom shaders, baked lighting, unlimited polygons, Shader Graph, VFX Graph and a full animation state machine; Roblox can't. Plan for a phone budget from day one: the whole garden at about **150k–250k triangles visible**, a few dozen unique textures, and Roblox handles level of detail automatically.

## 10. Hand-off format

- **Location:** put files under `assets/art-source/` (`features/`, `toys/`, `stations/`, `environment/`, `pets/`). Keep the `.blend` alongside each FBX.
- **Names:** use the names in this document; Claude matches pieces by name.
- **Pieces:** one FBX per asset or kit piece. Environment chunks can share one FBX if they share the world origin.
- **When a batch is ready:** tell Claude, or tick the box in TODO.md. Claude imports it, records the asset IDs, wires it into the code, captures before/after screenshots and updates TODO.md.

### What Claude does on the Roblox side
- Pivots, scale fixes, collision, LOD and render-fidelity settings, and SurfaceAppearance / MaterialVariant setup.
- Code-driven animation: wing flaps, toy motion, waterfall scroll, swaying plants. Simple Blender armature animations if needed.
- Greybox layouts, plus the walking map and pet routes.
- Import checks: size, triangle count, missing UVs, mesh resources Rojo lost (`scripts/RepairPetAssets.lua`).
