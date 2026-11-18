# B1 plan: one round reproducible from a tick-stamped input log (2026-11-17)

Slice B1 of "Option B, revised" (`client-sim-plan.md`). Flag stays off: the live game keeps
`BoardSimulation` + `BoardRound` + `FieldRun` + `BoardItems` in `init.server.lua`. The Welcome
round is out of scope (stays on today's path).

## New: `src/shared/BoardRoundSim.lua` (pure, server and client)

A round host around a `BoardSim` board. Plain-data state (no metatables, no closures), so
`snapshot`/`restore` stay deep copies. Everything counted in ticks (1 tick = `FixedStep` = 1/120
sim s; a timer that today sums `FixedStep` into a float uses the tick at which that sum first
reaches the limit, so it matches to the tick; `Pace` 1.3 is only the wall-clock driver's business, never inside the host):

| Today (seconds, os.clock) | Host (ticks) |
|---|---|
| `DropInterval` 0.2 real s | `DropIntervalTicks` = floor(0.2 x 1.3 / FixedStep) = 31 |
| contact gate 0.6 sim s | 72 (BoardSim, unchanged) |
| chain window `<= 1.25` / `expireChain > 1.25` | the same float clocks (`playTime`, `lastMergeTime`), nominally 150 ticks |
| `roundAge >= 1.4` (overflow warm-up) | 169 ticks since the ball's `bornTick` |
| overflow grace (heat: 3.0 / 2.4 / 2.0) | 361 / 289 / 241 |
| field settle 3 s | 361 (same "first tick enters Settling" rule) |

Spec (round start, all data, sent to the client in B2): `{ preset, serial, queue = {tiers}, stars
= {false|itemId per slot}, contactGate, kick, bounce, heat, descriptor (FieldObjectives),
itemsOn, budget, bonusHeight }`. Queue and stars are generated once on the server
(`BoardRoundSim.plan(seed, bag, heat, itemsOn)`, same streams as today) and passed as data;
`BoardSim.new` gains `options.queue`/`options.stars` (data wins over `seed`; B0 hashes unchanged).
`new(spec)` validates the spec and returns `nil, reason` on bad data.

Inputs `{ n, tick, kind, ... }`, `n` strictly increasing, `tick` non-decreasing, applied after
`tick` steps and before step `tick+1`:
- `drop {aim = integer 0..400}`: refused when paused, over, field not Playing / budget spent,
  gate closed, `tick - lastDropTick < 31`, full, spawn blocked (as today the interval latch is
  taken before the spawn check);
- `swap`, `pop`, `arm {item = "bomb"|"magnet"}`: today's `BoardItems.request` rules minus the
  network ones (throttle, resetId, item seq stay in the network layer): items on, round live,
  field not Complete, on the belt, nothing armed, budget room (swap: drops+2; arm: drops+1 and
  Playing). Accepted while paused (as today). Belt, `itemSeq`, `itemKinds` live in the host;
- `pause`, `resume`. While paused the host does not step (a paused board has no ticks, so
  inputs after a pause carry the same tick until `resume`).
`apply` returns `false, reason` (never errors) for: bad shape, `n` not increasing (Duplicate),
`tick ~= host.tick` (Late / Early), unknown kind, rule refusals.

`step(host)` -> events for that tick, or nil when paused/over: merges `{tick, tier, chain,
cleared, x, y, id, firstId, secondId, points, observed}`, bursts, grants (`granted|full`),
`over`. Order is today's Heartbeat order: sim step, overflow rules, per merge (chain, peak,
maxTier, clears, score, field observe, belt grants), bursts, expireChain, field step -> outcome.
`result(host)`: `{ over, overTick, reason, success, reward, tidy, goalsMet, maxHeight, score,
peakChain, clears, drops, merges, maxTier, itemsUsed, itemKinds, heat, templateId }`, the inputs
`settleReward`'s summary and `Nursery.award` need (family, day and boost stay server-side).
`hash(host)`: `BoardSim.encode(board) ..` host bytes (belt, itemSeq, itemKinds, paused, over,
lastDropTick, chain state, score, overflow ticks, field stage/progress/phase/settle, per-ball
bornTick and enteredTray). `replay(spec, inputs, options)`: drives `apply`/`step` to round over
(or `options.endTick`), returns events, result, per-60-tick hashes and refusal reasons; never
asserts on a bad log.

## Recorder (Studio only): `src/server/RoundRecorder.lua`

One guarded local in `init.server.lua` (`RunService:IsStudio()` and the
`ServerStorage` attribute `RoundRecorder`), hooks at: field `reset` (spec from the live
board: queue/stars copied from `board.sim`, descriptor, options), `acceptedDrop` (aim -> grid
index; the harness sends grid aims so quantization is a no-op), accepted `item`, `pause` changes,
each merge (tick, tier, chain, cleared, x, score), round over (outcome + summary fields). Round
tick = `board.simTick - startTick`. `ServerStorage.EggDropRoundRecorder` (BindableFunction):
`take`/`clear`. At most 32 rounds kept.

## Specs

- `scripts/BoardRoundParity.spec.lua` (Server): replays every recorded round through the host and
  compares merges (count, tier sequence, chain sequence), score, peak chain, clears, max tier,
  drops, items used, goals met, success, reward, reason, over tick. Also a run with the recorded
  ticks but the interval check off, and the count of recorded gaps under 31 ticks (wall-clock
  quantization), so the interval rule and the physics are reported separately.
- `scripts/BoardRoundDeterminism.spec.lua` (Server + Client): seeded synthetic rounds (3 heats,
  items, pause/resume) through `replay`, hash every 60 ticks, digest; unit checks: refusals
  (duplicate n, late/early tick, bad aim, bad kind, item not on belt, drop while paused) never
  error; snapshot/restore resumes to the same final hash; optional recorded logs passed in as JSON.
- Driver: Client execute_luau (DeckNetHarness `H.setup`, then a scripted player: grid aims,
  mashing and slow gaps, items when on the belt, pause/resume, heats medium and hard), after one
  Studio "tidy" win so items and stars are on.

## Out of scope (B2+)

Network messages, lockstep, publishing the queue to the client, the nursery-save wait moving to
rewards, the step cap on the client clock, the Welcome round, non-field rounds (save not Ready).

## Architect review (Software Architect agent): 3 blockers, applied

1. Parity cannot separate rule bugs from float32 drift (the live board is still Vector2). Added a
   **rules reference** inside the parity spec: today's `BoardRound`, `FieldRun`,
   `BoardItems.request/grant` and the Heartbeat merge loop (copied), stepped on a `BoardSim`
   board (eggs get a `position` Vector2 before each rule call). The host must match it exactly;
   the live recording is compared too and its differences are reported as drift.
2. The spec carries `starter` (fields use `{}`; `BoardSim.new` would otherwise add
   `Config.Starter`).
3. Untrusted logs are bounded: `replay` needs `maxTicks` (default 120 x 600), at most 512 inputs,
   at most 16 inputs per tick; `n`/`tick` must be finite integers, `kind` a string.

Also applied: `publicSpec(spec)` strips `queue`/`stars` (B2 reveals tiers 4 ahead); `bornTick` =
the host tick before the first step the ball lives through (age after step t+1 is 1; a merge
result is a new ball, so its age and `enteredTray` restart); `lastMergeTick` nil (encoded -1 plus
a flag), chain 0; `overflowY`, grace, `armAfter`, warning margin from `Config.heat(heat)` are in
the spec and the hash (`MaxEggs` is a constant). The recorder copies queue and stars at reset and
converts the old sparse star map to the dense `false` array. `DropIntervalTicks` 31 is one tick
looser than 0.26 s (31.2) on purpose: an integer, never stricter than today. The nursery-save
wait and the step cap move to B2 (client-sim-plan.md updated). `PocketTrials` only ORs in
thresholds on chain, score and clears, which only rise, so the final peak values in `result` are
enough.

## Code review (Code Reviewer agent): 2 blockers, applied

1. Chain window: today compares two running float sums (`playTime - lastMerge <= 1.25`), and at
   an exact 150-tick gap that lands on either side of 1.25 depending on the start tick (the
   reviewer counted 8,275 of the first 72,000 start ticks). The host now keeps the same two
   doubles (`playTime`, `lastMergeTime`, both hashed) and the same comparison, for the chain and
   for `expireChain`; IEEE addition is identical on every side.
2. A pause could lock for good: inputs after a pause share its tick, so 16 refused taps there
   used up the per-tick cap and `resume` was refused forever. `resume` now skips both caps
   (spec: pause, 20 pops, resume -> unpaused).
Also applied: pause/resume after the round end are refused (`RoundOver`); the parity spec checks
`fieldSpec` against every recorded spec; the interval comment says the wall-clock check can be
looser when the server lags; the recorder ignores drops after the round end and holds boards
weakly; the tick table above corrected (289/241/361/169). Noted for B2: `MaxInputs` counts refused
inputs too, so the client should send (or the server should count) only inputs its own host
accepted.

## Results (Studio Play, 2026-11-17)

- Determinism (`BoardRoundDeterminism`, 7 cases): Server and Client give the same 160 hashes,
  digest `bb0570e589372cea`. With the 12 recorded live logs added: 862 hashes, digest
  `9053cdbec6bb8e2d`, identical on both. B0's owner check still matches (`05a4e5ecb8ad2f44`).
- Parity (`BoardRoundParity`), 12 live field rounds (after one Studio tidy win so items and
  stars are on; heats medium/hard/easy, all six templates, mashing and slow taps, item uses and a
  pause with an item inside it; 3 rounds ended by overflow):
  - recorded log replayed on today's `BoardSimulation` with today's rule code = live: **12/12
    exact** (merges with ticks, score, chain, goals, reward, round-over tick, items). The log
    captures the round.
  - host = today's rule code on `BoardSim` physics: **12/12 exact**. No rule divergence.
  - `fieldSpec` = the spec read off the live board: 12/12 (queue, stars, kick, bounce, budget, tidy line).
  - live vs host (float32 Vector2 vs doubles): the merge sequence parts in every round, at merge
    3 to 16 (tick 855 to 3071). Full result equal (score, merges, chain, goals, reward, over tick,
    items) 5/12; outcome (success, reward, goals, reason) 7/12; score 5/12. Two host rounds did not
    end: a drop the live board took was refused (gate or spawn) on the drifted board, so the
    budget was never spent. This is the B0 float32 drift, not a rule difference.
  - Drop interval: no recorded gap under 31 ticks (the 72-tick contact gate binds first); the
    host at 31 ticks refused none of the live drops.

## What B2 needs

The server runs `BoardRoundSim` as the authority (the float32 drift above is why live parity
cannot be exact until then): start-of-round message with `publicSpec` plus the next tiers,
`{n, tick, kind, ...}` input messages fed to `apply`, `step` driven to the client's reported tick
under the clock guards, rewards from `result` through the existing `settleReward`/`Nursery.award`
(family, day, boost server-side), the item throttle and resetId in the network layer, the
nursery-save wait holding rewards only, the step cap on the client clock, and a timeout for a
round that never ends (stuck paused or budget unspent).
