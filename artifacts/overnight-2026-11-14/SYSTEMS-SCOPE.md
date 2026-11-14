# Overnight 2026-11-14: systems scope for slices E, B, C, D, F

Scoping only. Written against `feat/egg-drop-arcade-polish` at `d4c21cc`, after slice A (`fd6435c`, `d4c21cc`). It reads with `CONTENT-SCOPE.md` §2–§6 (all five §6 recommendations are accepted) and with `VISUAL-BRIEF.md` in this folder, which owns the art list and the art cut order. Every price is still `[PLACEHOLDER]`.

**Build order:** E (generalization code) → B → C → D → F. The order is fixed, but the work can be written in three parallel lanes (§7).

**Rules for the whole build**

- **The save stays v11.** Every new field is optional and additive, like `playDate` and `coachMask` (`HatchProgress.lua:171-175`).
  - A missing field is valid.
  - A malformed field is dropped at load (`Hatching.load`, `HatchProgress.lua:294-301`) and never fails the load.
  - Bumping the version would also touch `HueState.valid`, which pins version numbers (memory note `studio-spec-running`), so nothing here bumps it.
- **Every Stars change goes through `transact`** (`HatchProgress.lua:454`), with an operation id and a digest.
  - No new remote events. New actions ride `HatchRequest` (`init.server.lua:1008`).
  - Replies ride the existing result remotes.
- **No new top-level locals in `src/client/init.client.lua`.** It already has 219 `local` lines at column 0.
  - New wiring goes on the `clientUI` table (`init.client.lua:46`) or inside a `do ... end` block, like the Wardrobe block (`init.client.lua:1064`).
  - A spec checks this (§6, `ClientLocalBudget`).
- **`UICopy.lua` is append-only, one block per slice.** Before the lanes start, lane 0 adds empty stubs `e2={}`, `variants={}`, `shelf={}`, `pool3={}`, `bond={}` ahead of the closing `}` at `UICopy.lua:241`. Each lane then writes only inside its own stub.
- **Translations before every publish:** `export_localization_csv.py`, then `sync_localization.py` (AGENTS.md).

---

## 1. Slice E: generalize "one pet", and grant Blip on the 7th stamp

### 1.1 Feature flag and the "art not ready" plan

**Add `SecondPet=false` to `FeatureFlags.lua:13`.** Blip's rig is not in this build (VISUAL-BRIEF §6 puts Blip's export, import, rig data and portraits in LATER). The code still ships safely:

| Piece | `SecondPet=false` (tonight's publish) | `SecondPet=true` (week-1 update, once the rig is in) |
|---|---|---|
| `PetCatalog` entry `blip` | Present. Appended to `Pets.collection` at **index 8** (bit `0x80`), after the rares. It does **not** go into the `Pets` array, so `migrate()` (`HatchProgress.lua:78-83`, which walks `Pets[1..rank]`) and the rare indices are unchanged | same |
| Save validator `inventoryMask` | Upper bound raised **127 → 255** (`HatchProgress.lua:110`) | same |
| `Pets.active` (`PetCatalog.lua:46-47`) | Bear only | Bear + Blip, **only if** `PetRigDefinitions.blip ~= nil` |
| Grant | Never | On the 7th lifetime stamp, plus a repair grant for saves already past it |
| Book Pets page (`BookCatalog.lua:35-37`) | Closed (reads `#Pets.active`) | Opens automatically |

- **One shared gate: `EarnedPets.enabled(petId)`** = `FeatureFlags.SecondPet and Defs[petId] ~= nil`.
  - Server and client both read it, so they can never disagree about whether Blip exists.
  - `Pets.active` is built from the same rule.
- **Rollback safety (post-launch).** The 255 bound must be in a published build **before** any build can grant Blip.
  - A server running an older build would read a mask with bit `0x80` as `InvalidData` and hand the player the temporary `nectar=0` record (`HatchProgress.lua:321-326`).
  - Shipping E tonight with the flag off is exactly what makes this safe.
- **Studio art QA without shipping a rig:** a Studio-only alias, `if RunService:IsStudio() and workspace:GetAttribute("StudioBlipPlaceholder") then definitions.blip = <Bear clone, id "blip">`, placed in `PetRigDefinitions.lua` after line 7.
  - A live server never runs this.
  - It lets the code paths (switching, wardrobe, hue, book) be exercised end to end tonight.

### 1.2 The one-pet sites (39, against the scope's estimate of about 25)

Classes:

- **G (generalize):** replace the `pip` literal with "the active companion" or "the first owned active pet".
- **D (data):** add `blip` to a per-pet table.
- **R (rig-specific, keep):** the literal is correct. It names a rig behaviour, not the roster.
- **L (legacy, keep):** retired-pet compatibility. Do not touch.

| # | Site | Today | Class | Approach |
|---|---|---|---|---|
| 1 | `HatchProgress.lua:110` | `inventoryMask ≤ 127` | G | `≤ 255` (`2^#Pets.collection - 1`, computed) |
| 2 | `HatchProgress.lua:779`, `:813` | `MeetPipFirst` on hatch | L | Hatch recipes are all retired (`EggCatalog.lua:10-24`). Leave it |
| 3 | `HatchProgress.lua:839-855` | `grantStarter` hardcodes pip | L | The onboarding starter *is* the Bear. Leave it. The new `grantEarnedPet` is a separate function (§1.3) |
| 4 | `init.server.lua:98-100` `hasPip` | Room unlock = owns pip | G-lite | Rename to `hasPet`, true if `inventoryMask & activeMask ≠ 0`. Same behaviour today |
| 5 | `init.server.lua:352-356` | Companion not owned → equip pip | G | Equip `firstOwnedActive(mask)`. Also covers "owned but not active" (a Blip rig removed by a rollback): never leave an unrenderable companion equipped |
| 6 | `init.server.lua:407-408` | `RunFamily`/`SelectedFamily` default `"pip"` | L | Families are frozen at 4 (`EggCatalog.lua:26`); `blip` has no family. Leave it |
| 7 | `init.server.lua:500-501` | `runFamily` falls back to pip | L | `FamilyMastery.ownsFamily(…,"blip")` is false, so Blip rounds report `family="pip"`. That is fine: the award validator (`HatchProgress.lua:1045`) needs an owned family. **Do not add `blip` to `Families`:** `validBase` iterates `Families` over `state.mastery` (`HatchProgress.lua:133-136`), so every old save would fail |
| 8 | `init.server.lua:584`, `:1544` | `mode = Room if owns pip` | G-lite | `hasPet(board)` |
| 9 | `init.server.lua:860-866` `companion` action | `isOwned` | G | Also require `Pets.isActive(pet)` |
| 10 | `init.server.lua:1341` | After the starter grant, `companionId="pip"` | L | Correct for onboarding |
| 11 | `init.server.lua:1543` | `selectedFamily` default pip | L | as #7 |
| 12 | `init.server.lua:398-403` `OwnedPets` prefix | Legacy welcome-guide count | L | Leave it |
| 13 | `SessionProfile.lua:16-18` | Fallback companion pip | G | `if owned and active → keep; else firstOwnedActive(mask)` |
| 14 | `PetAppearance.lua:2` `Ids` | 7 ids | D | Append `"blip"`. Charm preferences for an unlisted id are silently dropped (`:13-15`) |
| 15 | `HueCatalog.lua:2` `Supported` | 7 ids | D | Add `blip=true`. Charm requests also gate on it (`PetAppearance.lua:5`, `:74`) |
| 16 | `PetCatalog.lua:46-47` `active` | `{pip}` | G | Built from `EarnedPets.enabled` |
| 17 | `FamilyMastery.lua:14` | Legacy rare ids | L | Leave it |
| 18 | `BookCatalog.lua:35-37`, `:111`, `:132` | Read `Pets.active` | none | Already general. The Pets page and Blip's refits join when Blip is active |
| 19 | `WearableCatalog.lua:52-54` `Fit` | `bear` only | D | `Fit.blip` comes with the rig. Missing means a zero offset (`:55-59`), which is safe |
| 20 | `PetRigDefinitions.lua:9-11` | Neutral white palette for every rig | D | **Exempt `blip`**, so its undyed palette is the showcase green `#7BD88F` / `#D6F5E3`. That answers VISUAL-BRIEF's open question with no save write (§8 #3) |
| 21 | `CompanionsHub.lua:128`, `:135`, `:235`, `:409` | `activeId or "pip"` | G | `activeId or Hub.firstOwned(state)`. `Hub.petCards` (`:78-84`) iterates `Pets.collection`; filter it to `Pets.isActive` |
| 22 | `WardrobeShop.lua:144`, `:681` | `petId="pip"` default and fallback | G | Default `nil` until `open(petId)`; fall back to the first active pet that `hasItems` |
| 23 | `DeckMenu.lua:22`, `:56`, `:69` | Bear portrait and crest on the deck menu | G | Pass the companion id in; fall back to the first active pet |
| 24 | `init.client.lua:1071` | Wardrobe context `petId or "pip"` | G | `shop.petId` (no fallback once #22 lands) |
| 25 | `init.client.lua:1929` | Results "{pet} is impressed" uses the Bear's name | G | `Pets.byId[board:GetAttribute("CompanionId")]` |
| 26 | `init.client.lua:2010` | Pre-onboarding meter text | L | Shows only while `owned == 0`, which is always pre-Bear |
| 27 | `init.client.lua:2636` | Coach companion fallback | G-lite | Already reads `CompanionId` first. Keep the fallback |
| 28 | `FirstHatchGuide.lua:92` | Bear name | L | Onboarding only |
| 29 | `HueEggView.lua:66` | `petId="pip"` initial | G | Initial `nil`. `open(petId)` already sets it |
| 30 | `HueEggView.lua:1300` | Charm icon by id | D (slice D) | Icons for the new charm shapes |
| 31 | `RoomView.lua:476`, `:482` | Charm toggle only on pip/puddle | G | Use `PetAppearance.supported[id]`, i.e. `Hue.Supported` (it holds blip after #15) |
| 32 | `RoomView.lua:655`, `:658` | Greeting capture by rig id | R | Add `rig=="blip"` beside `"bear"`: Blip is on the Bear base, so the same capture path applies |
| 33 | `HatchCinematic.lua:25`, `:279`, `:451` | Greeting pose for pip/puddle; pip fallback | R + L | Blip is never hatched (no recipe). `:25` gains `or pet.id=="blip"` for the "a friend arrived" card if it reuses `rest()` |
| 34 | `GardenPetVisual.lua:378` | Walk squash only for `petId=="pip"` | R | Key on the rig: `definition.id=="bear" or definition.id=="blip"` |
| 35 | `GardenPetVisual.lua:96`, `:105`, `:108`, `:62`, `:88` | zivvi/ovelle import quirks | R | Blip takes the "new FBX at 100x" path automatically. No change |
| 36 | `PetPortrait.lua:45`, `:52-53` | Sprite map, pip accent | D | Blip's portrait comes from `NewBabyPortraitDefinitions` (`:46-47`) with the rig. The accent falls through to `pet.accent` |
| 37 | `FamilyCrest.lua:18`, `:50` | Crest per family, default pip | L | Crests are family art; Blip shows the pip crest on the deck menu (#23). Acceptable for v1 |
| 38 | `PetPlayVisual.lua:8-9`, `:17` | Hand map per pet, pip fallback | D | Add `blip={left="HandL",right="HandR"}`. The fallback already covers it |
| 39 | `PetCooScheduler.lua:14` | Coo pitch per pet | D | `blip=1.08` (placeholder; Astra owns the audio) |

There are also two client sites that need no change: `EggHatchView.lua:257` and `RevealStage.lua:224` only fall back to the Bear when there is no result pet (L). Specs that hardcode the roster also need updating: `scripts/NeutralPetRoster.spec.lua:13`, `:19`, `:25` (`#Pets.collection==7`, mask 127) and `scripts/HatchProgress.spec.lua:56`.

**Count:** 17 G, 8 D, 4 R, 10 L. About 29 sites change; 10 are documented as intentional and left alone.

### 1.3 The 7th-stamp grant transaction

- **New module `src/shared/EarnedPets.lua`** (pure):
  - `Rules = { blip = { stamps = 7 } }`
  - `enabled(petId)` (§1.1)
  - `owed(state)`: every enabled pet with `state.stamps >= rule.stamps` that the player does not own yet.
- **New server function `Hatching.grantEarnedPet(handle, petId)`** in `HatchProgress.lua`, placed after `grantStarter` (`:855`), modelled on it and on `coachMark` (`:858-871`):
  - signature `"earnedpet:" .. petId`, digest `"earnedpet:" .. petId`
  - candidate `{petId}`
  - apply:
    - not enabled → `"Disabled"`
    - already owned → `"AlreadyOwned"`, which the caller treats as success
    - `state.stamps < rule` → `"NotEarned"`
    - otherwise `inventoryMask |= bit(petId)`
  - **No `lastHatch`.** Setting it would block hatching, awards and items behind `RevealPending` (`HatchProgress.lua:811`, `:758`) until an ack.
  - **The ownership bit is the idempotency receipt.** A replayed callback, a retried write or a second server all converge on the same result.
  - `Lifetime.record` (`HatchProgress.lua:488`) already counts the new bit into `stats.pets` (`LifetimeState.lua:62-63`).
- **Two triggers on the host (`init.server.lua`).** Both use one loop `grantEarned(player, board)`, a copy of the `grantWelcome` pattern (`:1327-1350`): busy-aware, retries every 2 s, stops on close.
  1. **After a successful `daily` claim** (`init.server.lua:1244-1249`): if `EarnedPets.owed(state)` is not empty, start the loop.
  2. **On profile ready and on save reload** (beside `:1462`, and in the reload block `:1538-1545`). This repairs:
     - saves that passed 7 stamps while the flag was off
     - a server that died between the stamp write and the pet write
- **Why not in the same write as the stamp?** One code path that both the 7th stamp and the repair use is easier to prove than two. The gap between the two writes is harmless: a pet that is owed is granted on the next join.
- **The reveal needs no new save field.**
  - Append `CoachMarks.Bits.petArrived=10` (`CoachMarks.lua:13-24`; append-only, `Max` covers bits 0..30).
  - The client shows the "a friend arrived" card when it owns Blip, the bit is unset and Room is presentable.
  - The card's **Say hi** button sends the existing `companion` action (`init.server.lua:860`), then `coachMark("petArrived")`.
  - The companion does **not** switch automatically (§8 #2).
- **Analytics:** `Economy.event(player, "PetEarned", 1, {petId})`. One new low-cardinality name (slice A PLAN, "Risks").

### 1.4 Data and save changes (E)

| Field | Change | How old saves stay valid |
|---|---|---|
| `inventoryMask` | Bound 127 → 255 | Every old value (≤ 127) is still inside the bound. `migrate()` writes only bits 1–7 |
| `coachMask` | New bit 10 | Already tolerant of unknown bits (`CoachMarks.lua:6-9`) |
| `petWearables[blip]`, `petHues[blip]`, `petMaterials[blip]`, `petToys[blip]`, `petFeatures[blip]` | Appear only after the grant | Each validator requires the pet to be owned (`WearableState.lua:27`, `ToyState.lua:64`, `MaterialState.lua:64`, `HueState.lua:149`, `FeatureState.lua:63`). After the grant it is owned. **Nothing ever un-owns a pet.** |
| `lastPetAward.petId`, `lastHatch.petId` | May name `blip` | `Pets.byId` holds it (`HatchProgress.lua:145-148`, `:157`) |
| Profile `companionId` | May be `blip` | `PlayerProgress.lua:312`, `:322` check `Pets.byId`. `SessionProfile.hydrate` repairs it if Blip is not active (#13) |

### 1.5 Server validation (E)

- `companion` action: owned **and** active (#9).
- `wearableBuy`/`wearableEquip` for `blip`: already gated on ownership (`WearableState.lua:66`, `:91`) and on the catalog (`WearableCatalog.forPet("blip")` is empty until the rig carries `wearableItems`). The result is `NotForSale`.
- Hue, finish, toy and feature for `blip`: owned-gated in each state module. Hue also needs `Supported` (#15).
- `grantEarnedPet`: flag, rule and ownership are re-checked inside UpdateAsync.

### 1.6 Client UI touchpoints (E)

- `CompanionsHub` selector: Blip's card appears when it is owned and active.
- `CoachCards`: the arrival card, using `UICopy` `e2.arrived.title`, `.line`, `.sayHi`.
- `StampCardView` (`src/client/StampCardView.lua`): on stamp 7, a "Someone's on the way…" teaser line, shown only while `EarnedPets.enabled("blip")` and Blip is not owned. With the flag off it shows nothing.
- `BookView`: the Pets page joins on its own (`BookView.lua:68-76`).

### 1.7 Specs (E)

| Spec | Side | Cases |
|---|---|---|
| `scripts/EarnedPet.spec.lua` → `src/server/ZZSpecs/EarnedPet.lua` | server | Flag off: no grant at 7 stamps and `owed` is empty. Flag on (inject `enabled`): the 7th stamp grants; a replay or an ambiguous write grants once; the repair at 9 stamps works; a mask with bit `0x80` is valid; a save at ≤127 still loads; `stats.pets` goes up by 1; `lastHatch` stays nil; awards and hatches are not blocked |
| `scripts/NeutralPetRoster.spec.lua` (update) | shared | `#Pets.collection==8`, `blip.index==8`, `Pets.active` follows `enabled`, `Families` is still 4 |
| `scripts/PetGeneralization.spec.lua` → client ZZSpecs | client | A grep-style assertion over module Sources: every `"pip"` literal in `src/client` and `src/server` sits on an allowlisted line (the L and R rows above), so a new one fails the spec. Plus `Hub.petCards` filters inactive pets, and `WardrobeShop.open(nil)` picks the first active pet |
| `scripts/CoachMask.spec.lua` (extend) | server | Bit 10 round-trips |

### 1.8 Risks (E)

- **The rollback hazard** (§1.1). Mitigated by shipping the 255 bound tonight with the flag off.
- **A Blip rig that half-loads.** `GardenPetVisual.new` asserts that the definition exists (`GardenPetVisual.lua:196`). The `isActive` gates in #5, #9, #13 and #21 keep an unrenderable pet from ever being the companion.
- **The Wardrobe book page drops** for Bear-only players when Blip's refits go active. Claims are kept (`BookCatalog.lua:14`). Accepted (§8 #5).

---

## 2. Slice B: recolour variants and the new tabs

### 2.1 Data model decision: **a variant is its own item id**

| | Separate item id (`beanie_mint`) | Item + palette (`{id="beanie", palette="mint"}`) |
|---|---|---|
| Save shape | Unchanged: `owned` is a list of ids, `equipped` maps slot → id (`WearableState.lua:6`) | `equipped` values become tables, so `WearableState.valid` (`:35-38`), `PetAttachmentRules.normalize` (`:29-34`), `PetAppearance.public` (`:40-41`) and the book all change |
| Old saves | Valid as they are | Need a migration or a dual reader |
| Ownership | One id per purchase; per pet as today | Ownership would have to be (item, palette) pairs |
| Price | Inherits the base tier and can override | Same |
| Cost | Mapping to the base at render time (one function) | A schema change touching about 6 modules |

**Decision:** a separate id. It is the only option with zero save change, and every server path (`WearableState.check`, `applyBuy`, `applyEquip`) already treats ids as opaque.

### 2.2 Files

- **New `src/shared/WearableVariants.lua`** (data plus a pure validator):
  - rows `{id, base, name, color, price?, from?}`
  - `from` is an optional week number (§3), so Spencer can preload future variants that unlock on their own with no server state.
  - Ten rows from VISUAL-BRIEF §1.
- **`WearableCatalog.lua:16-37` `forPet`:** after the rig items, append every variant whose `base` exists for that pet (and whose `from ≤ currentWeek`, or which has no `from`). Each variant item gets:
  - the base's `slot`, `keys`, `perSide`, `flags` and `tier`
  - `variant=true`, `base=<id>`, `color=<hex>`
  - `price = row.price or base.price`
  - `primary`/`role` copied from the base, so the renderer knows which pieces are the main ones

  Validation asserts at require time, like `BookCatalog.lua:60-66`: ids are unique, at most 32 characters (`WearableState.lua:14`), never collide with a base id, and the base exists.
- **Carry-over to Blip is automatic.** `forPet("blip")` lists `beanie_mint` as soon as Blip's rig has a `beanie`.
- **New `WearableCatalog.renderMap(petId, wearables)`** returns:
  - `mapped`: the same slot keys, with variant ids replaced by base ids
  - `tints`: slot key → `{to=hex, primary=<own hex or role>}`
- **Main-piece rule, verified against `BearRigDefinition` data:**
  - For an own-colour base (`beanie` is `own:#E9574C`), pieces with `colorRole=="own"` and `color==primary` are recoloured.
  - For a role-tinted base (`bellcollar` is `secondary`), the variant recolours the **own** piece (`Neck_BellCollar_Bell` `#FFC240`); the band keeps its secondary tint.
  - **Rule:** a variant row may set `piece=<attachment name>`. Without it, the default is "pieces whose own colour equals the base's main own colour". Bell Collar rows set `piece="Neck_BellCollar_Bell"`.
- **`PetPlayVisual.lua:47-60`:**
  - Normalize `renderMap(...).mapped` instead of the raw wearables.
  - Build the cache key at `:49` from the **unmapped** signature, so switching between `beanie` and `beanie_mint` rebuilds.
  - Pass `tints` into `Attachments.build`.
- **`PetAttachments.lua:41-45` `build(v, resolved, source, tints)`:** when `a.item` and `tints[key]` match the main-piece rule, `color = Color3.fromHex(tint.to)` and the role stays `"own"`.
- **`WardrobeShop.lua:518`:** preview signature from the unmapped wearables, with tints passed the same way.
- **`WearableCatalog.lua:8-11` `Tabs`:** append `eyewear` (Eyewear), `cheek` (Cheek), `wrist` (Wrist) and `ankle` (Ankle) after `tail`. The slots already exist on the Bear rig (`slots` includes all four).
- **`WardrobeShop`:** show only tabs that have at least one item for the current pet, so Ankle stays hidden until Jingle Anklets exists (VISUAL-BRIEF: LATER).
  - `Shop:items()` and `Shop:slot()` (`WardrobeShop.lua:158-159`) index a filtered tab list instead of `Catalog.Tabs`.
  - `WearableState.equipResult` (`:99-101`) still validates take-off against the full `Catalog.Tabs`, so appending is enough on the server.
- **`BookCatalog.lua:112`:** skip `item.variant` (§8 #4).
- **`WearableCatalog.OwnedLimit` 64 → 128** (`WearableCatalog.lua:6`, used by `WearableState.lua:12`, `:32`, `:71`).
  - Bear count after B: 17 + 10 new + 10 variants = 37.
  - At 3 variants a week, 64 is reached in about 9 weeks.
  - Raising the bound keeps every old save valid. The only exposure is a rollback after a player owns more than 64.
- **Art pipeline (Astra's lane):** `scripts/build_bear_wearables.py` `ITEMS` → `export_bear_attachments.py` → `build_bear_attachments.py` → `build_bear_assets.py`, which regenerates `BearRigDefinition.wearableItems`. That is the same path as slice A, PLAN Part 1.

### 2.3 Data and save (B)

- No save change. Variant ids are stored like any item id.
- Old saves have no variant ids. A save that holds a variant id a future catalog removes keeps it: `valid` is tolerant (`WearableState.lua:21-22`), and normalize drops it at render (`PetAttachmentRules.lua:28-34`).

### 2.4 Server validation (B)

No new path.

- `Catalog.item(petId, variantId)` resolves, so the price, ownership and slot checks in `WearableState.check` and `equipResult` apply unchanged.
- A client cannot invent a colour: the hex lives only in shared data.

### 2.5 Client UI (B)

- **`WardrobeShop`:**
  - A variant card shows the base name with a colour swatch dot, and its tier chip (`:28`).
  - Variants sit right after their base within the slot tab, since `forPet` order is base, then its variants.
  - The 4 new tabs keep their text labels; tab icons are NICE in the brief.
  - The tab bar grows from 7 to up to 10 visible tabs. On phone it needs a scrollable strip (check against `UsableSheetWidth.spec`).
- **`CompanionsHub` "Wearing" line** (`CompanionsHub.lua:74-75`): names come from `Catalog.item`, so a variant reads "Mint Pom Beanie".

### 2.6 Specs (B)

| Spec | Cases |
|---|---|
| `scripts/WearableVariants.spec.lua` (shared, run from the server ZZSpecs) | Rows valid (unique, ≤ 32 characters, base exists); `forPet("pip")` lists 10 variants at base prices; `from` in the future hides a row; a pet without the base lists none; `renderMap` maps to base ids; the tint picks the main piece (beanie) and the explicit bell piece (bellcollar); trim stays secondary |
| `scripts/WearablePurchase.spec.lua` (extend) | Buy and equip `beanie_mint`; owning `beanie` does not own `beanie_mint`; equipping `beanie_mint` replaces `beanie` in `Hat`; `OwnedLimit` is 128 |
| `scripts/PetAttachments.spec.lua` (extend) | The cache key changes beanie → beanie_mint; the part colour is `#7FE0CF` |
| `scripts/WardrobeTabs.spec.lua` (client) | Empty tabs are hidden; Q/E cycles only the visible tabs; take-off on a hidden slot still validates |

### 2.7 Risks (B)

- **Book atlas is full** (VISUAL-BRIEF item 5). `BookView` falls back to name chips for a whole page if any item is undrawable (`BookView.lua:43-46`). That would knock every slice's page back to chips. **Fix in B:** a per-item fallback (draw a chip only for the missing cell). It is a small change in `BookView`'s tile builder and keeps the B, C and D pages drawable while atlas page 3 is pending.
- **Phone tab overflow** with 10 tabs.
- **Variant colours on a dyed pet:** none clash with face ink by brief design. Capture-check one dark and one light dye.

---

## 3. Slice C: weekly shelf, the deluxe tier, book-only plate #2

### 3.1 Auto-rotating weekly shelf: deterministic, no server state

- **New `src/shared/WeeklyShelf.lua`** (pure).
- **Week:** `Shelf.week(now) = QuestRotation.week(tonumber(Daily.dayOf(now)))` (`QuestRotation.lua:4-10`). It starts Monday and resets with the weekly quests.
- **Pools**, sorted by id:
  - `wearable`: every Bear base item and variant with a price.
  - `faceplate`: `Themes.Order` with `Themes.price`, excluding `tier=="deluxe"` and book-only plates.
  - `ball`: `Balls.Order` with `Balls.price`, excluding deluxe.
- **Three slots:**
  1. A variant: rows with `from==week` first, otherwise any variant.
  2. A non-variant wearable.
  3. A faceplate in even weeks, a ball theme in odd weeks.
- **Pick by rendezvous hashing:** the highest `hash(week, salt, id)` wins. Adding catalog items mid-week changes a slot only if the new item outranks the current one, so a publish rarely reshuffles the live shelf.
  - Exclude last week's picks (compute `slots(week-1)`, depth 1, no recursion).
  - `Shelf.Salt` is a constant; bump it only to force a reshuffle.
- **Discount:** 20%. `shelfPrice = price - floor(price*0.2 + 0.5)`, so 15→12, 30→24, 60→48, 20→16, 40→32, 80→64, 120→96.
- **Scope:** a shelf price applies to that item id for any pet that sells it. Wardrobe ownership is still per pet.
- **API:**
  - `Shelf.slots(week)` returns `{kind, id, full, price}` ×3.
  - `Shelf.price(kind, id, week)` returns the discounted price if `id` is on this week's shelf, otherwise nil.
- **Feature flag:** `WeeklyShelf=true`. Off means `Shelf.slots` returns `{}`, so every price is full.

### 3.2 Server validation (shelf)

- **Expected price.** Each check takes the week:
  - `WearableState.check(state, petId, itemId, price, week)` (`WearableState.lua:65-74`)
  - `Faceplates.check(…, week)` (`FaceplateState.lua:27-35`)
  - `BallThemeState.check(…, week)` (`BallThemeState.lua` `State.check`)

  Each computes `expected = Shelf.price(kind, id, week) or base price`, and `price ~= expected` → `"PriceChanged"` (as today).
- **The week is in the candidate.**
  - `buyWearable` (`HatchProgress.lua:905-919`), `buyFaceplate` (`:887-900`) and `buyBallTheme` (`:945-958`) add `week = Shelf.week(now)` to the frozen candidate.
  - `price` goes into the digest, so a reused op id at another price is an `OperationConflict`.
- **A week boundary mid-write.** Inside apply, `Shelf.week(handle.adapter.now()) ~= candidate.week` → `"ShelfChanged"`, with no charge.
  - `committed()` runs before apply (`HatchProgress.lua:480`), so a write that had already committed still proves "Saved" after the boundary.
  - Apply functions do not take `handle`. The three buy functions wrap the state apply in a closure that captures `handle.adapter.now`, as `parkPlay` does (`HatchProgress.lua:1129-1131`).
- **Book claims and Robux are untouched.**

### 3.3 Deluxe tier (160)

- **Faceplates** are generated from `assets/deck/faceplates/faceplates.json` through `scripts/deck_art/build_faceplates.py` (Astra; `"deluxe": 160` in `PRICE`).
  - `DeckThemes.lua:70-105` copies `tier` and `priceStars` through unchanged, so no Lua logic changes.
  - `Themes.Order` (`DeckThemes.lua:3-4`) gains Grape Soda, Rose Chrome and Garden Party.
- **Ball themes:** `BallThemes.ById` gets a `tier="deluxe", price=160` row, but only if Ducklings ships. It is LATER in the brief and first in the cut order, so the default is no deluxe ball tonight. Bubbles (40) ships.
- **UI tier chips:** add `deluxe={"DELUXE", <gold>}` to `FaceplateShop.lua:40` and `BallShop.lua:21`.
- **Server:** no change. The price comes from the catalog. Deluxe items are excluded from the shelf (§3.1).

### 3.4 Book-only plate #2 (Stargazer)

- **Rule:** Discoveries page at 100% (§8 #8).
- **`BookCatalog.lua:26`:** keep `BookOnlyFaceplate="bookworm"` for compatibility and add `Book.BookOnlyPlates = { {id="bookworm", earned=pages3}, {id="stargazer", earned=claimed("discoveries.100")} }`, plus `Book.platesOwed(state)`.
- **`HatchProgress.lua:980-992`:** `bookFaceplateOwed` and `grantBookFaceplate` loop over `BookOnlyPlates`. The repair-on-repeat-claim behaviour (`:999-1002`) carries over to every plate.
- **`init.server.lua:1121-1137`:** `plateBefore` and `granted` become "the first plate in `BookOnlyPlates` owned after and not before".
- **`DeckThemes.lua:108` `Themes.BookOnly`:** append `stargazer`. Its plate row gets `bookOnly=true` (the generator sets it).
- **Faceplates page `bookOnly` list** (`BookCatalog.lua:107`): both plates.

### 3.5 Data and save (C)

None. The shelf is computed from data. Plates are stored in `faceplates` (limit 64, `FaceplateState.lua:5`) as before.

### 3.6 Client UI (C)

- **`WardrobeShop`, `FaceplateShop`, `BallShop`:**
  - A "THIS WEEK −20%" chip.
  - The struck-through full price beside the shelf price.
  - The buy request sends the shelf price.
  - The client needs the same week the server uses. `public.dailyDay` already exists (`HatchProgress.lua:372`), so derive `week` from it rather than from the client clock.
- **Hub strip:** one line on the Deck style and Companions tiles, "This week: {a}, {b}, {c}" (`MachineHub`; UICopy `shelf.line`). No countdown (CONTENT-SCOPE §4.2: no FOMO).
- **`BookView`:** the Faceplates page lists two book-only plates.

### 3.7 Specs (C)

| Spec | Cases |
|---|---|
| `scripts/WeeklyShelf.spec.lua` (shared) | Same week gives the same slots; adjacent weeks differ; never deluxe, book-only or free; slot 1 is a variant; adding one catalog id changes at most one slot in at least 90% of 200 weeks (rendezvous property); price table matches §3.1 |
| `scripts/WearablePurchase.spec.lua`, `FaceplatePurchase.spec.lua`, `BallThemePurchase.spec.lua` (extend) | Shelf price accepted on the shelf week; full price refused (PriceChanged) on the shelf week; a boundary between request and apply gives ShelfChanged and charges 0; an ambiguous write retried after the boundary pays once |
| `scripts/BookClaim.spec.lua` (extend) | `discoveries.100` grants stargazer; a repeat claim repairs a missed plate; bookworm behaviour unchanged |

### 3.8 Risks (C)

- **The client computes a different week than the server** (clock skew near Monday 05:00 UTC). It is harmless, since the server refuses with PriceChanged and the client re-reads the snapshot. Specs cover it.
- **Faceplate texture uploads** need Open Cloud (memory: `open_cloud_invoke`). A plate without a texture must stay out of `Order`, so the generator should emit only uploaded plates.
- **Stargazer depends on all 17 Discoveries** (§4.4), including `win_each_item`. If that badge is cut, the page still works; it just has fewer items.

---

## 4. Slice D: toy pool, finish pool, earned charms, +6 Discoveries

### 4.1 Toy pool ("v3" in the scope; it is actually `Pools[2]`, since the toy pool is at version 1)

- **`ToyCatalog.lua:2-5`:**
  - `PoolVersion=2`
  - `Pools[2] = {"ball","bone","bubble_wand","mini_plush","sparkler","squeaky_carrot","wobble_top"}`, containing only the toys that ship.
  - Add the new ids to `ById` and `Order`.
  - Append them to `PaidOrder`, so a restricted player's fixed next item stays the old ones first (`ToyCatalog.lua:15-19`).
- **Hard constraint: every pool must be in strictly ascending id order.**
  - `ToyState.poolValid` (`ToyState.lua:15-20`) requires `id > previous`.
  - `purchaseEligibility` compares `quote.eligible` with `Catalog.remaining` in pool order (`:107`).
  - An unsorted pool makes every purchase `PoolChanged`.
- **Keep `Pools[1]` forever.** Stored `toyReceipts` re-validate their quote against `Pools[q.poolVersion]` on every load (`ToyState.lua:46-50`, `:69`). Removing it fails every save that holds a toy receipt.
- **In-flight reservation across the deploy:** a `toyReservation` with `poolVersion=1` settles against pool 1 (`purchaseEligibility` uses `quote.poolVersion`). Correct: the player gets an old-pool toy, as quoted.
- **Stale client:** add `if quote.poolVersion ~= ToyCatalog.PoolVersion then "LegacyPurchaseClosed"` for new `toyBuy` in `itemCommand` (`HatchProgress.lua:713-714`). It mirrors the material check at `:649`.
- **Render whitelists** (each currently names only three toys):
  - `PetToyGeometry.lua:6` (+ geometry per the brief)
  - `PetPlayVisual.lua:40`
  - `GardenClient.lua:69`
  - `RewardItemArt.lua:29`
  - `BookView.lua:52` (atlas slots)

  Replace the three literal whitelists with `ToyCatalog.known(id)`, and give `PetToyGeometry` a lookup table keyed by id.
- **Ship only the toys whose geometry is built.** Brief: Wobble Top and Squeaky Carrot are MUST; Mini Plush and Bubble Wand are NICE. The pool list is the gate.

### 4.2 Finish pool v3

- `MaterialCatalog` `Pools[3] = {"gloss","matte","pearl_edge","speckle_satin"}`, sorted, with `Pools[1]` and `Pools[2]` kept.
- **Hard constraint:** `MaterialCatalog.available` (`MaterialCatalog.lua:26-33`) requires a verified `SurfaceAppearance` template for **every** `PaidOrder` profile. Adding pearl or satin to `PaidOrder` without templates turns **all** material purchases into `MaterialsUnavailable` (`init.server.lua:1197`).
- **Plan:** commit the `Pools[3]` and `ById` data, but keep `PoolVersion=2` and `PaidOrder` unchanged until `BuildPetMaterialTemplates.lua` has produced verified templates in Studio. Flip both in one later commit.
- Also needs `PetMaterialConfig.lua:19-21` profiles and `MaterialFinishPreview.lua:46`, `:57` labels.
- Brief: LATER, second in the cut order. **Default: data only tonight; not sold.**

### 4.3 Earned charm shapes

- **`PetCharmCatalog.lua:3-4`:** add `heart`, `star` and `leaf` to `Order`/`ById`, each with a `rule`:
  - `heart`: `book.claimed` has `"wardrobe.100"`
  - `star`: `stats.weeklyBonuses >= 4`
  - `leaf`: `stamps >= 14`

  New `Catalog.earned(id, facts)`. Free shapes have no rule.
- **Every rule is monotonic.** Claims, stamps and counters never decrease, so an earned shape can never become unearned. That is why the check can be stateless.
- **New optional counter `weeklyBonuses`** in `LifetimeState.lua`:
  - Add it to `known` (`:14`) but **not** to the required `Counters` list (`:7-8`). `valid` requires only the listed keys and tolerates extra capped integers (`:25-30`), so old saves stay valid.
  - Increment it in `Lifetime.record` (`:57`) when `signature` matches `^quest:weekly:.+:0$` and the wallet went up. Slot 0 is the weekly bonus (`QuestState.lua:93-104`). **No `QuestState` edit.**
  - Not backfilled: counting starts at deploy (§8 #10).
- **Server validation:**
  - `PetAppearance.request` (`PetAppearance.lua:73-104`) gains an `earned(shape)` callback beside `owns`; locked → `"Locked"`.
  - `init.server.lua:781-782` passes `function(shape) return PetCharms.earned(shape, facts(board.nursery.state)) end`.
  - `PlayerProgress.setPetAppearance` (`:375`) already checks `Charms.known`.
- **Render:** `PetCharms` draws Heart and Star from the existing `CharmDot_AltHeart` and `CharmDot_AltStar` meshes via the Ring mesh path (VISUAL-BRIEF D). `renderShape` (`PetCharmCatalog.lua:7`) still falls back to the Default for unknown shapes. Leaf is NICE.
- **UI:** `HueEggView` Charm tab (`:133-149`, icon at `:1300`) shows locked cards with the rule line from UICopy `pool3.charm.<id>.rule`.

### 4.4 +6 Discoveries (bits 11–16, ids from VISUAL-BRIEF)

- **Rule:** five of the six are derived from **state** after any committed transaction. They need no new fields, and existing players earn them on their next save.
- **Hook:** `Lifetime.record(before, after, signature)` (`HatchProgress.lua:488`) calls `State.setFound(after, Book.stateBits(after, now))`.
- **Why the hook needs `now`:** today `record` gets no time. Pass `handle.adapter.now()` through `transact`: it is in scope at `:488`, and the time is read inside the UpdateAsync callback, so it is deterministic per attempt.

| Bit | Id | Condition | Source |
|---|---|---|---|
| 11 | `pet_night` | `lastPetAward.day == today` and the garden's **real** hour (UTC−5, `HollowClock.cycle` formula duplicated as `Book.hour(unix)`) is in 20:00–06:00 when the pet write commits | state + now. Signature `pet:` only |
| 12 | `play_date` | `playDate.count >= PlayDate.Target` | state |
| 13 | `full_outfit` | Any pet's `petWearables[p].equipped` covers at least 5 distinct slots (pairs count once) | state |
| 14 | `win_each_item` | `stats.itemWinKinds == 15`, a new optional stats key OR-ed with `summary.itemKinds` on a win | run + state |
| 15 | `tidy_25` | `stats.tidyWins >= 25` | state |
| 16 | `rounds_100` | `stats.rounds >= 100` | state |

- **`win_each_item` needs a host change:**
  - `init.server.lua` records a 4-bit `board.itemKinds` mask when a round item is used (swap/pop/bomb/magnet, `RoundItems.lua:9`), at the same place `board.itemSeq` advances.
  - It passes `itemKinds` in the summary (`:1269-1275`).
  - The award validator adds `summary.itemKinds == nil or integer(summary.itemKinds, 15)` (`HatchProgress.lua:1047-1065`).
  - `Lifetime.recordRun` ORs it into the optional key on success. Lifetime needs a `bor` setter, since `add` sums.
- **`BookCatalog.lua:44-48`:** append the six entries with fixed bits. The existing assert (`:60-66`) guards uniqueness and `MaxBit=30`.
- **Atlas:** cells 35+ on atlas pages 2/3 (Astra's `build_book_atlas.py` BADGES). The per-item chip fallback from B keeps the page readable until the upload.

### 4.5 Data and save (D)

| Field | Change | Old saves |
|---|---|---|
| `toyUnlocks` | New ids | `Catalog.known` gains them; old saves hold only old ids |
| `toyReceipts.quote.poolVersion` | 2 appears | `Pools[1]` kept |
| `stats.weeklyBonuses`, `stats.itemWinKinds` | Optional keys | Not required by `Lifetime.valid`; missing reads 0 |
| `book.found` | Bits 11–16 | Within `FoundMask` (`LifetimeState.lua:11`) |
| Profile `petAppearance[id].charmShape` | heart/star/leaf | Already `validStored`-tolerant (`PetCharmCatalog.lua:6`) |

### 4.6 Specs (D)

| Spec | Cases |
|---|---|
| `scripts/ToyFeatureProgress.spec.lua` (extend) | A v1 receipt still validates after the bump; a v1 reservation settles on pool 1; a new buy with `poolVersion=1` is `LegacyPurchaseClosed`; pool 2 is sorted (assert in the spec); restricted `fixedNext` order is old toys first |
| `scripts/MaterialProgress.spec.lua` (extend) | `Pools[3]` present; `PoolVersion` still 2; `available()` unchanged |
| `scripts/CharmRules.spec.lua` (server) | Locked shape → `Locked`; earned → `Saved`; free shapes unaffected; `weeklyBonuses` goes up only on a slot-0 weekly claim; a save without the key is valid |
| `scripts/LifetimeCounters.spec.lua` (extend) | Each of the 6 bits; a save with 30 tidy wins earns `tidy_25` on any commit; `itemKinds` out of range → `InvalidSummary`; `itemWinKinds` ORs only on a win |

### 4.7 Risks (D)

- **Unsorted pools** silently break buying. Mitigated by a spec assert.
- **Material `available()` all-or-nothing.** Mitigated by not flipping it tonight.
- **`pet_night` on the real clock while `DayNight=false`** shows dusk visuals at "night" (§8 #9).
- **`Lifetime.record` now runs a state scan on every commit.** It is cheap: at most 6 checks plus one `petWearables` walk of at most 16 pets × 24 keys.

---

## 5. Slice F: bond levels 1–5

### 5.1 Storage

- **New optional field `state.bond = { [petId] = xp }`** on v11.
  - **valid:** nil, or a table of at most 16 entries, each `Pets.byId[k]` and `integer(xp, Bond.MaxXP=100000)`.
  - **sanitize at load:** malformed entries are dropped, beside `playDate` (`HatchProgress.lua:296-299`).
  - It is added to `valid` (`:175`) as `BondState.valid(state)`.
- **Ownership is not required for an entry.** XP is only ever written for owned pets, so it does not need checking, and leaving it out avoids a new load-failure mode.
- **New `src/shared/BondCatalog.lua`:**
  - `Thresholds = {0, 25, 75, 150, 250}` for L1–5, with L6–10 at 350/475/600/725/850 reserved for week 2 `[PLACEHOLDER]`
  - `MaxLevelShipped = 5`
  - `level(xp)`, `progress(xp)`
- **XP keeps accruing past L5** (capped at `MaxXP`), so week-2 levels need no migration. The UI caps the display at "Lv 5 · more soon".
- **New `src/server/BondState.lua`:** `valid`, `sanitize`, `add(state, petId, amount)`. `add` clamps and **never fails**: it returns nothing and is a no-op for unowned or unknown pets.

### 5.2 XP sources (all server-authoritative, inside transactions that already exist)

| Source | XP | Where |
|---|---|---|
| Paid pet (up to 10 a day) | +1 | `awardPet` apply (`HatchProgress.lua:749-761`), `captured.petId` |
| Saved round finished with the pet as companion | +2, or +3 on a win | `award` apply (`:1073-1102`). New 6th param `petId` from `board.profile.companionId` (`init.server.lua:1286`), frozen in the candidate and not in the signature. Ownership checked inside apply; not owned → no XP, award unaffected |
| Play date completed today | +5 | `parkPlay` (`:1121-1132`). Candidate gains an optional `petId` (companion), not in the digest (`playDate.op` stays the proof). XP only when the count crosses `Target` in this write |
| Toy play, care, garden | none in v1 | No server event exists. Week 2 |

- **Pace** (scope §1 income model): engaged players earn about 10 + 8×2.5 + 5 = 35 a day, so L5 in about 7 days. Casual players earn about 13 a day, so L5 in about 19 days.
- **Rule:** bond XP must never make an award, a pet or a park write fail. `BondState.add` has no failure return, and the specs assert it.

### 5.3 Unlock list (VISUAL-BRIEF §5: no new models or poses)

| Lv | Unlock | Built from |
|---|---|---|
| 1 | Hello: a wave the first time you walk up each session | `PetIdleBeats` `wave` |
| 2 | Sit: sits when you stand still nearby | `PetSitPose` (`Sit.fromOwner`) |
| 3 | Wiggle dance | `wiggle` ×2 |
| 4 | Big stretch | `stretch` → sit |
| 5 | Happy hop with hearts | `stretch` + `wiggle` + `wave` + heart burst |

- **Tricks are local presentation only.** They are gated client-side on `public.bond[petId]` and are not replicated to other players in v1 (§8 #12). They cannot be exploited: they cost nothing and pay nothing.
- **Save: none beyond `bond`.**

### 5.4 Client UI (F)

- `HatchProgress.public` (`:353-404`) adds `public.bond = clone(state.bond or {})`.
- **`CompanionsHub` pet card and `PetFocusUI`:** five heart pips (brief §5), drawn from `BondCatalog.level`.
- **Level-up flourish:**
  - Detect it client-side when a snapshot's level is higher than the last level seen for that pet, keyed per pet in `clientUI.bondSeen`.
  - It fires a toast (UICopy `bond.levelUp`, `{level}`, `{trick}`) and plays the brief's 1.2 s flourish through `PetAffection`'s pooled emitter (`PetAffection.lua:41-55`).
  - It respects reduced effects.
- **Trick triggers:** `PetIdleBeats` and `PetSitPose` read `bondLevel` from the visual's appearance context. Wire it in a `do`-block in `init.client.lua`, or better inside `RoomView`/`GardenClient`, to stay off the local budget.

### 5.5 Specs (F)

| Spec | Cases |
|---|---|
| `scripts/BondProgress.spec.lua` (server) | +1 per paid pet; capped by `PetDailyCap`; a round gives +2 or +3 to the companion; an unowned companion gives no XP and the award still pays; Play date +5 once a day; ambiguous writes count once; no `bond` field is valid; a malformed `bond` is sanitized (load succeeds); XP is capped at `MaxXP`; per pet |
| `scripts/BondCatalog.spec.lua` (shared) | Thresholds rise strictly; `level(249)==4`, `level(250)==5`; the display caps at 5 |
| `scripts/BondView.spec.lua` (client) | Pips render; level-up detection fires once per pet per level; reduced effects mode |

### 5.6 Risks (F)

- **The `award` signature grows a parameter.** All callers are in `init.server.lua:1286` and the specs. Missing means `nil`, which gives no XP.
- **XP cannot be backfilled.** The F server part (XP accrual) should land even if the F UI is cut (§9).

---

## 6. Cross-slice specs and gates

- **`scripts/ClientLocalBudget.spec.lua`** (client, new): counts column-0 `local` declarations in `init.client.lua` Source and fails above 219. Run it in every lane.
- **Per publish:**
  - all server specs and all client specs (the 7 known client failures stay as they are)
  - `LocalizationFit` with 0 clips
  - `UICopy.spec` width checks for every new string
- **Studio Play smoke per slice** (memory `studio-spec-running`: copy each spec into ZZSpecs, restart Play after a Rojo sync, `require(...)(server)`).

---

## 7. Dependency graph and parallel lanes

```
            ┌────────── Lane 0 (primary, ~20 min, first) ───────────┐
            │ FeatureFlags: SecondPet=false, WeeklyShelf=true         │
            │ UICopy stubs e2/variants/shelf/pool3/bond               │
            │ CoachMarks bit 10 · inventoryMask ≤255 · OwnedLimit 128 │
            │ BookView per-item chip fallback · ClientLocalBudget spec│
            └────────────────────────────┬──────────────────────────────┘
          ┌──────────────────────────────┼───────────────────────────────┐
          ▼                              ▼                               ▼
 Lane S (server core)           Lane K (catalog + render)        Lane U (client UI)
 owns: HatchProgress.lua,       owns: WearableCatalog,           owns: CompanionsHub, WardrobeShop,
 init.server.lua, Lifetime-     WearableVariants (new),          FaceplateShop, BallShop, HueEggView,
 State, BondState (new),        PetAttachments, PetPlayVisual,   RoomView, CoachCards, StampCardView,
 EarnedPets (new), Session-     BookCatalog, ToyCatalog,         PetFocusUI, MachineHub, DeckMenu,
 Profile, PetAppearance,        MaterialCatalog, PetCharm-       init.client.lua (do-blocks only)
 WearableState, Faceplate-      Catalog, PetToyGeometry,
 State, BallThemeState          GardenClient, RewardItemArt,
                                WeeklyShelf (new), BondCatalog
 E-srv ─► C-srv ─► F-srv ─► D-srv   B ─► C-data ─► D-data ─► F-data    E-cli ─► B-cli ─► C-cli ─► D-cli ─► F-cli
```

**Interfaces to agree before the lanes start.** These are the only cross-lane contracts.

| Contract | Producer | Consumer |
|---|---|---|
| `EarnedPets.enabled(id)`, `.owed(state)` | S | U, K (`Pets.active`) |
| `WearableCatalog.renderMap(petId, wearables)` returns `{mapped, tints}`; item `variant=true` | K | U, PetPlayVisual |
| `WeeklyShelf.week(now)`, `.slots(week)`, `.price(kind, id, week)` | K | S (checks), U (chips) |
| `Book.BookOnlyPlates`, `Book.platesOwed(state)`, `Book.stateBits(state, now)` | K | S |
| `PetCharmCatalog.earned(id, facts)`; `facts = {stamps, claimed, stats, bond}` | K | S (`PetAppearance`), U |
| `BondCatalog.level(xp)`; `public.bond` | K / S | U |

**Hot files and who may touch them:**

| File | Rule |
|---|---|
| `init.server.lua` | Lane S only. Hunks by slice: E (`:98-100`, `:352-356`, `:584`, `:860-866`, `:1462`, `:1538-1545`, plus the new `grantEarned` beside `:1327`), C (`:1121-1137`), D (`:781-782`, summary `itemKinds`), F (`:1286`, `:1380`) |
| `init.client.lua` | Lane U only. Do-blocks or `clientUI.*` only. E (`:1071`, `:1929`) |
| `UICopy.lua` | Every lane, inside its own stub block only |
| `HatchProgress.lua` | Lane S only. E (`:110`, after `:855`), C (`:887-958`, `:980-1012`), D (`:488`, `:713`, `:1047-1065`), F (`:175`, `:296-299`, `:353-404`, `:741-764`, `:1035-1102`, `:1121-1132`) |
| `BookCatalog.lua` | Lane K only: B (`:112`), C (`:26`, `:107`), D (`:44-48`, `stateBits`) |
| `PetCharmCatalog.lua` | Lane K only |

- **Lanes S and K can start at the same time once lane 0 lands.**
- **Lane U starts E-cli at once.** For B-cli onward it waits only for the matching lane K contract (the shapes above can be stubbed).
- **Art (Astra / Fable) runs beside all three:**
  - wearables → manifest → `BearRigDefinition` regeneration. **Lane K owns the regeneration commit**, since it rewrites a shared file.
  - faceplates json
  - toy geometry, written directly in `PetToyGeometry` by lane K from the brief's tables
  - atlas pages

---

## 8. Decisions the scope left open (answered, with defaults)

| # | Question | Default (Spencer is asleep) |
|---|---|---|
| 1 | Ship Blip tonight? | **No.** Ship E with `SecondPet=false`; bit 8 is reserved and the 255 bound is live. Flip the flag in the week-1 update with the rig |
| 2 | Switch the companion to Blip automatically on arrival? | No. The arrival card's "Say hi" switches with one tap |
| 3 | Is a white (undyed) Blip acceptable at the reveal? | No. Blip's **base** palette is the showcase green (exempt from the neutral pass, `PetRigDefinitions.lua:9-11`). No dye written to the save; "Original colour" on Blip is green |
| 4 | Do recolour variants count on the book's Wardrobe page? | No. Otherwise every weekly variant moves 100% further away. Base items only |
| 5 | Do Blip's refits count on the Wardrobe page? | Yes, once Blip is active. Claims already made are kept |
| 6 | Are variants shelf-only (rotating availability)? | No. Every released variant is always in the Wardrobe at full price. The shelf only spotlights and discounts (no FOMO) |
| 7 | Shelf shape | 3 slots (variant, wearable, faceplate/ball alternating), 20% off, Monday reset with the weekly quests, no deluxe or book-only items |
| 8 | Book-only plate #2 rule | Discoveries page 100% → Stargazer (independent of Blip and of the flag) |
| 9 | `pet_night` while `DayNight=false` | Use the real garden hour (UTC−5, 20:00–06:00). The badge is earnable today and stays correct when DayNight returns |
| 10 | Backfill for the Star charm (weekly bonus ×4)? | No. The counter starts at deploy. Leaf (stamp 14) and Heart (Wardrobe 100%) read existing data, so they are backfilled |
| 11 | `win_each_item` is the costliest Discovery | Build it (4-bit mask). If short on time, swap the condition to "win a round using 3 items" (`summary.itemsUsed >= 3`) under the same id and bit, before publish |
| 12 | Do other players see bond tricks? | Not in v1 (local only) |
| 13 | Bond XP numbers | Thresholds 25/75/150/250; pet +1, round +2/+3, Play date +5 `[PLACEHOLDER]` |
| 14 | Wardrobe owned limit | 128 per pet |
| 15 | Material v3 tonight? | Data only; `PoolVersion` stays 2 until templates are verified in Studio |
| 16 | Deluxe ball theme | Cut tonight (Ducklings is LATER in the brief). The deluxe tier ships on faceplates only if Garden Party is rendered and uploaded |
| 17 | Toy pool contents | Only toys with built geometry go into `Pools[2]` (MUST: Wobble Top, Squeaky Carrot) |
| 18 | Undrawable book cells | Chip per item, not per page (lane 0) |

---

## 9. Realistic overnight cut line

**Estimates** are agent hours including review-driven-build and specs, but not Studio capture time.

| Item | Est. |
|---|---|
| Lane 0 | 0.3 h |
| E code + specs | 2.5 h |
| B system + 10 variants + tabs | 2 h |
| C shelf + plate #2 + deluxe chip | 2 h |
| D toys + Discoveries + charms | 2.5 h |
| F server | 1 h |
| F UI | 1.5 h |
| **Serial total** | **about 12 h** |

Three lanes compress it to about 6–7 h of wall clock, plus two private publishes.

**Above the line (land tonight, in this order):**

1. Lane 0 seams.
2. **E complete** with the flag off: all G and D sites, `grantEarnedPet`, repair loop, arrival card, specs.
3. **B:** variant system, 10 variants, the new tabs (shown as art lands), OwnedLimit, per-item book chips.
4. **C:** weekly shelf (server check + chips + hub line), book-only plate generalization + Stargazer if rendered, deluxe chip.
5. **F server only:** `bond` storage + XP accrual + `public.bond`. It cannot be backfilled, so it outranks the rest of D and the F UI.
6. **D:** toy pool 2 with the MUST toys, the 6 Discoveries (with the #11 fallback ready), Heart and Star charms with rules.
- **Publish checkpoint 1** after item 3. **Publish checkpoint 2** after item 6.

**Below the line (cut in this order if time runs out):**

1. Deluxe ball theme (already cut).
2. Finishes v3 sales (data stays).
3. F UI tricks 3–5 (pips + level-up toast stay).
4. `win_each_item` mask: use the #11 fallback.
5. Leaf charm.
6. F UI entirely: XP keeps accruing invisibly.

**Never cut:** E generalization, the 255 bound, F server accrual.

---

## 10. Top risks

1. **The rollback hazard on `inventoryMask`** (§1.1). Ship the bound before any grant.
2. **Unsorted or removed item pools** (`ToyState.lua:15-20`, `:46-50`). Specs assert ordering and `Pools[1]` retention.
3. **`MaterialCatalog.available` all-or-nothing** (`MaterialCatalog.lua:26-33`). Do not flip `PoolVersion` tonight.
4. **Three lanes on hot files** (`init.server.lua`, `HatchProgress.lua`, `UICopy.lua`). One owner per file plus UICopy stubs.
5. **The book atlas is full.** Every new item would knock its page back to name chips without the per-item fallback.

Also watch:

- the `init.client.lua` local budget (219)
- phone tab overflow with 10 Wardrobe tabs
- clock skew at the shelf boundary (refused safely)
- `pet_night` reading as night while the garden shows dusk
