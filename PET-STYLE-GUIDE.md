# Pet style guide

Spencer approved this on 2026-11-12. The **plush Bear** is the reference pet. Every new pet should look like it belongs next to the Bear. If this page disagrees with an older direction doc, this page wins.

Reference art: `assets/art-source/pets/pet-bear.blend` (root `PetBear`). Renders: `artifacts/pet-bear/`.

## The idea

Pets are **baby stuffed animals**: a teddy bear, a puppy, a kitten, and so on. They should feel chunky, huggable and toy-like, as if you could pick one up off a shelf. Use real plush toys (teddy bears, Webkinz-style plushies) as references for mood and proportions only. Never copy a brand's character.

Keep every pet generic enough that its customisable parts (eyes, mouth, tail, charm, features) still read as the same pet when swapped.

**Not this:** anything that reads as a Sonic Adventure Chao. Avoid a teardrop head with a single point, and avoid the Chao's look and name. A charm floating above the head is fine on a design that clearly isn't a Chao, like the Bear.

## Shape and polygon style

- The look is **low poly but organic**, like Dreamcast or GameCube characters. The silhouette shows its facets, but the shading stays **smooth**. Avoid flat-shaded faceting (v2 was rejected for that) and avoid high-poly smoothness.
- Budget: about **1,200–1,800 triangles** for a pet's visible pieces. The hard ceiling is 4,000.
- Chibi proportions: the head is about as big as the body. Stubby arms and legs, big feet, a short tail.
- The Bear's shared body, hands and feet are the base. A new animal changes its **head pieces** (ears, muzzle, nose) and its **tail**, not the body.

## Colour: exactly two colours on the body

Every pet's body uses **one primary and one secondary colour**, nothing more:

- **Primary:** most of the body, at the top of the gradient.
- **Secondary:** the bottom of a vertical gradient (paw tips, toes, lower belly), plus flat-secondary pieces (inner ears, muzzle, the charm).
- The gradient is UV-driven and the same on every pet. UV v = 0 is fully secondary, and v ≥ 0.64 is fully primary. The source mask is `assets/art-source/pets/pet-gradient-mask.png`: white means primary, grey means secondary.
- Undyed, every pet starts **white (primary) with a light grey secondary** (`PetBaseColors`). The Hue Egg dyes the two colours.
- In Blender, recolour a pet by editing the `PetPalette` node group, which holds the Primary and Secondary colours.
- In Roblox, it works like this (verified in Studio on 2026-11-12):
  - The MeshPart's `Color` is the primary.
  - A SurfaceAppearance with `AlphaMode = Overlay` uses a white ColorMap whose alpha is the gradient.
  - `SurfaceAppearance.Color` is the secondary.
  - Both colours can be changed while the game runs. The ColorMap can't, so the gradient is baked into the material templates.
- The eyes, nose, mouth and wings keep their own fixed colours. They don't count toward the two body colours.

## Finish

- Moderate gloss: soft highlights, not mirror-shiny. In Blender that means roughness about 0.35 and a light clear coat (about 0.1).
- Optional finishes (Gloss, Matte, Metal) are separate cosmetics.

## Face

- **Eyes:** tall ovals with a white ring and a dark pupil (eye texture), slightly large and set wide for cuteness. The Bear's eyes were scaled up 20% from the first pass. Keep one or two alternate eye shapes as hidden variants.
- **Mouth:** a small "v" drawn by an alpha texture on its own patch. Use **Closest** (pixel) filtering for a crisp retro edge. Keep transparent pixels the same colour as the ink so no light fringe shows. Alternates (such as "w") are hidden variants.
- **Nose:** a small dark rounded piece on the muzzle.

## What a pet starts with, and what comes from eggs

- A new pet starts with **no charm and no wings**. It's just the bear: body, head, ears, face, tail.
- **Charms come from the Charm Egg** (see below).
- **Wings, horns and claws come from the Feature Egg.** Wings are its Rare result. The Bear's `WingL/R` meshes (three-feather style) are the art for that item and are hidden by default.

## Charm Egg (approved idea, not built yet)

- A Charm Egg rolls a charm's **shape** and its **position**:
  - **Left or right side:** common.
  - **Centred above the head:** rare.
- It should be **expensive** to roll: a late-game Star sink, priced well above the other item eggs. Exact prices are not set yet.
- It's a paid random item, so its odds must be shown on the shop card like the other item eggs.
- Charms use the pet's **secondary** colour.
- Shapes so far: flower (the favourite), star, heart, button.
- Position anchors on every pet: `CharmLeft`, `CharmRight`, `CharmCenter` (crown) and `CharmFloat` (centred above the head).
- This replaces today's free charm picker (`PetCharmCatalog`, the Charm tab).

## Rig conventions (every pet)

- **Axes and scale:** 1 Blender unit = 1 stud at garden size. Front is −Y and up is +Z in Blender. L = −X. Feet sit at z = 0.
- **Root:** one empty for the pet, with anchor empties under it named `<Pet>__Anchor_<Name>`:
  - Body, Head (the neck joint), EyeLine, HandCatch
  - HandL/R (shoulders), FootL/R
  - Tail, EarL/R, WingL/R
  - CharmFloat, CharmLeft, CharmRight, CharmCenter
- **Meshes:**
  - Each mesh is named `<Pet>__<Role>` and parented to its anchor with an identity transform, so the mesh origin sits on the anchor.
  - Give each mesh custom properties `role` and `channel`. Ears, inner ears, muzzle, nose, eyes and mouth use channel `Head`. Tail and wings use channel `Body`.
  - One material per mesh, and every mesh has a UV map.
  - Paired parts are always separate L and R meshes.
- **Names the importer looks for:** eyes are `Eye*`, the mouth is `Mouth*`, and the charm is `CharmDot`.

## Making a new pet

1. Copy the Bear's collection in `pet-bear.blend`.
2. Swap the head pieces (ears, muzzle, nose) and the tail for the new animal, and keep the body.
3. Set its palette in `PetPalette`.
4. Render the pet next to the Bear with the scene lights, at front, three-quarter, side and back. Then check it at garden distance in Studio.
5. Follow the import steps in `assets/garden-babies/IMPORT.md` and `artifacts/pet-bear/SWAP-PLAN.md`.
