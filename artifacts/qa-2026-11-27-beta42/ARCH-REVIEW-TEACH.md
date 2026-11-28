# Architect review: more teaching + onboarding remembered (2026-11-27)

Plan: `TEACH-MORE-BRIEF.md` + `DIAGNOSIS.md` B8. Decisions: build all lessons; graduation at 12 rounds; colour reset show-only.
Verdict: **GO WITH CHANGES.**

## teachMask
- New optional integer `teachMask` on hatching v11 beside `coachMask`; own module `src/shared/TeachMarks.lua` reusing CoachMarks' helpers (integer, sanitize, merge, covers, validId). Ids append-only (17 listed fit in 31 bits).
- Written by a `teachMark` action beside `coachMark` (`init.server.lua:2296`): `board.teachPending` flushed in the same `flushCoach` write (one revision bump per quiet window); `Hatching.coachMark` (`HatchProgress.lua:1335`) takes the second mask, signature `coach:<c>:<t>`; `public.teachMask` beside line 540.
- Cross-version safe: older servers keep the field (`transact`/`acquire` clone the whole previous root, `HatchProgress.lua:653`, 355; `valid()` ignores unknown keys). A save rebuilt from scratch loses it: only a repeat lesson.

## Required changes
1. Latch in the same transaction that makes a fact true wherever the fact can later turn false: `dress` in hueUse, `snacks` in snackFeed (petBoosts drop to 0), `dash` in the ribbon award. Until saved, the client keeps a session copy of its latches (like `live.mask`).
2. Backfill on the server inside the acquire callback (OR-only, idempotent, no extra write): `done` when not owed the gift chain (`Gifts.owed` false) or `stats.rounds >= 12`; `dress` from any pot used; `menu` from `menuSeen`; `park` from fetches > 0; `dash` from a ribbon; `deckTour`, `tipNext`, `tipGoal` from rounds >= 1; `level` from rounds >= 2; `quests` from coach bit `quests` or `questDone`.
3. Neither "You're all set!" nor needHi/needDeck/gardenIntro/wins sets `done` (All set comes before most lessons; it would kill the course and beta saves mid-course). Map those facts to a new appended `needs` id that only `Needs.current` honours.
4. `Coach.wants` respects graduation only for teaching ids; keep `petArrived`, `questDone`, `weekDone`, `nestIntro`.
5. `Chain.may` (`GiftChain.lua:145`): once `done`, refuse invite steps only (`giftOf == nil`); gift bubbles stay.
6. Deck tour keys: A/Space drop and B is Items during a round, so no "A to go on / B to skip". Bind only unbound keys with ContextActionService (never A, Space or touch); read HUD taps from a `UserInputService.InputBegan` position test, no Active/Modal frame; mount the pointer under the deck's GUI (or higher DisplayOrder, same inset).
7. Dim cards through the existing calm path (`DeckScreen.lua:2078`), not card transparency (clashes with the C10 `nextBase` fix).
8. No long-press "Skip the tips" inside the deck; only the Settings row.
9. A lesson whose feature is off on that place (Dash or Park off) counts as done. The client asks for `done` with reason `finished` or `skipped`; the server sets `veteran` and `moved on` itself and checks `moved on` at round award.
10. Latch a lesson after it has been ignored in 3 sessions (a garden-only player would otherwise get it forever).
11. `init.client.lua` is at the 200-local limit: wiring in `DeckTour.lua` and a teach-wiring module, no new top-level locals.

## Cut order (first to last)
wardrobe → stats → snacks → the three deck tips → Settings skip row → quests → reset. Never cut: the mask, latches, graduation, backfill, the Dash veteran fix, the deck tour with `level`.
