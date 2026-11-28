# Onboarding, shorter: the deck tour, the Goals look, Things to do (Fable, 2026-11-28)

Answers beta (44) notes 5 to 14, 21 and 24. For an Opus build. Switch: Onboard `teach` (no new switch). Supersedes TEACH-MORE-BRIEF sections 1 and 2; its section 3 (latches, `done`) stands.

**The whole course now:** guided first minutes (pet, nest, Welcome deck) → free Paint egg → lesson A (Dress up, Tap Paint) + reset → "Let's try playing a game!" → the deck tour → the deck closes → "You're all set!" → graduated. Everything else is a Things to do row.

## 1. The invite (notes 5, 11)

- When `Lessons.next()=="deck"` and the garden is free, the pet's own bubble (the GiftChain bubble, head only, no sub-line) says **"Let's try playing a game!"** New key `teach.deckInvite`. The TeachPointer ring stays on the dock's Deck button with its "Play!" label. A tap on the bubble or the button opens the deck.
- Nudge and park as any GiftChain bubble (8 s, one hop, 8 s, parked). Parked: the Things row "Pocket Deck: Play" still starts the tour.
- `Chain.next`: no `pull` ("You can hatch one!") while `teach` is on and the save is not graduated. New fact `f.course = live.teach and not graduated`; `pull` needs `not f.course`. It returns after graduation as built.
- Note 13: the 12 s ignore clock (`Lessons.Ignore`) pauses while the window is unfocused, so lesson A is not parked by alt-tabbing.

## 2. The deck tour (notes 6, 8, 9, 10)

**When:** `deckTour` not latched, a field round, 0 drops, no overlay, **and the deck is ready**: `deck.visible` and `deck.boot.playing == false`, held for 0.4 s. New `ctx.ready` in `TeachWiring:round()`; `Tour.opener` requires it. No ring, pill or dim before that.

**Drops are held.** While the tour is active the deck ignores drop and item input (one flag, `deck.tourHold`, read where the drop is sent). So a tap can mean Next everywhere.

**Six steps, one line each.** Label carries "1/6". Steps whose card this layout does not have are left out when the tour starts (the count is the real number), not waited on.

| # | Lit card | Words (key) |
|---|---|---|
| 1 | Goals | **"Do these to win!"** (`tour1`) |
| 2 | EggsLeft | **"Win before they run out!"** (`tour2`) |
| 3 | WinPays, Difficulty lit with it | **"A win pays Stars ★"** (`tourPays`); sub pill on Difficulty, unguided rounds only: **"Harder pays more"** |
| 4 | Score | **"Your high score. Goals win Stars!"** (`tourScore`) |
| 5 | Chain (skipped where the chain sits in the Goals header) | **"Merge fast for a chain!"** (`tourChain`) |
| 6 | QuestHandle (the clipboard) or DailyQuests | **"Tap here for quests ★"** (`tourQuests`) |

- **Next:** a tap anywhere on the deck, Enter or Space, gamepad A or R1. No timer; untouched, it stays.
- **Skip:** the Skip pill, B or L1. It ends the tour and leaves the deck open with the round live (they chose to play).
- **After step 6:** latches `deckTour`, `level`, `quests`; the pointer goes, and 0.5 s later the deck closes by itself through the normal Back path. Then section 4's card.
- `Lessons.done("deck")` becomes `latched.deckTour or rounds >= 1`. The round-two `level` opener and the three round tips (`tipNext`, `tipChain`, `tipGoal`) are removed; the fill-line card stays.

**The dealt round.** It never gets a drop, so it is the "empty board is already a fresh round" case (`init.client` restart path): leaving it is not a round over. No award transaction runs. The implementer proves it in a spec: after tour + auto close, `stats.rounds`, `totalWins`, `starterRounds`, quest progress, `bestScore` and `nectar` are unchanged, and no results screen shows. If the Back path writes anything on an empty board, fix that path rather than adding a special remote.

**What Score does (note 9, from the code).** A win pays by level only: 6 Stars, 8 for a tidy win, times the level (`HeatPayout`). Score sets BEST (`PlayerProgress`), fills the "Score 400/600/800" quests (`QuestCatalog`), and on a lost round with no goal met, 100+ score pays 1 Star (`Payout.Effort`). So: score is the high score, not the pay. That is step 4's line. **Spencer decides** later if score should pay a small bonus; not in this build.

## 3. The look

### Goals card (note 7, shot-75)

Faults: rows are stretched to fill the card (gap up to 26), the hollow check outweighs the words, the text wraps "Green ● on / the left", bar and count repeat the check.

Regular card (244 high):

- Row: check 20 at x 14 → 10 → **target ball 22** (the real ball sprite, as on Next, fixed size) → 8 → text. The ball replaces the colour word and the inline dot: "Green ● on the left" becomes [ball] **"on the left"**; "Make a green or bigger on the left" becomes [ball] **"or bigger, on the left"**. Add these short variants to GoalWords; AccessibleLabel keeps the full sentence.
- Text: BodyMedium 15, line height 19, one line preferred, two at most.
- Row height 34 (one line) or 44 (two). **Gap fixed 12**, with a 1 px divider at 12% white in the middle of each gap. The block of rows is centred between y 40 and 230; never stretched.
- Bar (6 px, 4 under the text, from the text's x) and count only on goals that count above 1. A yes/no goal shows neither.
- Open check: 2 px ring, 55% white. Done: filled green, white tick, text at 60%.

Small deck card (136): check 18, ball 18, text 13, pitch 34 for three goals, 44 for two or fewer, block centred.

### Results goals list (in place)

- Title "GOALS 1/2", 11 caps; first row 8 under it.
- Row: tick disc 16 (green with ✓, or a 1.5 px ring) → 6 → ball 16 → 6 → text 13, line height 17, two lines at most. The second line starts under the text, not under the disc (text is its own label). Row gap 8.
- Metrics 12 under the last row, 11 px soft, two fixed lines: "Score 700 · Best 700" / "Best chain ×4". Score equal to a new best: the first line reads "New best! 700" in Stars gold.

### Results buttons (note 21, shot-76)

`DeckResultsLayout`: the 3 pt lip eats the 4 px gap, so Replay touches the level stepper.

- **8 px of pane showing between a key's lip and the next key**, on all three rows (Gap 8 if the row rect includes the lip, 11 if not).
- Hatch and Leave: 8 px apart. Pad 8 left, right and bottom.
- Stack: 44 + 8 + 36 + 8 + 40 = 136 (was 128); the 8 comes from the goals area. Fallback stack: the same 8.

## 4. Ending sooner (notes 12, 14, 24)

**Lessons that stay** (`Lessons.Order`): `dress`, `reset`, `deck`. `Teach.Course` = `{"deckTour"}`. Remove from Order and Course (bits stay, never renumbered): `menu`, `level`, `quests`, `park`, `dash`, `snacks`, `stats`, `wardrobe`. Their pointers, targets and `TeachWiring` latching go. Gifts, the ribbon and the park and dash bubbles stay as built.

**"You're all set!" moves.** With `teach` on and the chain owed, BearNeeds' `allSet` only latches `needs` and sends its event; it shows no card. The card (AllSetCard, the +5 welcome gift with it) shows once: in the garden, 0.6 s after the tour's auto close, or after a Skip once the player is back in the garden. It sends `done:finished`. Sub-line: **"More to try in Things to do!"** Its button "What's next?" always opens Things to do (no Menu pointer). A save that graduates another way (ignored three sessions, 12 rounds, veteran) gets no card.

**Things to do rows**, in this order. Learn rows carry a check: done ones show a green tick, drop below the undone ones, and keep their button. Remove the Play Den row (`ctx.den`).

| Row | Words / line | Icon | Button does | Ticked when (saved) |
|---|---|---|---|---|
| gift | as built | target | as built | n/a |
| deck | "Pocket Deck" | deck | Play | n/a |
| customize | **"Customize your pet"** / "Paint and shine" | drop | Show me: opens the pet screen, rings Dress up, then the Colour tab | teach `dress` |
| dress | **"Dress up your pet"** / "Try on outfits" | shirt | Show me: pet screen, rings Dress up, then the Outfit tab | teach `wardrobe` |
| quests | **"Finish quests"** / "{done}/{total} today" | quests | Open: the quest log | coach `questDone` |
| book | **"Fill your collection book"** / "{percent}% found" | book | Open: the Collection book | coach `book` |
| style | **"Change your deck style"** / "{owned}/{total} styles" | faceplate | Open: Deck style | coach `style` |
| park, dash, finds | as built | | | n/a |

The Show me ring is one TeachPointer, gone on the tap or after 12 s; it works for graduates (it is asked for, not a lesson). New keys under `things`: the names and lines above, `open="Open"`.

## 5. Priority and files

1. **Invite, tour, order of "done":** `GiftChain.lua` (`course`, the deck bubble), `DeckTour.lua` (six steps, ready gate, hold, auto close, no tips), `TeachWiring.lua` (`ready`, drop the old targets), `TeachLessons.lua` and `TeachMarks.lua` (Order, Course, `deck` done, focus pause), `DeckScreen.lua` (`tourHold`, Score and Chain in `teachDim`), `init.client.lua` (all-set after the tour, `next`), `BearNeeds.lua`, specs (`DeckTour`, `TeachLessons`, `GiftChain`, the untouched-round spec).
2. **Things rows:** `ThingsPage.lua` (rows, tick, sort, Den out), `init.client.lua` (`things.context`, `things.act`).
3. **Look:** `DeckScreen.lua` (`GoalRows`, `placeGoalRows`, `pitchSmallGoals`), `GoalWords`, `DeckResultsInPlace.lua`, `DeckResultsLayout.lua`.
4. `UICopy.lua`, export and sync; `V3-TEST-PASS.md` rows.

Captures for my review, 600 x 360 and phone 568 x 320: each tour step, the Goals card with one-line and two-line goals, the results pane, Things to do with ticked and unticked rows.
