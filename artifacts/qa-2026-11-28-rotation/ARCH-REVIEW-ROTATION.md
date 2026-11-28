# Architect review: daily rotation (2026-11-28)

Plan: `ROTATION-BRIEF.md`. Verdict: **GO WITH CHANGES.**

## Q1 rack + Outfit Egg grant
1. **Idempotency:** `giftEgg` uses a server guid op id (`HatchProgress.lua:1190`), fine only for once-per-save gifts. The Outfit Egg is paid and repeatable: the client sends a `requestId` (opaque, <=100 chars); signature `rack:<id>`; inside UpdateAsync check `rack.ops` first, a match answers AlreadySaved with `rack.last`.
2. **Bind what the player saw:** request `{petId, day, price, mode, poolKey}` (`poolKey` = hash of today's unowned ids + the sparkle pick). Mismatch answers DayChanged / PriceChanged / PolicyChanged / PoolChanged with no charge (the lookBuy eligibility pattern, `LookState.lua:139-146`). Compare the day with `dayOf(now)` once before the first attempt; retries use the frozen `c.day`.
3. **Inside the write:** refuse under `Guard.other` (as `giftEgg` :1193); dedupe on `rack.ops`; refuse an owned item; refuse `ClosetFull` when `#owned >= WearableState.Limit`; check Stars; refuse (never overwrite) a broken `rack`; roll on the exact integer weights, not rounded percentages.
4. **Lane A owns `server/WearableState.lua`:** `check` refuses `egg=true` rows as NotForSale (as weekly rows at :93).

## Q2 the 128 ceiling
5. `WearableState.lua:46` (`count>State.Limit`, 128 in `WearableCatalog.lua:10`); every build since v10 enforces it and going over fails the save. 124 is safe if every write path refuses at 128 (Wardrobe buy does, :102; the rack egg and the Outfit gift must). Don't raise it tonight (two releases needed). Headroom shrinks with each This week row (9 already).
6. **Egg rows would go on sale:** `Variants.released` (`WearableVariants.lua:97`) lists rows without `from` at base price. Add an `egg=true` branch (listed only under `math.huge`); in `problem()` forbid `price`, `from`, `gate`, `weekly` on egg rows. Lane A owns this and the `WearableCatalog` listing code; lane C only renders.

## Q3 Paint daily odds + charms never guaranteed
"Older builds reject on load" is true only of a new pool version: saved lookBuy quotes (64-receipt ring + reservation) are re-checked at load (`HueState.lua:67,176,206`); `LookState.validQuote` rejects unknown `poolVersion` (`LookState.lua:69`); the quote needs exactly the known keys (`HueState.lua:58`). `Tables` and `PityAt` are never checked against a save (`LookEggCatalog.lua:10-12`).
7. **Build both tonight, each behind its own switch** (`look_daily`, `look_nopity`): `PoolVersion` stays 1, no new quote key; the day goes in as a separate lookBuy request argument; `HatchProgress.lua:806` checks day == today (PoolChanged otherwise) and rolls with `Look.tables(day)`. No pity = `pityDue` false while on; misses still stop at 63 (`LookState.lua:182`). No save-shape change. Update the header rule in `LookEggCatalog.lua`.
8. **Before live:** Spencer decides how to keep the promise to players partway to a guaranteed charm (e.g. grandfather via a tolerant top-level `lookPityHold`); remove the "charm in N" (`pityLeft`) copy; review the odds text; restricted players keep `RestrictedCharmEvery` (fixed, not random).

## Q4 onboarding
9. Conflicts with the onboarding-simplify lane: `GiftChain.lua`, `init.client.lua`, `init.server.lua`, `UICopy.lua`, `CoachMarks.lua`, `V3-TEST-PASS.md`, `TODO.md`. Merge simplify first; B rebases onto it.
10. Don't spend coach bit 29 on `picksSeen`: latch `gifts.outfit.seen` through the existing `giftSeen`.
11. The new order (Outfit → Paint → Toy → Snack) only while `daily_rack` is on (inside `GiftEggs.due`); off = Paint → Toy → Snack. The Outfit gift checks pet ownership and the 128 cap.

## Q5 previews + colour selector
12. Reuse `CardPreviewCache` (lazy, <=8 live, 16 cached, posed once, never animates; live 6 on phone) instead of a new `RackPreview.lua`. Previews show the finish as a still colour + `UISparks`; `WearableFinish` steps garden pets only.
13. Swatch equip works only if `forPet(pet, math.huge).byId` includes egg rows (`WearableState.equipResult` :122). One equip in flight, last tap wins (each tap is a DataStore write).

## Q6 lanes
14. Lanes share files: `WearableCatalog` moves to A (change 6); D needs a server op in A's files. Merge order: simplify → A → C → B. **Cut D tonight.**
15. Cut order: D; (a) the Paint daily shift; the animated finishes (rows ship as still colours); the odds pointer step; closet mode. Never cut 1-6, the odds list, or the specs.
