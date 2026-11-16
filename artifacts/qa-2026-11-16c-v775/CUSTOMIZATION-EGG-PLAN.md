# Customization Egg: implementation plan and architect review (2026-11-16)

Planning only. No code or Studio changes. Opus/Sol lane (implementation and architecture). Fable/Astra owns the finish stage renders, the egg and jar art, and review of the actual renders.

**Spencer's decision (v775 notes, items 3 and 4):** the v1.1 Look Egg moves into v1 as the **Customization Egg**, containing hue jars, finish jars (Gloss, Matte, Jelly, with stages and mixing) and charms as a rare drop. The Toy Egg stays separate and the Wardrobe stays direct-buy. New pets start with **no charm**. Snowflake, Ring and Pebble become rare egg drops; Heart, Star and Leaf stay earned; charms players already own are kept.

Read against: `ECONOMY-SCOPE.md` §2, §3 and §5; `HueCatalog`, `MaterialCatalog`, `PetCharmCatalog`, `ToyCatalog`, `FeatureFlags`; `HatchProgress`, `HueState`, `MaterialState`, `ToyState`, `HatchGuard`, `PaidRandomPolicy`, `PetAppearance`; `EggHatchView`, `HueEggView`, `MaterialPanel`, `NextItemText`, `PetCharms`, `PetMaterials`, `BookCatalog`; `UICopy`.

Every number marked `[PLACEHOLDER]` is a starting value, to be tuned after week-1 telemetry.

---

## 0. Decisions in one place

| Question | Decision |
|---|---|
| Hatch eggs list | **Toy Egg, Customization Egg.** The Hue Egg row is replaced by the Customization Egg, and the Material Egg stays off (`EnablePurchases=false`). |
| Price | **12 Stars** `[PLACEHOLDER]`, as in the scope for the Look Egg. |
| Save version | **Stays v11.** Only new optional top-level fields. A missing field is valid, as with the existing `playDate`, `coachMask` and `bond`. No v12: `validBase` never checks top-level keys exactly, so v11 already accepts new optional fields. `inventoryMask` is not touched; its 8 bits all belong to pets. |
| State machine | **No fourth machine.** The egg is a new `lookBuy` action **inside `HueState`**. It reuses `hueReservation`, `pendingHueResult`, `hueItemReceipts`, the `hueStore` ack, `resumeHueReservation` and `HatchGuard` kind `"hue"`. Finish doses reuse the dose logic of `hueUse`/`hueClear`. The quote follows the Material pool-4 pattern: price, selection mode and fixed item are bound into the quote. |
| Charm ownership | Egg shapes are saved in `charmUnlocks`. Earned shapes stay rule-derived; the rules are monotonic, so nothing is written for them. |
| Existing saves | At load, a save that has no `charmUnlocks` is a **legacy save** and gets `{dot, ring, pebble}`, because under the old rules everyone owned all three. A brand-new save gets `{}`. |
| Duplicates | Charms you own leave the pool, so a charm duplicate cannot be rolled. Jars stack, so a repeated jar adds +1. Every egg gives something. |
| Finish model | Two axes per pet: **sheen** -3..+3 (Matte jars push it down, Gloss jars push it up, and they cancel) and **jelly** 0..3. 7 x 4 = 28 looks. |

---

## 1. Pool, odds and pity

### 1.1 Pool

| Group | Items | Lands in |
|---|---|---|
| Hue jars | Rose, Tide, Citrus, Iris | `hueInventory` (existing) |
| Finish jars | Gloss, Matte, Jelly | `finishInventory` (new) |
| Charms | Snowflake (`dot`), Ring, Pebble: only shapes the player does **not** own | `charmUnlocks` (new) |

Item ids are unique across the egg: `rose tide citrus iris gloss matte jelly charm_dot charm_ring charm_pebble`. Heart, Star and Leaf are never in the pool.

### 1.2 Odds `[PLACEHOLDER]`

There is one table for each value of M, the number of egg charm shapes still missing. Every cell is a whole percentage and every column sums to exactly 100, so the displayed odds *are* the real odds. Unlike `OddsText.list`, nothing is rounded, which avoids the misstatement that made pool 4 need `preciseList`.

| Item | M = 3 | M = 2 | M = 1 | M = 0 |
|---|---:|---:|---:|---:|
| Rose | 17 | 17 | 17 | 17 |
| Tide | 17 | 17 | 17 | 17 |
| Citrus | 17 | 17 | 17 | 17 |
| Iris | 17 | 17 | 17 | 17 |
| Gloss | 10 | 11 | 12 | 13 |
| Matte | 10 | 11 | 12 | 13 |
| Jelly | 6 | 6 | 6 | 6 |
| **Each missing charm** | **2** | **2** | **2** | n/a |
| Charm total | 6 | 4 | 2 | 0 |
| **Sum** | **100** | **100** | **100** | **100** |

Rule of thumb: hues and Jelly never move, each missing charm is 2%, and the charm share moves into Gloss and Matte as charms are collected.

### 1.3 Pity (disclosed)

- While M > 0, `lookCharmMisses` counts eggs in a row that gave no charm. **When it reaches 14, the 15th egg is a charm** `[PLACEHOLDER]`: uniform over the missing shapes, published order on a tie (not possible with uniform).
- The counter resets to 0 on a charm and stays at 0 while M = 0.
- Expected cost, random path: about 10 eggs for the first charm, about 11 for the second and about 13 for the third. That is roughly **34 eggs (about 410 Stars) for all three**, so charms stay rare. A fully kitted pet (two hue channels, sheen ±3, Jelly 3) still takes 45 to 50 eggs, as in the scope.

### 1.4 Restricted accounts (`ArePaidRandomItemsRestricted`, or policy unknown, which fails closed)

There is no roll. The fixed next item is named on the button ("Next: Ring charm").

1. If M > 0 and `lookCharmMisses` = 11 (so **every 12th egg**, about the random mean) `[PLACEHOLDER]`: the first missing shape in the order Snowflake, Ring, Pebble.
2. Otherwise: the jar held fewest of, in the order Rose, Tide, Citrus, Iris, Gloss, Matte, Jelly, with ties going to the first. This is the same rule `Hue.fixedNext` already discloses.

---

## 2. Save changes (hatching record v11, additive only)

### 2.1 New optional fields

| Field | Shape | Missing means | Validator |
|---|---|---|---|
| `finishInventory` | `{gloss=n, matte=n, jelly=n}` | all zero | keys ⊆ {gloss, matte, jelly}, integers 0..`Hue.StackLimit` |
| `petFinish` | `{[petId]={sheen=-3..3, jelly=0..3}}` | no dose look | owned pet (`Eggs.isOwned`), `Hue.Supported`, exact keys, **frozen stored bounds ±3 / 0..3** (see R6) |
| `charmUnlocks` | `{dot=true, ring=true, pebble=true}` (subset) | legacy (see 2.2) | keys ⊆ `PetCharmCatalog.EggShapes`, values `true` |
| `lookCharmMisses` | integer 0..`PityAt-1` | 0 | integer |
| `lookFound` | bitmask 0..1023, one bit per item id (fixed bit numbers, never renumbered) | 0 | integer; Book reads it |

Inside existing HueState containers, which v11 builds from this one on will validate:

- `hueItemReceipts` gains three actions: `lookBuy`, `finishUse` and `finishClear`. `receiptKeys` gains `missesBefore`, `missesAfter`, `finishBefore`, `finishAfter`, `axis` and `substitutedFrom`.
- `hueReservation.itemId` may be a Customization Egg item id when `quote.action == "lookBuy"`.
- `pendingHueResult` keeps its exact keys. For a charm, `inventoryAfter` is 1 (the charm is owned), so the shape check does not change.

Nothing is removed or reinterpreted. `hueInventory`, `petHues`, every Hue and Material receipt, `materialUnlocks`, `petMaterials` and Material pools 1 to 4 stay frozen and valid.

### 2.2 The "no default charm" switch for existing saves

This is done in `acquire` (`HatchProgress.load`), inside the lease UpdateAsync, after `upgrade()` and next to the other sanitizers:

```
local fresh = root.hatching == nil            -- this acquire is creating the save
...after upgrade/sanitize...
if state.charmUnlocks == nil then
  state.charmUnlocks = if fresh then {} else {dot=true, ring=true, pebble=true}
end
```

- **Legacy saves** (any record written before this build, including pre-2026-11-13 tester saves in `EggDropLaunchV1` that become live when `TestFreshSaves` goes false) keep Snowflake, Ring and Pebble. Their current selection, `profile.petAppearance`, is untouched.
- **New saves** start with `{}`. A pet with no `petAppearance` entry already shows no charm (`PetAppearance.visible` returns false), so "new pets start with no charm" holds for new pets of legacy players too.
- The Temporary or load-failed path writes nothing. Its in-memory state gets `{}`.
- After the first load, every save has the field written out, so the client, the Book and `public()` read one representation.

### 2.3 Where charm ownership is checked

`PetCharmCatalog` gains `EggShapes = {"dot","ring","pebble"}` and `Catalog.usable(id, facts, unlocks)`:

- an egg shape is usable when `unlocks[id] == true`;
- an earned shape is usable when its rule is met (`earned`, unchanged);
- an unknown shape is never usable.

`Default` stays `"dot"` **only as the render fallback id** for unknown stored shapes. It no longer means "owned".

Rule for later: an earned charm rule may only ever be loosened. Since earned shapes are not latched in the save, tightening a rule would take the charm away.

---

## 3. Server purchase and receipt flow

### 3.1 Wire actions (added to `HueState.wire`)

| Action | Fields | Notes |
|---|---|---|
| `lookBuy` | `id, catalogVersion, poolVersion, price, selectionMode, fixedItemId, missingCharms, charmMisses` | `missingCharms` is a sorted list. Like Material `eligible`, the quote binds the odds table the player saw. |
| `finishUse` | `id, catalogVersion, petId, itemId, finish, pendingResultId` | `finish` is the expected `{sheen, jelly}` row; a change gives `FinishChanged`, mirroring `counts` in `hueUse`. |
| `finishClear` | `id, catalogVersion, petId, axis, finish` | Free "Original" for one axis (`sheen` or `jelly`), mirroring `hueClear`. |

`catalogVersion` stays `"hue-items-v1"`. Bumping it would invalidate every stored Hue receipt. The Customization Egg has its own `LookEggCatalog.PoolVersion = 1`.

### 3.2 `lookBuy`, step by step (existing `hueCommand` path)

1. **Quote** (`HueState.quote`): the exact field set, the id matches `^<revision>:look-…`, `price == LookEggCatalog.Price`, `selectionMode` is `random` or `fixed`, and `fixedItemId` is present only when the mode is fixed.
2. **Idempotency:** `HueState.find`. The same quote returns `AlreadySaved` plus the public receipt. The same id with a different quote returns `OperationConflict`. A matching `handle.pending` resumes its phase (reserve or settle).
3. **Eligibility at reserve time only** (`HueState.purchaseEligibility(state, quote)`):
   - `Guard.other` or `pendingHueResult` gives `RevealPending`, and another reservation gives `PurchasePending`;
   - no owned pet gives `MeetPipFirst`;
   - `LookEggCatalog.available(...)` false gives `NotReady`, covering both the switch and the finish templates being `NativeVerified`;
   - the selection mode differing from the handle's policy gives `PolicyChanged`;
   - `missingCharms` or `charmMisses` differing from the state gives `PoolChanged`;
   - in fixed mode, `fixedItemId` differing from `LookEggCatalog.fixedNext(state)` gives `PoolChanged`;
   - a wallet below the price gives `NeedStars`.
4. **Roll** (server only): `LookEggCatalog.roll(handle.adapter.random(), quote.missingCharms, quote.charmMisses)`, or `fixedNext` when restricted. The candidate is `{quote, operationId=guid, sequence=opSeq+1, itemId}`.
5. **Reserve** (`reserveHue`, unchanged): the candidate is written durably to `hueReservation`. A disconnect or retry can no longer re-roll.
6. **Settle** (`HueState.apply`, `lookBuy` branch), **total and self-contained**. It checks only that the reservation equals the candidate and that the quote is valid; there are no live availability, price or policy checks (see R4). Then:
   - debit `quote.price`;
   - grant the item: a hue jar goes to `hueInventory +1`, a finish jar to `finishInventory +1`, a charm to `charmUnlocks[id]=true`;
   - update `lookCharmMisses` (0 on a charm, +1 if M > 0, else 0);
   - set the `lookFound` bit;
   - write the receipt (`missesBefore/After`, `inventoryBefore/After`, `resultId=id`) and `pendingHueResult`;
   - clear `hueReservation`.

   If the charm is already owned (not reachable while the quote is bound, but defended anyway), substitute `fixedNext`'s jar and record `substitutedFrom`. The egg still gives something. A jar stack at `StackLimit` gives the existing cost-0 `Refused` receipt, which also clears the reservation.
7. **Resume on load:** `resumeHueReservation` (already exists). It settles exactly the saved candidate.
8. **Ack** (one pending result at a time, `Guard`):
   - a hue jar: `hueUse` with `pendingResultId` (Use now), or `hueStore` (Later);
   - a finish jar: `finishUse` with `pendingResultId`, or `hueStore`;
   - a charm: `hueStore`, after which the client sends the existing `petAppearance` selection (`shapeVersion`) when the player taps **Wear**. These are two writes to two namespaces. If the wear fails, the charm is still owned and the button offers a retry.
9. **Analytics:** add `Economy.eggOpened(player, "look", receipt)` beside the `hueBuy` one in `init.server.lua`.

### 3.3 Retiring the Hue Egg

- `HueCatalog.EnableEgg = false`. `hueCommand` refuses a **new** `hueBuy` with `LegacyPurchaseClosed`.
- A saved `hueReservation` or `pendingHueResult` from a `hueBuy` still settles and acks, because the resume path does not go through the switch.
- `Hue.charged` keeps accepting 8 and 12 for stored receipts.

### 3.4 Charm gate (`PetAppearance` and `init.server`)

- `Appearance.request`: **any** `visible=true` request must resolve to a usable shape, including the unmarked visibility-only path that today skips `earned`. Otherwise it is rejected with `Locked`. The `earned` callback becomes `usable(shape)`, which reads `board.nursery.state` (stamps, claims, stats, `charmUnlocks`).
- `Appearance.public` (and therefore `gardenInput.charmVisible` and the replicated garden snapshot) takes the hatching state and **masks** a saved visible charm whose shape is not usable. This covers stale profile rows and rows written by an old server during a rollout.

### 3.5 Public snapshot additions

`finishInventory`, `petFinish` (owned pets), `charmUnlocks`, `lookCharmMisses`, `lookFound`, `lookAvailable`, `lookSelectionMode`, `lookPoolVersion` and `nextFixed.look`.

The per-pet public appearance gains `sheen` and `jellyStage`. The legacy `finish` stays.

---

## 4. Sheen stages and mixing

- **Per pet, body-wide** (the one-tone and two-tone templates already cover the Secondary channel): `petFinish[petId] = {sheen, jelly}`.
- **A Gloss jar** sets sheen +1 and is refused with `MaxSheen` at +3. **A Matte jar** sets sheen -1 and is refused at -3. **A Jelly jar** sets jelly +1 and is refused with `MaxJelly` at 3. A refusal costs nothing, so the jar stays.
- **Cancel, like hue mixing:** Gloss and Matte share one axis. A Gloss jar on a Matte -2 pet moves it to -1. Hue fruits blend through set anchors; finishes blend through a signed axis, because a `SurfaceAppearance` can only show discrete flat roughness maps.
- **Second axis:** Jelly translucency combines with any sheen. That gives 7 x 4 = **28 looks**, each with a name (`{jelly} {sheen}`: "Glassy Clear Jelly", "Chalky Misty" and so on). Copy is in §6.
- **"Original" is free per axis** (`finishClear` with an `axis`).
- **Render:**
  - `PetMaterialConfig.SheenProfiles[-3..3]` gives the one-tone and two-tone template names. Stop 0 is the existing `Body`. The existing `BodyMatte` and `BodyGloss` maps can serve as two of the stops if Fable's renders agree. The other stops are new flat roughness maps from the existing tooling: up to 12 templates.
  - Jelly stage s scales `JellyAlphaByPart` by `JellyStageAlpha[s]` = {0, .45, .75, 1} `[PLACEHOLDER]`.
  - An unverified stop falls back to the **nearest verified stop toward 0**. It never moves in the wrong direction and never errors.
- **Legacy permanent finishes** (`petMaterials`, which no live player has since v760): when a pet's `petFinish` row is non-zero, the dose look wins; otherwise `petMaterials` renders as today.
- **Gate:** `LookEggCatalog.available()` requires every sheen template, one-tone and two-tone, to be `NativeVerified`, using the same `verified()` helper as `MaterialCatalog.capable`. If they are not, the **whole egg** shows "Not ready". Finishes are never silently dropped from the pool, because that would change the disclosed odds.
- **Fable approves renders on a phone first.** If three stops do not read, the display cap drops to 2 (`SheenStops`), while the **stored** bound stays ±3 and is clamped at render and at use (see R6).

---

## 5. Client changes

### 5.1 Hatch eggs list (`EggHatchView`)

- `liveOrder = {"toy","look"}`. The `hue` row leaves; `material` and `feature` stay behind their flags.
- `recipe("look")` = {name "Customization Egg", cost `LookEggCatalog.Price`}. The tap opens the existing Hue buy page (`onOpenHue`) in `look` mode.
- Pending states keep "Open saved colour" for a Hue Egg result, and add "Open saved charm" and "Open saved finish".
- Fable supplies new egg art (`EggArt`, `HatchDisplayAssets`).

### 5.2 Odds panel (`EggHatchView.oddsRows("look", state)` and the buy page)

- Rows in published order: Rose, Tide, Citrus, Iris, Gloss, Matte, Jelly, then **one Charm row** showing the total with the sub-line "2% each: Snowflake, Ring" (missing shapes only). That is at most 8 rows, in two columns on a phone.
- **Values come straight from the integer table** (`LookEggCatalog.odds(state)`), not `OddsText.list`.
- A pity line under the rows: "A charm within {count} eggs" (the count runs down). When M = 0: "All egg charms found."
- Restricted: the existing "Next: {item}" row (`NextItemText` kind `look`), plus "Charm in {count} eggs" when M > 0.
- The quote is rebuilt from the latest snapshot on every tap. A `PoolChanged` or `PolicyChanged` reply re-renders the panel and asks for one more tap; it never shows an error toast (see R15).

### 5.3 Customize tabs (`HueEggView`)

- Tabs: **Hue / Finish / Charm / Toys** (Features stays behind its flag). **Finish replaces Materials**. A merged "Look" tab is later polish and is not needed for v1.
- **Finish tab** (new `FinishPanel`, the successor to `MaterialPanel`):
  - a Sheen slider with 7 notches, Matte jar at the left and Gloss jar at the right, each with its count;
  - a Jelly jar with 3 pips;
  - "Original" per axis;
  - the look name, and the pet updating live;
  - one tap spends one jar (`finishUse`);
  - a legacy finish, if any, shown as a "Kept" chip;
  - empty state: "Find finish jars in the Customization Egg."
- **Hue tab** is unchanged. Its "more jars" link points to the Customization Egg.
- **NEW badge** (`noteNewItems` and `isNewItem`) for finish jars and charms, the same as for hue jars.
- The Companions Toys tab is being removed by another lane (v775 note 7). Coordinate the tab list there.

### 5.4 Charm picker showing locked shapes (`View.charmCards`, `charmPane`)

- The cards are None, then all six shapes in `Order`. An unowned egg shape is `locked` with the rule line "Rare in the Customization Egg" and a 🔒. It can still be focused, which previews it on the pet, nothing saved, as locked earned shapes already do.
- Its button is "Find in eggs", which deep-links to Hatch eggs with the Customization Egg selected.
- Heart, Star and Leaf are unchanged (progress `have/need`).
- `charmTitle` drops the hard-coded "A floating Snowflake…". With no charm it reads "No charm yet. Charms are rare in the Customization Egg, or earned."
- `selectDot()` and any code that assumes Snowflake is available are removed. `charmRequestFor` never sends an unowned shape.

### 5.5 Reveal and receipt (`HueItemReveal`, `HatchItemStage`, `HatchRarityCue`, `ItemReceiptLayout`)

- **Tiers** `[PLACEHOLDER]`: hue jars are Common, Gloss and Matte Uncommon, Jelly and charms Rare. The banner reads "RARE CHARM" or "UNCOMMON FINISH JAR".
- **Result builders:** the jar art for hue jars (Fable is redrawing the jars now, note 5), finish jar art (a new jar with a sheen swatch, by Fable), and a charm preview from the `PetCharms` meshes, tinted in the companion's Secondary colour.
- **Receipt actions:**

  | Result | Primary | Secondary |
  |---|---|---|
  | Hue jar | Use now (lands on the Hue tab) | Later |
  | Finish jar | Use now (Finish tab) | Later |
  | Charm | **Wear on {pet}** | Later |

  "Later" sends `hueStore`. A NEW badge waits in Customize.
- `HueIntent` gains `lookHatch()`, `finishUse(petId, itemId, resultId)` and `finishClear(petId, axis)`.

### 5.6 Book (`BookCatalog`, `BookView`)

- **Toys page becomes "Toys & finishes":** the toy pool plus Gloss, Matte and Jelly, owned once found (`lookFound` bits). The `Finishes.EnablePurchases` gate is replaced by `LookEggCatalog.EnablePurchases`. Existing claims stay, under the existing rule "a catalogue that grows can drop a page below a claimed milestone".
- **New Charms page** (`"charms"`, milestones `charms.25…charms.100`, ids never reused):
  - Snowflake, Ring and Pebble count when they are in `charmUnlocks`;
  - Heart, Star and Leaf count when `earned`;
  - the page shows how each shape is obtained.
- `PageOrder` gains `"charms"` after `"toys"`. That adds 35 Stars of milestones `[PLACEHOLDER]`, and Bookworm (any 3 pages) gets slightly easier. Spencer to OK.

---

## 6. Copy keys (UICopy; then `export_localization_csv.py` and `sync_localization.py`)

New keys:

```
hatch.egg.look.line          "Colours, finishes and the odd charm"
hatch.egg.look.description   "Hatches one jar of colour or finish. Now and then, a rare charm."
hatch.egg.look.per           "1 item per egg"
hatch.look.charmRow          "Charm · {each} each: {shapes}"
hatch.look.pity              "A charm within {count} eggs"
hatch.look.pityRule          "If 14 eggs pass without a charm, the next one is a charm."
hatch.look.allCharms         "All egg charms found"
hatch.look.restrictedCharm   "Charm in {count} eggs"
hatch.look.notReady          "Customization Eggs are not ready yet."
hatch.look.promise.random    "The odds are on the label. They shift only as you collect charms."
hatch.look.promise.fixed     "No surprises. Your next item is shown above."
hatch.reveal.kind.finish     "FINISH JAR"
hatch.reveal.kind.charm      "CHARM"
hatch.reveal.describe.finishJar.gloss / .matte / .jelly
hatch.reveal.describe.charm.dot / .ring / .pebble
hatch.display.charm          "A charm for your pet"
customize.finish.title / .sheen / .jelly / .original / .empty / .kept
customize.finish.sheen.m3 m2 m1 zero p1 p2 p3   ("Chalky", "Matte", "Soft", "Original", "Satin", "Glossy", "Glassy")
customize.finish.jelly.s1 s2 s3                ("Misty", "Jelly", "Clear Jelly")
customize.finish.mix          "{jelly} {sheen}"
customize.finish.useJar       "Use a {item} jar"
customize.receipt.wear        "Wear on {pet}"
pool3.charm.egg.rule          "Rare in the Customization Egg"
pool3.charm.findInEggs        "Find in eggs"
pool3.charm.none              "No charm yet. Charms are rare in the Customization Egg, or earned."
book.page.toys                "Toys & finishes"
book.page.charms              "Charms"
reason.PoolChanged            "Your odds just changed. Check them and tap again."
reason.MaxSheen / reason.MaxJelly / reason.FinishChanged / reason.Locked / reason.NotReady
```

Changed keys:

- `hatch.promise` ("The odds never change") becomes false; use `hatch.look.promise.*` for this egg.
- `customize.moreMaterials` becomes "More finishes hatch from Customization Eggs."
- The coach and help lines that promise "add a charm" (`UICopy` lines 231, 245 and 360, and `r3.help.companions.c/.d`) are reworded so a new player is not promised a charm they cannot have.
- The `hatch.egg.hue.*` keys stay for the saved-result path and are deleted by the sync only after one release.
- The store listing maturity answer on paid random items stays "yes".

---

## 7. Specs to add or update

Server specs (`src/server/ZZSpecs`, with offline mirrors in `scripts/*.spec.lua`):

| Spec | Covers |
|---|---|
| **LookEggCatalog** (new) | Each M table sums to 100 and every row is an integer. `roll` boundaries at every cumulative edge, with unit 0 and 1-ε. Pity forces a charm at 14 misses and never when M = 0. `fixedNext` order, the every-12th charm and ties. Charms never in the pool once owned. `odds(state)` equals the table. |
| **HueProgress** | `lookBuy` quote validation. Reserve, then settle. Idempotent replay (same op returns AlreadySaved; same id with a different quote returns OperationConflict). Resume after a crash between reserve and settle. Price taken from the quote. Every item kind lands in the right inventory. `lookCharmMisses` and `lookFound` updates. `finishUse` and `finishClear` bounds. Ack via `hueStore`, `hueUse` and `finishUse`. Substitution when a charm is already owned. **A reservation saved with the switch on settles after the switch goes off.** |
| **RestrictedEggs** | Restricted and unknown policy get fixed mode. `fixedItemId` is bound. Policy flips between quote and buy give `PolicyChanged`. |
| **HatchProgress** | Load fixtures: a v775 save with no new fields (legacy charm grant); a fresh save (`{}`); a save with every new field; malformed new fields. A saved Hue Egg reservation still settles after the Hue Egg retires. `Guard` still allows one pending result. |
| **CharmRules → CharmOwnership** | `usable` for egg, earned and unknown shapes. The visibility-only `visible=true` request is gated. `public` masks unowned shapes. Rows written by an old server are masked. |
| **BookClaim, BookStateBits** | The Charms page, the Toys & finishes page, and claims kept when a page total grows. |
| **HueHost / MaterialHost** | Retire `materialBuy` expectations that assumed Materials in Customize. Keep the legacy finish rendering test. |

Client specs (`src/client/ZZSpecs` and mirrors):

| Spec | Covers |
|---|---|
| **HatchEggsList** | Two rows (Toy, Customization). The pending labels. |
| **HatchDisclosure** | Charm row and sub-line, pity line, restricted Next and charm countdown, at 5 phone sizes (no overflow). |
| **CharmCards** | Locked egg shapes, "Find in eggs", no Snowflake by default, earned shapes unchanged. |
| **CustomizeRedesign / CustomizeNewItem** | Finish tab replaces Materials. NEW badge for finish jars and charms. |
| **FinishPanel** (new, replacing MaterialEditor coverage) | Slider notches, refusal at the ends, Original per axis, look names. |
| **JellyMaterials, MaterialFinishPreview** | Sheen stop profile mapping, fallback to the nearest verified stop toward 0, jelly stage alpha. |
| **HueItemReveal, HatchItemStage, HatchRarityCue** | Finish jar and charm builders and tiers. |
| **HueIntent** | `lookHatch`, `finishUse`, `finishClear` packets. |
| **UICopy** | Every new key exists; no hard-coded "Snowflake" default copy is left. |

The Studio run uses the ZZSpecs copies (no loadstring or HTTP in MCP). The expected baseline stays server 59+/59+ and client failures limited to the 14 already known.

---

## 8. Ordered slices

Each slice is publishable privately on its own, with tests green. Slices 2 and 3 must not reach a public build without slice 4.

| # | Slice | Contents | Done when | Size |
|---|---|---|---|---|
| **1** | **Foundation (dark)** | `LookEggCatalog` (pure). New optional save fields and validators. `charmUnlocks` normalization in `acquire`. HueState accepts `lookBuy`, `finishUse` and `finishClear` receipts (switch `EnablePurchases=false`, so nothing sells). Public snapshot fields. | LookEggCatalog, HueProgress validator and HatchProgress load specs green. Nothing visible changes. **This build is the rollback floor** (R1). | 1 session |
| **2** | **Charm ownership switch** | `usable`, the request gate including visibility-only, public masking, the locked egg shapes in the charm picker, charm copy. | CharmOwnership and CharmCards specs green. A fresh Studio save shows no charm; a legacy fixture keeps its Snowflake. | 0.5 |
| **3** | **Finish doses** (parallel with Fable's templates from day 1) | `finishUse` and `finishClear`. `petFinish` in the appearance and garden snapshot. Sheen and jelly rendering with fallback. The Finish tab, plus a Studio-only jar grant for testing (`RunService:IsStudio()`). | Fable approves the phone renders of all 7 stops and 3 jelly stages. Every template passes `NativeVerified`. FinishPanel and JellyMaterials specs green. | 1.5 + Fable 1 |
| **4** | **Customization Egg on sale** | `lookBuy` through `hueCommand`. `EnableEgg=false` for the Hue Egg. The Hatch eggs list, odds panel, pity line and restricted Next. Reveal, receipt and wear. Analytics. | Live private test: a random account and a restricted account (policy override in Studio) each buy 20 eggs. Pity is seen. A charm is worn and survives a rejoin. A kill-the-server test lands between reserve and settle. | 1.5 |
| **5** | **Book** | Toys & finishes page, Charms page, milestones. | BookClaim and BookView specs green. Claims survive. | 0.5 |
| **6** | **Copy, translation, listing, review** | All keys, changed promises, How it works, coach cards. Localization export and sync. PLAY-BUILD entry. Code review. Publish. | Translations synced (N/M recorded). Code review GO. Spencer QA. | 0.5 |

Total: about **5.5 sessions plus Fable's template and art pass**, so 3 to 4 calendar days with review. That matches the scope.

---

## 9. Risks (summary; the architect review in §10 has the fixes)

1. Mixed-version servers and place rollbacks reject saves that contain the new receipts.
2. Charm gate holes: the unmarked visibility path and stale profile rows could show a Snowflake to a player who does not own it.
3. Reservations that can never settle after a deploy (switch, price, policy or pool drift) block every egg for that player.
4. Seven sheen stops may not read on a phone, or may fail `NativeVerified`; that blocks the egg.
5. Odds disclosure is wrong or out of date: rounding, the "odds never change" promise, or a stale client table.
6. Phone layout: 8 odds rows plus the pity line; the Finish tab slider on small screens.
7. Merge conflicts: `HueEggView` (1,793 lines) is also touched by Fable's jar art and the Companions Toys-tab removal.
8. A second economy change days before launch, plus Book milestone inflation.

---

## 10. Architect review: what breaks in production

I reviewed the plan above as if it were already live. Each finding has its fix, and the fix is already folded into the sections cited.

**R1. Mixed-version servers and rollback (severity: high).** v775's `HueState.validReceipt` rejects any `lookBuy`, `finishUse` or `finishClear` receipt, so an old server loads such a save as `InvalidData`. The player gets a session with 0 Stars that saves nothing. Roblox keeps old servers running during an update, and a place rollback has the same effect. This failure is not destructive (`acquire` returns nil and writes nothing), but players see it.

*Fix* (slice 1, §2.1):
- **Expand, then contract.** Slice 1 ships the validators and new fields with nothing selling, so every build that can write the new data is preceded by one that can read it.
- Record slice 1's place version as the **rollback floor** in PLAY-BUILD.
- Publish any public update that changes the save's shape with **"Migrate to latest update"**, so no old server serves a new save.
- Because the launch build will include slice 1, public players can never meet a pre-floor server.

**R2. Charm visibility hole (high, and the first thing players would notice).** `Appearance.request` documents that "Visibility-only requests never ask" the gate, and an entry with no shape resolves to `Default="dot"`. So a fresh player (or an old client) sending `{visible=true}` would get a free Snowflake. Separately, a profile row written by a v775 server during a rollout can say `ring, visible`.

*Fix* (§3.4):
- Every `visible=true` must resolve to a usable shape.
- `Appearance.public` masks unowned shapes, and so does the garden snapshot.
- `Default` is only a render fallback.

**R3. Is a missing `charmUnlocks` "legacy" or "fresh"? (medium).** If the field were only interpreted at read time, any code path that rebuilt a state without it would hand out three charms, and a fresh save would look legacy.

*Fix* (§2.2): the field is materialized once in `acquire`, and freshness is detected by `root.hatching == nil` in the same UpdateAsync.

*Known gap:* a brand-new player whose save is first created by an old server during a rolling update counts as legacy and gets three free charms. This is cosmetic and bounded, and Migrate to latest closes it. Accepted.

**R4. Stuck reservations (high, and silent).** `HatchGuard` allows one in-flight reservation or pending result across all eggs. If settlement re-checks live conditions (a switch turned off, a price change, a policy change, the pool changing) and returns false, the durable reservation is retried on every load and fails every time. That player can never buy any egg again. The existing `hueBuy` settle re-checks `purchaseEligibility` and charges the *current* `Hue.Cost`, so a saved reservation outlives a price change.

*Fix* (§3.2 steps 3 and 6):
- Settlement is **total**: it checks only the reservation and quote integrity, and charges `quote.price`.
- Live checks happen at reserve time only.
- Any drift resolves deterministically, either by substitution or by a cost-0 `Refused` receipt that clears the reservation.
- The switch blocks only *new* reservations.
- Spec: "reservation saved under the switch on, settled with the switch off".
- Follow-up outside this feature: audit `hueBuy`, `materialBuy` and `toyBuy` settlement for the same flaw.

**R5. Odds disclosure accuracy (high, compliance).** Rounding weights with `OddsText.list` would show percentages that are not the real odds (the pool-4 problem again). The shared promise "The odds never change" becomes false once the table moves with charms. A client holding a stale snapshot could buy against a table that no longer applies.

*Fix* (§1.2, §3.1, §5.2, §6):
- Integer tables for each M, where displayed equals actual, with a spec per table.
- The quote binds `missingCharms` and `charmMisses`, and the server refuses `PoolChanged`. So the roll always uses the table the player saw.
- The pity rule is disclosed as a line, with a countdown.
- New promise copy.

**R6. Changing the stage cap later would invalidate saves (medium).** If Fable's review drops sheen to 2 stops and the validator bound followed `SheenStops`, every save holding sheen ±3 would fail validation, which means `InvalidData` again.

*Fix* (§2.1, §4): the stored bounds are frozen at ±3 and 0..3 forever. The display and use caps are separate catalog constants. Out-of-cap values clamp at render and at use, and are never rejected at load.

**R7. Missing or unverified templates in the live place (medium).** If finishes simply disappeared from the pool when templates are missing, the disclosed odds would silently change. If they stayed in the pool, players would buy jars that render as nothing.

*Fix* (§4): `available()` gates the **whole egg** on every template being verified, so it fails closed with "Not ready". The renderer falls back to the nearest verified stop toward 0.

**R8. Policy flips and PolicyService outages (medium).** Unknown policy is treated as restricted. A player who opens the panel before the policy resolves sees "Next: X". After it resolves, the quote's `selectionMode` no longer matches.

*Fix* (§5.2): the client rebuilds the quote from the latest snapshot on every tap, and treats `PolicyChanged` or `PoolChanged` as "re-render, tap again", not an error. The server keeps refusing mismatches.

**R9. Two stores for one charm (low).** The ack lives in the hatching state and the wear in the profile `petAppearance`: two writes, either of which can fail.

*Fix* (§3.2 step 8): ownership is committed with the purchase. The wear is a plain preference write that can be retried, and the receipt's button stays until it is saved. Wearing never blocks the ack.

**R10. The shared 64-entry receipt ring (low).** `finishUse` taps write receipts into the same ring as `lookBuy`, so a heavy jar user pushes purchase receipts out faster. The idempotent-replay window for an old op id shrinks. That is safe: an evicted quote's revision is stale, so the reply is `RevisionChanged`, never a double charge. `pendingHueResult`'s receipt is already protected from eviction. No change; noted.

**R11. Retiring the Hue Egg (medium).** A player with a saved `hueBuy` reservation or pending colour must still be able to finish it.

*Fix* (§3.3, §5.1): the switch refuses only new `hueBuy` quotes, the resume path is unchanged, the "Open saved colour" label stays, and a spec covers it.

**R12. Economy and Book drift (low; Spencer's call).** The Charms page adds 35 Stars and makes Bookworm easier. Legacy-granted players fill half the Charms page at once. Adding finishes drops the Toys page percentage, though claims stay.

*Fix*: the rewards are `[PLACEHOLDER]` and listed for Spencer in §11. Telemetry: `Economy.eggOpened("look")` is added, or the day-7 wallet check would read the sink as missing.

**R13. Restricted "fewest held" quirk (low).** A restricted player who spends every jar always holds zero of everything, so they would get Rose forever, because ties go to the first. This copies a behaviour the Hue Egg already discloses.

*Fix option* (not taken unless Spencer prefers it): a rotating cursor, which means one more optional integer. The button always names the next item, so nothing is hidden.

**R14. Merge collisions (medium, process).** `HueEggView` is 1,793 lines and is also touched by Fable's jar art and by the Companions Toys-tab removal (note 7).

*Fix*:
- The Finish tab lives in a new `FinishPanel` module, and `HueEggView` only mounts it.
- Each slice records "Now working on" in TODO.md before it starts.
- Rebase onto the art lane's commits before slice 4.

**R15. `TestFreshSaves` (launch blocker, already on the launch list).** While it is true, every private build starts fresh, so the legacy-grant path never runs in a private build.

*Fix*: a HatchProgress spec loads a real v775-shaped save fixture through `acquire`, and the launch checklist adds "legacy charm grant verified on a pre-launch save copy" before `TestFreshSaves` goes false.

---

## 11. Questions for Spencer

1. Price stays 12 Stars? (Recommended: yes for v1; it has the most items of any egg.)
2. Charm share starts at 6% (2% for each missing shape), with a pity of 15 and every 12th egg for restricted accounts?
3. Legacy saves keep **all three** free shapes, not only the one being worn? (Recommended: all three, since everyone owned them under the old rules.)
4. Finish as its own tab now, and the merged "Look" tab later? (Recommended: yes, to keep the change small days before launch.)
5. The new Charms Book page and its 35 Stars of milestones?
