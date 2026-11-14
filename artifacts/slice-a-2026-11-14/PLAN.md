# Slice A (CONTENT-SCOPE §5): sell three existing face items + the analytics pass

Spencer accepted all five scope recommendations on 2026-11-14. Slice A is the "start now" slice. It needs no new art.

## Goal

1. **Three new items in Wardrobe:**
   - Round Eyes (Eyes, 15 Stars)
   - Wide Eyes (Eyes, 15 Stars)
   - Kitty W (Mouth, 15 Stars)

   They are bought and equipped like the other 13 items. Their meshes are already imported in `BearAttachments` as `Bear__EyeL/R_AltRound`, `Bear__EyeL/R_AltSmallWide` and `Bear__Mouth_AltW`, but no shop entry sells them yet.
2. **Analytics before launch,** so D1/D7 can be diagnosed:
   - an onboarding funnel that matches today's flow
   - egg-open results
   - engagement events
   - the wallet at session end

## Part 1: the items (data only)

Source of truth: `assets/garden-babies/attachments/attachments-manifest.json` `items`, built by `scripts/export_bear_attachments.py` from `ITEMS` in `scripts/build_bear_wearables.py`.

- Add an `ALT_ITEMS` dict to `export_bear_attachments.py`:
  - `round` → Round Eyes, `smallwide` → Wide Eyes (both Eyes, common).
  - `w` → Kitty W (Mouth, common).
  - These faces were authored before the wearables script existed, so they are kept out of `build_bear_wearables.ITEMS` and the Blender build never re-authors them.
  - The export appends them after `ITEMS`, so a future Blender re-export keeps them.
- Patch the manifest `items` in place with the same three rows, which is what the export would produce. Blender is not needed.
  - Piece rows come from the existing manifest meshes: triangles, channel, anchor, colorRole `face`.
- Run `python scripts/build_bear_attachments.py`, then `python scripts/build_bear_assets.py`. This regenerates `BearRigDefinition.wearableItems` and the template. Mesh ids are unchanged.
- **Lineup order:** append at the end, so existing card positions don't move. `WearableCatalog.inTab` groups items by slot anyway, so the order only applies within the Eyes and Mouth tabs.
- **Localization:** run `export_localization_csv.py`, then `sync_localization.py`. That adds 3 names.
- **Risk: Kitty W.** It replaces `MouthSmile` without `neutralOnly`.
  - Check in Studio that the expression system still swaps to `MouthO` for open-mouth frames, and that W doesn't stack with it.
  - If it does stack, flag it `neutralOnly`, which is how Blep already works.
- **Risk: Round and Wide Eyes.** Both use the eye texture. Check in Studio that blink and sleepy expressions still hide or replace them the way they handle Sparkle.

## Part 2: analytics (server only, live servers only, Studio no-op as today)

### 2a. Onboarding funnel (`FirstSession.lua`)

The funnel is rebuilt as 9 steps that match today's flow. Each step is logged once per first session, as today, under the gate `profile.rank == 0`, not Studio, `GameId ~= 0`, and not `loadFailed`.

| # | Step name | Fired from (server) |
|---|---|---|
| 1 | Board ready | board spawn (existing advance(1), both sites) |
| 2 | First drop | drop handler (existing advance(2)) |
| 3 | First merge | merge handler (existing advance(3)) |
| 4 | Bear met | `grantStarter` success (existing advance(4) at ~1317). The duplicate at ~357 in `publishNursery` is removed; it fired whenever any later publish found pip owned |
| 5 | Garden walkthrough done | `coachMark` "gardenIntro" accepted (new) |
| 6 | First machine opened | `coachMark` any of hatch/style/companions/quests/book accepted (new) |
| 7 | First quest claimed | quest claim ok (new, ~1145) |
| 8 | First Stars spend | any `Economy.command` / sink with after < before (new) |
| 9 | Second round started | the second `reset` into Board after step 4 (new) |

- **Order tolerance:** today `advance(n)` drops a step that arrives early. Players can spend before they claim a quest, or open a machine before the walkthrough finishes.
  - New behaviour: `advance(n)` marks step n done, then logs every consecutive done step from `self.step + 1`. A late step 7 then releases a held step 8.
  - Steps are never logged out of order, and never invented.
- The old step name "Pip hatched" goes away.
- Existing custom events stay: `FirstSessionLoungeVisit`, `FirstSessionRoundRetry`.

### 2b. Custom events (`EconomyAnalytics.event`, all fire-and-forget)

| Event | Value | Where |
|---|---|---|
| `EggOpened_<family>` (Hue/Feature/Material/Toy… the families that exist) | 1 | each server egg-open success; the result goes in the custom field `result` = item id |
| `StampAdded` | stamp count after (1–7) | daily stamp grant |
| `PlayDateDone` | 1 | Play date payout (~1357) |
| `PettingCapReached` | 1 | the petting grant that reaches 10 for the day |
| `BookMilestone` | 1, customField `milestone` = id | book claim ok (~1119) |
| `WardrobeEquip` | 1 | wearable equip ok (first time per session) |
| `RobuxPurchase_<productKey>` | 1 | StoreService receipt granted |
| `SessionRounds` | rounds finished this session | PlayerRemoving |
| `SessionEndWallet` | Stars balance | PlayerRemoving |

- **Session-end events:** these are logged synchronously inside `PlayerRemoving`, inside a pcall. `call()` defers and then checks `player.Parent == Players`, so a deferred call would drop them.
- **Event names stay low-cardinality,** a fixed set of about 20. Ids go in custom fields, never in names. The one exception is `EggOpened_<family>`, which has 4–5 values.
- **Not doing `FirstStarsSpend`, `FirstWardrobeEquip` or `FirstRobuxPurchase` as once-ever events.** "Ever" needs saved state, which this slice won't add. Funnel step 8 covers the first spend in the first session, and the economy sink logs cover the rest.

## Edge cases

| Case | Behaviour |
|---|---|
| Returning player (rank > 0) | no funnel, events still log |
| Studio / GameId 0 | everything a no-op |
| Steps arrive 8 before 7 | 8 held, both logged when 7 lands |
| Player leaves mid-step | nothing logged after leave; session-end events logged in PlayerRemoving |
| Save reload (~1513 replaces firstSession) | new FirstSession, step counter restarts. Roblox dedupes funnel steps per player, so a repeat is harmless |
| Item bought before the rig defines it | n/a: server validates via `WearableCatalog.item` |
| Old saves | no save change; owned/equipped validation already accepts any catalogue id |

## Not doing this slice

- Recolours, new tabs and new art (slice B).
- Once-ever "first" events (they need a save field).
- Client-side funnel beats for the individual garden beats. The client reports only `gardenIntro` when the walkthrough completes.

## Test plan

- **Server spec `FirstSessionFunnel`** (new, ZZSpecs, AnalyticsService stubbed through an injectable logger):
  - in-order logging
  - out-of-order hold and release
  - no duplicates
  - the gate (rank > 0 gives nil)
  - the removal of the 357 path, by grep assertion
- **`WearableCatalog`:** existing specs plus a case that `forPet("bear")` has 16 items, including `round` / `smallwide` / `w` at 15.
- **Studio Play:**
  - Buy and equip each of the three items.
  - Capture the Bear front view with each.
  - Cycle expressions (happy, sleepy, open mouth) with Kitty W and with both eye sets.
  - Check that no default eye or mouth shows through.
- **Regression:** all server specs, all client specs (the 7 known failures stay as they are), and LocalizationFit with 0 clips.
- **Live:** analytics only show on a published place. Check Creator Analytics → Funnels and Custom events after the next private publish. One session gives a 1-player sample, which is enough to see that the events arrive.

## Risks

- **Too many custom event names:** Roblox caps unique custom event names. About 20 names fit.
- **`LogOnboardingFunnelStepEvent` names are fixed at first log.** Old private-test data had "Pip hatched" at step 4. Launch uses a fresh universe save, but the analytics keep the old name until the dashboard rolls over. If it shows the old label, the fallback is to log the new funnel as `LogFunnelStepEvent("Onboarding_v1", …)`.
- **Kitty W expression stacking:** covered by the Studio check and the `neutralOnly` fallback.

## Architect review (2026-11-14) — revisions

| Original | Revised (reason) |
|---|---|
| Kitty W might stack with MouthO | Verified no stacking: W hides on the open frame (GardenPetVisual.lua:388-389). Small gap: W stays full size on line/soft frames; accept or add a scale later |
| `neutralOnly` fallback on manifest items | If ever needed, flag the manifest **mesh** rows (build_bear_attachments.py:103 reads mesh flags) |
| Order-tolerant funnel (hold steps until earlier ones land) | Log each step when it happens; the dashboard computes conversion (holding hid real drop-off) |
| Save reload restarts the funnel | It killed it (rank>0 after the first hatch): keep the existing object, `board.firstSession = board.firstSession or FirstSession.new(...)` |
| Step 7 on quest claim ok | Also require `reason ~= "AlreadyClaimed"` |
| Custom fields as `{result=id}` | Keys must be `Enum.AnalyticsCustomFieldKeys.CustomField01..03`; extend `Economy.event` with a fields arg |
| One egg-open site | toyBuy/featureBuy (:1165), materialBuy (:1186), hueBuy (:1225); skip *Ack/*Use/*Equip and AlreadySaved |
| StampAdded value = stamp count | `state.stamps` is lifetime: value `((s-1)%7)+1`, logged on the `daily` action |
| PlayerRemoving logs | Valid synchronously; read wallet/rounds before `boards[player]=nil` / closeBoard |
| Keep onboarding funnel vs new LogFunnelStepEvent | Keep onboarding funnel (deduped per player; old step-4 name only affects testers) |
