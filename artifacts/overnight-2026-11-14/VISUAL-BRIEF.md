# Egg Drop v1 overnight build: visual brief (slices B–F)

Art direction, 2026-11-14. Scoping only: no game code, Studio or commits were touched to write this.
Plan: `artifacts/content-v1-2026-11-13/CONTENT-SCOPE.md` (§6 accepted). Style law: `PET-STYLE-GUIDE.md`.

## 0. Rules that apply to every asset

- **No AI-generated art.** Blender from code (`scripts/build_bear_wearables.py` pattern), Python/PIL (`scripts/deck_art/`), or Luau primitives (`PetToyGeometry`). No `generate_*` tools, no image models, no downloaded asset libraries.
- **Original designs.** Cozy-life-sim mood only. Nothing that reads as a specific game's character, item or icon. Named risks: a teardrop head with a point (Chao), three-eyed or grey almond-eyed aliens, any franchise antenna/colour combo.
- **Cute at phone size.** Judge every asset at the size it ships: pets about 96 px tall in the garden, book cells at 48 px, tab icons at 20–24 px. If the read fails there, the asset fails.
- **The "creepy" lesson (Wide Eyes, rejected).** Small pupils set far apart with bare skin between them read as staring. For any face art: eyes are tall or round and large, sit at or inside the Bear's eye spacing, carry a catchlight, and nothing dark and small sits alone on a pale face. No pointed teeth, no pupils without shine.
- **Colour roles.** Each mesh is one of `own:#hex`, `secondary`, or `face` (ink `#2A2226` in game, `attach__ink` in Blender). Every item has exactly one *main* own colour; recolour variants override only that.
- **Budgets.** Wearable item ≤ 600 tris (export asserts); targets below are much lower. Full outfit ≤ about 800. Pet 1,200–1,800.
- **Coordinates** are pet-local studs: front −Y, up +Z, L = −X, feet at z = 0.

Measured from `pet-bear-attachments.blend` tonight (read-only), used throughout:

| Bear mesh | x | y | z | tris |
|---|---|---|---|---|
| Head | ±0.492 | −0.477 … 0.417 | 0.630 … 1.390 | 198 |
| Muzzle | ±0.164 | −0.531 … −0.259 | 0.730 … 0.970 | 72 |
| Eye (each) | 0.132 … 0.297 | front −0.469 | 0.907 … 1.151 | 42 |
| Ear (each) | 0.194 … 0.495 | ±0.075 | 1.180 … 1.479 | 78 + 48 inner |
| Body | ±0.302 | −0.406 … 0.236 | 0.165 … 0.745 | 148 |
| Hand (each) | 0.194 … 0.472 | −0.220 … 0 | 0.356 … 0.704 | 72 |
| Foot (each) | 0.014 … 0.316 | −0.345 … 0.185 | 0 … 0.215 | 84 |
| Tail | ±0.089 | 0.220 … 0.390 | 0.285 … 0.455 | 64 |

Findings from reading the pipeline that change the plan:

1. **Slice A already shipped three of the "13"** (Round Eyes, Kitty W, and Happy + Lash in place of Wide). Slice B is **10 new models**, not 13.
2. **Charm meshes for Heart and Star already exist** hidden in the blend (`CharmDot_AltHeart` 96 tris, `CharmDot_AltStar` 60, also `AltButton` 72). Only Leaf is new art.
3. **Toys are Luau sphere/wedge primitives** (`PetPropGeometry.h:add`), mirrored in `assets/art-source/toys/toys.blend` only for book icons. No FBX work.
4. **The Wrist anchor sits under a sleeve.** WristL is about 0.20 along the arm axis; the sleeve cuff is at 0.268 (0.33 on the body side). Bands must sit lower (see B5).
5. **Book atlas is full.** 34 slots are used and a page holds 32. This plan adds up to about 43 cells (10 wearables, 10 recolours, 4 toys, 2 finishes, 6 badges, Blip + 10 refits), so the atlas needs page 2 completed and a page 3.
6. **Wardrobe tabs are text labels today** (`WearableCatalog.Tabs`), and the bar grows from 7 to up to 11. Phone layout needs checking whatever the icons look like.

---

## 1. Slice B: wearables

All built as new blocks in `scripts/build_bear_wearables.py` (add to `ITEMS`, add colour constants, call `finish(...)`). Add any new glossy own colour to the low-roughness list in `finish()`.

New own colours:

| Const | Hex | Used by |
|---|---|---|
| `C_PARTY` | `#45C2E0` | Party Hat cone |
| `C_BUCKET` | `#8FBF7F` | Bucket Hat |
| `C_RIBBON` | `#F2596B` | Bow Tail ribbon |
| `C_NUT` | `#D9A05B` | Acorn nut |
| `C_CAP` | `#8B5A34` | Acorn cap |
| `C_BLUSH` | `#FF9FB2` | Blush Stickers |
| `C_BAND` | `#4FC3C8` | Friendship Bands |
| `C_SHADES` | `#FF6F9F` | Heart Shades lens (rough 0.3) |
| `C_TOOTH` | `#FFF6E9` | Toothy Grin teeth (rig ivory) |
| `C_GOLD` | `#FFC240` | existing; Round Specs, anklet bell |

### B1. Blush Stickers (Cheek, 15) — MUST
- **Anchor / channel:** `CheekL`, `CheekR` (∓0.36, −0.31, 0.88), Head, face kind. Meshes `CheekL_Blush`, `CheekR_Blush`, one item id `blush`.
- **Shape:** two soft horizontal ovals that hug the head. `face_patch(bm, ±0.36, 0.875, ellipse_outline(10, 0.062, 0.038), rise=0.006, rim=0.003, sink=0.008, tree=HEAD)`, `facing=(0,-1,0)`.
- **Colour:** `own:#FF9FB2`. Not secondary: the undyed secondary is grey and grey cheeks look dirty.
- **Tris:** 100 total (budget 120).
- **Fit:** top edge at least 0.03 below the eye's lower edge (0.907) and outside the muzzle (|x| > 0.164). Must read as blush, never as a bruise or a second pair of eyes: keep it wider than tall and paler than the ink.

### B2. Party Hat (Hat, 15) — MUST
- **Anchor:** `HatCrown`, Head. Flags `coversHorns=True`.
- **Shape:** a stubby cone tilted 8° to the pet's right, a pom on top and a soft ruffle round the base.
  - Cone: `lathe([(0.118,-0.030),(0.114,0.000),(0.062,0.085),(0.0,0.140)], 10, tilt)`.
  - Ruffle: `tube(closed, 10 pts at r 0.120, z −0.022, radius 0.020, sides 3)`.
  - Pom: `ball(tilt @ (0,0,0.146), 0.030, segs=6, rings=2)`.
- **Colour:** cone `own:#45C2E0`; ruffle + pom `secondary` (piece `Trim`).
- **Tris:** about 160 (budget 200).
- **Fit:** total height ≤ 0.18 (`height=0.176`), base radius 0.14 < 0.19 between the ears. Sits level on the crown, not sunk more than 0.03.

### B3. Bow Tail (Tail, 30) — MUST
- **Anchor:** `Tail` (0, 0.24, 0.33), Body. Replaces the species tail (`alternate`).
- **Shape:** a round nub with a big ribbon bow sitting on its upper back.
  - Nub: `ball(t + (0,0.065,0), 0.085, segs=7, rings=3)`, starts 0.04 inside the body.
  - Bow: reuse the Sun Hat bow recipe: two `puff` loops (outline `[(0,0),(0.55,0.60),(1.0,0.46),(1.0,-0.46),(0.55,-0.60)]`, size 0.105, rise 0.034, `sink=0.016`) facing back-and-up `(0, 0.90, 0.44)`, a knot `ball(r 0.026)`, and two short ribbon ends (triangular `puff`, size 0.06) hanging down-out at ±25°.
- **Colour:** nub `secondary`; bow `own:#F2596B` (piece `Ribbon`, the main colour).
- **Tris:** about 150 (budget 200).
- **Fit:** bow spans 0.22 wide; stays inside 0.3 behind and 0.45 above the anchor. Must read from behind *and* show a sliver of bow from the front three-quarter view.

### B4. Acorn Pendant (Neck, 30) — MUST
- **Anchor:** `Neck` (0, −0.07, 0.63), Body.
- **Shape:** thin cord with one plump acorn on the chest.
  - Cord: `tube(neck_path(16, 0.030), 0.008, sides=3, closed=True)`.
  - Acorn at `neck_path(16, 0.046)[0] + (0, −0.014, −0.055)`: nut `lathe([(0,-0.040),(0.018,-0.032),(0.028,-0.012),(0.029,0.004)], 7)`; cap `lathe([(0.032,0.000),(0.034,0.010),(0.025,0.024),(0.008,0.030),(0.006,0.042),(0,0.044)], 7)`.
- **Colour:** cord `secondary`; nut `own:#D9A05B` (main); cap `own:#8B5A34`.
- **Tris:** about 190 (budget 220).
- **Fit:** acorn 0.085 tall, clears a shirt shell (lift 0.046 > shell 0.024). Hangs along world −Z, centred, no tilt.

### B5. Friendship Bands (Wrist, 15) — MUST
- **Anchor / channel:** parented to `WristL` / `WristR`, channels HandL / HandR. Sold as a pair under one id `bands` (same model as Little Hoops).
- **Shape:** a chunky woven band with three beads on the outside of each arm.
  - Path: 10 points round the arm axis (`SLEEVE_AXIS`, mirrored x for R) at **t = 0.315** from the shoulder (not at the anchor's 0.20, which is under a sleeve); ray-cast inward onto `bvh_of("HandL")`, lift 0.012.
  - Band: `tube(path, 0.017, sides=4, closed=True, flat=0.7)`.
  - Beads: three `ball(r 0.020, segs=5, rings=2)` on the outer side, 0.03 apart.
- **Colour:** band `own:#4FC3C8` (main); beads `secondary` (piece `Beads`).
- **Tris:** about 150 a side, 300 the pair (budget 340).
- **Fit:** visible below the cuff with Stripy Tee and Star Hoodie on (the body-side cuff reaches 0.33, so the inner part may tuck under: acceptable, the outer beads must show). Run `check_bear_shirt.py`-style arm sweep by eye: no gap opens at ±35°.

### B6. Round Specs (Eyewear, 15) — MUST
- **Anchor:** `FaceBridge` (0, −0.46, 1.04), Head. Mesh `Eyewear_RoundSpecs`.
- **Shape:** gold wire frames, slightly oval so they hold the tall eye; no lenses (no transparency sorting).
  - Rims: per eye, 14 points on an ellipse rx 0.118, rz 0.138 centred (±0.2145, 1.03); each point at `face_y(x, z) − 0.022`; `tube(closed, radius 0.011, sides=4)`.
  - Bridge: 3-point arc between the rims at z 1.06, same radius.
  - Temples: one 2-point stub each side from the outer rim back to (±0.47, −0.15, 1.06), ending inside the head.
- **Colour:** all `own:#FFC240` (existing gold path, rough 0.28). Gold, not black: dark rims merge with the ink eyes at phone size.
- **Tris:** about 270 (budget 300).
- **Fit:** rims surround the eye's 0.165 × 0.245 footprint with a visible gap all round; the lower rim rides over the muzzle edge without sinking (it follows `FACE`). Must still read with Sparkle and Lash eyes. Check blink: lids/squint stay inside the rim.

### B7. Toothy Grin (Mouth, 30) — NICE
- **Anchor:** `Mouth` (0, −0.51, 0.80), Head. `neutralOnly=True` like Blep.
- **Shape:** an open, happy half-moon with a soft strip of milk teeth along the top. Round, never pointed.
  - Mouth: `face_patch` over a D outline, flat edge up: width 0.096, height 0.046, top at z 0.822; rise 0.008, `tree=MUZ`.
  - Teeth: `face_patch` rounded bar 0.070 × 0.018 under the top edge, rise 0.013, with a 0.004 centre notch so it reads as two teeth.
- **Colour:** mouth `face`; teeth `own:#FFF6E9` (main).
- **Tris:** about 110 (budget 140).
- **Fit:** stays on the muzzle below the nose (nose bottom 0.871). Creepy risk is real: if it reads as a grimace at 96 px, cut it rather than tune it.

### B8. Heart Shades (Eyewear, 30) — NICE
- **Anchor:** `FaceBridge`, Head. Mesh `Eyewear_HeartShades` + `_Shine`.
- **Shape:** two puffy opaque heart lenses and a short bridge.
  - Lens: `face_patch(±0.2145, 1.035, heart_outline(12) scaled to 0.26 wide × 0.24 tall, rise=0.020, rim=0.008, sink=0.004, lift=0.050)` so it clears eyes that stand 0.045 proud.
  - Bridge: 3-point `tube`, radius 0.012.
  - Shine: one small oval per lens, upper outer corner, mirrored per side (the Sparkle Eyes fix).
- **Colour:** lenses + bridge `own:#FF6F9F` (main, glossy); shine `own:#FFFFFF`.
- **Tris:** about 220 (budget 260).
- **Fit:** fully hides the eye beneath, including Sparkle's star shine. Hearts tilt 0°; the inner lobes must not touch.

### B9. Bucket Hat (Hat, 30) — NICE
- **Anchor:** `HatCrown`, Head. `coversHorns=True`.
- **Shape:** soft flat-top crown with a short down-turned brim, oval like the Sun Hat so it passes the ears.
  - `lathe([(0.0,0.108),(0.092,0.104),(0.146,0.074),(0.160,0.012),(0.190,-0.034),(0.184,-0.044),(0.150,-0.012)], 14, tilt(−4° X), squash=oval)` using the Sun Hat's `oval` callable (1.0 across, up to 1.30 front-to-back).
  - Band: `lathe([(0.158,0.010),(0.166,0.014),(0.160,0.044),(0.152,0.048)], 14, tilt)`.
- **Colour:** hat `own:#8FBF7F` (main); band `secondary`.
- **Tris:** about 260 (budget 300).
- **Fit:** 0.19 across the ears, `height=0.11`. Brim shades the brow but leaves both eyes fully visible from the front.

### B10. Jingle Anklets (Ankle, 30) — LATER
- **Anchor / channel:** `AnkleL` / `AnkleR` (∓0.165, −0.01, 0.17), FootL / FootR. Pair under one id.
- **Shape:** thin band round the top of each foot with one small bell at the outer front.
  - Band: 12 points round the foot's vertical axis at z 0.150, ray-cast onto `bvh_of("FootL")`, lift 0.010; `tube(closed, 0.012, sides=3)`.
  - Bell: the Bell Collar lathe at 0.55 scale, 6 segments.
- **Colour:** band `secondary`; bell `own:#FFC240` (main).
- **Tris:** about 145 a side, 290 the pair.
- **Why later:** the ankle is at z 0.17 and the body's underside is at 0.165, so most of the band is buried. It needs a look in Blender before anyone commits to it, and the **Ankle tab should not ship empty**: no Anklets, no Ankle tab.

### Recolour variants (10) — MUST (data only)

Each variant = base item's meshes + an override of the **main own colour**. Trim that tints by secondary stays tinted. Price = base tier.

| Variant id | Shop name | Base (main hex) | New hex |
|---|---|---|---|
| `beanie_mint` | Mint Pom Beanie | beanie `#E9574C` | `#7FE0CF` |
| `beanie_butter` | Butter Pom Beanie | beanie | `#FFD86B` |
| `beanie_grape` | Grape Pom Beanie | beanie | `#9B7BE8` |
| `tee_berry` | Berry Stripy Tee | tee `#33539E` | `#D94A7A` |
| `tee_forest` | Forest Stripy Tee | tee | `#3F8F6B` |
| `tee_tangerine` | Tangerine Stripy Tee | tee | `#F08A3C` |
| `bellcollar_silver` | Silver Bell Collar | bellcollar bell `#FFC240` | `#DCE3EE` |
| `bellcollar_rose` | Rose Bell Collar | bellcollar bell | `#F2A0A8` |
| `sunhat_cocoa` | Cocoa Sun Hat | sunhat `#F3D37E` | `#A9764F` |
| `sunhat_peach` | Peach Sun Hat | sunhat | `#FFB38A` |

Notes: all ten avoid near-white (they must show on an undyed white pet) and near-ink. The Bell Collar variants recolour the bell, since its band is secondary. Icons: re-render the base item's book cell with the override; do not hand-tint PNGs.

### Tab icons: Eyewear, Cheek, Wrist, Ankle — NICE (labels are enough to ship)

Tabs are text today. If icons are added, draw them as `DeckKit.VectorIcons` entries in the same language as the `toy` icon: filled shapes, round ends, one ink colour (`theme.ui.tabInk`), designed on a 24-unit grid, minimum stroke 2 units, legible at 20 px.

| Tab | Glyph |
|---|---|
| Eyewear | Two circles (r 5) joined by a short arched bridge; no temples. |
| Cheek | A wide smile arc with one filled oval at each end, slightly above it. |
| Wrist | A vertical rounded capsule (the arm) crossed by a band of three dots. |
| Ankle | A horizontal bean (the foot) with a ring over its top and one dot (the bell) hanging at the front. |

Wrist and Ankle must differ in silhouette (vertical vs horizontal), not only in detail. Keep the text label with the icon; new labels go through the localization export.

---

## 2. Slice C: faceplates and ball themes

Faceplates are functions in `scripts/deck_art/build_faceplates.py` plus one `PLATES` row; `ui_theme(accent, deep)` derives the UI colours. Add `"deluxe": 160` to `PRICE` and to the json `tiers`. Existing accents already cover mint, cyan, orange, lime, gold, peach, silver, lilac and magenta; the new plates take **violet, rose, cream-and-daisy, and night indigo**.

| Id | Name | Tier / price | How | Palette | Row values | Priority |
|---|---|---|---|---|---|---|
| `grape_soda` | Grape Soda | common 20 | Palette variant of `aqua_pop()`: same wave, same `rand_bubbles(seed 7, 26, 0.022, 0.13)` | ramp `#6A3FD0` → `#9B6BFF` → `#D4BFFF` → `#F4EEFF`; blobs `#FFFFFF` and `#FF9CE0` | accent `#C9A6FF`, deep `#5A3FA8`, band S, "glossy bubbles", SmoothPlastic, `("gloss",0.0,0.40,5.0)` | MUST |
| `rose_chrome` | Rose Chrome | rare 40 | Palette variant of `liquid_chrome()`: same bands, stops tinted | stops `#FFE9EF`, `#F2A7BC`, `#B9647F`, `#6E3149`, highlight `#FFFFFF` | accent `#FFC2D4`, deep `#8A4660`, band RS, "rose chrome", Metal, `("gloss",0.0,0.50,4.0)` | MUST |
| `garden_party` | Garden Party | deluxe 160 | Hand-built function | see below | accent `#FFE08A`, deep `#2F7D5B`, band G, "gingham and daisies", SmoothPlastic, `("sparkle",0.0,0.60,3.0)` | NICE |
| `stargazer` | Stargazer | book | Hand-built function, simple | see below | accent `#B9C6FF`, deep `#1B1F4A`, band G, "foil-stamped night sky", SmoothPlastic, no overlay; `ENGRAVE` `("#FFE9A8", 0.85)` | NICE |

**Garden Party (deluxe).** A picnic cloth: cream `#FFF8E7` with a mint gingham (`#BFEBD3` single weave, `#8FD6B4` where bands cross, squares about 1/14 of plate width, rotated 0°), a scalloped cream border inset 4%, and 18–22 daisies placed by a seeded generator that rejects the screen, button and wordmark zones (use `deck_uv` the way `bookworm()` does). Daisy = 8 round white petals (`#FFFFFF`, soft shadow `#CFE8DA` offset 1 px) round a yolk `#FFD23F` centre with a `#F2A93B` lower shade; sizes 3–6% of width, random rotation. Finish with `gloss_arc(img, 0.16)`. It is the only plate with a pattern *and* motifs, which is what earns 160.

**Stargazer (second book-only plate).** Night gradient `base3("#3A2F7A", "#262663", "#1B1F4A", angle=70)`; about 90 seeded stars (1–3 px, `#FFFFFF` and `#FFE9A8`, 6 of them four-point glints 10–14 px); one gold constellation (`#FFE9A8`, 2 px line, 5 px nodes) drawing a simple egg outline with a star above it, lower left; a thin double gold rule round the plate as on Bookworm. Recommended grant: the **Discoveries page at 100%** (the constellation is the "you found everything" picture). Add to `Themes.BookOnly`. If code keeps it for the Pets page instead, the art does not change.

Ball themes are data in `src/shared/BallThemes.lua`; each keeps the hue family per size (blue, orange, green, pink, violet).

**`bubbles` — Bubbles, rare 40 — MUST.** `face="dots"`, `texture="none"`, `ink="#2A2450"`. Pale bodies with near-white lights so they read as soap bubbles next to Gumdrops' candy.

| Size | body | deep | light | name |
|---|---|---|---|---|
| 1 | `#8FD0FF` | `#4A9BE8` | `#F0FAFF` | Sky |
| 2 | `#FFC48A` | `#F08A4A` | `#FFF1DC` | Peach |
| 3 | `#9FF0C0` | `#3FC486` | `#EFFFF2` | Melon |
| 4 | `#FFA8D0` | `#E85FA0` | `#FFEAF4` | Blossom |
| 5 | `#CDB0FF` | `#8B5FE8` | `#F5ECFF` | Violet |

pitch: "Soft and shiny. Two little eyes."

**`ducklings` — Ducklings, deluxe 160 — LATER** (first in the plan's cut order; needs renderer code). Rubber ducklings in the five hues: new face style `duck` (two round ink eyes with a shine, set close, and a small rounded orange bill `#FF9A2E`; on the orange size the bill is `#FFE27A`), and a three-feather head tuft from size 2 drawn through the same hook as the kitten ears (`earsFrom`). Ramps: body `#6FB2FF / #FFA54A / #5FE093 / #FF8CC0 / #B08BFF`, deep `#2F6FD6 / #D9621A / #1BA35C / #D43F88 / #6A3BDB`, light `#D9ECFF / #FFE7B8 / #D6FFDF / #FFDDEC / #EADCFF`, ink `#1A1228`. Names: Bluebill, Marigold, Clover, Peony, Plum.

---

## 3. Slice D: toys, finishes, charms, badges

### Toys (Toy Egg pool v3) 

Built in `PetToyGeometry.create` with `h:add(name, size, CFrame, colour, "sphere")`, normalised to one pet body-height like the existing three (the Ball is 0.24 across). Cap: 12 parts a toy. All four reuse the generic hold-and-play pose (`PetToyPose`); no new animation. Each also needs a mirror in `assets/art-source/toys/toys.blend` for its book cell (`render_book_icons.py -- toys`).

| Toy | Parts (size x,y,z · offset · colour) | Priority |
|---|---|---|
| **Wobble Top** | Body 0.20×0.15×0.20 at (0,0,0) teal `#3FB7B0`; equator band 0.205×0.04×0.205 at (0,0.01,0) cream `#FFF0C9`; foot 0.05×0.07×0.05 at (0,−0.09,0) coral `#EF786B`; stem 0.04×0.10×0.04 at (0,0.11,0) brass `#C69A45`; knob 0.06 at (0,0.17,0) citrine `#F6D759`. Whole toy tilted 0.18 rad. 5 parts. | MUST |
| **Squeaky Carrot** | Three stacked orange `#FF8A3C` spheres down the diagonal: 0.085×0.11×0.085, 0.07×0.10×0.07, 0.05×0.09×0.05 (centres 0.075 apart); three leaf prongs 0.03×0.08×0.03 green `#58B368` fanned ±0.5 rad at the fat end; squeaker dot 0.03 cream `#FFF0C9` on the side. 7 parts. | MUST |
| **Mini Plush** | A tiny teddy for the pet to hug: head 0.13, body 0.12×0.13×0.11, two ears 0.05, four limbs 0.05×0.06×0.05, all oatmeal `#E8D2B0`; a coral `#EF786B` tummy patch 0.05×0.05×0.012; two ink `#2A2226` eyes 0.018 set **close and low** (0.04 apart) under the head's centre line. 11 parts. | NICE |
| **Bubble Wand** | Grip 0.045×0.17×0.045 lilac `#B79CF2` tilted −0.10 rad; hoop made of 8 pink `#FF9CC2` spheres 0.035 on a circle r 0.075 above the grip; one `ParticleEmitter` on the hoop centre copied from the Sparkler's (Rate 5, Lifetime 1.2–2.0, Speed 0.4–0.9 × s, Acceleration +1.5 × s up, Size 0.10 → 0.16 × s, Transparency 0.2 → 1). Bubble texture: a 64 px PIL drawing (white ring 3 px, one highlight dot upper left), tinted `#DFF4FF`. 9 parts. | NICE (shape); emitter can follow |

Colours deliberately reuse the Ball/Bone/Sparkler family (coral, cream, teal, brass, citrine) so the seven toys look like one toy box.

### Finishes (Material Egg pool v3) — LATER (second in the plan's cut order)

A finish is a `SurfaceAppearance` profile: the white ColorMap with the gradient in alpha cannot change, so a finish can only vary roughness, metalness and a normal map. All maps are PIL-generated, 256 px, tileable.

- **Pearl Edge** (`BodyPearl`, two-tone `BodyTwoTonePearl`): roughness a vertical ramp 0.18 (top) → 0.30 (bottom); metalness flat 0.14; no normal map. Reads as a soft pearl sheen, between Standard and Gloss. A true rim tint is not possible in this material model; do not fake it in the ColorMap.
- **Speckle Satin** (`BodySpeckle`): roughness 0.55 with about 140 seeded round flecks (r 1–3 px) at 0.22; a matching normal map of shallow dimples (strength 0.25); metalness 0.
- **Risk:** neither may be visible at garden distance. Prove each against Gloss and Matte at 96 px, noon and midnight, before spending Studio time. If the difference cannot be seen there, do not ship it.

### Earned charm shapes — MUST (Heart, Star), NICE (Leaf)

All `secondary`, all inside the Snowflake's box (0.26 wide × 0.24 tall × 0.12 deep), all rounded (no interior angle sharper than 60°) so they sit with a plush.

- **Heart** (book Wardrobe 100%): use the existing `CharmDot_AltHeart` (96 tris). Art exists.
- **Star** (weekly bonus ×4): use the existing `CharmDot_AltStar` (60 tris). Check its inner radius is ≥ 0.5 so the points stay soft.
- **Leaf** (stamp 14): new. Two back-to-back `puff`s over the Flower Crown leaf outline `[(-1,0),(-0.35,0.50),(0.45,0.42),(1,0),(0.45,-0.42),(-0.35,-0.50)]`, size 0.11 (0.22 long), rise 0.03, plus a 2-point stem `tube` r 0.012; rolled 20° so it is not a flat lozenge. ≤ 60 tris. Name `CharmDot_AltLeaf`.
- Runtime: `PetCharms` draws Ring from a mesh and Pebble from spheres. Heart/Star/Leaf should follow the Ring's mesh path (export with the attachments FBX). That is code, flagged here because it decides whether "art exists" really means free.

### Discovery badges (+6) — MUST

Add to `BADGES` in `scripts/deck_art/build_book_atlas.py` as `(face, rim, icon_fn)`, same `disc_layer` medal, same rules: filled shapes, round ends, one highlight, nothing past the rim, icon must survive as a solid white silhouette over the 30% disc.

New medal families: `ROSE = (255,143,177)`, rim `(214,84,128)` for pet moments; `NIGHT = (70,76,160)`, rim `(40,43,104)`; `VIOLET = (166,107,255)`, rim `(91,33,214)` for items. Counting milestones reuse `GOLD / GOLD_RIM`.

| Id | Discovery | Medal | Icon |
|---|---|---|---|
| `pet_night` | See your pet at night | NIGHT | Cream crescent upper right, two four-point stars (`star()`), and a bear-head silhouette (circle r 0.20N + two ear circles r 0.075N) low left **in cream**, not ink, for contrast on the dark face. |
| `play_date` | Play date with another pet | ROSE | Two ink head silhouettes side by side, the right one 85% size and overlapping behind; a cream heart (same formula as `heart_outline`) above the gap. |
| `full_outfit` | Wear a full outfit | ROSE | An ink T-shirt shape (rounded body, two short sleeves) with a cream star knocked out of the chest, and a small pom-beanie dome above it. |
| `win_each_item` | Win with each item type | VIOLET | Three balls in a triangle using `ball(d, …, tier, face=False)` in tiers 1, 2 and 4, each carrying a cream star (the power-up mark). |
| `tidy_25` | 25 tidy wins | GOLD | One large ink four-point sparkle upper left and "25" in rounded ink strokes (extend `five()` with a matching "2"). |
| `rounds_100` | Play 100 rounds | GOLD | "100" in rounded ink strokes (bar + two rings) over a small tier-1 ball centred beneath. |

Numerals must be readable at 48 px: stroke ≥ 0.06 N, digit height ≥ 0.28 N.

---

## 4. Slice E: Blip, the green toy alien

### Read
A wide, soft, slightly flat-topped head on the Bear's exact body; two short antennae with fat ball tips where the ears would be; big friendly eyes; a small smile on a pale face patch; a little curl tail. It should look like a shelf toy that happens to be an alien.

**Originality guard (hard):** two eyes only; eyes are upright ovals, never tilted or almond; head is wider than tall with **no point or tuft on top**; green with mint, never grey; antennae are short and thick with round tips, not thin wires or bobbles on springs; no three-of-anything on the head.

### Palette
- Showcase: primary `#7BD88F`, secondary `#D6F5E3`. Fallback secondary if it blows out at night: `#BDEBD2`.
- Face ink `#2A2226`, mouth `#66332E` (the Bear's).
- Undyed it is white / `#A8A5AE` like every pet. **Open question for Spencer:** a white Blip is not "the green toy alien" at the reveal. Recommendation: grant Blip already dyed in the showcase palette.

### Head pieces

| Piece (role) | Build | Colour | Tris |
|---|---|---|---|
| Head | Copy of the Bear's `Head`, scaled about the neck joint (0, −0.02, 0.70): X 1.07, Y 0.98, Z 0.95. Result about x ±0.526, z 0.634 … 1.356. Keep the gradient UVs. | body (two-tone) | 198 |
| Antenna stalk L/R (`EarL`, `EarR`) | `tube`, 4 points, 6 sides, radius 0.046 → 0.036. Base on the head at about (∓0.27, +0.05, 1.27), sunk 0.03; leans 18° outward; top at (∓0.325, +0.05, 1.45). All UV v = 0.9 (fully primary). | body | 42 each |
| Antenna tip L/R (`EarInnerL`, `EarInnerR`) | `ball`, r 0.080, segs 8, rings 4, centre (∓0.335, +0.05, 1.50). | secondary | 64 each |
| Face patch (`Muzzle`) | `face_patch` on the new head: ellipse rx 0.20, rz 0.125, centre z 0.845, rise 0.012, 12 points. Very shallow: a colour change more than a bump. | secondary | 60 |
| Nose | None. Keep the `Nose` anchor (re-projected to z 0.90); mark the slot unavailable. | — | 0 |
| Eyes | The Bear's eye mesh and texture, scaled 1.10 (0.18 × 0.27), at x **±0.2145** (unchanged, so every eye item still lines up; on the wider head they read closer-set, which is the cute direction), z 1.01. | eye | 42 each |
| Mouth | The Bear's "v" mouth patch and its expression frames, re-projected onto the face patch at z 0.80. A bespoke smile comes later. | mouth | 128 |
| Tail (`Tail`) | A small curl: `tube`, 5 points spiralling up and back from 0.04 inside the body, radius 0.036 → 0.024, 6 sides, closed with a `ball` r 0.028. Inside 0.20 behind, 0.22 above. Nothing pointed. | secondary | 70 |

Total with the shared body (148), hands (144) and feet (168): about **1,210 tris**.

Antenna numbers that matter:
- Top of silhouette 1.58 (Bear 1.48). Portrait and cradle framing need +0.10 headroom.
- Inner edge of each stalk at |x| ≈ 0.22: the **hat limit stays 0.19** with 0.03 to spare. Measure and record it.
- Stalks sit 0.05 **behind** the crown line so hats and horns pass in front.
- Horn S5 from the Bear's anchor reaches about (0.33, 1.58) and would hit a tip. Move Blip's `HornL/R` to (∓0.14, −0.12, on-surface) and check S4 and S5.
- The `EarL/R` anchors move to the stalk bases, so the ear-flick channel pivots there and becomes the antenna wiggle.
- Night: the scope asks for softly glowing tips. Wearables and flat-secondary pieces do not glow by rule, so glowing tips need their own emissive material and Spencer's approval. Treat as NICE; the pet must look right without it.

### Face kit
- Default: upright oval eyes with white ring, dark pupil, catchlight; "v" mouth.
- Expressions: the Bear's full set through the shared contract (neutral, curious, startled, pleased, sleepy, affectionate). No new frames.
- Alternates at launch: Sleepy Eyes, Happy Eyes, Blep (below).

### The 10 refits

Make `build_bear_wearables.py` take the pet root (`PetBear` / `PetBlip`) so every item is rebuilt against that pet's own anchors and surfaces. Then a "refit" is a rebuild, not a re-model.

| # | Item | Channel | Refit work |
|---|---|---|---|
| 1 | Stripy Tee | Body + Hands | None: shared body, identical meshes. |
| 2 | Star Hoodie | Body + Hands | None. |
| 3 | Pearl Beads | Body | None. |
| 4 | Bell Collar | Body | None. |
| 5 | Heart Tail | Body | None; replaces the curl. Check the stalk leaves the body cleanly. |
| 6 | Pom Beanie | Head | Rebuild at Blip's `HatCrown` (about z 1.345). The dome bulges to 0.199: confirm it clears both stalks. |
| 7 | Tiny Sun Hat | Head | Rebuild. Brim is 0.19 across: same check. |
| 8 | Sleepy Eyes | Head | Rebuild; `face_stroke` re-projects onto the new head. |
| 9 | Happy Eyes | Head | Rebuild, same. |
| 10 | Blep | Head | Rebuild with `tree` = face patch + head. |

Held back: Little Hoops and Star Studs (no outer ear; need side-of-head placement), Flower Crown (576 tris and wraps the whole head; check after launch), Sparkle / Lash / Round eyes (layered; verify after the simple strokes pass). All of the new slice B items except Specs and Shades are either body-channel or simple face patches and should come across in the same rebuild; treat them as a bonus, not as part of the 10.

### Poses and portraits to check or make
- Garden: idle, walk, sit (`PetSitPose`), all eight idle beats. `scratch` aims a paw at the ear: confirm it lands near the stalk base and does not pass through the tip.
- Ear motion (`PetIdleMotion.EarPerk` / `EarDroop`): a longer lever than a bear ear. Halve the amplitude for Blip if the tips swing more than about 0.08.
- Park: swing, slide, ladder for tips clipping equipment (10 cm taller).
- Petting / care pose and the cradle preview: nothing clips, tips stay in frame.
- Renders: turnaround beside the Bear (front, three-quarter, side, back) at noon and midnight; a 96 px phone-size strip; book cell `pet:blip` in the round porthole style with its silhouette; `PetPortrait` head shot; a 1024 px "a friend arrived" hero (three-quarter, waving) for the reveal.

### Blender build recipe

Work in a copy. Never edit `pet-bear*.blend`.

1. Copy `assets/art-source/pets/pet-bear-attachments.blend` to `assets/art-source/pets/pet-blip.blend`. Rename the root `PetBear` → `PetBlip` and every object, anchor and material prefix (`PetBear__` → `PetBlip__`, `petBear__` → `petBlip__`). Delete the `PetBear_Wearables` collection contents (they are rebuilt in step 9).
2. **Do not touch** `Body`, `HandL/R`, `FootL/R`. Confirm their vertex counts match the Bear's (148 / 72 / 84 tris).
3. Head: select `PetBlip__Head`, set the 3D cursor to (0, −0.02, 0.70), scale about the cursor X 1.07, Y 0.98, Z 0.95, apply scale. Shade smooth. Confirm the top is a broad dome: no vertex stands alone above its neighbours.
4. Delete `EarL/R`, `EarInnerL/R`, `Muzzle`, `Nose`, `Tail` meshes (keep all anchors).
5. Antennae, by script (same helpers as the wearables file): for each side, ray-cast down onto the head at (∓0.27, +0.05) to find the base; build the stalk `tube` and tip `ball` from the table above; set stalk UVs to v = 0.9; assign the body material to stalks and the secondary material to tips. Move `Anchor_EarL/R` to each stalk base and parent the meshes with identity transforms. Properties: `role` EarL/EarR and EarInnerL/EarInnerR, `channel` Head.
6. Face patch, eyes, mouth: build the patch with `face_patch` against the new head; name it `PetBlip__Muzzle`, `role` Muzzle, `channel` Head, secondary material. Scale each eye 1.10 about its own origin and re-seat it so its front stands 0.045 proud of the new surface at (±0.2145, z 1.01). Re-project the mouth patch onto the face patch at z 0.80.
7. Tail: build the curl at `Anchor_Tail`, secondary material, `role` Tail, `channel` Body.
8. Anchors: body, limb and root anchors stay. Re-project the head anchors onto the new surface: `HatCrown`, `Forehead`, `EyeL/R`, `FaceBridge`, `CheekL/R`, `Nose`, `Mouth`. Move `HornL/R` to (∓0.14, −0.12). Put `HelixL/R` and `LobeL/R` on the side of the head at z 1.20 and 1.05, facing out. Keep all 46 anchors; none deleted, all scale 1.
9. Set `PetPalette` to `#7BD88F` / `#D6F5E3`. Check the gradient on the head and stalks.
10. Fit check: run the parameterised wearables build for `PetBlip`; show beanie, sun hat, tee, beads, horns S1 and S5, sleepy eyes, blep, heart tail. Nothing floats or sinks more than 0.03. Record the measured hat gap between the stalks.
11. Render the review sheets (background Blender, scene lights): turnaround with the Bear, noon and midnight; the 96 px strip. **Stop here for art review before any export.**
12. After approval: FBX export (forward −Z, up Y), `blip-export-manifest.json`, Studio import to place 96451847774961, `blip-studio-import.json`, `build_blip_assets.py`, register in `PetCatalog` / `PetRigDefinitions` with `twoTone = true`, then the Studio checks in style guide §8 step 11.

Evidence goes in `artifacts/pet-blip/`.

---

## 5. Slice F: bond levels 1–5

No new models and no new poses: every trick is an existing lever. The art is the feedback.

| Level | Unlock | Built from |
|---|---|---|
| 1 | **Hello** — a wave the first time you walk up each session | `wave` beat, `pleased` face, `bear_chirp` |
| 2 | **Sit** — sits when you stand still nearby, content face | `PetSitPose` (`Sit.fromOwner`) |
| 3 | **Wiggle dance** — two wiggles back to back with a fast tail | `wiggle` beat ×2 |
| 4 | **Big stretch** — onto the toes, arms up, settles into a sit | `stretch` beat then `sit` |
| 5 | **Happy hop** — stretch-rise, a wiggle and a wave in one, with hearts | `stretch` rise + `wiggle` + `wave`, plus the heart burst below |

(The earned charm shapes keep their own goals in slice D, so level 5 is a behaviour, not a charm.)

**Bond pips (UI).** Five small hearts in a row under the pet's name in the Companions panel and the focus card. Filled = plate `accent`; empty = `line` at 40%. Heart drawn from the same formula as `heart_outline` so UI and 3D hearts match. Pip 14 px on phone, 18 px on desktop, 4 px gaps. A thin progress bar (3 px, accent on `well`) under the row shows progress to the next level.

**Level-up flourish (about 1.2 s).**
1. Pet plays the stretch rise (0.3 s) with the `pleased` face.
2. A ground ring pulses once under the feet: reuse the `CareHaloRing` mesh, scale 1.0 → 1.8, transparency 0.2 → 1 over 0.5 s, in the pet's **secondary** colour.
3. Six hearts burst from head height, rise 0.6 studs over 0.9 s, drift ±0.25, size 0.14 → 0.20 → 0, in the secondary colour lightened 20% toward white. `LightEmission` 0.6 at night so they read after dark.
4. The next pip fills with a 0.2 s scale pop (1.0 → 1.25 → 1.0), then a toast: "Bond level 3 · New trick: Wiggle dance".
5. Sound: `bear_chirp`.

**Assets:** one 64 px white heart PNG drawn in PIL (particle and pip share it), and the pip row in UI code. Reduced-effects setting: no ring, no particles; the pip fades in and the toast shows.

**Priority:** pips and the heart burst are MUST; the ground ring is NICE.

---

## 6. Priority and cut order

Budget assumed: one AI developer, one night, who also writes all the slice code. Art time available is about 6 hours, so MUST totals about 5.5.

### MUST (tonight)

| # | Asset | Est. |
|---|---|---|
| 1 | 10 recolour variants (data + re-rendered cells) | 0.25 h |
| 2 | Blush Stickers | 0.25 h |
| 3 | Party Hat | 0.25 h |
| 4 | Bow Tail | 0.25 h |
| 5 | Acorn Pendant | 0.25 h |
| 6 | Friendship Bands | 0.5 h |
| 7 | Round Specs | 0.5 h |
| 8 | Faceplate: Grape Soda (palette variant) | 0.25 h |
| 9 | Faceplate: Rose Chrome (palette variant) | 0.25 h |
| 10 | Ball theme: Bubbles (ramp data) | 0.25 h |
| 11 | Toy: Wobble Top | 0.25 h |
| 12 | Toy: Squeaky Carrot | 0.25 h |
| 13 | Charms: Heart and Star (existing meshes) | 0.25 h |
| 14 | 6 Discovery badges | 1.0 h |
| 15 | Blip Blender model + review renders (recipe steps 1–11), no export | 2.0 h |
| 16 | Bond pips + heart-burst flourish (one PIL heart) | 0.25 h |

### NICE (only after every MUST is rendered and reviewed), in this order
1. Faceplate: Stargazer (book-only #2).
2. Toy: Mini Plush.
3. Bucket Hat.
4. Charm: Leaf.
5. Toothy Grin.
6. Heart Shades.
7. Faceplate: Garden Party (deluxe 160).
8. Toy: Bubble Wand.
9. Tab icons (four vector glyphs).
10. Bond ground-ring pulse.
11. Blip's 10 refits through the parameterised build.

### LATER (not tonight)
- Jingle Anklets and the Ankle tab.
- Ducklings ball theme (new face style and tuft).
- Pearl Edge and Speckle Satin finishes.
- Blip export, Studio import, rig data, portraits, reveal hero, glowing tips, bespoke smile.
- Blip refits of ear items, Flower Crown and layered eyes.

### If the night runs short, cut from the bottom of MUST upward in this order
Round Specs → Friendship Bands → Squeaky Carrot → Rose Chrome. Never cut the recolours, the badges or the Blip review renders: the first two are the cheapest content in the plan and the third is the longest lead item.

A tab ships only if it has an item: Eyewear needs Specs, Cheek needs Blush, Wrist needs Bands.

---

## 7. Review checklist (what I will check on the real renders)

**Every asset**
- [ ] Made by script or by hand; the generating script is in the repo and re-runs clean.
- [ ] Reads at shipping size (96 px pet, 48 px cell, 20 px icon) without zooming.
- [ ] Nothing resembles a specific existing character or item.
- [ ] Looked at on the undyed white/grey pet **and** one dark dye, at noon **and** midnight.

**Wearables**
- [ ] Tri count printed by the build is at or under the budget above; none over 600.
- [ ] No float or sink beyond 0.03; no z-fighting; no inside-out faces from any of the four views.
- [ ] Colour roles correct: main colour is own, trim tints with secondary, ink pieces are ink.
- [ ] Hats: ≤ 0.19 across the ears, ≤ 0.18 tall, a floating charm clears them, horns hide.
- [ ] Specs: visible gap round the eye; still fine with Sparkle, Lash, Happy and Sleepy; fine during a blink.
- [ ] Blush: reads as blush on white, yellow and dark pets; clear of eyes and muzzle.
- [ ] Bands: visible under Stripy Tee and Star Hoodie; no gap through a ±35° arm swing.
- [ ] Bow Tail: visible from behind and at three-quarter; survives a tail wag without clipping the body.
- [ ] Acorn: hangs straight, clears both shirts and the chest star.
- [ ] Toothy Grin (if built): friendly at 96 px. Any hint of grimace = cut.
- [ ] Recolours: each of the ten is distinct from its base and from each other at 48 px; none vanish on a white pet.
- [ ] Full outfit (hat + specs + blush + shirt + pendant + bands + tail) ≤ about 800 tris and still shows the face.

**Faceplates and balls**
- [ ] Wordmark, screen and buttons stay readable; accent-on-ink contrast printed by the script is ≥ 4.5.
- [ ] Each new plate is told apart from its parent at shop-grid size.
- [ ] Bubbles: all five sizes separable in play on the dark well; blue vs violet still distinct; eyes readable on the two smallest sizes.

**Toys, charms, badges**
- [ ] Each toy reads in the held pose at garden distance and in its book cell; ≤ 12 parts.
- [ ] Charms: rounded, inside the Snowflake's box, tint with secondary, readable against sky and grass.
- [ ] Badges: match the existing medals side by side in the atlas preview; each silhouette version still says what it is; numerals legible at 48 px.
- [ ] Atlas: new cells land on the right page and slot; the preview sheet is regenerated.

**Blip**
- [ ] Silhouette test: filled black, next to the Bear, at 96 px. Recognisably different, recognisably the same family.
- [ ] Originality guard passes line by line (two upright eyes, no point, green and mint, short thick antennae).
- [ ] Not creepy: eyes large, at Bear spacing, with catchlights; face patch reads as a soft face, not a mask.
- [ ] Shared body untouched (tri counts equal the Bear's); 1,200–1,800 tris total.
- [ ] Hat gap between stalks measured and ≥ 0.19; horns S1–S5 clear the tips.
- [ ] Secondary does not blow out at midnight; green does not go flat.
- [ ] All 46 anchors present, scale 1, head anchors on the new surface.
- [ ] Fit set (beanie, sun hat, tee, beads, sleepy eyes, blep, heart tail) within 0.03.

**Bond**
- [ ] Pips readable at 14 px on a phone; filled vs empty obvious without colour alone.
- [ ] Hearts take the pet's secondary colour and are visible at noon and at midnight.
- [ ] Flourish never covers the pet's face for more than a moment; reduced-effects path shows pip and toast only.

## 8. Open questions for Spencer
1. Should Blip arrive already green (showcase palette) rather than undyed white? Recommended: yes.
2. Stargazer plate: grant for the Discoveries page at 100%, or for the Pets page? Recommended: Discoveries.
3. May Blip's antenna tips glow at night (needs its own emissive material)? Recommended: yes, after launch.
4. Friendship Bands and Jingle Anklets sold as a pair (like Little Hoops) rather than per side? Recommended: pair.
