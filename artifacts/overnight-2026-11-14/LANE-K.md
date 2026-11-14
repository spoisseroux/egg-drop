# Lane K notes: catalog and render data (overnight 2026-11-14)

Slices B, C-data, D-data, F-data. Nothing committed, nothing deleted, Play never started.

## 1. Files

New:

| File | What |
|---|---|
| `src/shared/WearableVariants.lua` | The 10 recolour rows, a pure row validator, the shared week number |
| `src/shared/WeeklyShelf.lua` | The weekly shelf (pure, no state) |
| `src/shared/BondCatalog.lua` | Bond thresholds, levels, unlocks |
| `scripts/WearableVariants.spec.lua`, `WeeklyShelf.spec.lua`, `BookStateBits.spec.lua`, `BondCatalog.spec.lua` | New specs (section 4) |

Changed:

| File | What |
|---|---|
| `src/shared/WearableCatalog.lua` | Variants listed after their base; 4 new tabs; `renderMap`, `tintFor`, `tabsFor`, `compose`, `attachmentKey`, `tintSignature`; `forPet(petId, week)` |
| `src/client/PetAttachments.lua` | `build(v, resolved, source, tints)` recolours the main own piece(s) |
| `src/client/PetPlayVisual.lua` | Maps variants to base ids before the rig rules; cache key carries the tints; toy whitelist is `PetToyGeometry.has`; per-toy play style (`Toys.Play`) |
| `src/shared/BookCatalog.lua` | Wardrobe page skips variants; `BookOnlyPlates`, `platesOwed`; 6 Discoveries (bits 11-16), `stateBits`, `hour`, `isNight`, `outfitSlots` |
| `src/shared/ToyCatalog.lua` | `PoolVersion=2`, `Pools[2]`, Wobble Top and Squeaky Carrot; a require-time sorted-pool assert |
| `src/client/PetToyGeometry.lua` | One builder per toy id; `Toys.has`, `Toys.Play`, `Toys.PartLimit`; the two new toys |
| `src/shared/MaterialCatalog.lua` | `Pools[3]` and two `ById` rows. **Data only: `PoolVersion` is still 2, `PaidOrder` and `Order` unchanged** |
| `src/shared/PetCharmCatalog.lua` | Heart and Star with rules; `earned`, `rule`, `progress`, `facts`; Leaf reserved |
| `src/client/PetCharms.lua` | Draws a shape's authored mesh (`PetAssets.Bear.Bear__CharmHeart` / `Bear__CharmStar`) at the default charm's frame. Not on my list, but nobody owned it and without it a selected Heart drew nothing |
| `src/client/GardenClient.lua` | Toy whitelist is `ToyCatalog.known` (one line plus a require) |
| `src/client/RewardItemArt.lua` | An undrawable toy id shows an empty slot instead of erroring |

Not touched: `BearRigDefinition.lua`, the manifest, `build_bear_wearables.py`, `DeckThemes`, `BallThemes`, `UICopy.lua` (Lane U had already written every string I needed, including `bond.trick.l1..l5`, which `BondCatalog.Unlocks[n].copy` points at).

## 2. Contracts as implemented

```
WearableCatalog.renderMap(petId, wearables) -> { mapped = {slotKey = baseOrSameId}, tints = {slotKey = tint} }
    tint = { to = "#RRGGBB", primary = <base main own hex, or its palette role>, piece = <attachment name or nil>,
             item = <base id>, id = <variant id> }
WearableCatalog.tintFor(tint, attachmentRow) -> hex or nil      -- the main-piece rule
WearableCatalog.tabsFor(petId) -> { tab, ... }                  -- tabs with at least one item, in Tabs order
WearableCatalog.forPet(petId, week?) -> { order, byId }         -- week gates rows with `from`; math.huge = all
WearableCatalog.compose(petId, rows) -> { order, byId }         -- uncached, explicit variant rows (specs)
item (variant): { id, slot, name, tier, price, flags, perSide, keys, primary, role,
                  variant = true, base = <id>, color = <hex>, piece = <name or nil> }

WeeklyShelf.week(now) -> integer            WeeklyShelf.weekOfDay(day) -> integer
WeeklyShelf.slots(week) -> { {kind, id, full, price}, ... }     -- up to 3; {} when the flag is off or week is not an integer
WeeklyShelf.price(kind, id, week) -> discounted price or nil    -- kind: "wearable" | "faceplate" | "ball"
WeeklyShelf.compute(week, poolsOf) / .pools(week) / .discounted(price) / .has(kind, id, week)

Book.BookOnlyPlates = { {id, rule, earned = function(claimed) -> bool}, ... }
Book.platesOwed(state) -> { plateId, ... }
Book.stateBits(state, now, signature?) -> mask (bits 11..16)
Book.hour(unix), Book.isNight(unix), Book.outfitSlots(petId, equipped)
Book.public(state).plates = { {id, rule, earned, owned}, ... }  -- added; faceplate / faceplateEarned kept

PetCharmCatalog.earned(id, facts) -> bool      facts = { stamps, claimed, stats, bond }
PetCharmCatalog.rule(id), .progress(id, facts) -> {have, need, earned}, .facts(state)

BondCatalog.level(xp) -> 1..5                  Thresholds = {0, 25, 75, 150, 250, 350, 475, 600, 725, 850}
BondCatalog.progress(xp) -> {level, xp, floor, next, fraction, capped}
BondCatalog.XP = {pet = 1, round = 2, win = 3, playDate = 5}, .MaxXP = 100000, .MaxLevelShipped = 5
BondCatalog.Unlocks[level] = {level, id, copy = "bond.trick.l<level>", beats, hearts?}
BondCatalog.unlock(level), .unlocked(xp), .xpOf(bondMap, petId), .clamp(xp), .threshold(level)

ToyCatalog.PoolVersion = 2, Pools[2] = {ball, bone, sparkler, squeaky_carrot, wobble_top}
PetToyGeometry.has(id), .Play[id] = "wave" | "roll" | "chew" | "spin"
```

## 3. Decisions

- **`renderMap` returns one table** with `mapped` and `tints` fields (the scope's PetPlayVisual text reads `renderMap(...).mapped`). Lane U's `WardrobeShop.previewSignature` already reads it that way.
- **Variants sit right after their base** in `forPet(...).order`, not after all rig items. The scope says both; only this gives "base, then its recolours" inside a slot tab.
- **`Stargazer` is listed only if `DeckThemes` has it as a book-only plate.** Lane A did not build it tonight, so `BookOnlyPlates` is Bookworm alone and nothing can grant an unknown plate. It switches on by itself when the plate lands.
- **`pet_night` takes the transaction signature** as an optional third argument. Without it the rule would also fire for any other write at night on a day already petted. Lane S passes it.
- **Shelf "no repeat" is exact, not depth 1.** The scoped depth-1 look-back could repeat an item two weeks running (the spec caught it in week 2835). A slot now walks back to a week whose pick is certain and replays forward; usually 0 or 1 step, capped at 12. Slot 3 alternates kind, so it avoids its pick from two weeks back.
- **Two Discovery names differ from the brief** so they say what to do: `pet_night` is "Pet your pet at night" (the rule is a pet at night, not seeing), `play_date` is "Finish a Play date" (the rule is today's three park activities). Ids, bits and badge art are unchanged. Revert in `BookCatalog.lua` if Spencer prefers the brief's wording.
- **Leaf charm is not selectable.** Its mesh does not exist in the place. The rule (`stamps14`) is reserved under `PetCharmCatalog.Reserved` so the id and the UI line are ready.
- **Wobble Top spins in the hand; Squeaky Carrot is brought to the mouth** like the Bone. Both hold still under Reduced Motion.
- **`ToyCatalog.CatalogVersion` stays 1.** Stored receipts and quotes pin it; bumping it would fail every save that holds a toy receipt.

## 4. Specs and how to run them

Shared-data specs (mine, new). Server side. Each takes an optional second argument, the Shared folder to read:

| Spec | Run | Cases |
|---|---|---|
| `scripts/WearableVariants.spec.lua` | `require(Server.ZZSpecs.WearableVariants)(Server)` | 6 |
| `scripts/WeeklyShelf.spec.lua` | `require(Server.ZZSpecs.WeeklyShelf)(Server)` | 9 |
| `scripts/BookStateBits.spec.lua` | `require(Server.ZZSpecs.BookStateBits)(Server)` | 7 |
| `scripts/BondCatalog.spec.lua` (also covers `PetCharmCatalog.earned`) | `require(Server.ZZSpecs.BondCatalog)(Server)` | 6 |

Existing specs I updated:

| Spec | Side | Arguments | What changed |
|---|---|---|---|
| `WearablePurchase` | server | `(Server)` | Counts no longer pinned to 17; new variant buy / equip case; prices read the shelf (`WearableState.price`); digest check accepts the appended price |
| `ToyFeatureProgress` | server | `(Server, FixtureFrozenV370.Value, FixtureFrozenDaily.Value)` | New pool case; buys use `TC.PoolVersion`; exhaustion costs `8 * #pool`; line 135 skips `blip` |
| `MaterialProgress` | server | `(Server)` | New case: pool 3 is data only, `available()` unchanged |
| `LifetimeCounters` | server | `(Server)` | Rounds reach the 11 round Discoveries, not all 17 |
| `RestrictedEggs` | server | `(Server)` | "last toy" is the pool's last, not index 3 |
| `BookClaim` | server | `(Server)` | Bubbles (5 paid ball themes) and the 5-toy pool: three cases now reach their milestones |
| `PetAttachments` | client | `(Client)` | New variant tint case; item counts follow the manifest (27 rig items); rigless pets skipped |
| `PetPersonalPlay` | client | `(Client)` | Every catalogue toy has a builder; part limits; rigless pets skipped |
| `HatchEggsList`, `DeviceItemFront` | client | `(Client)` | Toy odds rows for a 5-toy pool |
| `scripts/PetAssetsReadyFixture.lua` | client helper | | Skips a collection pet with no rig (Blip) |

Results, run in Studio **Edit** on nil-parented clones of `Shared`, `Server` and `Client` (so the stale require cache and the DataModel are not involved):

- Server: every spec I own or changed is green, and so is the sweep of the other 20 or so server specs that load in Edit (including Lane S's `ShelfPurchase` 22, `CharmRules` 10, `BondProgress` 10, `HatchProgress`). `ToyFeatureProgress` line 135 failed on Lane S's `blip` in `Appearance.Ids`; I added the same skip Lane S used five lines above it, and it passes.
- Not run (they need a live server or world): `GardenGreyboxWorld`, `GardenMotion`, `GardenNook`, `WorldRoutes`, `StudioStore`, `PetContactHost`, `GardenCare`, `GardenState`, `ParkDirector`, `ParkMount`, `SessionRecovery`, `RunReturn`, `BugReports`, `FirstSessionFunnel`.
- Client: `PetAttachments` 9/9, `PetPersonalPlay` 17/17, `DeviceItemFront` 13/13, `BookView` 13/13, `CompanionsHub` 5/5, `CustomizeRedesign` 7/7, `HatchEggsList` 16/17 (line 167, the shop shade; it needs a PlayerGui, so it has to be confirmed in Play).
- These Edit runs are not the Play run. The coordinator's ZZSpecs run in Play is still the gate.
- I refreshed the gitignored `src/*/ZZSpecs` copies of the specs above from `scripts/`.

## 5. Open issues and risks

1. **Toy Egg odds now show five rows.** The pane was laid out for three. `HatchEggsList` builds at 1920x1080 and 812x354 without error, but nobody has looked at it on a phone.
2. **Heart and Star charms have never been seen rendered.** The meshes sit at the default charm's transform in `PetAssets.Bear`, so placement should match; needs a capture on a dyed and an undyed pet.
3. **`PetCharmCatalog.Order` now has five shapes**, so the Customize Charm tab shows five cards (Lane U gates locked ones; the server refuses with `Locked`).
4. **`HatchCinematic` 2 of 10 fail in the Edit run** (`DeckArt:629`, "all seven real subjects"). Probably Blip having no rig or portrait (slice E), or the Edit environment. Not from this lane; worth one look in Play.
5. **The shelf reads its wearable pools from the Bear.** When Blip sells wearables with different ids, `ShelfPet` needs to become a list.
6. **A `from` row is gated on each side's own clock** (`os.time()` on the client). No row uses `from` tonight. A skewed client could list a variant a few minutes early; the server refuses the purchase (`NotForSale`).
7. **Finish pool 3 must not be switched on by `PoolVersion` alone.** Templates first, then `PoolVersion=3` plus both ids appended to `PaidOrder` and `Order`, in one commit (see the comment in `MaterialCatalog.lua`).
8. **Rendezvous numbers** (one new id, 200 weeks, share of weeks untouched): wearable 188, variant 182, faceplate 190, ball 180. The spec floors are 176 / 170 / 160 / 160, lower than the scope's flat 90%, because the variant and ball pools are small.
9. `TODO.md` not updated by this lane (three lanes were writing at once); the coordinator should fold this file in.
10. `scripts/ShelfDeal.spec.lua` (Lane U) did not compile when I last checked (line 41, an unclosed `{`); it may have been mid-edit.
