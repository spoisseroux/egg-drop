# Egg Drop — nectar and egg loop

The active prototype now uses field runs and random egg hatches. The physical
nursery and staged care proposal is deferred in `assets/concepts/nursery/` and
`OVERNIGHT-NURSERY-LOOP.md`; it is not included in the runtime Rojo tree.

## What to play

1. A new player starts on the welcome board and earns guaranteed Pip. Existing
   owned pets remain owned. Pip's reveal opens Sprout Hollow.
2. Open the deck for a 24-drop field run. Make a tier-III-or-higher merge in the
   illuminated left bank region, then the right region. Keep the pile low.
3. The next drop becomes ready after the falling jelly first contacts the floor,
   a bank or another jelly, or merges. A 1.8-second simulation-time fallback
   prevents a stuck ready state. The minimum 0.35-second request cadence remains.
4. After the final accepted drop, a four-second settlement window lets cascades
   finish. Completing the route without overflow earns six nectar, plus two for
   finishing below Y=10.5. Failed runs keep prior progress and can retry quickly.
5. Choose **Hatch eggs** on the recap, **EGGS** on the landscape handheld, or
   **Eggs** in the lounge. Spend nectar on one of two egg recipes.
6. Watch the shell swell, crack, split and release its 3D pet with original synth
   cues. The server commits the outcome before the reveal. Closing/reopening or
   reconnecting cannot reroll or charge twice. **Try another run** acknowledges
   the result and returns to play.

Returning players start in the lounge. Leaving for the lounge pauses a current
board; returning resumes it. An unfinished field run restarts on reconnect.

## Rewards and odds

One welcome credit gives six nectar. Remaining legacy hatch charge converts
once at one nectar per charge. Thereafter, ordinary merges do not automatically
grant post-Pip pets or nectar. Completed Pocket Trials remain achievements and
cosmetic progression; they no longer bypass egg ownership.

| Recipe | Cost | Outcomes |
|---|---:|---|
| Mixed Meadow | 18 nectar | Pip 35%, Puddle 25%, Wick 20%, Orbit 10%, Bloom Pip 5%, Foxfire Wick 3%, Eclipse Orbit 2% |
| Sprout Focused | 24 nectar | Pip 80%, Bloom Pip 20% |

After seven consecutive non-rare hatches, the next guarantees a rare. Mixed
Meadow then shows Bloom Pip 50%, Foxfire Wick 30%, Eclipse Orbit 20%; focused
shows Bloom Pip 100%. A rare resets the counter. This does not guarantee a
missing common or a full collection. The UI displays the actual applicable pool.

Duplicate hatches add a family mastery mark, capped at three. At three, that
family's equipped companion has a colored sparkle finish in the lounge. Rare
variants count toward their base family. Reduced effects disables the sparkles.

An optional daily claim gives six nectar once per Hollow day (UTC−5). The
migration day already receives the welcome credit, so it cannot also claim that
day's daily bonus. There is **no daily play/drop limit** and no paid currency,
paid egg, or luck product in this prototype.

## Data and authority

`HatchProgress` uses a versioned `hatching` subrecord inside the existing
`EggDropProgressV1` profile. It preserves legacy fields and snapshots ownership
into an explicit seven-bit inventory. Sparse ownership such as Pip + Orbit does
not grant Puddle or Wick. Equip, journal, counts and Wick's sticker use actual
inventory rather than treating inventory as a contiguous rank.

Nectar debits, random results, inventory/mastery updates and the rare counter are
atomic. The result persists until its specific ID is acknowledged. Session
leases use tokens and epochs; stale writers cannot renew or spend. Operations
have monotonic sequences, and run awards are protected against replay. Both
before-commit failures and ambiguous committed failures retry the same operation
and RNG candidate. Background retry runs every two seconds; lease maintenance
runs every twenty seconds. Failed loads cannot spend or overwrite a profile.

## Verification performed

- Rojo build and Studio Luau compilation of all runtime scripts.
- Thirteen transaction regression cases, including all advertised outcomes,
  rare protection, seven-pet migration, credits, sparse inventory, stale writers,
  daily boundaries, callback retries, pre-commit errors and ambiguous commits.
- Actual-solver held-out comparisons stored in
  `scripts/FieldRunBenchmark-results.json`, including rejected tuning candidates.
  The final setup uses empty field trays, seeded four-I/two-II bags, kick six,
  first-contact readiness, and bank boundaries at X=−3.8/+3.8.
- Thirty fresh seeds: deliberate heuristic 30/30 completions, uniform random
  8/30, minimum-cooldown random 3/30, center-only zero. Nectar rates were
  14.43, 3.85 and 1.38 per active minute respectively.
- Another thirty seeds modeling 2.5-second deliberate decisions yielded a
  1.885× nectar-rate advantage over fast random. These are automated models,
  not evidence that human players find the loop fun or comfortable.
- Real Studio drag-and-release runs earned nectar. At 22 nectar, an actual
  Meadow purchase deducted eighteen and hatched Orbit, leaving four and an
  inventory of Pip + Orbit. Reopening retained its result ID and balance.
  Journal and equip checks kept Puddle locked and correctly selected Orbit.
- All seven 3D hero models rendered; reduced-effects and cleanup checks passed.
  Safe-content fixtures 844×300, 667×285, 568×198 and 390×740 retained 44px
  footer controls and readable names. Seven-row odds lists scroll without
  dropping the footer. A silent rare-reveal visual preview was recorded.

## What still needs validation

Fresh physical-phone comfort, player understanding, voluntary replay, live
DataStore networking, and shared live multiplayer remain separate checks. The
benchmarks are provisional tuning evidence, not retention or revenue claims.
The seven-species pool and capped mastery finishes are finite prototype content.

Five-minute playtest: explain the two bank goals; finish or retry a field run;
read an egg's odds and cost; hatch; select the companion; leave/rejoin; verify
balance, ownership and any pending reveal; decide whether to play another run.
