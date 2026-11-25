# Live growth cuts on the beta: port decisions (Opus, 2026-11-25)

Spencer: "port the live changes into the beta and publish beta 21". Branch `feat/port-live-growth` from
`feat/egg-drop-arcade-polish` (e8130d85). Live line `growth/v1057` + `hotfix/v1202`, `hotfix/v1203` = live 54dca260 plus:

| Live commit | What | On the beta |
|---|---|---|
| cf9e7ee8 | funnel fix | already there as e9f58bf6 (the beta's original; range-diff: same change, only FeatureFlags context differs) |
| efb72c9b | Hatch another spacing | already there as f1d62577 (the live commit is a backport of it) |
| 9c6ae100 | Bear eye fix | already there as 5492b7f5 (backport of it) |
| 1ef100c1 | reveal resumes on focus | already there as 84379c68 (backport of it) |
| ce5376a0 + c5c1927a | G1: TomorrowStrip, GardenTourCut, StarterBonus + ResultsNudge, "balls" copy | cherry-picked with `-x`, conflicts resolved by hand (below) |
| 8bd460cd | G2: PetTrail, FirstHelloBonus, RoundTwoNudge, ToyPillCopy, CalmFirstDeck | cherry-picked with `-x`, conflicts resolved by hand (below) |

All eight `FeatureFlags` switches are on. Specs, plans and looks: `GROWTH-CUTS-PLAN.md`, `G2-PLAN.md`,
`GROWTH-CUTS-LOOK.md`, `G2-FIRST-SESSION-LOOK.md` (this folder).

## The rule

Where onboarding v3 already has its own version of a moment, **one of the two shows, never both**. While the v3
switch for that moment is on (`Onboard.on(...)`: beta place or Studio, Things to do on, its runtime key), v3 wins;
with it off (`/onboard follow off`, `/onboard needs off`, `/onboard nest off`) the live behaviour applies, so the
beta can show exactly the live first session. Off the beta (any other place) the v3 ceiling is closed and every
live cut runs as on live.

## Per feature

| Feature | v3 equivalent | Decision |
|---|---|---|
| **GardenTourCut** (say-hi rail line instead of the four tour cards) | follow the Bear + the needHi bubble ("Say hi to {pet}.") | **v3 wins while `follow` is on.** The say-hi line now runs only where the tour would (`Cards.stage(base, following) == "garden"`); follow on reads the stage "free", so neither the tour nor the line runs and the bubble says hi. Follow off with `needs` on: still no line (the needHi bubble is the one hello prompt), and `gardenIntro` is saved at that moment instead (BearNeeds saves it only while following). Follow and needs both off: the line, as live. Why: the bubble sits on the Bear and is the v3 first-minute language; two "say hi" prompts at once would compete. |
| **TomorrowStrip** (TOMORROW chips on results + one garden line) | the Sleepy Nest's "Coming up" strip (results) and its egg ticket on the rail | **v3 wins while `nest` is on** (`TomorrowChips.live()`): no live model in the results data, no live row reserved under the panes (PC) or phone block, no Tomorrow rail line. Nest off: the live strip and line, including on the v3 results layout (DeckLook): the PC row under the panes, the phone block in place of the TODAY line. Which strip the panes make room for (`DeckResultsInPlace.stripChoice`) is part of the results view key, chosen when a results screen opens, so a switch flip takes effect on the next results screen, never mid-screen. Why: both strips answer "why come back"; the v3 one carries the nest egg, which is the beta's main come-back hook. The beta never built the plan's "60 s rail showing" of its strip; the egg ticket covers the rail. The Tomorrow line is also now the last line on the rail, after the Things to do lines. |
| **StarterBonus** (+12/+4/+4, saved `starterRounds`) + **ResultsNudge** | none | **On.** The gold "Welcome bonus" row also paints in the v3 payout. |
| **"balls" copy** | none | **On** (no switch, as live). |
| **PetTrail** (paw prints to the pet) | the need bubble sits over the Bear but nothing leads to it when it is off to one side; v3's own prints (ThingsTrail) go to the machine | **On, both ways.** Follow off: with the say-hi line, as live. Need bubbles on (`CoachCards` `options.bubbles` = `Onboard.on("needs")`), follow on or off: raised once as the garden step would have opened, so the prints lead to the Bear while the needHi bubble asks for a hello; they end on that hello (a saved pet, or BearNeeds' own `saidHi`, which a greeting also sets) or as soon as BearNeeds starts its prints to the machine: a hand-off, never two trails at once. Follow on without bubbles: v3's prints go to the machine at once, so no trail to the pet. `finishGarden` from BearNeeds never raises it. |
| **FirstHelloBonus** (+2 on the first paid pet, saved `firstHello`) | none (needHi's hello is the same petting award) | **On.** The needHi tap goes through PetContact, so the bubble's hello pays and shows "First hello! +3 ★". |
| **RoundTwoNudge** (round-two pill) | the needDeck bubble | **v3 wins while the bubbles run for this session** (`needs` on, BearNeeds mounted and alive, not a returning save): no pill. Needs off, or a returning save (bubbles never show for it, e.g. a new player back the next day before round two): the pill, as live. |
| **ToyPillCopy** ("Hatch a toy for {pet}") | none: with `needs` on the pill is already quiet (`FirstSpendGuide` stage "quiet", the needToy bubble) | **On.** Applies whenever the pill shows. |
| **CalmFirstDeck** (Welcome round shows only the board, Next, the egg and the coach card) | none | **On.** Same card names on the beta HUD; `CalmDeck.spec` is Studio-only (not run here). |

## Save fields

`starterRounds` and `firstHello` are optional additive fields on the **hatching save (v11)**, the same as live:
`StarterBonus.valid` / `FirstHello.valid` in `HatchProgress.valid`, malformed values dropped at load
(`sanitize`, never a failed load), written only inside `Hatching.award` / `Hatching.awardPet` transactions
(fenced lease, pending-op resume, `lastAwardSeq` / `lastPetAward` receipt proofs), so a retry, an ambiguous
write, a rejoin or a second server never pays twice. `PlayerProgress` stores the hatching table whole and keeps
unknown keys; the beta's own hatching fields (`nest`, finds, medal eggs) are untouched. Eligibility is the live
rule: a save that never saved a field round (`stats.rounds == 0` and `lastAwardSeq == 0`; first hello also
`lastPetAward == nil`). The beta's `/freshsave` key starts a new save, which is eligible again (owner only).
The only other award caller is `CloseProgress` (the same round on a closing server); Dash prizes, play dates and
the nest pay through their own paths and never touch either field.

## Economy

One-time Stars per save, none multiplied by the 2x pass or Supporter:

| Grant | Stars | When |
|---|---|---|
| Welcome round (beta and live, `Coach.WelcomeStars`) | 14, unchanged | with the Bear |
| StarterBonus (live) | 12 + 4 + 4 = 20, `Cap` 20 | field rounds 1-3 |
| FirstHello (live) | 2 | first paid pet |
| Sleepy Nest welcome week (beta) | 100 face value (+ hat, toy, neck piece, charm) | eggs 1-7, the first one 8 h after it lands |

They do not stack into a hole: each has its own once-per-save field, the first session can hold only the 22 from
the live cuts (no nest egg pays before 8 h), and week one is at most 125 one-time Stars, under the plan's casual
week of about 200. No new cap was needed; `GrowthPort.spec` pins these numbers as a tripwire (change one and the
spec fails until this table is revisited).

## Code notes

- `init.client.lua`: no new top-level locals (the G2 trail is inside `do (function() ... end)() end`; the gates are
  inline `require`s). Every file compiles (`luau-compile`, 524 files), which also checks the 200-register limit.
- `CoachCards`: a coach built without `Cards.new` (older specs) reads every growth switch off (`Cards.NoFlags`).
- Offline runner: `TomorrowChips`, `ResultsNudge`, `GrowthCoach`, `GrowthG2`, `GrowthPort` (client) and
  `StarterBonus`, `FirstHello` (server, with the HatchProgress fixture) join it; the mocks gain `CFrame.fromMatrix`.
- Localization exported (not synced: beta). `ui.onboarding.spend.ready` is now keyed `ui.notice.firstToy.title`
  and `ui.stamp.promise` `ui.notice.tomorrow.next` (same text, one row per text), as on live.

## Studio check, fresh save on the beta (every Play Solo is a fresh save)

Default (all switches on):
1. Welcome round: the calm deck (board, Next, the egg, the coach card; no Score, Chain, quests, Difficulty, Win pays,
   Controls or THEN balls), "Merge" words. Everything is back on the first field round.
2. Garden after the Bear: the first-Stars toast, no tour cards and **no** "Tap Bear to say hi" line; the needHi bubble
   over the Bear and cream paw prints from your feet to him, a ring at him, an edge chip while he is off screen.
3. Pet him: gold "First hello! +3 ★", six hearts, wallet up by 3; the prints fade, the Bear's prints to the egg
   machine start; the needToy bubble.
4. Toy Egg, Give: the needDeck bubble and **no** round-two pill.
5. Round two results: gold "Welcome bonus +12" row, the next-egg line under the Star (Hatch eggs gold when it is
   affordable), the v3 Coming up strip at the foot and **no** TOMORROW row. Rounds three and four: +4 each; five: none.
6. Back in the garden: the nest egg ticket, **no** "Tomorrow: Stamp ..." line.

Mixed: `/onboard follow off` alone: no tour, no say-hi line, the needHi bubble with the paw prints to the Bear.

Live first session on the beta (`/onboard follow off`, `/onboard needs off`, `/onboard nest off` before the Bear;
follow is read once a session, so set it in the Welcome round): the say-hi line with the prints, "Hatch a toy for
Bear" pill, the round-two pill "Round two: ★ 12 Welcome bonus", the TOMORROW row (PC under the panes, phone block in
the Payout pane) and one "Tomorrow:" line after a results screen. `/onboard nest on` again: the next results screen
has the Coming up strip only.

## Code review (Code Reviewer subagent, 2026-11-25): GO WITH CHANGES, all applied

1. The round-two pill was gated on the `needs` switch, not on the bubbles running: a returning new player (back the
   next day before round two) got neither. Now gated on BearNeeds being live and not returning.
2. The strip choice was fixed at `View.new` and the view is reused across screens: a nest flip left an empty gap or no
   strip. Now part of the view key, chosen on open.
3. Follow off with needs on showed the say-hi line and the needHi bubble together. Now the bubble only; the step is
   saved there; the prints run.
4. The trail to the pet ended only on a saved pet; a greeting closes needHi without one, so BearNeeds' prints could
   start beside it. Now it also ends on BearNeeds' `saidHi` or its first trail.
5. A comment moved back onto `Chips.entry`.
