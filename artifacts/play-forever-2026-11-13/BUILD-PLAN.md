# Play-forever v1 set: build plan (2026-11-13)

Spencer approved `PLAY-FOREVER-SCOPE-2026-11-13.md` ("proceed with all recommended") and, after private v558,
"Yes, start it". v1 set: lifetime counters (fields already in save v11 since 0cc2c3a), collection book, no-reset
stamp card, lifetime stats screen, plus the scope's slice 5 policy pass. Kittens 120 already shipped.

## Goal

A returning player always has a goal that is not "buy the next thing": fill the book (six pages, Stars at 25/50/75/100%),
stamp the card every day played (never resets, a missed day costs nothing), and see their own records.

## What exists (checked)

- Save v11 (`HatchProgress.lua`): `stats` (13 counters), `stamps` (integer), `book = {claimed = {...}, found = bitmask}`,
  validated by `src/server/LifetimeState.lua`. `Lifetime.record` (spend/earn on every transaction) and
  `Lifetime.recordRun` (rounds, wins by difficulty, tidy, best chain, tier V) are live. `merges`, `itemsUsed`, `pets`,
  `parkGames` are still always 0.
- Daily gift: `action == "daily"` pays `EggCatalog.DailyBonus` (6) once per `dayOf(now)`; client shows it in
  `DeckMenu` / `EggHatchView` (`dailyAvailable`).
- Ownership lists the book reads: `ballThemes.owned`, faceplates, `petWearables`, toys + material finishes, pets
  (`inventoryMask`).

## Slices

| Slice | Owns |
|---|---|
| F1 Server + shared | new `src/shared/BookCatalog.lua` (pages, totals from the live catalogues, milestone ids `page.pct` never reused, rewards 5/5/10/15 per page = 35 x 6 = 210 total, discoveries list + bit numbers); `src/shared/StampCard.lua` (7-stamp rewards 4,4,5,5,6,6,12 = 42/week, same as today's 6 x 7); `LifetimeState` helpers (`setFound`, `claim`); HatchProgress: `daily` becomes the stamp (stamps += 1, pays the stamp reward; still once per day), new `bookClaim` action (op id bound to milestone id + reward, server computes percent from the save, pays once, records `book.claimed`), discoveries set inside `recordRun` (first tier V, chain of 5, each goal type won, each difficulty won), counters `merges` + `itemsUsed` passed from the run receipt, `pets` from the petting transaction; book-only faceplate `bookworm` (not sold, granted when any three pages reach 100%, shown on the Faceplates page as "From the book"); public snapshot fields (`stamps`, `stampDay`, book progress + claimable, `stats`). Policy: `OddsText` prints percentages; eggs for `ArePaidRandomItemsRestricted` players show the next item instead of a roll (fixed order) or are hidden. |
| F2 Client | new `src/client/BookView.lua` (Collection book: page list with owned/total and % bars, one open page with items, milestone chips claimable with the sticker style, a "Records" page that shows the lifetime stats), reachable from the Pocket Menu (new row "Collection book") and the Companions hub; stamp card on the daily gift moment (seven stamps, today's lands with a boing, the 7th shows the bigger gift) replacing the flat gift card; strings in `UICopy`; uses the personality kit (Fredoka, tint `book` = mint-teal accent, seams, stickers, pet peek on desktop). Phone 812 x 354 and desktop. |

Order: F1 first (snapshot shape the client reads), F2 after. One Studio; implementers write code and specs, the
coordinator runs Studio.

## Rules

- Book percentages and claims are computed on the server from the save; the client never sends a percent.
- A milestone pays once (`book.claimed`), ids never reused; adding catalogue items later can drop a page below a
  claimed milestone without clawing anything back.
- Stamp card: one stamp per day played (claimed on arrival, as the gift is today); the count never resets; reward
  index = `stamps % 7`; no streak, no penalty, no paid element.
- Counters stay capped integers written only inside fenced transactions.
- Odds shown as percentages; restricted players never get a paid random roll.

## Edge cases

| Case | Expected |
|---|---|
| Old v11 saves (stamps 0, book empty) | Book shows progress from owned items; all reached milestones claimable at once |
| Claim retried after timeout | Op id dedupes; pays once |
| Two milestones claimable | Claimed one at a time; "Claim all" optional if cheap |
| Catalogue grows after a claim | Percent can drop; claims stay |
| Day boundary while the menu is open | Server rejects with DayChanged; client refreshes |
| Fresh save before Pip | Book shows zeros; stamp still works (as the gift does today) |
| Restricted player | No paid roll; egg shows the next item at the same price, or is hidden |

## Tests

Server specs: `BookClaim` (percent from save, pay once, op-id retry, claimed survives catalogue growth, bookworm grant
at three pages), `StampCard` (one per day, rewards cycle, never resets, DayChanged), `LifetimeCounters` (merges,
itemsUsed, pets written; caps), HatchProgress / HueProgress / ToyFeatureProgress still pass. Client specs: `BookView`
(layout at 1920x1080 and 812x354, no text under 12 px, claim button states, Records page), `StampCardView`,
`UICopy` keys. Studio captures of the book (list, open page, claim), the stamp card and Records at both sizes.

## Not in this pass

Weekly Board, Bear bond, Style Egg, shop shelf, Polish, theme weeks (weeks 2-8 roadmap).
