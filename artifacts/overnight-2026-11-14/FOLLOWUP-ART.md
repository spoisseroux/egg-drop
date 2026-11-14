# Art follow-ups, 2026-11-14 (after the overnight run)

Nothing is committed. Nothing was deleted. Studio: Edit only (one `InsertService:LoadAsset` read, destroyed after);
Play was not started and the place was not changed. All art is procedural (numpy / PIL, Blender from code).

## Asset ids

| What | Type | Id | Source |
|---|---|---|---|
| Stargazer faceplate | Image | `rbxassetid://75553254311335` (Approved) | `assets/deck/faceplates/stargazer.png` |
| Bond heart sprite | Image | `rbxassetid://78220417355081` (moderation was "Reviewing" at upload) | `assets/ui/bond/heart-burst.png` |
| Leaf charm FBX | Model | `74964674417956` | `assets/garden-babies/bear-charm-leaf.fbx` |
| `Bear__CharmLeaf` | MeshId | `rbxassetid://129794057479035`, MeshSize (18.8, 23.6, 11.0), 78 tris | read with `LoadAsset` in Edit |

## 1. Stargazer (book-only plate, Discoveries 100%)

- `scripts/deck_art/build_faceplates.py`: new `stargazer()` (night gradient, 90 seeded stars, 6 four-point glints,
  gold egg-and-star constellation in the free corner of the left grip between the menu button and the glass, double
  gold rule), a `PLATES` row appended (order 20, tier `book`, band gold), `ENGRAVE` entry. Only `stargazer` was
  rendered; the other PNGs are untouched. `faceplates.json` rewritten (one row added), `asset-ids.json` + 1.
- `src/shared/DeckThemes.lua`: `stargazer` entry (id `stargazer` = `BookCatalog.StargazerPlate`),
  `Themes.BookOnly={"bookworm","stargazer"}`. `Themes.Order` is unchanged (18 sold / earned plates), so
  `BookCatalog.BookOnlyPlates` now lists both and the server grant switches on by itself (Lane K's design).
- Accent on ink contrast 11.48.
- Specs (scripts/ and the ZZSpecs copy of each): the sold count stays 18; book plates are now asserted apart.
  - `FaceplatePurchase.spec.lua`: `#Themes.BookOnly == 2`, both book-only, rule `book`, no price, not in `Order`.
  - `BackgroundAppearanceCatalog.spec.lua`: `#Themes.BookOnly==2`, neither in `Order`, both have ui / lcd colours.
  - `DeckStyle.spec.lua` (Bookworm case): Stargazer alone is the 19th card; with Bookworm it is the 20th,
    tile `Tile_stargazer`, status "From the book".
  - Existing `BookStateBits` / `ShelfPurchase` specs already branch on Stargazer being present; not edited.

## 2. Bond heart sprite

- `scripts/deck_art/build_bond_heart.py` (new) writes `assets/ui/bond/heart-burst.png`: 64 px, pure white, soft
  feathered rim, pillow alpha, small gloss; tinted at runtime by `ImageColor3`. Preview: `art/bond-heart-preview.png`.
- `src/client/PetAffection.lua`: `Affection.BondHeartImage="rbxassetid://78220417355081"`. The glyph TextLabel stays
  as the nil fallback. The three petting hearts (line 45) still use the glyph and the `PetLife` spec asserts it: left alone.

## 3. Leaf charm

- Heart and Star are NOT in the attachments pipeline: they are `PetBear__CharmDot_AltHeart/AltStar` in
  `assets/art-source/pets/pet-bear.blend`, exported with the Bear, listed in `bear-export-manifest.json` +
  `bear-studio-import.json`, and placed by `build_bear_assets.py` (`TEMPLATE_EXTRA`) into `PetAssets.Bear`, which is
  where `PetCharms.authored()` looks. Leaf follows that route, so `bear-attachments-studio-import.json` was not
  touched and the (-0.002, 93.439, 1.038) offset was not needed (charm `rel` is unused; the template puts every charm
  at the default charm's centre).
- `scripts/build_bear_charm_leaf.py` (new, background Blender): adds hidden `PetBear__CharmDot_AltLeaf` beside the
  other alternates (same anchor, material, props; `variant="Leaf"`), saves `pet-bear.blend`, exports
  `bear-charm-leaf.fbx` (mesh `Bear__CharmLeaf`). 0.188 x 0.236 x 0.11, inside the Snowflake's box. Front view:
  `art/charm-leaf-front.png` (drawn before the tip was narrowed a little).
- `bear-export-manifest.json` + 1 object, `bear-studio-import.json` + 1 part, `build_bear_assets.py`
  `TEMPLATE_EXTRA` + `CharmLeaf`. Ran `build_bear_attachments.py` then `build_bear_assets.py`:
  `PetAssets.rbxmx` + 39 lines (one MeshPart), `BearRigDefinition.lua` unchanged.
- `src/shared/PetCharmCatalog.lua`: `leaf` moved from `Reserved` into `Order` / `ById` (rule `stamps14`, 14 stamps);
  `Reserved` is now an empty frozen table. `scripts/BondCatalog.spec.lua` + its ZZSpecs copy: the charm-shapes case
  now expects six shapes, Leaf earned at 14 stamps, and uses `clover` for the unknown-stored-shape check.

## 4. World flicker: SKIPPED (over the 30% line)

Why: the remaining overlaps are not one duplicate to delete. A scan (new, read-only
`scripts/scan_world_v7_coplanar.py`, run with `-- "Colonnade|Aqueduct" --detail`) finds 38 same-facing coplanar
pairs in those chunks, in four different shapes of problem. Each needs its own geometric decision, then a re-merge
that re-exports about seven merged meshes (two of them 2048 studs wide), seven mesh ids and a collision rebuild.
No Blender source, FBX or world JSON was changed. Findings for whoever picks it up (Roblox coordinates):

- Colonnade entablature, x -54..-28, z -28..-9: four beam segments, each a trim (y 13.0-13.9) / gold (13.9-14.12) /
  marble (14.12-14.48) stack, overlap their neighbours at the joints. Same-layer tops and bottoms are coplanar
  there (3.4 to 5.0 sq studs per joint, 3 joints, 6 planes). Suggested fix: lift alternate segments 0.02.
- High spring, y 52.0, x 37..85, z -104..-82: `Anim__Water_AqueductChannel__water_stream` face 0 lies in the plane
  of `Architecture_Aqueduct__marble_smooth` face 0 (7.35 sq studs). Suggested: lower the water 0.04.
- High spring, y 52.2: `Architecture_Aqueduct__gold` faces 0 and 6 on `Architecture_Aqueduct__marble` faces 13 and
  19 (0.63 each). Suggested: lift the gold 0.02.
- High spring, y 51: three 0.026 slivers inside `Architecture_Aqueduct__marble` (faces 310/311 with 316/317/323).
- MeshParts that would change: `W7_Architecture__marble`, `W7_Architecture__trim`, `W7_Architecture__palette`,
  `W7_Aqueduct__marble`, `W7_Aqueduct__marble_smooth`, `W7_Aqueduct__palette`, `W7_Water__water_stream`
  (gold is assumed to merge into `palette`; confirm in `build_world_v7_chunks.py`).
- The scan reads the raw import chunks, so it also lists what `dedupe_edging` / `aqueduct_bed` already fix.

## Open issues

1. **Nothing was run in Studio.** No spec was executed and no plate, heart or leaf was seen in the engine. The Lua
   edits were not syntax-checked by a tool (no Luau CLI on this machine); they were read back as diffs only.
2. Stargazer's lock text and toast are Bookworm's: `AppearanceCatalog` rule `book` says "Fill any three collection
   book pages" and `init.client.lua:1226` shows `book.toast.bookworm` for any plate. Needs a Stargazer line (code + UICopy).
3. Localization: new strings "Stargazer" and "Leaf"; run the export + sync before the next publish.
4. The Charm tab has no leaf icon: `HueEggView.charmIcon` falls back to the sparkle (as Heart does).
5. The constellation is small (about 50 x 75 px of 1024): the only free plate area lower left is that corner.
6. `assets/garden-babies/garden-babies.blend` (already modified by someone else) does not have the Leaf; the source
   of truth is `pet-bear.blend`.
7. The heart image was still in moderation review when uploaded. If it is rejected the burst shows nothing (the glyph
   fallback only applies when `BondHeartImage` is nil).
8. `scripts/BondCatalog.spec.lua` is also being edited by another lane (bond levels 6 to 10); my change is the
   charm-shapes case only. `src/server/ZZSpecs/BondCatalog.lua` got the same charm edit but not the other lane's.
9. `TODO.md`: one line added under "Now working on".
