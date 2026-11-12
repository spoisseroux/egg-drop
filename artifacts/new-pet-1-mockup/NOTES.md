# New Pet 1 mockup: original redesign of Spencer's base pet

Built 11 November 2026 in `assets/garden-babies/garden-babies.blend` (not saved) and written to `assets/art-source/pets/new-pet-1-mockup.blend`. The mockup stands at world (-3.2, 0, 0) in collection `EggDrop_NewPet1Mockup`, beside the untouched `newPet1`.

Renders (viewport, material shading):
- `comparison-original-vs-mockup-front-back-threequarters.png`: both pets, front / back / two three-quarter views
- `original-newPet1-front-right-back-threequarter.png`: the base alone
- `mockup-back-rearquarter-left-final.png`: final back, rear three-quarter and side
- `mockup-six-views-pre-wing-rounding.png`: six views from one iteration earlier (wings were pointier; everything else is final)
- `alt-head-nubs.png`, `alt-sprout-tuft.png`: the two hidden alternates

## Important: no geometry was copied from the base

`newPet1` is a Collada import whose node names (`n000_object_00021578`, `attach_0001CD08_material_0`) and textures look like a model extracted from a game, not a hand-built one. If that is the case, copying its meshes would carry the IP risk into the new pet no matter how the head is reshaped. So every mesh in the mockup is new geometry, generated from scratch and sized to the base's measured proportions. Nothing from `newPet1` was duplicated, and no textures are used.

## What was kept from the base

| Kept | Base (pet-local) | Mockup |
|---|---|---|
| Chubby pear body | 0.54 wide, 0.65 deep, z 0.17–0.74 | 0.57 wide, 0.66 deep, z 0.16–0.75 |
| Head size | about 0.93 wide, bottom at z 0.59 | 1.04 wide at the cheeks, bottom at z 0.62 |
| Feet | 0.31 × 0.60 × 0.24 slippers at x ±0.17 | 0.30 × 0.59 × 0.24, flat soles on z = 0, 7° toe-out |
| Stubby arms | shoulders at x ±0.20, z 0.66, hanging out and down | same joints, mitten shape |
| Stance | upright, feet under belly, faces −Y | same |

## What changed, and why

| Chao identifier in the base | Mockup |
|---|---|
| Teardrop head with one point on top | Wide mochi head with a soft loaf top and puffed lower cheeks. No point. Two droopy petal ear-flaps (`EarL`, `EarR`) hang from the upper sides and give the silhouette at garden distance. |
| Sphere floating straight above the head | A five-petal bloom, 0.25 across, drifting beside the right ear at (0.60, −0.12, 1.47), tilted toward the viewer. Still `CharmDot` on `CharmAnchor`, still optional, secondary colour. |
| Small feathered angel wings | Two smooth rounded petal paddles per side (large upper, small lower), swept back and out. No feather notches. |
| Short upturned teardrop tail | A fiddlehead curl: a tapering tube that spirals 1.2 turns. |
| Yellow body, pink/blue tips | Lilac body, muted apricot secondary. |
| Big vertical oval eyes with white rings, set close | Small round-ish dark bead eyes (slightly wider than tall), no white ring, set wide and low, with a small ivory glint. Blush cheeks. Soft "w" mouth instead of a "v". |

The primary design reads as a lop-eared garden baby. Of the two alternates, **`AltHeadNubs`** (two round nubs on top) is equally safe. **`AltSproutTuft`** puts a single stalk on top of the head, which is closer to the Chao "one point" read and to other well-known sprout characters; treat it as the weakest option.

## Palette

| Material | Hex | Used on |
|---|---|---|
| `newPet1Mockup__body` | `#D3C9E2` | Body, Head, HandL/R, Tail, AltHeadNubs |
| `newPet1Mockup__secondary` | `#E2AE8C` | EarL/R, FootL/R, WingL/R, CharmDot, AltSproutTuft |
| `newPet1Mockup__face` | `#3B3348` | EyeL/R |
| `newPet1Mockup__mouth` | `#7C5468` | Mouth |
| `newPet1Mockup__ivory` | `#FFF6E9` | GlintL/R |
| `newPet1Mockup__blush` | `#E3A7AE` | CheekL/R (added material, same role as Ovelle's blush) |

Flat Principled colours, roughness 0.48 (0.32 on face and ivory), matching Zivvi's materials.

## Anchors

Pet-local, Blender axes (front −Y, up +Z, L = −X). Root `NewPet1Mockup` is at world (−3.2, 0, 0), scale 1. All anchors are empties named `NewPet1Mockup__Anchor_<Name>`, parented to the root.

| Anchor | x | y | z | Meaning |
|---|---:|---:|---:|---|
| Body | 0 | −0.05 | 0.455 | body centre |
| Head | 0 | −0.02 | 0.70 | neck joint at the top of the body |
| EyeLine | 0 | −0.503 | 0.955 | on the face surface between the eyes |
| HandCatch | 0 | −0.50 | 0.45 | 0.06 in front of the belly at hand height |
| HandL / HandR | ∓0.235 | −0.04 | 0.635 | shoulder joints |
| FootL / FootR | ∓0.168 | −0.09 | 0.105 | foot centres |
| WingL / WingR | ∓0.11 | 0.20 | 0.585 | wing roots on the back |
| Tail | 0 | 0.22 | 0.33 | tail root |
| CharmAnchor | 0.60 | −0.12 | 1.47 | bloom centre (offset to the pet's right, not overhead) |

## Meshes

Every mesh is `NewPet1Mockup__<Role>`, parented to its anchor with identity transform (origin = anchor), one material, smooth shaded, one UV map (smart project), custom props `role` and `channel`.

| Mesh | Channel | Anchor | Material | Triangles |
|---|---|---|---|---:|
| Body | Body | Body | body | 440 |
| Head | Head | Head | body | 1088 |
| EarL / EarR | Head | Head | secondary | 260 each |
| EyeL / EyeR | Head | Head | face | 196 each |
| GlintL / GlintR | Head | Head | ivory | 48 each |
| CheekL / CheekR | Head | Head | blush | 120 each |
| Mouth | Head | Head | mouth | 204 |
| HandL / HandR | HandL / HandR | HandL / HandR | body | 240 each |
| FootL / FootR | FootL / FootR | FootL / FootR | secondary | 324 each |
| WingL / WingR | Body | WingL / WingR | secondary | 352 each |
| Tail | Body | Tail | body | 400 |
| CharmDot (`optional = True`) | CharmAnchor | CharmAnchor | secondary | 384 |
| **Total, primary design** | | | | **5,596** |
| AltHeadNubs (hidden, `alternate = True`) | Head | Head | body | 1480 |
| AltSproutTuft (hidden, `alternate = True`) | Head | Head | secondary | 568 |

Zivvi in the same file totals about 5,950 triangles. ART-HANDOFF.md asks for under about 4,000 per pet for shipping; the quickest savings are the Head (drop to 24 × 14 segments, about 620), the feet and the charm.

Parts that are new compared with Zivvi's list, which the import code will need to know about: `EarL`, `EarR`, `CheekL`, `CheekR` (Ovelle has a single `Cheeks`), `WingL`, `WingR`, `Tail`, and the `WingL` / `WingR` / `Tail` anchors.

## Viewing the alternates

Both are hidden with the outliner's monitor icon (`hide_viewport`) and the render icon.
- **Nubs:** show `NewPet1Mockup__AltHeadNubs`, hide `__Head`, `__EarL`, `__EarR`.
- **Sprout:** show `NewPet1Mockup__AltSproutTuft`, hide `__EarL`, `__EarR` (it sits on the normal Head).

## Hand-tuning

Reshape anything inside a part. Keep these fixed:
- **Names, parenting and custom props** of every object and anchor.
- **Origins.** Each mesh origin is its anchor. Edit in Edit Mode so the origin does not move. If a joint really should move, move the anchor empty and tell Claude the new position.
- **Splits.** Left and right stay separate meshes; one material per mesh. After mirroring a sculpt change to the other side, apply the mirror (no negative scale).
- **Transforms.** Location 0, rotation 0, scale 1 on every mesh. Apply any object-mode transform before handing back.
- **Feet** bottoms on z = 0 and the pet facing −Y.

Things worth a hand pass:
- The eyes, glints, cheeks and mouth were projected onto the generated head. If you reshape the face area of the Head, re-seat them (Shrinkwrap to Head with a small offset, then apply).
- Ears, wings, tail and the alternates' nubs are separate closed shells that poke into the head or body. That is fine for separate rigid parts in Roblox; weld only if a seam shows.
- The bloom is six overlapping blobs in one mesh; a hand-modelled flower would be cleaner and cheaper.
- Wings are mostly hidden from the front by the head, as on the base. Scale them up or lower the roots if they should read from the front.

`build_mockup.py` in this folder is the generator script that produced the meshes (run inside Blender; it deletes and rebuilds only the `EggDrop_NewPet1Mockup` collection). Re-running it discards hand edits.

## Not verified

- No FBX export and no Roblox import were done; scale, facing and pivots are checked in Blender only.
- Renders are viewport material-shading captures under the file's existing lights, not final renders, and not seen at garden distance beside an avatar.
- The alternates were looked at from the front and one three-quarter view only.
- Whether the design is clear of IP concerns is an art judgement, not a legal review.

---

# v2: New Pet 1 "Mix" (low-poly retro blend)

Built 11 November 2026 from Spencer's review of v1: "a mixture of the fable mockup and my chao like creature", low-poly and angular, his materials, his wings, the side charm kept.

- File: `assets/art-source/pets/new-pet-1-mix.blend` (collection `EggDrop_NewPet1Mix`, root `NewPet1Mix` at world (−5.4, 0, 0)). v1 and `newPet1` are untouched; the open file was not saved.
- Renders: `v2/mix-front-threequarter-side-back.png`, `v2/lineup-mix-v1-original-front-threequarter-back.png` (in the front and three-quarter tiles the order is v2, v1, original; reversed in the back tile).
- Generator: `v2/build_mix.py` (rebuilds only `EggDrop_NewPet1Mix`; re-running discards hand edits).

## What comes from where

| Part | Source |
|---|---|
| Body, arms, feet, stance | His proportions (body 0.54 wide, z 0.17–0.75; long arms hanging to z 0.25; 0.31 × 0.60 × 0.24 slippers) |
| Head | v1's wide mochi head and droopy petal ears, faceted, with slight cheek corners and a flat loaf top. No point on top. |
| Eyes | His style: tall ovals using his eye texture (black disc, white ring), set a little wider than his |
| Mouth | His mouth texture on an alpha-cutout patch (reads as his "v" smile) |
| Wings | His wing style: small white three-feather wings at his placement, size and 45° back sweep. New 30-triangle mesh per wing; his mesh was not copied. |
| Tail | v1's fiddlehead curl, low-poly |
| Charm | v1's side-offset bloom, now a 48-triangle faceted flower, at (0.60, −0.12, 1.47). No ball above the head. |

All meshes are new geometry, flat shaded. Nothing was duplicated from `newPet1` except materials (copied).

## Materials (copies of his, images shared)

| Copy | Copied from | Image | Used on |
|---|---|---|---|
| `newPet1Mix__body` | `bodyMat` | `bodyTex_Gradient.001` (32²) | Body, Head, EarL/R, HandL/R, FootL/R, Tail |
| `newPet1Mix__face` | `PetEye` | `EyeTex.001` (128²) | EyeL/R |
| `newPet1Mix__mouth` | `attach_0001D590_material_1` | `mouthTex.001` (32², alpha, blended) | Mouth |
| `newPet1Mix__wing` | `attach_0001CD08_material_0` | `wingTex.001` (32², plain white) | WingL/R |
| `newPet1Mix__secondary` | `charmMat` | none (flat colour) | CharmDot |

How the UVs were laid out to match his:
- **Body gradient** runs along V only (V = 1 yellow, V = 0 pink); U has no effect. As on his model: hand tips and toes pink, belly patch peach, head yellow. Added in the same spirit: pink ear tips, a faint peach crown, and the tail fading to pink at the curl centre (his tail runs the other way, pink at the root).
- **Eyes** are planar-mapped so the black disc is centred with a white ring about a quarter of the radius wide.
- **Mouth** uses his orientation (top of the patch = V 0), cropped to the middle half of the texture so the mark is centred on the patch.

## Triangles

| Mesh | Channel | Anchor | Triangles |
|---|---|---|---:|
| Body | Body | Body | 168 |
| Head | Head | Head | 192 |
| EarL / EarR | Head | Head | 112 each |
| EyeL / EyeR | Head | Head | 10 each |
| Mouth | Head | Head | 8 |
| HandL / HandR | HandL / HandR | HandL / HandR | 80 each |
| FootL / FootR | FootL / FootR | FootL / FootR | 100 each |
| WingL / WingR | Body | WingL / WingR | 30 each |
| Tail | Body | Tail | 228 |
| CharmDot (`optional = True`) | CharmAnchor | CharmAnchor | 48 |
| **Total** | | | **1,308** |

This is below the 1,500–2,500 target on purpose: more segments softened the facets. His original is about 600. Easiest places to add detail if wanted: head rings, wing thickness.

No glints, cheeks or alternates in v2.

## Anchors (pet-local; front −Y, up +Z, L = −X)

| Anchor | x | y | z |
|---|---:|---:|---:|
| Body | 0 | −0.05 | 0.455 |
| Head | 0 | −0.02 | 0.70 |
| EyeLine | 0 | −0.489 | 0.95 |
| HandCatch | 0 | −0.47 | 0.45 |
| HandL / HandR | ∓0.215 | −0.08 | 0.65 |
| FootL / FootR | ∓0.165 | −0.09 | 0.105 |
| WingL / WingR | ∓0.11 | 0.17 | 0.54 |
| Tail | 0 | 0.22 | 0.33 |
| CharmAnchor | 0.60 | −0.12 | 1.47 |

Same conventions as v1: meshes `NewPet1Mix__<Role>` parented to their anchor with identity transform, `role` / `channel` props, one material and one UV map per mesh, feet on z = 0. Total height 1.60.

## Things to know

- **IP:** v2 moves back toward the Chao look at Spencer's request: yellow-to-pink body, white-ringed oval eyes, "v" mouth and small white feathered wings. What still separates it is the head (no point, droopy ears), the side bloom instead of an overhead ball, and the curl tail. It is closer to the source than v1; that trade-off is Spencer's call.
- **Roblox:** the game tints pets by part, and Roblox multiplies textures by the tint. The yellow gradient texture will not recolour cleanly; a grayscale version would be needed for hue variants. The mouth relies on texture alpha, which needs a SurfaceAppearance alpha mode.
- **Hand-tuning:** same rules as v1. In addition, if you move vertices on gradient-mapped parts the colours stay put (UVs are per vertex), but new vertices need a V value that matches their neighbours.
- **Not verified:** no FBX export or Roblox import; renders are viewport material shading only.

---

# v3: four plush baby animals on one shared base

Built 11–12 November 2026 from Spencer's review of v2: more charm ideas, smoother body, his eyes in a few directions, keep the wings, and "more like stuffed animals… a bear, a dog, a cat… but still generic enough to customize eyes, mouth, tail".

- File: `assets/art-source/pets/new-pet-1-plush.blend` (4 collections, 180 objects, 108 meshes, 14 materials, 4 images; verified by loading it back). His model, v1 and v2 are untouched; the open file was not saved.
- Generator: `v3/build_plush.py` (rebuilds only the `EggDrop_NewPet1Plush*` collections; re-running discards hand edits).

| Animal | Collection / root | World x | Body tint | Secondary tint | Height | Triangles (default set) |
|---|---|---:|---|---|---:|---:|
| Bear | `EggDrop_NewPet1PlushBear` / `NewPet1PlushBear` | −7.8 | honey `#D8A45C` | cream `#F2E2C2` | 1.60 | 3,168 |
| Dog | `EggDrop_NewPet1PlushDog` / `NewPet1PlushDog` | −10.2 | cream `#EEDFC4` | tan `#B88A5E` | 1.60 | 3,008 |
| Cat | `EggDrop_NewPet1PlushCat` / `NewPet1PlushCat` | −12.6 | gray `#A7ABB8` | off-white `#ECEAF1` | 1.61 | 3,260 |
| Bunny | `EggDrop_NewPet1PlushBunny` / `NewPet1PlushBunny` | −15.0 | pink `#F1B8C7` | white-pink `#FCEFF1` | 1.99 | 3,396 |

Each animal also carries 552 triangles of hidden alternates (not counted above).

## Renders (`v3/`, viewport material shading)

- `lineup-bunny-cat-dog-bear-front-threequarter.png`: all four, default parts
- `bear-…`, `dog-…`, `cat-…`, `bunny-front-threequarter-side-back.png`: four angles each. The bear and dog sheets were captured one iteration before the final tint texture (base tone slightly lighter then); geometry is identical.
- `variants-eyes-mouth-charms.png` and `variants-closeup-cat-dog.png`: Bear = defaults (his tall-oval eyes, "v" mouth, flower). Dog = Round eyes, "w" mouth, Star. Cat = SmallWide eyes, "w" mouth, Heart. Bunny = Round eyes, "v" mouth, Button.
- `charm-positions-left-center-right-bear.png`: Star at CharmLeft, Heart at CharmCenter, Flower at CharmRight.

## Shared base and swappable parts

Shared on every animal (same shape, per-animal mesh copies so each can carry its tint): `Body` 440, `Head` 624, `HandL/R` 180 each, `FootL/R` 224 each, `WingL/R` 30 each. Smooth shaded, no flat facets on body or head. Wings are exact copies of the v2 wing meshes, flat shaded.

| Slot | Bear | Dog | Cat | Bunny |
|---|---|---|---|---|
| `EarL/R` (on `Anchor_EarL/R`) | round, 196 each | floppy, secondary, 240 each | pointed, 144 each | tall upright, 240 each |
| `EarInnerL/R` (same anchors, secondary) | 120 each | none | 96 each | 144 each |
| `Muzzle` (Head, secondary) | round, 196 | long, 196 | two whisker pads, 288 | two small pads, 288 |
| `Nose` (Head) | dark, 100 | dark, 100 | pink, 100 | pink, 100 |
| `Tail` (on `Anchor_Tail`) | round nub, 168 | short upturned, 160 | long curved, 224 | white puff, 168 |
| Optional detail | | | `CheekTuftL/R`, 48 each | |

Same on every animal, so the game can mix and match:
- `EyeL/R` (42 each): his eye texture on tall ovals shaped like his. Hidden: `EyeL/R_AltRound`, `EyeL/R_AltSmallWide` (smaller, set wider).
- `Mouth` (8): his mouthTex alpha "v" patch. Hidden: `Mouth_AltW` (156), a small modelled "w" in the nose colour.
- `CharmDot` (48): the v2 flower, default. Hidden: `CharmDot_AltStar` (60), `CharmDot_AltHeart` (96), `CharmDot_AltButton` (72).

Alternates carry `alternate = True` and `variant = "<Name>"`, keep the same `role` as the part they replace, and are hidden with the outliner monitor and render icons.

## Materials

| Material | Copied from | Change made to the copy |
|---|---|---|
| `newPet1Plush__<animal>_body`, `__<animal>_secondary` | `bodyMat` | image swapped to `plushBodyTex_Gray`; a Multiply node ("Plush tint") between texture and Base Color holds the tint; roughness 0.85 |
| `newPet1Plush__face` | `PetEye` | none (shares `EyeTex.001`) |
| `newPet1Plush__mouth` | `attach_0001D590_material_1` | none (shares `mouthTex.001`, alpha blended) |
| `newPet1Plush__wing` | `attach_0001CD08_material_0` | none (shares `wingTex.001`) |
| `newPet1Plush__charm` | `charmMat` | none |
| `newPet1Plush__nose`, `__nosePink` | `charmMat` | flat colour `#3A2A2E` / `#D98A9A` (two extra materials, needed for noses and the "w" mouth) |

`plushBodyTex_Gray` is a new packed 32 × 32 image with the same layout as `bodyTex_Gradient`: where his texture is yellow it is 72% gray, where his turns pink it rises to white. Multiplied by the tint this gives slightly lighter paws, toes, tail tips and belly. Because it is near-white grayscale it should also take Roblox's part tint cleanly (not tested).

## Anchors (pet-local; front −Y, up +Z, L = −X)

All named `<Root>__Anchor_<Name>`, parented to the root, rotation 0, scale 1. Same for all four animals except the ear roots.

| Anchor | x | y | z |
|---|---:|---:|---:|
| Body | 0 | −0.05 | 0.455 |
| Head | 0 | −0.02 | 0.70 |
| EyeLine | 0 | −0.469 | 1.03 |
| HandCatch | 0 | −0.47 | 0.45 |
| HandL / HandR | ∓0.225 | −0.06 | 0.655 |
| FootL / FootR | ∓0.165 | −0.08 | 0.10 |
| WingL / WingR | ∓0.11 | 0.17 | 0.54 |
| Tail | 0 | 0.24 | 0.33 |
| CharmAnchor (default) | 0.60 | −0.12 | 1.47 |
| CharmRight | 0.60 | −0.12 | 1.47 |
| CharmLeft | −0.60 | −0.12 | 1.47 |
| CharmCenter (rare) | 0 | −0.16 | 1.40 |
| EarL / EarR: Bear | ∓0.33 | 0.00 | 1.27 |
| EarL / EarR: Dog | ∓0.32 | 0.02 | 1.27 |
| EarL / EarR: Cat | ∓0.27 | 0.00 | 1.27 |
| EarL / EarR: Bunny | ∓0.17 | 0.02 | 1.33 |

### Charm positions

- Every charm mesh has its origin at the charm centre, so it can be re-parented to any of the three charm anchors with an identity transform.
- **CharmCenter** is not a floating ball. The charm sits on the crown like a pin, its lower edge sunk slightly into the head, just in front of the top. On the bunny it sits between the ear roots and touches them.
- The charms are modelled tilted slightly toward the pet's right. At CharmLeft they keep that tilt; mirror the tilt in code (or ask for mirrored meshes) if it should lean the other way.
- The dog's ears and the bunny's ears do not reach the side spots; no clipping was seen at Left or Right on the bear. Left and Center were only rendered on the bear.

## Things to know

- **Mix-and-match limits:** eyes sit on the shared head, so they swap freely across animals. Mouths and noses were seated on each animal's own muzzle, so a mouth moved to another animal needs re-seating or a small offset. Tails and ears swap freely on their anchors.
- **Seams:** no modelled seam lines. A stitched belly or head seam would be a texture or a thin secondary strip; say if you want one tried.
- **IP:** these read as generic plush animals. The remaining borrowed elements are his white-ringed oval eyes, "v" mouth and the small white wings; the Round and SmallWide eye variants move furthest from that look.
- **Not verified:** no FBX export or Roblox import; the tint multiply is a Blender node and would be a part colour or SurfaceAppearance tint in Roblox; renders are viewport captures only.
