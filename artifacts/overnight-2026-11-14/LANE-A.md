# Lane A (art) notes, overnight 2026-11-14

Nothing here is committed. All art is procedural (Blender from code, PIL); no generated art, no downloaded assets.
Review renders: `artifacts/overnight-2026-11-14/art/`.

## 1. Wearables (slice B): 6 items, 14 meshes, in `BearRigDefinition.wearableItems`

Built in `scripts/build_bear_wearables.py` (section "SLICE B"), exported to their own FBX
`assets/garden-babies/attachments/bear-attachments-slice-b.fbx` (new export group `slice-b`; the older group
files keep their contents). Open Cloud Model asset **123556704488674**. `bear-attachments-studio-import.json`,
`BearRigDefinition.lua` and `PetAssets.rbxmx` are regenerated. Manifest diff: 14 meshes and 6 items added, nothing
else changed.

| Item id | Display name | Slot (slot keys) | Tier / price | Tris | Main colour (`primary`) | Pieces |
|---|---|---|---|---|---|---|
| `blush` | Blush Stickers | `Cheek` (`Cheek`) | common 15 | 100 | own `#FF9FB2` | `CheekL_Blush`, `CheekR_Blush` |
| `partyhat` | Party Hat | `Hat` (`Hat`), `coversHorns` | common 15 | 146 | own `#45C2E0` | `Hat_PartyHat`, `Hat_PartyHat_Trim` (secondary) |
| `bowtail` | Bow Tail | `Tail` (`Tail`), replaces `Tail` | rare 30 | 126 | own `#F2596B` | `Tail_AltBow` (Ribbon), `Tail_AltBow_Nub` (secondary) |
| `acorn` | Acorn Pendant | `Neck` (`Neck`) | rare 30 | 208 | own `#D9A05B` | `Neck_Acorn` (Nut), `Neck_Acorn_Cap` (own `#8B5A34`), `Neck_Acorn_Cord` (secondary) |
| `bands` | Friendship Bands | `Wrist`, per side (`WristL`, `WristR`), sold as a pair | common 15 | 280 | own `#4FC3C8` | `WristL/R_Bands`, `WristL/R_Bands_Beads` (secondary); channels `HandL` / `HandR` |
| `specs` | Round Specs | `Eyewear` (`Eyewear`) | common 15 | 328 | own `#FFC240` | `Eyewear_RoundSpecs` |

For Lane K / U:
- New tabs that now have an item: **Cheek** (`blush`), **Wrist** (`bands`), **Eyewear** (`specs`). **Ankle has none: keep it hidden.**
- `bands` is `perSide=true` in `wearableItems` (the export marks `Wrist` like `EarPiercing`), so it equips as
  `WristL` + `WristR` exactly like Little Hoops.
- `blush` is one slot key with two meshes (not per side).
- Recolour rule check: every new item's first piece is its own-colour main piece, so `primary` is an `own:#hex`.
- New strings for the localization export: the six display names above.

Mesh ids (also in `bear-attachments-studio-import.json`):

| Mesh | MeshId |
|---|---|
| Bear__CheekL_Blush | 104763963175021 |
| Bear__CheekR_Blush | 133632326281119 |
| Bear__Hat_PartyHat | 111935733785399 |
| Bear__Hat_PartyHat_Trim | 87785804345248 |
| Bear__Tail_AltBow | 108119110033211 |
| Bear__Tail_AltBow_Nub | 95546655344317 |
| Bear__Neck_Acorn | 88333156684846 |
| Bear__Neck_Acorn_Cap | 78813388584570 |
| Bear__Neck_Acorn_Cord | 138074773933839 |
| Bear__WristL_Bands | 121519824839054 |
| Bear__WristL_Bands_Beads | 82317013755116 |
| Bear__WristR_Bands | 139439941356299 |
| Bear__WristR_Bands_Beads | 98950796507091 |
| Bear__Eyewear_RoundSpecs | 101088743280480 |

Changes from the brief (measured in Blender, see the review sheets):
- Blush sits at z 0.848 (brief 0.875) to clear the eye, and stands 0.009 proud: flush with the head it was cut by the
  low-poly facets.
- Bands sit at 0.305 along the arm (brief 0.315), just below both cuffs; the arm ends at 0.359.
- Bow is 0.276 wide (brief 0.22): at 0.22 it was lost behind the body. It is not visible from the front.
- Specs rim tube 0.013 (brief 0.011) and the rim is flattened toward one plane so the muzzle does not bend it.

Review sheets: `wear-all-white.png`, `wear-all-dark-tee.png`, `wear-hoodie-night.png`, `specs-with-eye-items.png`.

## 2. Faceplates and ball theme (slice C)

| Id | Name | Tier / price | Texture (Image asset) | Where |
|---|---|---|---|---|
| `grape_soda` | Grape Soda | common 20 | `rbxassetid://99091469418481` | `DeckThemes.Plates`, `Themes.Order[17]`, order 18 |
| `rose_chrome` | Rose Chrome | rare 40 | `rbxassetid://120581388184665` | `DeckThemes.Plates`, `Themes.Order[18]`, order 19 |
| `bubbles` | Bubbles (ball theme) | rare 40 | none (ramp data, `face="dots"`) | `BallThemes.ById`, `Themes.Order[7]` |

- Generator: `scripts/deck_art/build_faceplates.py` (`grape_soda()`, `rose_chrome()`, two `PLATES` rows appended after
  Bookworm so no earlier `order` moves). `faceplates.json` and `asset-ids.json` updated. Accent-on-ink contrast 9.47 and 12.7.
- Both reuse the existing gloss overlay. Review: `art/faceplates-grape-rose.png`.
- Bubbles size names: Sky, Peach, Melon, Blossom, Violet. Pitch: "Soft and shiny. Two little eyes."
- **Specs that pin the old counts and must move with this data** (not edited by Lane A):
  `scripts/FaceplatePurchase.spec.lua:41` and `scripts/BackgroundAppearanceCatalog.spec.lua:69` (`#Themes.Order==16` -> 18),
  `scripts/BallThemePurchase.spec.lua:42` (`#Themes.Order==6` -> 7), and the DeckStyle client spec (`#Shop.order(...)==16`,
  "4 x 4 grid, no scroll": with 18 plates the shop always uses its existing scrolling grid).
- Not built: Stargazer and Garden Party (NICE), Ducklings (LATER). `stargazer` does not exist in `DeckThemes`.

## 3. Book atlas (slices B and D)

No third page was needed: 48 of 64 slots are used. **Page 1 (`book-atlas.png`) is byte-identical and keeps its id.**
Page 2 (`book-atlas-2.png`) was rebuilt and re-uploaded: Image asset **120543961860755**.

`View.Art` in `src/client/BookView.lua` (only that table was edited): `atlas2="rbxassetid://120543961860755"`, plus

| Slot | Id | Slot | Id |
|---|---|---|---|
| 35 | `pip:blush` | 42 | `toy:squeaky_carrot` |
| 36 | `pip:partyhat` | 43 | `pet_night` |
| 37 | `pip:bowtail` | 44 | `play_date` |
| 38 | `pip:acorn` | 45 | `full_outfit` |
| 39 | `pip:bands` | 46 | `win_each_item` |
| 40 | `pip:specs` | 47 | `tidy_25` |
| 41 | `toy:wobble_top` | 48 | `rounds_100` |

- `atlasRect` paging is unchanged (page 2 = slots 33..64). `assets/ui/book/book-atlas.json` mirrors the slots.
- Badges are drawn in `build_book_atlas.py` (new medal families ROSE, NIGHT, VIOLET; rounded numerals 0/1/2/5).
- The two toy cells are rendered from the same sphere table as Lane K's `PetToyGeometry` builders
  (`PRIMITIVE_TOYS` in `render_book_icons.py`, built in memory; `toys.blend` is not modified). If Lane K changes a
  toy's parts, update that table and re-render.
- Recolour variants have no book cell (they do not count on the Wardrobe page, SYSTEMS-SCOPE 8 #4).
- The preview sheet now writes to `art/book-atlas-preview.png` (was `artifacts/v1-art/`).
- `scripts/BookView.spec.lua` may want one assert for a slot past 34 (for example `pip:specs` = page 2, column 7, row 0).

## 4. Charms (slice D)

No new art. Heart and Star are the existing `Bear__CharmHeart` (96 tris, 0.211 x 0.184) and `Bear__CharmStar`
(60 tris, 0.231 x 0.216) in `PetAssets.Bear`, which is what Lane K's `PetCharmCatalog` `mesh` fields name. Both fit
inside the Snowflake's box (0.259 x 0.241). Leaf was not built (NICE); it stays in `Catalog.Reserved`.

## 5. Blip (slice E art): model and review renders only. No export, no import.

- Builder: `scripts/build_blip.py`. Run on the Bear's blend, writes **`assets/art-source/pets/pet-blip.blend`**
  (root `PetBlip`, all objects/anchors/materials renamed). The Bear's blend is never saved by it.
- `scripts/build_bear_wearables.py` now picks the pet root (`PetBear` or `PetBlip`) and rebuilds every item against
  that pet's anchors and surfaces. Ear items (Little Hoops, Star Studs) are skipped for Blip. The Bear build output is
  unchanged (same tri counts, same manifest).
- 1,262 tris. Body, hands and feet untouched (148 / 72 / 84). 46 anchors, all scale 1. Head anchors re-projected.
- Measured: silhouette top 1.573 (Bear 1.48); stalk inner edge |x| 0.202 (hat limit 0.19, **0.012 to spare, not the
  brief's 0.03**); tips inner edge 0.232; `HatCrown` z 1.348; `HornL/R` at (-/+0.14, -0.12, 1.336);
  `CharmFloat` raised 0.10 to z 1.80.
- Changes from the brief, made after looking at the renders:
  - Antennae are thicker and shorter (stalk radius 0.066 -> 0.052, tip r 0.098 at z 1.475). At the brief's 0.046 /
    0.080 they read as thin wires with bobbles, which the originality guard forbids.
  - Face patch is a small round snout spot (0.27 x 0.18 at z 0.805, 0.010 proud). The brief's 0.40 x 0.25 patch
    ran into the eyes and read as a mask.
  - Review secondary is the fallback `#BDEBD2`: `#D6F5E3` rendered as plain white at noon.
- Fit set checked (see renders): beanie, sun hat, tee, beads, sleepy eyes, blep, heart tail all sit within 0.03.
- Renders: `blip-turnaround-noon.png`, `blip-turnaround-midnight.png`, `blip-vs-bear-turnaround.png`,
  `blip-phone-96px-and-silhouette.png`, `blip-fit-*.png`.

## 6. Open issues

1. **Horn stages 4 and 5 crowd Blip's antenna tips** (`blip-fit-horns-S5-S1.png`): four things on the head, and the S5
   tip passes in front of the ball from the front view. Decide before Blip's export: cap the shown horn stage on Blip, or
   move the horns further in.
2. Blip's hat clearance is 0.012, not 0.03. The Pom Beanie (bulge 0.199) just clears. Check hats under the antenna wiggle.
3. Blip's two-tone gradient was not checked: review renders use flat colours (the `PetPalette` node group has no
   colour inputs to set from a script). The stalk UVs are all v = 0.9 as specified.
4. Bow Tail is not visible from the front three-quarter view (the body hides it); it reads well from behind.
5. Lash Eyes' lashes poke a little past the Round Specs rim. Acceptable; noted.
6. The Acorn Pendant overlaps the top point of the Star Hoodie's chest star (it hangs in front of it, no z-fight).
7. The export re-wrote the older FBX group files (same meshes; Blender stamps a new time). Only `slice-b` was uploaded.
8. Nothing was checked in Studio Play (not allowed tonight): the six wearables, the two plates, Bubbles and the new
   atlas cells are verified in Blender / PIL renders and by reading the generated rig data only.
9. `TODO.md` was not updated by this lane.
10. Not built: Stargazer, Garden Party, Bucket Hat, Toothy Grin, Heart Shades, Leaf charm, tab icons, the bond heart PNG
    (brief MUST #16: Lane U's `BondPips.lua` exists; no PIL heart was drawn by this lane).
