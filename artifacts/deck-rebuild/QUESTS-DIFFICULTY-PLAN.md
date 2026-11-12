# Plan: quest rotation and log, plus Easy / Medium / Hard

Proposed 2026-11-12, against code at `7886356`.

## Facts this plan depends on

- `FieldRun:step` pays 6 for a win, +2 if the stack ends at or below 7.5. `roundOptions()` hard-codes overflow 8.6, grace 2.4 and arming after 12 drops.
- `BoardSimulation.new` uses a fixed bag `{1,1,1,1,2,2}`. `validatePublic` requires exactly 2 goals.
- `settleReward` (in `init.server.lua`) builds the round summary on the server and calls `HatchProgress.award`. `award` accepts only `amount ∈ {0,6,8}`, runs `DailyContracts.apply` in the same fenced transaction, and pays `(amount + contractExtra) * pass + supporter`.
- The day rolls at UTC−5 (`DayOffsetSeconds`). The save is `hatching.version = 8`.
- The 2× pass blurb promises "Double Stars from every round **and daily contract**", so quest claims must be doubled.

## 1. Difficulty

**`BoardConfig.Heat`**

| | easy | medium | hard |
|---|---|---|---|
| `tenths` | 8 | 10 | 15 |
| overflowY / grace / armAfter | 9.6 / 3.0 / 16 | 8.6 / 2.4 / 12 | 7.6 / 2.0 / 10 |
| bag | 1,1,1,1,1,2 | 1,1,1,1,2,2 | 1,1,1,2,2,3 |
| bonusHeight | 8.5 | 7.5 | 6.5 |
| goals | template | template | template + 1 (tier IV or chain 3) |

- Medium must be byte-equal to today's settings, and the benchmark must reproduce today's results.
- **`bonusHeight` must scale with the line.** Otherwise a Hard stack that survives under the 7.6 line almost always earns the +2 for free.

**Flow**
- The client sends `BoardRequest("heat", key)`. The server checks the key, then stores it in `board.nextHeat` and `profile.lastHeat`. A guided first session forces `easy`.
- The server accepts the request only when `round.over` is true or `sim.drops == 0`, and never while `payoutPending`. If `drops == 0`, the server re-runs `reset()`.
- `reset()` copies the stored heat to `board.runHeat` and passes it to `FieldObjectives.create`, `FieldRun.new`/`roundOptions` and `Simulation.new`. **A run's heat is frozen at its first drop.**
- The picker shows the server's `Heat` and `WinPays` attributes.

**Payout. Answer to question 2.** The multiplier goes inside `HatchProgress.award`'s transaction, on the round amount, before the pass:

```
roundStars = (amount * tenths + 5) // 10     -- integer, half-up
total      = roundStars * passMultiplier + supporterBonus
```

- The multiplier covers both the base 6 and the tidy +2.
- Supporter stays a flat +1, as its blurb says.
- Results:

  | | Win / tidy win | With the 2× pass |
  |---|---|---|
  | Easy | 5 / 6 | 10 / 12 |
  | Medium | 6 / 8 | 12 / 16 |
  | Hard | 9 / 12 | 18 / 24 |

  Each gets +1 with Supporter, so the maximum is 25. Easy is never the best grind.
- `summary.heat` is set by the server and validated in `award`. The signature becomes `award:<seq>:<amount>:<heat>`. `lastRunReward` gains `heat` and `roundStars` for the results payout card's multiplier row.
- Contract Stars leave this formula; Supporter never applies to quests.

**Third goal.** `FieldObjectives.create(id, seed, heat)` appends the third goal. `validatePublic` must accept 2 or 3 goals and `step` from 1 to 4. `FieldRun` uses the goal count, and the HUD side panel and the results card each show three rows.

## 2. Quest definitions

`src/shared/QuestCatalog.lua` holds data only:

```lua
{ id="win_2", scope="daily", pool="play", title="Win 2 rounds",
  metric="wins", mode="sum", target=2, heat=nil, reward=4 }
```

- `metric`: `rounds | wins | cleanWins | score | chain | tierMade | goalsMet | heatsPlayed | templates`.
- `mode`: `sum | max | set`, where `set` is a bitmask of heats or templates. `heat` sets the minimum heat.
- Daily: 8 quests per pool (play, craft, skill), each worth 4 Stars.
- Weekly: 12 quests worth 10 each, plus `WeeklyBonus = 5`.
- There is a `CatalogVersion`. Ids are never reused.

`QuestRules.progress(def, prev, summary)` is pure and reads only facts the server measured: the existing summary plus `heat`, `maxTier`, `goalsMet` and `templateId`.

## 3. Save schema (hatching v9)

```lua
quests = { v=1, catalog=CatalogVersion, day="20404", week="2915",
  daily ={ ids={a,b,c}, prog={0,0,0}, claimed=0, rerolled=false },
  weekly={ ids={x,y,z}, prog={0,0,0}, claimed=0, bonus=false },
  weekUsed=0,                                  -- 24-bit mask of daily ids drawn this week
  history={ {d="20404", id="win_2", s=8, a=false} } }  -- ring buffer, at most 30
```

- `upgrade` adds a `version == 8` branch: create `quests`, drop `contracts`, set version to 9. `valid()` checks v9.
- `Quests.sanitize` runs on load and at every roll. It replaces a malformed record, an unknown id or an old catalog with a fresh draw. **Old saves never crash.**
- The record stays under about 1.5 KB.

## 4. Rotation

- **Clock.** `day = Daily.dayOf(now)` is the same clock as the gift. The week starts on Monday: `week = (day + 3) // 7`.
  - The brief says "UTC day", but the game rolls at 05:00 UTC. If midnight UTC is wanted, change `DayOffsetSeconds` once, before the wipe. Never run two clocks.
- **Seed.** `Random.new(((userId % 2147483629) * 31 + day * 7 + pool + salt * 1009) % 2147483647)`, where `salt` is the reroll count.
- **Daily draw.** For each pool, pick from entries that are not in `weekUsed` and not in today's slots, then set their bits. If the pool is exhausted, avoid only today's slots. With 8 per pool, that happens only after a reroll on day 7.
- **Weekly draw.** The same method, seeded by `week`.
- **When it rolls.** The roll happens inside award, claim and reroll transactions. `public()` previews it read-only.
  - Before the roll, a quest that is complete but unclaimed is **auto-credited** and logged with `a=true`.
  - If the stored day or week is later than now (clock rollback), nothing happens.
  - A run counts only toward its own start day and week.

## 5. Progress, claim and reroll

- **Progress** is applied inside `award`'s transaction from the server summary (`drops == 24`). It is atomic with the payout and idempotent through `lastAwardSeq`. There is no client progress remote. `lastRunReward.quests` lists the slots that moved, for the results strip.
- **Claim:** `HatchRequest("questClaim", {scope, slot, period})`, signature `quest:<scope>:<period>:<slot>`.
  - It requires the current period, a complete slot and an unset claimed bit.
  - It pays `reward * passMultiplier` (captured like `boost`), sets the bit and adds a history entry.
  - A repeat returns `true, "AlreadyClaimed"`.
  - `slot=0` claims the weekly bonus once all three weekly slots are claimed.
- **Reroll:** `HatchRequest("questReroll", {slot, day})`, daily only.
  - It requires `not rerolled`, `prog[slot] == 0`, an unclaimed slot and the current day.
  - It redraws with `salt=1` from the same pool and saves `rerolled = true`.

## 6. Contracts and caps. Answer to question 1

**Replace the dailies; don't run both.** Keeping both would pay 22 a day across two overlapping "today" lists.
- `DailyContracts` keeps only `dayOf`. `DeckMenu`'s contract page becomes the log.
- Change the pass blurb to "every round and quest".
- The gift (+6) and the petting cap are unchanged. Round income stays uncapped, as today.
- Net effect:
  - dailies go from 10 to 12 a day (24 with the pass);
  - weekly adds 35 (70 with the pass);
  - Hard raises a win from 6–8 to 9–12.
- Log `Economy.source` sources `"Quest"` and `"RoundReward:<heat>"`.

## 7. API

| Direction | Name | Notes |
|---|---|---|
| C→S | `BoardRequest("heat", key)` | applied at reset |
| C→S | `HatchRequest("questClaim", {...})` | idempotent |
| C→S | `HatchRequest("questReroll", {...})` | 1 a day |
| S→C | `NurserySnapshot.quests` | daily, weekly, history, `resetIn`, `weekResetIn`, `rerollLeft`, `bonusReady`; rewards shown ×pass |
| S→C | `Heat` and `WinPays` attributes; `lastRunReward.heat`, `roundStars` and `quests` | |

Add both quest actions to the allowlist at `init.server.lua:886`, with the same rate limits as the other hatch actions.

## 8. Specs (`scripts/`)

- `HeatPayout`: every heat × tidy × pass × Supporter; Hard > Medium > Easy.
- `FieldObjectives`, `FieldRun`: 3 goals on Hard; validation accepts 2–3; Medium equals today.
- `FieldRunBenchmark`: 6 seeds × 6 templates × 3 heats; Hard winnable.
- `HeatRequest`: ignored after the first drop or while a payout is pending; guided session forces Easy.
- `QuestRotation`, `QuestRules`: determinism, no weekly repeats (with rerolls), fallback, Monday boundary, each metric, late runs, rollback.
- `HatchProgress`: v8→v9, sanitizing, claims pay once (including after an ambiguous retry), pass doubling, reroll guards, auto-credit.
- Client: picker and log focus order, payout rows.

## 9. Commit order

1. `feat(shared): BoardConfig.Heat, HeatPayout` + spec
2. `feat(field): heat-aware objectives, options, bag, third goal` + specs + benchmark
3. `feat(server): heat request, run-stored heat, heat in award` + specs
4. `feat(deck): difficulty picker, HUD heat chip, payout row`
5. `feat(shared): QuestCatalog, QuestRules, QuestRotation` + specs
6. `feat(server): hatching v9 quests, claim/reroll, retire contracts` + specs
7. `feat(deck): quest log, results quest strip`
8. `docs: balance evidence, pass blurb, TODO`

## 10. Risks

- **Inflation.** Medium and quest totals are fixed; Hard (+50%) is the lever, so watch per-heat logs.
- **Mid-run switching.** Heat freezes at the first drop; payout reads only the stored heat. (`RunReturn.retry` template fishing already exists today.)
- **Reroll abuse.** Saved under the lease fence on the server's day; rejoin, server hop or client clock cannot restore it.
- **Timezone edges.** One server clock, start-day attribution, rollback ignored, auto-credit at boundaries.
- **Hard could be unwinnable.** If the solver fails, use the bag `{1,1,1,2,2,2}`.
- **Save size.** Bounded at about 1.5 KB.
- **Schema changes after launch** need a real migration. Section 3 must land before the wipe.

## Answer to question 3: the minimal safe first ship

Commits 1 to 7, with Daily and Weekly working and the History tab as a placeholder, because history is already being saved.
- The **full v9 schema** (weekly, `weekUsed`, history) and the retirement of contracts must ship together before the wipe. UI can follow later; schema cannot.
- If time is short, cut the third Hard goal first: Hard keeps 2 goals plus the lower line and the faster mix.
