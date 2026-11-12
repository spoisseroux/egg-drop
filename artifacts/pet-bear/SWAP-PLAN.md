# Bear replaces Zivvi: swap plan (revised after architect review, 2026-11-12)

Goal: the plush Bear (`assets/art-source/pets/pet-bear.blend`) is the v1 pet, with a two-colour body (primary + secondary gradient) that the Hue Egg can dye.

| Area | Original plan | Revised (why) |
|---|---|---|
| Pet id | Keep `pip` or add `bear` | Keep account id `pip` (hard-coded in about 20 files, including onboarding and `MeetPipFirst`). Change the rig id to `bear` (`PetRigDefinitions.pip.id`), so `GardenPetVisual` loads `PetAssets.Bear`. Fix the hard-coded "Zivvi" in `HueEggView` and `MaterialFinishPreview`. |
| Two-tone body | Add an Overlay SurfaceAppearance at runtime | ColorMaps can't change at runtime, so bake new templates (`BodyTwoTone` plus Gloss/Matte/Metal versions) in `scripts/BuildPetMaterialTemplates.lua`. The gradient goes in the ColorMap alpha; the emissive mask stays its own image. In `PetMaterials.paint`, `part.Color` = primary and `surface.Color` = secondary, with a separate cache field. Bumping the material version clears the finishes' verified status until each one is proven in Studio again. |
| Piece list | Map the new parts to channels | Bear meshes are named for the importer: `Eye*`, `MouthSmile`. Ears, EarInner, Muzzle and Nose use channel Head; Tail and Wings use Body; wings use colour role ivory with no gradient. The rig definition lists exactly the exported pieces. Keep the 100× MeshSize import quirk. |
| Fallback | Native recipe renders a bear | Same, but it renders flat primary (no gradient), because the fallback has no MeshParts. Accepted and documented. |
| Wings | Built into the bear | Decided (Spencer): the wings come from the Feature Egg's Rare "wings" item. The bear's WingL/R meshes are hidden by default and become the art for that item, replacing the `PlushWingRoot` geometry in `PetFeatureGeometry`. |
| Order | Single change | Six small commits: (1) gradient templates and the primary/secondary split, behind a flag and proven on Zivvi; (2) import `PetAssets.Bear`, unused, plus the repair manifest; (3) `bear` rig definition and native JSON; (4) repoint `pip` and fix the hard-coded names; (5) wings; (6) specs, full sweep, and Studio day and night evidence. |

Asset uploads to Spencer's Roblox account: the gradient ColorMap image plus about 20 bear meshes, uploaded through the Studio FBX import. Nothing is published to the live place.

Risks: FBX axes (Blender −Y front against the importer's π rotation and `PawsOrigin`); Overlay emission at night is untested; about 20 parts against Zivvi's ~17 (draw calls); a large spec update (about 130 scripts mention zivvi/pip).
