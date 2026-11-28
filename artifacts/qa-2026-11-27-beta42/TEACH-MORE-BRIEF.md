# Teach more: the deck tour, five more lessons, and "done for good" (Fable, 2026-11-27)

Answers Spencer's three beta (42) notes. For an Opus build on `TeachLessons` / `TeachPointer`. Switch: Onboard `teach` (no new switch). Off is beta (42).

**Two kinds of teaching, kept apart:**

- **Lesson**: a pointer on the real button; done only when the player does it (saved fact).
- **Tip**: one quiet pill (the CoachCards board pill, 6 s, fades by itself, never blocks a drop); saved the moment it shows. A tip never asks for anything.

## 0. Three faults to fix first

1. **Why Garden Dash never showed.** `Lessons.candidates` and `Chain.may` both stop at `f.veteran` (`totalWins >= 5`). The Toy gift waits three rounds and Dash waits for the first fetch, so most new players pass five wins before lesson E is ready: the pointer and the "Race time!" bubble are both refused. Also: the pointer only lives on the gate sheet's `Fun` tile, so with no bubble nobody reaches it; and the bubble counts toward three invites a session with a 90 s gap. **Fix:** a save owed the gift chain is never a veteran for lessons (drop `f.veteran` from `candidates`, `ask` and `Chain.may` when `gifts.owed`; section 3 replaces it). The next lesson's invite is exempt from `perSession`. Verify on a fresh beta save with 6+ wins.
2. **Reset un-does lesson A.** `painted` reads live paint; "Back to white" makes it false and Dress up lights again. Lessons need latches (section 3).
3. **Bits.** Leave coach bits 29 and 30 alone. Add one new save field, **`teachMask`** (integer, CoachMarks' rules exactly: optional, tolerant, OR-only, unknown bits kept, written through the same `coachMark`-style transact, client asks by id).

`teachMask` ids, in order (never renumber): `dress, deck, menu, park, dash` (latches for the five built lessons), `deckTour, tipChain, tipNext, tipGoal, level, quests, reset, snacks, stats, wardrobe`, `parked1` (unused, reserved), `done` (section 3).

## 1. The first full Pocket Deck round

When: `stats.rounds == 0`, a field round (not Welcome, `HeatGuided` false), teach on, not `done`. The stepper is live then (`Feel.stepperLive`: no drop yet), and nothing in the round moves until the first drop, so the tour costs the player nothing.

**The tour: three pointers, before the first drop.** TeachPointer on the deck's own cards (`Goals`, `EggsLeft`, `Difficulty` under `PocketDeck`); the other HUD cards go to 60%. The board stays live.

| Step | Lit card | Words |
|---|---|---|
| 1 | Goals | **"Tick these to win!"** |
| 2 | Balls left | **"Your balls. Use them well!"** |
| 3 | Level card (Win pays lit with it) | **"Tap to change level!"** sub pill on Win pays: **"Harder pays more ★"** |

- **Next:** a tap on the lit card, or anywhere on the HUD side; A on gamepad, Enter on keys. Each label carries a tiny "1/3".
- **Skip:** a "Skip" pill (existing `coach.skip`) under the label on every step. B / Backspace does the same.
- **Dropping a ball ends the tour at once**, on any step. They are playing; that is the point.
- All three paths save `deckTour`. No dim layer, no countdown; untouched, it just stays until they act.
- Step 3 is a real lesson too: stepping the level here saves `level`. If they drop without trying it, the round-two opener shows step 3 alone once ("Tap to change level!"), then saves `level` whatever they do.

**Tips during the round** (one at a time, 8 s apart at least, never over the fill-line card, none after the round ends):

| Tip | Shows on | Words | On |
|---|---|---|---|
| `tipNext` | the first drop lands | **"This one's next!"** | Next card |
| `tipChain` | the first chain of ×2 or more | **"Chain! Quick merges score more"** | Chain (or the Goals header when the chain lives there, `g.chainIn`) |
| `tipGoal` | the first goal ticks | **"One down! Tick them all to win"** | that goal row |
| `fillLine` | as built | as built | as built |

**Quests (lesson, `quests`).** Round two's opener, after `level`: pointer on `QuestHandle` (or the `DailyQuests` card on wide): **"Quests pay extra ★"**. Done when the quest log opens, from here or the hub. The pointer never shows mid-round; untouched 12 s it parks as usual.

**Results:** nothing new. The round's Stars and "You're all set!" already land there.

## 2. Lessons added

Order: `dress, reset, deck, [deck tour], menu, quests, park, dash, snacks, stats, wardrobe`. One pointer at a time, same parking rule (12 s, back once next session).

| Id | Triggers after | Lit, exact words | Done when |
|---|---|---|---|
| **reset** (a tip in a lesson's clothes) | Lesson A's wipe ends, pet screen still open | Dress up ringed: **"One more thing!"** It opens on Colour, scrolled to the last card; "Back to white" ringed: **"Change your mind? It's free!"** | Saved when the ringed card has been on screen (`reset`). A tap opens its normal confirm; closing is fine |
| **dash** (built; unblocked by section 0) | Fetch learned, garden free, same session | As built: "Race time! / Try the Garden Dash", the glow walks to the gate, `Fun` tile: **"Go!"**. Add a Things row "Garden Dash: Show me" while undone | A ribbon in `public.dash` (latch `dash`) |
| **snacks** | The Snack gift's reveal (first Dash finish), or any snack in `snackPouch` | The reveal's key reads **"Feed {pet}!"** and opens the pet screen (as lesson A does). `SnacksButton` ringed: **"Snack time!"**; in the tray the snack: **"Feed {pet}!"** | A snack fed (`snackFeed` succeeded: read `petBoosts`, any above 0; latch `snacks`) |
| **stats** | `snacks` done, pet screen open (the same visit if they stay) | `StatsButton` ringed: **"See {pet} grow!"** In the panel, the stat that rose pulses once (no pointer) | Stats panel opened (`stats`) |
| **wardrobe** | `stats` done, next time the pet screen opens | Dress up ringed: **"Dress up!"**, then the Outfit tab: **"Outfits!"** | The Wardrobe opened (`wardrobe`). Never asks for a buy |

Notes:

- **Reset must not make them wash off the gift.** Pots used stay used, so the lesson only shows the door. This is the one lesson not "done by doing"; Spencer decides if that is right.
- Snacks, Stats and Wardrobe never lead the player across the garden: they wait on the pet screen, where those buttons live. The reward is on the pet each time (it eats, a bar grows, the outfit previews).
- If `snackPouch` is empty and the Snack gift is spent, `snacks` waits; `stats` and `wardrobe` then unlock off `dash` so nothing dead-ends.
- The mini game itself: DashHints teach the jump as built. No extra pointers inside a race.

**New words** (UICopy `teach`, then export and sync): `tour1="Tick these to win!"`, `tour2="Your balls. Use them well!"`, `level="Tap to change level!"`, `levelSub="Harder pays more ★"`, `tipNext="This one's next!"`, `tipChain="Chain! Quick merges score more"`, `tipGoal="One down! Tick them all to win"`, `quests="Quests pay extra ★"`, `more="One more thing!"`, `reset="Change your mind? It's free!"`, `snack="Snack time!"`, `feed="Feed {pet}!"`, `stats="See {pet} grow!"`, `outfits="Outfits!"`, `skipAll="Skip the tips"`, `count="{n}/{of}"`. Keys and glyphs: Stats Y, Snacks X, level ▲▼, quest log as bound.

## 3. "Onboarding done", for good

**The rule: a save graduates once, and a graduate never sees a lesson, tour or lesson tip again, in this build or any later one.**

What is stored: `teachMask`. Each lesson's bit is a **latch**: the server sets it the first time its fact is true (`Lessons.done(id)` becomes `latched or fact`). The last bit, **`done`**, is graduation.

`done` is set, server side, the first time any of these is true:

1. **Finished:** every lesson id that this build's `Lessons.Order` lists is latched.
2. **Skipped:** the player picks **"Skip the tips"** (a row in the Menu's Settings, and the long-press of any tour Skip). One confirm: "No more tips? / You can still find everything in the Menu."
3. **Veteran:** at load, a save that is not owed the gift chain (`gifts.owed` false: every save older than the chain). Written once, so the check never runs again.
4. **Moved on:** `stats.rounds >= 12` at load. A player that far in has learned the game; this is a play count, not a clock.

Once `done`: `Lessons.candidates` returns nothing, the deck tour and its tips do not mount, `Chain.may` refuses invites. Gifts, the ribbon, the FREE tile and the Things rows stay (they are presents, not lessons).

**Lessons added in a later update** go to players still in the course only. Graduates meet new features through the existing "New in the garden" line and the New dot. Rule 1 reads the build's own list, so a mid-course player simply gets the new lesson at its place in the order. Never clear `done`, never version it.

`TeachDone` events: add `TeachGraduated` with its reason (finished, skipped, veteran, moved on) so the funnel shows where people leave.

## 4. Priority and files

**Must, next beta:**

1. Section 0 and 3 together: `CoachMarks.lua` or a small `TeachMarks.lua` (the `teachMask` ids), `HatchProgress.lua` (field, latch and graduation in transact, load-time rules 3 and 4), `TeachLessons.lua` (latched `done`, veteran rule out, new ids), `GiftChain.lua` (`may`, the exemption), `Onboard.lua` (`TeachGraduated`), specs `TeachLessons.spec`, `GiftChain.spec`.
2. The deck tour and `level`: new `DeckTour.lua` (pure steps and the controller), `init.client.lua` (mount by the deck, the teach `target` cases), `DeckScreen.lua` (name the goal rows; expose the HUD cards), `TeachPointer.lua` (the "1/3" and Skip pill, a sub pill).
3. Dash unblocked and verified, with its Things row: `ThingsPage.lua`.
4. `reset`: `PaintPanel.lua` (`teachWhite()` returns the card), the teach wiring after the wipe.
5. `UICopy.lua`, export and sync; `V3-TEST-PASS.md` rows.

**Later:** the three deck tips (`CoachCards.lua` pill), `quests` (`QuestLogHost.lua`), `snacks` and `stats` (`PetFocusUI.lua`, `SnackTray.lua`, `StatsPanel.lua`, the Snack reveal's key in `StatEggReveal.lua`), `wardrobe` (`HueEggView` tab row, `WardrobeShop.lua`), "Skip the tips" in Settings.

Captures for my review at 600 x 360 and phone 568 x 320: the three tour steps, the level step on a narrow HUD, the Back to white ring, the Snacks and Stats rings.

**Spencer decides:** reset as show-only (section 2); graduation at 12 rounds (rule 4).
