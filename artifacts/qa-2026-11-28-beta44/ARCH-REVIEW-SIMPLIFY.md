# Architect review: onboarding simplify (2026-11-28)

Plan: `ONBOARD-SIMPLIFY-BRIEF.md`. Verdict: **GO WITH CHANGES.**

**Q1 the tour round.** A 0-drop leave counts nothing: "Room" only stops stepping (`init.server.lua:2953`), `RunReturn.classify` keeps the unfinished round (Preserve), a field round ends only when the drop budget runs out or the board overflows (`FieldRun.lua:104`), and the award runs only from `settleReward` (`:2534`). Rounds, losses, quests, best, Stars, the 1-Star effort pay, `starterRounds`, `ToyRounds` stay unchanged. Keep the dealt round (no preview board).

## Required changes
1. **Idle timeout:** `ClientSimHost.lua:539-543` finishes a round after 300 s with no client reports (a phone backgrounded mid-tour) and pays a 0-drop round in full. Skip `RoundSim.finish` when `hb.drops==0`. Add it to the untouched-round spec.
2. **Holding drops:** check `tourHold` at the top of `dropEgg` (`init.client.lua:3114`, before `clientSim.drop`) and at the item send (`:3933`). The tour's binding (High+900) now takes Space, ButtonA, ButtonB: rewrite `Tour.Forbidden`/`keysSafe` and their spec. "Tap anywhere" hit-tests the whole deck, not just `hudRoot`.
3. **Ready gate:** `boot.playing==false` is also true before the boot starts: require a boot finished or skipped since this deck opened, then 0.4 s.
4. **Auto-close:** `leaveDeck` returns false while `roomView.busy`: retry until Mode is Room.
5. **Who graduates:** remove the automatic `done:finished` (`TeachLessons.lua:205`; with Course = {"deckTour"} it would graduate before the card). Card owed = `deckTour` latched, no `done`, no `needs`, in the garden; `deckTour` + `needs` without `done`: graduate silently. The server refuses every `teachMark` after `done` (`init.server.lua:2334`): set `needs` with `done` on the server, or treat `done` as needs-over in `BearNeeds.facts`.
6. **WelcomeGift:** `Gift.facts` needs `rounds>=1`, so the card never pays: accept `deckTour` too (save + `board.teachPending`, passed like `coachPending` at `:2291`), optionally only after this board was in a field round.
7. **"Not graduated" dependents (graduation now ~minute 5):** `Coach.wants` (`CoachMarks.lua:135`) blocks all but four cards (fill-line, item card, machine first-visit, station tips): widen `AfterGraduation`. `Chain.may` (`GiftChain.lua:154`) refuses "You can hatch one!" and park/dash/nest invites once graduated: limit that to the new deck invite.
8. **Bubbles:** `needDeck` ("Play for Stars!") stays locked until a real round, blocks the chain bubble via `busy()` and returns after the tour: close it on `deckTour` (or off while `teach` is on). Order the deck invite after unseen/nest/paint and before "You can hatch one!"/toy; exempt it from the 90 s post-gift gap and the session count. `course` = teach on, deck lesson not done (incl. the ignored-3-sessions latch), not graduated, from live latches.
9. **Things ticks:** latch or save fact. customize: `dress` or painted/pot used. dress: a saved equipped wearable (the `wardrobe` latch is client-only and refused after `done`). quests: `questDone` or `lastQuestClaim`. book/style: send coach marks `book`/`style` when those screens open (the server accepts them). New latches in teachMask bit 18+ with a server allow-list after `done`.
10. **Focus loss:** sum shown time from clamped `dt` only while the window is focused (not `now-s.since`); pause the deck invite's 8 s nudge and park clocks the same way.
11. **Show me:** its own TeachPointer (`Lessons:step` hides the lessons' pointer every frame when no lesson is due).

**Cut order (first to last):** results goals list restyle, goal ball short variants, book/style ticks, tour step 5 (Chain), the "Harder pays more" sub pill. Never cut 1-8 or 10.
