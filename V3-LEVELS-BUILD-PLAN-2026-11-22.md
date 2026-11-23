# Levels matter: build plan (S1, S2, S4, S3) (Opus, 2026-11-22)

Scope: `V3-SCOPE-2026-11-21.md` 2, 3.1, 6, 7. No capes. Starts after the Alive edits commit.

## Rules

- `FeatureFlags.LevelsMatter=true` is the build ceiling. `src/shared/Levels.lua` (pure): `Levels.on(part)` needs the flag **and** (place 107705084891479 **or** Studio). Parts `track, gates, medals, juice`. Specs inject flags, place and studio, and run each suite on and off. Runtime switch: ConfigService `levels_matter` (server `LevelsConfig`), off until it has loaded once, then missing = on.
- **Going live checklist:** move the beta constants, `Alive.PlaceId` (`src/shared/Alive.lua`), `Levels.PlaceId` (`src/shared/Levels.lua`) and `Finds.PlaceId` (`src/shared/Finds.lua`, Garden finds), to the live place (and their specs' beta ids), and set the `levels_matter`, `alive_*` and `garden_finds` keys in the live config first.
- Off = today: shops, shelf weeks, Book totals, pips, toasts, writes, snapshot keys. Saved ids still display and stay owned.
- Levels come from XP and XP never falls: derive everything. Levels in gates, medals and tricks are append-only and may only loosen.

## Saves: two optional fields, no version bump

| Field | Meaning | Missing / malformed |
|---|---|---|
| `hatching.medalEggsUsed` (integer, 0 to 1e6) | Medal eggs opened | Missing = 0. Malformed: set to the number earned (fail closed) at load, never a failed load |
| `deckJuice = {pop, trail, start}` (profile top level; `At`, `Writer` as `greetOff`) | Chosen cosmetics | Missing = classic. Strings up to 32; unknown ids kept, drawn classic |

Gated items use the existing owned lists. Nothing is deleted, moved or re-priced.

- **Old server, new save:** HEAD `valid()` ignores unknown keys and both writers clone the whole record, so both fields survive. Unknown owned ids validate and render as nothing or default. `medalEggsUsed` sits outside `statEgg` because load may drop `statEgg` whole.
- **Two sessions:** hatching is lease-fenced (`SessionLost`); `deckJuice` is newest-stamp-wins.

## S1 Reward track

- **Shared** `StatRewards.lua`: rows `{id, stat, level, kind, copy, part, ref}` from `NameCatalog`, trick levels, `gate` fields, medals, plus hand rows (park, fetch, book, juice). A row exists only if its part is on and its code and art ship. `forStat`, `next(stat, level)`, `earned(stat, from, to)`. No finds or Dash rows.
- **Tricks:** `BondCatalog.HeartLevels={1,5,10,14,18,22,25,28,31,33}`; `trickLevel(bondXp, heartLevel)=max(...)`. Both unlock a prefix, so nobody loses one. Bond XP keeps accruing.
- **Looks:** `ParkPerks.lua` (pure, from `PublicStats`): swing cheer and height, slide spin, see-saw hop, catch hop; drawn by `ParkClient`/`ParkPetPose`. Longer throw: server only, saved Speed of the thrower's companion, reach 5 studs, falling back to 4 on **any** failed preflight (lane, beside spot, path).
- **Client:** `StatsPanel` next line and session-only dot; new `StatGuide.lua`; `StatToasts` names the reward; `StatsHost` passes `focus` (missing today); Heart chip replaces pips in `CompanionsHub`, `PetFocusUI`; bond toast becomes the trick ticket; `BookView` hints (best Smarts 5).
- **Copy:** `stats.next.free|gate|top`, `stats.guide.*`, `stats.reward.<id>`, `stats.levelUpReward`, `book.where.<kind>`.

## S2 Gates

- Row field `gate={stat,level}` or `gate={total}` on `WearableVariants` (14 rows, existing meshes), `BallThemes` (`tangerine_pop`), `DeckThemes` (`sky_fizz`, `storm_glass`). Levels as scope 2.1; its ranges resolve to Rose Beanie 15, tees 15, Party Hat 15, bands 20, beads 20, bell 30, Lime Beanie 30, bow 30, blush 35, Sun Hat 35.
- **Server:** pure `LevelGate.met(levelsPerPet, gate)`: any owned pet for a stat; one pet's total. `check` in the three States, inside the existing transaction, from the save: after `AlreadyOwned`/`OwnedLimit`, before `NeedStars`, returns **`NeedsLevel`** (no charge). Off: gated ids are `NotForSale`. Equip looks up `forPet(pet, math.huge)` so owned items stay wearable.
- **Must not move:** `WearableVariants.released` hides gated rows unless on (`math.huge` still renders; cache key includes the flag). **`WeeklyShelf.pools` always skips gated items** (rows change picks). **`BookCatalog` skips gated balls and plates**.
- **Client:** `LockedItem.lua` (pure: chip "Needs Jump 15", bar, train route); try-on stays; lists hide gated ids when off unless owned.
- **Copy:** `shop.needs.stat|total`, `shop.reason.needsLevel`, `shop.train`.

## S4 Medals

- Shared `Medals.lua`: 25/50/75/99, `earned(levelsByPet)`. Six slots on `StatsPanel`, Marks row in `PetInspect` from `PublicStats`, trim at 75.
- **Egg credit is derived, not granted:** `medalLeft = max(0, earned(save) - medalEggsUsed)`. Writing the XP is the grant, so crossing, replay, shutdown and seeded saves cannot pay twice, and XP lost to repair cannot re-pay. The only write is the spend: `StatEggState.buy` with `free=true` uses `statEgg.free` first, else increments `medalEggsUsed` in the same transaction (receipt `source="medal"`). New server `MedalEggs.lua`. Snapshot `statEgg.free` becomes the total.
- The candidate freezes `medals=Levels.on("medals")`. Off: credit hidden, `NoFreeEgg` as today, nothing written; it reappears when on.
- Replaces the scope's "Collect egg" key: credit sits outside the 10-egg bank, so it never blocks the daily free egg. A full 12-snack pouch is still `PouchFull`, nothing spent.
- Moment: on a crossing seen this session, after rounds/hatches (`held`), one tinted stage; several share it. At join: one ticket if credit waits. Badges: after commit, pcall, once per session each; nil ids skip.
- **Copy:** `medal.<tier>`, `medal.earned`, `medal.eggs`, `inspect.marks`.

## S3 Deck juice

- Shared `DeckJuiceCatalog.lua` (2 pops, 2 trails, 2 starts; unlock = row). Client: `FieldEffects` style (same slots and pools), `DropTrail.lua` (12 pooled), `DeckFlourish.lua`, an Effects tab in Deck style.
- Server: settings action `deckJuice {kind, id}`: known id, unlocked from the save, profile loaded, 0.25 s throttle (as `whiteSecond`); locked ids ignored, and resolved to classic at publish (board attribute). Sim, score, RNG and hash never read it.

## Client and server

Server decides gates, medal credit, throw reach, chosen juice. Existing guards apply: 0.3 s `Throttled`, `Busy`, `Pending`, `Retrying`, op id + digest (`OperationConflict`), `PriceChanged`, `ShelfChanged`. A stale client gets `NeedsLevel`, re-reads the snapshot and shows the chip.

**Existing players** keep every item they own, and everything on sale today stays ungated at the same price (a spec pins ids and prices: wearables, 10 recolours, plates, balls, toys, eggs).

## Edge cases

| Case | Expected |
|---|---|
| Write ambiguous, then retried | Same pending id; `committed` proves it; one spend |
| Shutdown mid-buy | Saved whole or not at all; op id replays the receipt |
| Same egg op, two sessions | One commits; other `SessionLost` or `AlreadySaved` |
| Two stats cross 25 in one write | Two credits |
| Bank empty, credit 3, pet all 99 | `AllMaxed`, credit kept |
| `petStats` dropped at load | Credit 0, never negative |
| Client edits its own UI | `NeedsLevel` |
| Off with a gated item worn | Still worn, removable, re-wearable; not sold |
| Bond 10, Heart 1 | Ten tricks |
| Fetch lane blocked at 5 | Throws 4 |
| Reduced Motion | No trail, still pop, medal fades |

## Tests

New: `Levels`, `StatRewards`, `LevelGate`, `GatedPurchase`, `MedalEggs` (retry, replay, malformed, off/on), `DeckJuice`, `StatGuide`, `LockedItem`, `MedalView`, `DropTrail`, `ParkPerks`, `LevelsOffParity` (200 shelf weeks, Book totals, shop lists, snapshot keys identical to HEAD).

Re-run all against `artifacts/alive-2026-11-22/baseline-specs.json`; watch `WearableVariants` (golden count 10), `WeeklyShelf`, purchase specs, `StatEggs`, `StatState`, `HatchProgress`, `BookClaim`, `BondView`, `CompanionsHub`, `PetInspect`, `ParkFetch`, `PreferenceFlush`, determinism/lockstep, `LocalizationFit`, `ClientLocalBudget` (no new column-0 locals).

**Cross-version:** load a new-build save JSON in HEAD's modules, transact, reload in new; compare both fields and owned lists.
**Studio:** buy below/at the gate; open a medal egg at pouch 12; stop the server mid-buy; hub/guide/shop captures at 844x390, 667x375, desktop, gamepad; 15-drop chain frame time, juice on/off.
**Two clients:** Marks row, perks and park looks agree; a gated recolour worn by one shows on the other.

## Art (Fable)

- 14 recolour hexes, `tangerine_pop` ramp (5 x body/deep/light); renders on both rigs.
- 2 faceplate textures (as `assets/deck/faceplates/*.png`) with `ui` and `toyShell` rows.
- Medal disc, ring, second ring, star: PNG 256 px, transparent; tier stings x4 (ogg).
- Juice (optional): PNG sheets, 4x4 of 64 px cells. 3 badge icons, 512 px.

Ships without art: S1; S2 with placeholder hexes (beta only); S4 with drawn discs and existing sounds; S3 with Frame shapes. The two plates wait: no texture, no row.

## Order and split

1. **A (shared/server):** Levels, StatRewards, LevelGate, Medals, MedalEggs, ParkPerks, catalogues, States, HatchProgress, Shelf, Book, PlayerProgress, ParkFetch, specs.
2. **B (menus):** StatsPanel, StatGuide, StatsHost, StatToasts, PetInspect, CompanionsHub, PetFocusUI, RoomView, BookView, WardrobeShop, LockedItem, ParkClient, ParkPetPose.
3. **C (deck):** FaceplateShop, BallShop, DeckJuiceCatalog, FieldEffects, DropTrail, DeckFlourish.
4. **Integrator only:** FeatureFlags, UICopy, init.client, init.server, DeckKit, translations.

A commits stubs first (Levels, StatRewards, snapshot shape); then A, B, C run together. Land S1, S2, S4, S3, each reviewed and beta-published.

## Questions (default meanwhile)

1. Medal eggs outside the 10 bank, no Collect key? **Yes.**
2. Gated items never on the weekly shelf or in Book totals? **Yes.**
3. Extra at 25? **None.** Badges: you create 3; **ids nil until then.**
4. Juice drawn from shapes until Fable's sheets? **Yes.**
5. Up to 24 free eggs per pet (about 360 Stars)? **As scoped.**
