# Egg Drop — proposed overnight nursery loop

Status: proposed work, not shipped functionality. Astra reviewed the external
gameplay response and code at `3b2a109`, then revised the recommendation around
Spencer's request for earned resources, chosen eggs and uncertain pet outcomes.
Assume a 6–8-hour work window. Allowances are planning estimates, not guarantees.

## The player loop

**Aim deliberately → finish a field run → earn nectar → choose and nurture an
egg in Sprout Hollow → reveal a pet → collect or develop its family → play again.**

Nectar and the developing egg separate success on the board from acquisition.
A run advances a chosen project instead of immediately awarding the next pet.
Keep guaranteed starter Pip. Existing creatures retain their ownership.

Prefer an egg project over a separate random prize minigame: otherwise the board
risks becoming a ticket dispenser for a second game. A ticket-to-instant-hatch
system is easier to prototype but gives the nursery and companions little work.
Use a short hands-on hatch ritual and satisfying reveal within the nursery.
Do not imply that a cosmetic timing interaction changes randomly selected odds.

New players enter the welcome board, hatch Pip, receive their one-time nectar,
then visit the nursery. Returning players enter beside their companion and
unfinished egg, with the next field goal visible and one action to open the deck.
An egg persists between visits. Active care advances it; no mandatory real-time
waiting is needed for the first slice.

## Aiming must support the economy

The external review correctly identifies reward overlap: starter-assisted
cascades, strong merge kicks, only 78 aggregate base-pet charge, and easy rare
achievements reward the same accidental merges. A predictable queue and
one-dimensional placement are not inherently unskilled. One creator playtest
does not establish retention benchmarks or disprove the endless genre.

Provisional run rules:

- 24 accepted drops, current piece and two previews.
- Server-seeded shuffled bags of four tier-I and two tier-II pieces. Higher tiers
  remain earned through merging. Seed injection is new work.
- Initially keep the tray dimensions. Compare starter layouts without a free
  center chain. Test physical merge kick 11 versus 6 as an isolated variable.
- Preserve expressive visual squash and wobble while making actual motion
  legible. Avoid touch-speed-dependent launches or hidden fullness modifiers.
- A candidate goal is a tier-III-or-higher merge in a wide illuminated left root
  patch, then one in the right patch. Display the sequence and neutral center.
  Placement should preserve access to matches and channels, not reward arbitrary
  movement of the aiming cursor. Calibrate the zone dimensions with fixtures.
- Successful terminal completion earns 6 nectar; a visible secondary condition
  such as finishing below a pressure line can add 2. These are tuning hypotheses.
- Failed runs award no repeatable consolation nectar. Previously earned nectar,
  pet ownership and egg funding remain. Give a useful failure hint and quick retry.
- After the last accepted drop, disable further drops and allow a fixed
  four-second cascade window, then evaluate exactly once. Overflow ends sooner.
  Resolve existing merges/rewards on the terminal simulation tick consistently.
- Lounge visits pause the board and settlement window. Rejoining restarts an
  unfinished run. No early goal claim, reset payout or reward per button press.

Keep optional endless Free Play, but it must not retain an automatic pet-award
shortcut that bypasses the nursery. Future Free Play rewards require separate
calibration. The overnight economic loop is the bounded field run.

## Egg projects and anticipation

One active egg. Fund it in six-nectar stages, seeing its shell develop in the
world. A completed stage offers a brief companion care action. A player with
enough saved nectar can continue in the same visit; the interaction does not
require leaving and returning between stages.

All costs and odds are **provisional design values**, not playtest results.

| Egg | Total nectar | Possible outcomes |
|---|---:|---|
| Mixed Meadow | 18 | Pip 35%, Puddle 25%, Wick 20%, Orbit 10%, Bloom Pip 5%, Foxfire Wick 3%, Eclipse Orbit 2% |
| Sprout Focused | 24 | Pip 80%, Bloom Pip 20% |

Mixed Meadow is cheaper and offers more families; focused costs more and improves
the chance of the specific Bloom variant. Every existing pet remains obtainable.
A three-outcome pool is suitable for development fixtures, not default rollout.

After seven consecutive non-rare hatches, the next guarantees a rare. The mixed
pool then shows Bloom 50%, Foxfire 30%, Eclipse 20%; focused shows Bloom 100%.
A rare result resets the shared counter. Show the counter and actual current
odds before investment, and lock the recipe/odds for an active egg. A player can
choose which next egg receives the guarantee. This protects rare droughts, not
collection completion: an unowned common such as Orbit is not guaranteed.

State flow:

`NoEgg → Choose/FirstFunding → Growing/Care → Growing/Care → Ready → Revealed`

Focused eggs have an additional funding stage. Define each resource debit and
care transition explicitly so repeated commands cannot skip a stage. A player
cannot cancel to refund and reroll a committed outcome. No egg is lost on exit.

The stake is committing earned resources to a project and pursuing a harder
run for better income. Randomness should not erase an existing pet or destroy
all prior investment. A finished egg always produces its advertised outcome.

## Duplicates, companions and the Hollow

An already-owned hatch gives one family mastery mark. Three duplicate marks
unlock a visible nursery finish. Rare duplicates count toward their base family.
Show the next finish and its progress at the reveal. Mastery is a bounded progress
track, not another wallet. Implement four finishes from one shared ornament with
family-specific colors/details, rather than another creature roster.

Existing 7/7 profiles therefore have a new goal immediately. These finishes are
finite content: the slice tests appetite for another hatch, not long-term content
capacity or retention. More recipes, discoveries and destinations come later.

Build one owner-tagged nursery display per player, with two arrangement sockets
and a visible active egg. Nearby players see the right owner's egg, finish and
companion action. Allocate a bounded number of nursery slots within server
capacity. Reduce the earlier large garden restoration proposal to this area.

| Family | Nursery action |
|---|---|
| Pip | Prepare and plant the cradle; can perform every required care step. |
| Puddle | Water shell growth with a ripple and droplets. |
| Wick | Warm the shell and its surrounding lantern blossoms. |
| Orbit | Lift and turn the egg for care and reveal. |

Use one proximity/target/command/animation framework. Player approaches the
cradle and directs a pet, then sees the world change with a pleasant synth cue.
All required steps work with Pip; other families are alternatives, not mandatory
collection gates. Rares use family actions with distinctive flourishes. Board
physics and scoring never change invisibly when equipping a rare pet.

Pip's complete interaction is mandatory overnight. Puddle is the first visual
extension. Other family animations can follow once the shared system works.
Placeholder poses must be reported honestly in the morning handoff.

## Persistence is part of the feature

The current maximum/OR merge strategy suits earned rank and achievement flags.
It cannot safely handle spending: a stale maximum balance could restore nectar
already consumed. Do not bolt subtraction onto that save path.

Introduce a versioned nursery transaction record with explicit session ownership,
serialized commands, revisions and idempotent operation/run receipts. Define
receipt retention and stale-session rejection. Atomically commit resource
changes, egg stages, the one fixed outcome, inventory grants, mastery and the
rare-miss counter as appropriate. UpdateAsync retries must not roll again.
Reveal retries and reconnects must show the same committed result.

Migration requirements:

- Import legacy rank and earned rare ownership into stable pet-ID inventory.
- Preserve every existing pet, trial, appearance, setting and personal best.
- Convert remaining legacy hatch charge to nectar once at 1:1, with a migration
  marker. Give every profile six welcome nectar once, also marked atomically.
- Stop ongoing automatic post-Pip charge hatches and trial-to-pet grants in the
  new path; otherwise its egg economy is redundant. Existing achievements stay.
- Make inventory the ownership source for UI, journal and equip validation;
  newly earned legacy trial bits must not silently bypass egg acquisition.
- Preserve unknown fields and failed-load protections. Never initialize an empty
  replacement datastore as a migration shortcut. On failed loads, do not promise
  durable nectar spending or permanent hatches.

The server owns seed, budget, goals, payouts, ownership, spending, random outcome
and proximity checks. Clients own presentation and cannot supply trusted outcomes,
quantities or claims. Replicate the result only when it should be revealed.

## Overnight sequence

| Priority / allowance | Deliverable | Gate |
|---|---|---|
| 1 — about 2 hours | Seeded board, spatial goal and reward-rate benchmark | Intentional placement beats spam on held-out seeds, including nectar per minute. |
| 2 — about 3 hours | Transactional nursery record/migration, nectar, two egg recipes, staged care, committed hatch and mastery | Fresh and 7/7 profiles can complete run → fund → pet care → hatch → another project without duplicate payouts. |
| 3 — about 2 hours | Save, state, input and two-client checks; fix critical issues | Retry/rejoin, failure paths, long odds lists, nursery ownership and touch layouts pass. |
| Reserve / stretch | More care animation, family flourishes and calibrated goals | Add only after the whole loop works. |

Use architecture review, implementation, code review, fixes, verification and
checkpoints. Keep a working fallback build. A failed board or save gate remains
the next task; do not hide it beneath additional content. Update the private
build only after the complete slice passes. No public launch is implied.

Exclude Undo, Hold, a separate prize minigame, expeditions, trading, additional
currencies, new creature families, broader housing and physics-engine replacement.
The nursery resource is earned-only for this slice; paid access to random results
is a separate product and compliance decision.

## Tests and morning report

Use the actual Luau simulation with separate calibration and at least 30 held-out
seeds. Compare center-spam, uniform random legal placement and an exposed-state
heuristic, using identical seed, starting layout, cadence, budget and no perks.
Also run minimum-cooldown spam. Record success, overflow, accepted drops, score,
height, elapsed active time, nectar and nectar per minute, including settlement
and actual reset time. Model human decision latency explicitly until phone-tested.

Provisional gates: heuristic objective completion at least 25 percentage points
above center-spam, and modeled deliberate play at least 1.5 times spam's nectar
rate. Failure-only payouts or fast resets can reverse the advantage; measure it.
Neither gate proves human enjoyment or retention.

Exercise final cascades, overflow, invalid drops, pause/resume, rapid reset,
duplicate receipts, simultaneous funding, callback retries, reconnect during
reveal, legacy migration, concurrent writers, failed loads/writes and shutdown.
Test every outcome by controlled fixtures and sample distributions separately.
Check all seven odds rows, changed guarantee odds, full name fitting, reduced
effects, muted sound and two clients seeing each other's correct nursery state.

Morning deliverables: exact completed/deferred list, private version and commit,
benchmark table, save evidence, known issues, a short recorded playable path if
capture is available, and a five-minute fresh-phone script. Test whether a player
can explain aiming, choose an egg, understand its odds and next funding step,
direct the pet, hatch, rejoin and voluntarily start another project.

## Roblox policy boundary

If Robux, purchasable currency/tickets or paid probability modifiers become
connected to these random outcomes, paid-random-item disclosure and player
eligibility requirements apply. Display exact possible outcomes and current odds
even for the earned-only prototype. Adding a paid path later requires a fresh
review, not an assumption that the free path makes everything exempt.
[Roblox paid random items guidelines](https://create.roblox.com/docs/production/monetization/paid-random-items)
