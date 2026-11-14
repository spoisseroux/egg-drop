# Overnight build plan, 2026-11-14

Spencer authorized this run on 2026-11-14: "do all that then, over night… get fable to scope out any visuals… scope everything out properly before hand". It builds CONTENT-SCOPE slices E, B, C, D and F, and ships them as private publishes only.

Sources:
- `VISUAL-BRIEF.md` (Fable, art direction)
- `SYSTEMS-SCOPE.md` (architect)

Both scopes' open questions were answered with their recommended defaults, because Spencer is asleep:
- Blip's base colour is green.
- Stargazer is earned at Discoveries 100%.
- Blip's antennas don't glow at night until after launch.
- Bands sell as a pair.
- Plus SYSTEMS-SCOPE §8, items 1–18.

**Blip ships as data only tonight:** `FeatureFlags.SecondPet=false`. His rig, export and import are LATER. The 255 `inventoryMask` bound ships tonight, before any build can grant him.

## Lanes

Each lane owns its files exclusively; see SYSTEMS-SCOPE §7.

| Lane | Owner (agent) | Owns | Order |
|---|---|---|---|
| 0 | coordinator | flags, UICopy blocks, coach bit 10, 255 bound, OwnedLimit 128, Book per-item fallback, ClientLocalBudget spec | **done** |
| S, server core | Fable agent | `HatchProgress.lua`, `init.server.lua`, `LifetimeState`, new `BondState`/`EarnedPets`, `SessionProfile`, `PetAppearance`, `WearableState`, `FaceplateState`, `BallThemeState` | E-srv, C-srv, F-srv, D-srv |
| K, catalog + render | Fable agent | `WearableCatalog`, new `WearableVariants`, `PetAttachments`, `PetPlayVisual`, `BookCatalog`, `ToyCatalog`, `MaterialCatalog`, `PetCharmCatalog`, `PetToyGeometry`, `GardenClient`, `RewardItemArt`, new `WeeklyShelf`/`BondCatalog`; the `BearRigDefinition` regeneration | B, C-data, D-data, F-data |
| U, client UI | Fable agent | `CompanionsHub`, `WardrobeShop`, `FaceplateShop`, `BallShop`, `HueEggView`, `RoomView`, `CoachCards`, `StampCardView`, `PetFocusUI`, `MachineHub`, `DeckMenu`; `init.client.lua` in do-blocks only | E-cli, B-cli, C-cli, D-cli, F-cli |
| A, art | Fable agent | Blender: `build_bear_wearables.py` items, export; faceplate/ball data; Book atlas pages; charm and badge art | VISUAL-BRIEF MUST list |

Rules for every lane:
- Do not commit. The coordinator reviews each lane and commits it.
- Do not delete files, because Rojo crashes when a watched file is deleted.
- Do not start Play in Studio. `execute_luau` in Edit is fine for require and compile checks.
- Write specs in `scripts/*.spec.lua`. The coordinator copies them into ZZSpecs and runs them.
- `UICopy.lua`: write only inside your own block.
- `init.client.lua`: add no new column-0 locals (the budget is 219).
- No AI-generated art.

## Gates

1. **Checkpoint 1:** E plus B are reviewed, specs are green, translations synced, then a private publish.
2. **Checkpoint 2:** C, F-server and D are reviewed, specs are green, translations synced, then a private publish. F UI follows if there's time.
3. **Each lane:** a Code Reviewer pass, then fixes, then the Studio spec run, then a commit by the coordinator.

**Cut order:** deluxe ball, then finishes sales, then tricks 3–5, then the `win_each_item` mask (use the fallback instead), then the Leaf charm, then the F UI.

**Never cut:** E, the 255 bound, F server accrual.

**Usage guard:** if the weekly all-models limit passes 95%, stop and write the status into PROGRESS.md. An hourly heartbeat cron at :17 resumes the work after any stop.
