# Retention today (2026-11-25)

Inputs: `CREATOR-HUB-2026-11-25.md` (D1 1.4%, 45% gone by 1:00, 24% still in at 5 min), `DIAGNOSIS-REPO.md`, and the outside review `roblox_suica_collector/HANDOFF-retention-review-2026-11-25.md` (one Studio playtest, no analytics). Both agree: the board and the Bear hatch work; it falls apart right after the Bear.

## Already done
- **Live v1199:** the funnel counts steps in order, new saves only, plus FirstPet / FirstHatch / FiveMinutes. From today the Onboarding funnel shows where players really stop.

## Slice G1 (building now, `growth/v1056`, live line), each behind its own switch
1. Tomorrow strip on every results screen (stamp, 3 quests, Stat Eggs).
2. No garden tour for new players: one line, "Tap {pet} to say hi", up to 12 s.
3. Welcome bonus +12 / +4 / +4 Stars in the first three rounds (cap 20, new saves only), so round two buys an egg, plus the "{egg}: N more Stars" nudge.
4. One name for the pieces: balls.

## Slice G2 (next, same line), from the review
| # | Change | Why |
|---|---|---|
| 1 | **A beam or arrow from the player to the pet** when the garden opens, with hearts and a small instant reward on the first tap; then a nudge back to the deck: "Round two: hatch a toy for {pet}". | The review's drop-off cliff: no direction once the guided part ends. |
| 2 | **Rename the "Hatch your first egg" pill** (`UICopy.pill.firstSpend`). The player has just hatched the Bear, so it reads as a stale goal. Proposed: "Hatch a toy for {pet}". | Reads as a bug. |
| 3 | **A calmer first Deck screen until the first hatch:** hide daily quests, difficulty, the payout line and the controls list; give the board more room on phones. | Dense first 10 s on a phone. |
| 4 | **Delete the stale module copies** at the root of StarterPlayerScripts in the place (StatsPanel, StatsHost, CompanionsHub, PetFocusUI, DeckResultsInPlace, DeckResults, RoomView; nothing requires them; the real ones are under Client). | Place hygiene. |

## Not today (needs Spencer)
- **Feature freeze** (hide Park, Weekly Shelf, second pet for new players until later sessions): a design call.
- **One product name** (Pocket Pals vs Egg Drop vs Pocket Deck in player-facing text) and the store description line: public text.
- **Ads** stay paused until a build shows D1 of 4% or more.
- **Bringing v3's day-2 hooks to live** (Sleepy Nest, need bubbles): after Spencer's beta pass.

## How we will know
Read Creator Hub > Analytics > Funnels (Onboarding) and Engagement (5-minute retention) daily for a week after G1 and G2 ship. With ads paused, new players are few (about 1 to 5 a day), so the numbers will be thin until traffic returns.
