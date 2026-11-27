# Paint, Shine, Dress: build plan (Opus, 2026-11-27)

Source: Fable's `CUSTOMIZE-AUDIT.md`, approved by Spencer. This is the plan only; nothing gets built before the
architect review and a go.

## Goal

One "Dress up" door with four tabs: Colour, Shine, Outfit and Charm. A player can pick a colour, preview it and buy
it outright. The save, the renderer, the egg odds and stored prices do not change. Switch off is today, exactly.

## Key decision: pot receipts get their own namespace

A paint pot is a hue jar. Buying one adds 1 to `hueInventory[rose|tide|citrus|iris]`, and painting with it is
today's `hueUse`.

The receipt does **not** go into `hueItemReceipts`. Older builds validate that ring strictly, so the live build
(aeae2d9) and older beta servers would read the save as `InvalidData` (risk R1 in the Customization Egg plan).

Instead the receipt goes in a new optional top-level field, `paintPots`, the StatEggState pattern. `validBase`
ignores unknown top-level fields, so old builds load these saves with jars and Stars intact. That means there is no
rollback floor, and a cross-version spec proves it.

## Components

| Area | File | Change |
|---|---|---|
| Config | `src/shared/PaintPotCatalog.lua` (new) | `Price=15` [PLACEHOLDER], `Prices={[15]=true}` (frozen, only grows), `Items=Hue.RollOrder`, `ReceiptLimit=16`, `PerMinute=20` |
| Rules | `src/server/PaintPotState.lua` (new) | `quote`, `apply`, `find`, `valid`, `sanitize`, `public` |
| Save | `src/server/HatchProgress.lua` | `Hatching.potCommand`: one `transact` of kind `"pot"`. `PaintPotState.valid` joins `valid()`, `"pot"` joins the kinds that return root on a refusal, plus `public.paintPots` |
| Request | `src/server/init.server.lua` | `potBuy` branch with the Material branch's shape; new `Remotes.PotResult` |
| Switch | `Alive.lua`, `FeatureFlags.lua` | feature `paint` (`AlivePaint`), on when the value is missing; beta and Studio only |
| Intent | `src/client/PaintPotIntent.lua` (new) | HueIntent's begin, receive and reconcile, for `potBuy` only |
| Copy | `src/shared/UICopy.lua` | new `paint` section: Dress up, Colour, Shine, Outfit, Pink, Blue, Yellow, Purple, mix names, Soft / Normal / Shiny, See-through, Paint Egg, Snack Egg, Back to white. Old keys stay |
| Glue | `src/client/DressUp.lua` (new) | `on()`; `copy(key)` returns the `paint.*` override when on; `tabs()`: Colour=`hue`, Shine=`finish`, Outfit=`outfit`, Charm=`charm` |
| Door | `src/client/DressUpButton.lua` (new) | `attach(focus)`: a Kit button beside StatsButton that owns its own layout; not built when off or with no `callbacks.dressUp` |
| Hook | `src/client/PetFocusUI.lua` | **one line** after `buildStatsButton()`: `require(script.Parent.DressUpButton).attach(self)` |
| Callback | `src/client/RoomView.lua` | `dressUp` calls `clientUI.openHue("palette", petId, "focus")`; `openHue` accepts the `"focus"` back route |
| Screen | `src/client/HueEggView.lua` | `tabList` returns `DressUp.tabs()` when on, and the header reads "Dress up". Outfit calls `openWardrobe()` and keeps the current tab. Visible literals ("Hue", "Main", "Your jars", "Hue Egg") go through `DressUp.copy` |
| Colour | `src/client/PaintPanel.lua` (new) | Mounted in place of the dose rows when on: 10 swatches (4 pots, 6 mixes), body and tummy-and-ears pictures (`main` / `secondary`), five pips, a count per pot. Actions: **Paint** (`hueUse`), **Buy · 15★** at count 0, free **Back to white** (`hueClear`). Preview = `Hue.resolveTarget(counts+1)` |
| Shine | `src/client/FinishPanel.lua` | paint view: a Soft / Normal / Shiny slider with 7 ticks and 3 See-through steps; each tap is one `finishUse`; reset stays two `finishClear` |
| Outfit | `src/client/WardrobeShop.lua` | unchanged; its back already returns here |
| Charm | as today | egg-charm rule copy: "Rare in the Paint Egg" |
| Shop | `src/client/EggHatchView.lua` | Paint Egg and Snack Egg names; a "Looks" heading with a four-pot "Pick a colour" strip beside the Paint Egg; a separate "Snacks" heading. The Paint Egg keeps the Hue shell |
| Hub | `src/client/CompanionsHub.lua` | Wardrobe and Customize rows become one "Dress up" row when on. The Care Cradle path is unchanged |
| Untouched | PetMaterials, PetMaterialConfig, PetCatalog, HueCatalog, LookEggCatalog, LookState, HueState | |

## Server path for `potBuy`

1. **Request.** The client sends `HatchRequest("potBuy", {id="<revision>:<guid>", itemId, price}, revision)`.
2. **Gates in init.server.**
   - `Alive.on("paint")`, else `NotReady`.
   - The board's 0.3 s gap and a per-session `PerMinute` cap, else `Throttled`. The cap protects the DataStore budget.
   - `nurseryBusy` or `payoutPending`, else `Busy`.
3. **Quote check.** `quote` checks the exact keys and the id's revision prefix, then `itemId` is in `Items`, then
   `price == Price` (else `PriceChanged`).
4. **Duplicates.** `potCommand` looks the id up in the ring. Same digest: `AlreadySaved`, no charge. Different
   digest: `OperationConflict`. Otherwise it runs `transact`. A store error leaves the operation pending
   (`Retrying`), and the same id resumes it.
5. **`apply`, inside UpdateAsync.**
   - Refusals: no owned `Hue.Supported` pet gives `MeetPipFirst`. A pending reveal (`Guard.other(state,"hue")` or
     `pendingHueResult`) gives `RevealPending`. A full stack gives `StackLimit`. `nectar < price` gives `NeedStars`.
   - A refusal writes nothing.
   - Success: `nectar -= price`, `hueInventory[itemId] += 1`, and the receipt
     `{op, itemId, price, inventoryAfter, revision, digest}` goes into `paintPots.receipts` (oldest dropped after 16).
6. **Exactly once.** `committed()` (via `lastOperation`) plus the ring give exactly-once across retries and
   reconnects. `valid()` still runs before the write.
7. **Load.** `sanitize` drops malformed receipts (never jars or Stars), so a load never fails. `lookFound` is
   untouched: a pot is not an egg find.

## Switch

`/alive paint off|on|clear`; ceiling false on live. Off means no button, and today's tabs, copy, hub rows and shop.
The server returns `NotReady`. Pots already bought stay in `hueInventory`, so today's Hue tab shows them as jars.

## Edge cases

| Case | Behaviour |
|---|---|
| Double tap, lost reply | Same id, so `AlreadySaved` and one charge; one purchase in flight per client |
| Stars spent elsewhere first | `NeedStars` inside UpdateAsync; nothing written |
| Price retuned | `PriceChanged`; the swatch redraws |
| Switch flipped mid-buy | New requests refused; a transact already started finishes |
| Egg jar not yet opened | `RevealPending`; `quietOpen` stores the jar when Dress up opens |
| New colour on a painted pet | It mixes (data rule). The preview shows the real result and offers Back to white (Q2) |
| Mix swatch | Paint spends the lower-count pigment; Buy fills a missing pot |
| 5/5 pips | Paint disabled |
| Restricted accounts | Pots are not random, so they are on sale; the egg stays in fixed mode |
| No pet yet | No door; strip hidden |
| Shine at its end stop, or no jars | Tick disabled: "Find more in the Paint Egg" |
| Pet has no wearables | Outfit disabled |
| Gamepad | A free shoulder button while focus owns input (check PetFocusKey) |
| Beta rolled back below this build | `paintPots` ignored; jars and Stars still valid |

## Not in this slice

- The onboarding's free pot, free hat and any welcome gift (not confirmed).
- Paint Egg shell art.
- Feature Egg and an Extras tab.
- Shine items sold one at a time.
- Any change to the egg's odds, price or receipts, or to the renderer.
- A live publish.

## Offline specs (`run_dash_server_specs.py`)

| Spec | What it proves |
|---|---|
| `PaintPotCatalog` | Prices are frozen; the item list |
| `PaintPotState` | Every refusal, success, replay, digest conflict, ring bound, `sanitize`, `valid` |
| `PaintPotProgress` | HatchProgress fixture: −15 Stars, +1 jar, one revision; a retry after an error commits once; `NeedStars` writes nothing |
| `PaintPotCrossVersion` | A `paintPots` save loads on the live tree (aeae2d9) and the base tree |
| `Alive` | Adds `paint` |
| `DressUp` | Off is identical to today's `tabList`, hub rows and shop names |
| `PaintCopy` | No `paint.*` string contains a banned word: Hue, jar, dose, Main, Secondary, Rose, Tide, Citrus, Iris, Chalky, Satin, Glassy, Misty, Customization |

## Studio checks

- Buy each pot, then paint both targets.
- All ten swatches preview correctly.
- Slider and See-through steps work.
- Outfit round trip.
- The Snack Egg sits under its own heading.
- `/alive paint off` restores today: compare a text dump of the screens.
- No banned words in any visible TextLabel.
- The button stays clear of the new petting screen.
- 844x390 captures for Fable.
- `LocalizationFit` passes.

## Risks

1. **PetFocusUI conflicts.** It is being edited for the petting screen. The hook is one line, merged last, and the
   button may still collide with the new controls.
2. **HueEggView size.** It is 2,100 lines, so PaintPanel stays its own module.
3. **Mixing.** Mixing undercuts "pick a colour" (Q2).
4. **Economy.** Pots at 15 against the egg at 12 may thin out egg sales and its charm pity. Compare the two sinks after
   a week on the beta.
5. **Copy.** The Shine item and mix names are not decided, and translations of them may run long.

## Localization

- About 40 new `ui.paint.*` keys, none deleted: the switch-off path and live still read the old ones.
- Before the beta publish, run `export_localization_csv.py` and `sync_localization.py`, and record "translations
  synced (N add/update, 0 delete)".
- The old keys are deleted once paint ships live.

## Open questions

1. Are Shine jars also sold at a fixed price, or only from the egg? This plan sells colour only.
2. A new colour on a painted pet: mix it, or default to Back to white first?
3. Is 15 Stars confirmed? And with no pot, does Paint buy and paint in one tap (two saves)?
4. What are the Shine item and mix names? (Fable)
5. Does Dress up open over pet focus, with Back returning there, or leave focus?
