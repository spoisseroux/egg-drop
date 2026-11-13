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
- No glow by day; a soft glow fades in at night. See "Colour and night glow" under Character creation.

## Face

- **Eyes:** tall ovals with a white ring and a dark pupil (eye texture), slightly large and set wide for cuteness. The Bear's eyes were scaled up 20% from the first pass. Keep one or two alternate eye shapes as hidden variants.
- **Mouth:** a small "v" drawn by an alpha texture on its own patch. Use **Closest** (pixel) filtering for a crisp retro edge. Keep transparent pixels the same colour as the ink so no light fringe shows. Alternates (such as "w") are hidden variants.
- **Nose:** a small dark rounded piece on the muzzle.

## What a pet starts with, and what comes from eggs

- A new pet starts with **no charm and no wings**. It's just the bear: body, head, ears, face, tail.
- **Charms come from the Charm Egg** (see below).
- **Wings, horns and claws come from the Feature Egg.** Wings are its Rare result. They may move to a Personality Egg and panel (wings and horns in 5 sizes, plus procedural traits); see TODO. The Bear's `WingL/R` meshes (three-feather style) are the art for that item and are hidden by default.

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
  - The wearable anchors (hat, horns, helix piercings on both ears, eyes, mouth, neck, torso and the rest) are listed in "Character creation" below.
- **Meshes:**
  - Each mesh is named `<Pet>__<Role>` and parented to its anchor with an identity transform, so the mesh origin sits on the anchor.
  - Give each mesh custom properties `role` and `channel`. Ears, inner ears, muzzle, nose, eyes and mouth use channel `Head`. Tail and wings use channel `Body`.
  - One material per mesh, and every mesh has a UV map.
  - Paired parts are always separate L and R meshes.
- **Names the importer looks for:** eyes are `Eye*`, the mouth is `Mouth*`, and the charm is `CharmDot`.

## Character creation

Spencer approved the attachment list, the horn shape and the piercings on 2026-11-12. This section is the working spec for building a pet and anything it can wear. The reference file is `assets/art-source/pets/pet-bear-attachments.blend` (a copy of `pet-bear.blend` with every anchor and one placeholder per slot). Boards: `artifacts/scope-2026-11-12/01-attachment-anchors.png`, `02-attachment-mock-outfits.png`, `02b-helix-both-ears-closeup.png`, `03-horn-sizes.png`.

**Status (2026-11-12).** The Bear's rig reads all 46 anchors (`anchors` and `anchorFrames` in the generated `BearRigDefinition.lua`). Horns and wings S1 to S5 are the authored meshes from `assets/garden-babies/attachments/` (template `PetAssets.BearAttachments`, Open Cloud asset 97156894572368), coloured with the secondary. Claws, and every rig without an attachment template, still use the procedural `PetFeatureGeometry`. Wearable slots and exclusions are data-driven (`PetAttachmentRules`); no item is sold or saved yet, and the placeholders are equipped only through the Studio-only `workspace.StudioPetWearables` attribute (for example `Hat=beanie;Shirt=tee;Neck=beads;EarPiercingL=ring;EarPiercingR=ring;Eyes=button;Mouth=o;Tail=arrow`). Rebuild with `python scripts/build_bear_attachments.py` after a new export and Studio import.

### 1. Anchors: the rules

- **Name.** `<Pet>__Anchor_<Name>`, an empty parented to the pet root. Wearable meshes are `<Pet>__<Role>`, parented to their anchor with an identity transform, so the mesh origin is the anchor.
- **Properties on every wearable mesh.** `role`, `channel`, `slot`. Add `alternate` and `variant` for swaps, `feature` and `stage` for Feature Egg parts, `optional` for anything a pet does not start with.
- **Axes.** 1 unit = 1 stud. Front is −Y, up is +Z, L = −X. Feet at z = 0.
- **Channel** is the body part the anchor moves with: `Head`, `Body`, `HandL`, `HandR`, `FootL`, `FootR` or `Root`. A wearable inherits its anchor's channel, so head turns, ear flicks and arm swings carry it without extra code.
- **Orientation.** Three kinds of anchor:

  | Kind | Rotation | Used for |
  |---|---|---|
  | Surface | Local **+Z leaves the surface**. Local Y stays as close to world +Y as it can. | Horns, hat, helix, lobe, wrist, claws, toes |
  | Face | **Identity**, so textures and decals stay upright. The anchor sits on the surface and the part is modelled pushed out along −Y. | Eyes, mouth, nose, cheeks, bridge, forehead, chest, back |
  | Swap | Identity, origin at the joint | Tail, torso, neck |

- **Left and right.** Place each side **from that side's own mesh**, not by mirroring the other. The Bear's ears differ by about 0.02, so HelixR is not the mirror of HelixL. Never use negative scale. L and R wearables are separate meshes.
- **Scale.** Anchors are always scale 1. Wearables are authored at Bear size. A pet with a different head or body sets one number per channel (`fit.Head`, `fit.Body`) and the importer multiplies every wearable on that channel. Small hard parts (rings, beads, horns) never go below 0.8, so they stay readable.
- **Depth.** Hard parts sink 0.02 to 0.03 into the surface. Cloth shells sit 0.024 off the body. Nothing passes below z = 0.
- **Every pet has every anchor.** If a slot makes no sense on a species (no ears, no tail), keep the anchor and mark the slot unavailable in the rig data. Do not delete it.

### 2. Anchors: the list

Positions are the Bear's, in root-local studs. "Exists" means the anchor was already in `pet-bear.blend`.

| Anchor | Channel | Kind | Slot | Position (x, y, z) |
|---|---|---|---|---|
| HatCrown | Head | Surface | Hat | 0, −0.03, 1.38 |
| HornL / HornR | Head | Surface, tilted 17° out and 8° forward | Horns | ∓0.175, −0.10, 1.35 |
| HelixL | Head | Surface, 45° up and out | EarPiercing | −0.443, 0.002, 1.428 |
| HelixR | Head | Surface, 45° up and out | EarPiercing | 0.461, −0.001, 1.409 |
| LobeL / LobeR | Head | Surface | Earring | ∓0.46, 0, 1.25 |
| EarL / EarR (exists) | Head | Swap | species ears | ∓0.33, 0, 1.27 |
| EyeL / EyeR | Head | Face | Eyes | ∓0.2145, −0.425, 1.03 |
| FaceBridge | Head | Face | Eyewear | 0, −0.46, 1.04 |
| EyeLine (exists) | Head | Face | gaze target | 0, −0.469, 1.03 |
| Forehead | Head | Face | Forehead | 0, −0.37, 1.24 |
| CheekL / CheekR | Head | Face | Cheek | ∓0.36, −0.31, 0.88 |
| Nose | Head | Face | Nose | 0, −0.505, 0.905 |
| Mouth | Head | Face | Mouth | 0, −0.51, 0.80 |
| Head (exists) | Head | Swap | neck joint | 0, −0.02, 0.70 |
| Neck | Body | Swap | Neck | 0, −0.07, 0.63 |
| Torso | Body | Swap | Shirt | 0, −0.05, 0.455 (same point as Body) |
| Chest | Body | Face | Chest | 0, −0.40, 0.50 |
| Back | Body | Face | Back | 0, 0.215, 0.52 |
| WingL / WingR (exists) | Body | Swap | Back (wings) | ∓0.11, 0.17, 0.54 |
| Tail (exists) | Body | Swap | Tail | 0, 0.24, 0.33 |
| HandL / HandR (exists) | HandL / HandR | Swap | shoulder; sleeves | ∓0.225, −0.06, 0.655 |
| WristL / WristR | HandL / HandR | Surface | Wrist | ∓0.33, −0.11, 0.49 |
| ClawL / ClawR | HandL / HandR | Surface | Claws | ∓0.39, −0.14, 0.39 |
| FootL / FootR (exists) | FootL / FootR | Swap | foot joint | ∓0.165, −0.08, 0.10 |
| AnkleL / AnkleR | FootL / FootR | Swap | Ankle | ∓0.165, −0.01, 0.17 |
| ToeL / ToeR | FootL / FootR | Surface | Claws (toes) | ∓0.165, −0.325, 0.08 |
| CharmFloat, CharmLeft, CharmRight, CharmCenter (exist) | Root | Swap | Charm | see "Charm Egg" |
| HandCatch (exists) | Root | Swap | toy | 0, −0.47, 0.45 |
| Ground | Root | Swap | Aura | 0, 0, 0 |

There is **no leg or pants anchor**. Pets never wear pants.

### 3. Slots and what blocks what

A blocked item is **hidden, never unequipped**. It stays owned and selected, and comes back when the blocker is taken off.

| Slot | How many | Rule |
|---|---|---|
| Hat | 1 | A full hat hides **Horns** and **CharmCenter**. A hat flagged `openCrown` (band, bow, headphones) leaves horns visible. A hat flagged `hidesEars` hides EarPiercing and Earring. A low brim hides Forehead. |
| Horns | 1 style, stages 1 to 5 | Hidden under a full hat. The earned stage is kept. |
| EarPiercing | 1 per ear | HelixL and HelixR are independent: a pet can wear one, the other, or both. |
| Earring | 1 per ear | LobeL and LobeR, independent. |
| Eyes | 1 | Swap. Eyewear stacks on top unless the eye style is flagged `noEyewear`. |
| Mouth, Nose | 1 each | Swap. The expression system still picks which mouth frame shows. |
| Neck | 1 | Necklace or scarf or collar. It sits over a shirt. |
| Shirt | 1 | A shirt with a printed chest blocks Chest. |
| Back | 1 | Wings or a backpack or a cape. |
| Tail | 1 | Swap. Replaces the species tail. |
| Claws | 1 style, stages 1 to 5 | Hands and toes grow together. Mittens would hide hand claws. |
| Wrist, Ankle | 1 per side | No conflicts. |
| Charm | 1 | CharmCenter is hidden by a full hat. CharmFloat clears any hat up to 0.18 tall. |

### 4. How to author each slot

Common to all of them: one material per mesh, a UV map, smooth shading, origin on the anchor, modelled on the Bear in `pet-bear-attachments.blend`, and named so the importer can find it. Budget: a full outfit should add no more than about 800 triangles to a pet.

**Shirts (and never pants).**
- A shirt is **always three meshes**: a torso and two sleeves. Never ship a one-piece shirt. The arms move on their own channels, so a one-piece shell lets them poke through.

  | Mesh | Channel | Anchor (origin) | Slot |
  |---|---|---|---|
  | `Shirt_Torso` | Body | Torso | Shirt |
  | `Shirt_SleeveL` | HandL | HandL (the shoulder) | Shirt |
  | `Shirt_SleeveR` | HandR | HandR (the shoulder) | Shirt |

  The manifest lists them under `slots.Shirt.pieces`. All three share one item id through the `variant` property (`tee`), and are shown and hidden together.
- **Torso.** Start from a copy of the shared `Body` mesh. Push it out 0.024 along its normals to make a shell. Cut the hem with a flat plane at body-local z = −0.10 (just above the legs) and the collar at z = +0.25. The hem never goes lower. There are no pants, shorts, skirts or shoes that cover the leg.
- **No armholes.** Leave the torso shell closed behind the arms. The sleeves pass through it, cloth through cloth in one colour, so no gap can open when an arm turns.
- **Sleeves.** Start from a copy of that side's arm mesh (`HandL`, `HandR`), with the origin on the shoulder anchor. Push it out 0.020 along its normals, so the sleeve wraps the arm and turns with it.
- **Cuff.** Cut the sleeve with a slanted plane. On the outside of the arm the sleeve is short (about 0.23 from the shoulder). On the side that faces the body it is long (about 0.33). It has to be long there: that side of the arm sweeps inside the torso shell when the arm folds, and it must stay under the sleeve.
- **Cuff lip.** Turn the cuff edge in by 0.030 so it ends just under the arm surface. A sleeve has no open edge outside the arm.
- Because every pet shares the Bear's body and arms, one shirt fits every pet. Do not sculpt a shirt to one species.
- **Check before export.** Run `scripts/check_bear_shirt.py`. It turns each arm from −35° to +35° at the shoulder with the game's pose and fails if a sleeve cuts the arm, if the arm crosses the torso outside a sleeve, or if the torso lifts off the body. A walking step can still press the bare paw onto the belly; that contact is reported, not failed, because the bare Bear does the same.
- Placeholder: `PetBear__Shirt_Torso` (108 triangles), `PetBear__Shirt_SleeveL` (91) and `PetBear__Shirt_SleeveR` (97). `scripts/export_bear_attachments.py` rebuilds the sleeves from the arm meshes on every run.

**Necklaces.**
- Parent to Neck. The ring is tilted: the front sits 0.03 lower than the back, so it rests on the chest and clears the chin.
- Place beads by projecting onto the body surface and lifting 0.036, so the necklace clears a shirt shell as well as bare plush.
- Bead radius 0.022; a centre pendant bead 0.034. Sixteen beads is enough.
- For the final art, model the string as one low-poly ring and only the pendant as a separate shape. The placeholder uses 16 separate spheres (320 triangles), which is too heavy to ship.

**Piercings.**
- **Helix rings, one per ear**, on HelixL and HelixR. The anchor sits on the upper outer rim of the ear, 45° up and out.
- The ring clamps the rim: it lies in the anchor's local YZ plane (Z is the rim's radius, Y is the ear's thickness). Its centre is 0.018 inside the rim along −Z, so about a third of the ring is hidden in the ear.
- Size: **major radius 0.056, tube radius 0.0125** (Spencer asked for bigger; this is 1.65 times the first mock). 14 segments by 6 sides, 168 triangles.
- Each ear's ring is its own mesh on its own anchor: `HelixL_Ring`, `HelixR_Ring`.
- Metal material: gold by default. Piercings are one of the few wearables that do not take a pet colour.
- Lobe earrings use LobeL and LobeR. Studs follow the surface. Drops hang along world −Z, not the anchor's local axis.
- A species with no outer ears gets the helix anchors on the side of the head, at ear height.

**Hats.**
- Parent to HatCrown. The origin is the top of the skull; the brim hangs below it (down to about z = −0.06 local).
- A hat that sits between the ears is at most **0.19 radius**. Anything wider must cover the ears and set `hidesEars`.
- Keep it under 0.18 tall so a floating charm clears it.
- Set `coversHorns = true` for a full hat (it hides horns) or `openCrown = true` for a band, bow or headphones (horns stay).
- Placeholder: `PetBear__Hat_Beanie`, a 12-sided lathe, 228 triangles.

**Horns.** See "Horn growth stages" below. Same naming for claws and wings: `<Role>L_S<stage>`.

**Swappable eyes.**
- Parent to EyeL and EyeR (identity rotation). Model each eye pushed out along −Y so its front sits about 0.045 proud of the skull.
- Stay inside the default eye's footprint: about 0.165 wide by 0.245 tall. Bigger eyes collide with the muzzle and the brow line.
- Name them `EyeL_Alt<Variant>` and `EyeR_Alt<Variant>`. The importer finds eyes by the `Eye` prefix.
- A textured eye uses the shared eye material. A solid eye (button, bead) uses one dark glossy material.
- The expression system scales eyes, so keep the origin at the eye's centre.
- Placeholder: `EyeL_AltButton`, `EyeR_AltButton`.

**Mouths.**
- Parent to Mouth, on the muzzle. Two options:
  - An alpha-textured patch (the default "v"): Closest filtering, transparent pixels the same colour as the ink.
  - A small mesh (the "o" placeholder, 0.034 by 0.04).
- Name them `Mouth_Alt<Variant>`. A mouth style needs every expression frame the pet uses (smile, open, sleepy), or it must declare that it only replaces the neutral frame.

**Tails.**
- Parent to Tail. The first ring of the tail starts 0.04 inside the body so there is no gap when it wags.
- The tail wags around the anchor, so model it growing back along +Y and up.

**Status (2026-11-12 night).** The 13 launch wearables are in game: Open Cloud asset 93989945223773 (all 63 attachment meshes; unchanged horn, wing and face-alt meshes keep their earlier mesh ids), template and `BearRigDefinition.lua` rebuilt with `wearableItems`. They are sold for Stars in the **Wardrobe** (Companions editor at the Care Cradle, `WardrobeShop`), saved per pet in hatching v10 (`petWearables`: owned + equipped), and replicate through the public pet appearance. Pieces keep their colour role at runtime (own colour, secondary-tinted, face ink); tinted wearable pieces take the secondary but never the night glow. The Blep is `neutralOnly` (the default mouth returns for other moods), multi-piece eyes squint and blink about one centre, and `workspace.StudioPetWearables` (Studio only) still overrides the save for checks.

**Launch wearables (final art, 2026-11-12).** The grey-box placeholders are replaced by 13 items built from code by `scripts/build_bear_wearables.py` (run by `scripts/export_bear_attachments.py`); review sheets are in `artifacts/pet-attachments/final/`, regenerated by `scripts/render_bear_wearables.py`.
- **An item is one or more meshes that share an item id** (`item`, lower-case, also in `variant`). Pieces exist because a mesh has one colour. Name them `<Slot>_<Variant>[_<Piece>]` (`Hat_Beanie`, `Hat_Beanie_Trim`), eyes and mouths `EyeL_Alt<Variant>[_<Piece>]`, shirts `Shirt_<Variant>_Torso`, `_SleeveL`, `_SleeveR` plus trim (`_Stripes`, `_Hem`, `_Star`, `_Hood`).
- **Colour.** Each piece is `own:#hex` (the item's own colour), `secondary` (`tintBySecondary`: it takes the pet's secondary colour) or `face` (ink). Every item has a primary colour; trim usually tints.
- **Budget.** At most 600 triangles per item; the export fails above that.
- **Price tiers (suggested).** common 15, rare 30, showcase 60 Stars. The manifest lists every item under `items` with its display name, tier, price, flags and pieces.
- **Set.** Hats: Pom Beanie, Tiny Sun Hat (oval brim, 0.19 across so it passes between the ears), Flower Crown (a wreath round the head under the ears: `openCrown`, `lowBrim`). Shirts: Stripy Tee, Star Hoodie (`printedChest`). Neck: Pearl Beads, Bell Collar. Helix pairs: Little Hoops, Star Studs. Eyes: Sparkle, Sleepy. Mouth: Blep (`neutralOnly`). Tail: Heart Tail.
- Name it `Tail_Alt<Variant>`. Body-coloured tails use the body material and need the gradient UVs; a secondary-coloured tail (the arrow tail) uses the flat secondary material.
- Keep it inside 0.3 behind and 0.45 above the anchor so it does not clip the cradle preview.

### 5. Horn growth stages

The Feature Egg's "Horn buds" grow one stage per item, five stages in all. Each stage is its own pair of meshes, not a scaled copy, because the curve changes as it grows.

| Stage | Name | Height | Base radius | Leans out | Tip curls in | Triangles each |
|---|---|---|---|---|---|---|
| S1 | Bud | 0.06 | 0.050 | 4° | 0° | 46 |
| S2 | Nub | 0.10 | 0.057 | 12° | 10° | 46 |
| S3 | Horn | 0.15 | 0.064 | 20° | 24° | 58 |
| S4 | Curl | 0.21 | 0.071 | 27° | 38° | 70 |
| S5 | Crown | 0.28 | 0.078 | 33° | 52° | 82 |

- Simple devil horns: six sides, smooth shaded, a single tip vertex.
- Meshes: `HornL_S1` to `HornL_S5` on HornL, `HornR_S1` to `HornR_S5` on HornR. Properties: `feature = horns`, `stage`, `channel = Head`, `optional`.
- The base ring sits on the anchor and a collar ring sinks 0.025 into the head.
- Colour: the pet's **secondary**.
- At S4 and S5 a centred charm lifts 0.1 so it does not touch the tips.
- Horns keep 0.02 clear of the inner ear at S5. Check the ear-flick animation when horns change.

### 6. Colour and night glow

- **Two colours, always.** Primary on top, secondary at the bottom of the vertical gradient and on the flat-secondary pieces. The full rule is in "Colour: exactly two colours on the body" above.
- **Which wearables take a pet colour.**

  | Takes the secondary | Takes the primary | Has its own colour |
  |---|---|---|
  | Horns, claws, charm, inner ears, muzzle, a secondary tail | Body-coloured ears and tails | Shirts, hats, necklaces, piercings, eyes, mouth, nose, wings |

- **Night glow.** A two-tone pet does **not glow by day**. A soft glow fades in at night.
  - Emission is 0 while daylight is above 0.75.
  - Below that it follows a smoothstep up to 0.5 at full night (`Materials.nightGlow` in `src/client/PetMaterials.lua`, values in `PetMaterialConfig.BodyTwoTone`).
  - Daylight follows the real-time garden clock, so the fade takes the whole dusk, about two hours.
  - Checked in Studio: daylight 0.6 gives 0.05, 0.4 gives 0.23, 0.2 gives 0.41, 0 gives 0.50.
- **What glows.** Only the body material. Wearables do not glow, so a shirt reads as a dark shape over a softly lit pet at night. If a wearable should glow (a lantern charm), it gets its own emissive material and its own approval.
- When you pick a new pet's default colours, check them at noon and at midnight. A very dark primary looks flat at night even with the glow.

### 7. Voice

Every pet shares **one voice set** for now. A new pet needs no new sounds. Each pet gets its own set later.

| Cue | When |
|---|---|
| `bear_boop_1/2/3` | A tap or boop |
| `bear_chirp` | Happy, or cheering after a good round |
| `purr` (2 s loop) | Held petting |
| `bear_yawn` | Idle yawn or sleepy moment |
| `bear_sneeze` | Idle sneeze |

The `bear_` prefix is historical; it does not mean the cue is only for the Bear. The full brief is in [AUDIO-HANDOFF.md](AUDIO-HANDOFF.md). Several of these are still placeholders or missing.

### 8. Making a new pet, step by step

1. **Copy the Bear.** Duplicate `assets/art-source/pets/pet-bear-attachments.blend` to `pet-<name>.blend` and rename the root and every object from `PetBear` to `Pet<Name>`.
2. **Swap the head pieces and the tail.** Replace the ears, inner ears, muzzle and nose, and the tail. Keep the shared body, hands and feet exactly as they are. Stay inside 1,200 to 1,800 triangles for the visible pieces.
3. **Set the palette.** Edit the `PetPalette` node group. Check the gradient on the new head pieces: UV v = 0 is fully secondary, v ≥ 0.64 fully primary.
4. **Re-place the anchors.**
   - Body, limb and root anchors do not move, because the body is shared.
   - Head anchors move with the new head: project HatCrown, HornL/R, EyeL/R, CheekL/R, FaceBridge, Forehead, Nose and Mouth onto the new surface, and place HelixL/R and LobeL/R from each ear's own outline.
   - Keep all 28 new anchors and the existing ones. Mark a slot unavailable rather than deleting its anchor.
5. **Fit check.** Turn on the placeholders: beanie, tee, beads, both helix rings, horns S1 and S5, button eyes, "o" mouth, arrow tail. Nothing should float or sink more than 0.03. If the head is a different size, set `fit.Head` instead of editing the wearables.
6. **Render.** Front, three-quarter, side and back, next to the Bear, with the scene lights. Use background Blender: `"C:/Users/skunk/AppData/Local/Programs/Blender Foundation/Blender 5.2 LTS/blender.exe" -b <file> --python <script>`.
7. **Export.** One FBX per pet (`assets/garden-babies/<name>.fbx`, forward −Z, up Y) with the settings in [ART-HANDOFF.md](ART-HANDOFF.md). Write `<name>-export-manifest.json` next to it, in the same shape as `bear-export-manifest.json`: each object's centre, size and triangle count, and every anchor's position.
8. **Import in Studio.** Import the FBX, then record the mesh asset ids, raw mesh sizes and texture ids as `<name>-studio-import.json` (same shape as `bear-studio-import.json`). Studio imports at 100 times scale; the build script corrects it.
9. **Build the rig data.** Copy `scripts/build_bear_assets.py` to `build_<name>_assets.py`, point it at the two JSON files and update its piece table (name, channel, colour role, fallback shape). It writes the pet's rig definition in `src/shared/` and its template in `assets/garden-babies/PetAssets.rbxmx`.
10. **Register the pet.** Add it to `PetCatalog` and `PetRigDefinitions`, with `twoTone = true`.
11. **Verify in Studio.**
    - Run `scripts/RepairPetAssets.lua` in validate-only mode; every part must be healthy (see `assets/garden-babies/IMPORT.md`).
    - Play, and look at the pet at garden distance next to the Bear, at noon and at midnight.
    - Dye both colours with Hue fruits.
    - Pet it, watch an idle beat, a tail wag and an ear flick.
    - Open the cradle preview and check nothing clips.
    - Run the pet specs through `ZZSpecs`.
12. **Evidence.** Put renders and Studio captures in `artifacts/pet-<name>/` and say which checks were not done.

### 9. Next pet: the green toy alien

An original soft green toy-alien plush, built on the Bear's shared body.

- **Read at a glance:** a round head a little wider than the Bear's, two short stubby antennae with soft ball tips, big friendly eyes, a small smile, no muzzle bump (or a very shallow one).
- **Head pieces to make:** antennae in place of ears (`EarL`, `EarR` roles, so ear flicks become antenna wiggles), a flat face patch in place of the muzzle, a tiny nose or none.
- **Tail:** a short rounded nub or a small curl. Nothing pointed.
- **Default colours:** undyed it is white and light grey like every pet. Its showcase palette is a soft green primary with a paler mint or cream secondary. The ball tips and face patch take the secondary.
- **Anchors to watch:**
  - HelixL/R and LobeL/R have no outer ear to sit on. Put them on the side of the head at ear height, facing out.
  - HornL/R sit inboard of the antennae. Check S5 does not cross an antenna.
  - HatCrown: the antennae limit hat radius the same way the Bear's ears do. Measure the gap and record the limit.
  - With no muzzle, Mouth and Nose sit on the head surface; re-project them.
- **Night:** green reads well with the glow. Check the pale secondary does not blow out at full night.
- **Keep it original.** The mood reference is generic store-shelf alien plushies. Do not copy any specific product or character: no three-eyed claw-machine aliens, no grey almond-eyed heads, no existing franchise's antennae or colours.
