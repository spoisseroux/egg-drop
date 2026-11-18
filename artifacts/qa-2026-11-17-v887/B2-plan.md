# B2 plan: server lockstep on the round host, minimal client driver (2026-11-17)

Slice B2 of "Option B, revised" (`client-sim-plan.md`). Behind `FeatureFlags.DeckClientSim` (stays
false). Studio-only override: `ServerStorage` attribute `DeckClientSim = true` (read at each round
reset, so a spec turns it on and restarts the round). Flag off and override off: `ClientSimHost.begin`
returns nil, `board.lockstep` is nil, every new branch in `init.server.lua` is skipped. The Welcome
round and non-field rounds always stay on today's path. Rendering is not switched (B3): the owner's
deck keeps drawing the server Parts / snapshot stream, now fed from the authoritative host.

## Modules

| File | Side | What |
|---|---|---|
| `src/shared/BoardLockstep.lua` | both | Protocol constants, `readBatch` (strict shape check, normalized copy), `hash(host)` (round hash with never-consumed queue slots masked), reveal packets, client spec from the start packet. |
| `src/server/ClientSimHost.lua` | server | Per-board lockstep state, the `BoardClientSim` RemoteEvent (mounted only in Studio or with the flag), `begin` (spec, host, mirror, start packet), `receive` (guards, queue), `advance` (step to the input horizon under the clock guards, apply inputs at their ticks, events to hooks, reveals, stall/timeout, mirror), Studio stats. |
| `src/client/ClientRoundDriver.lua` | client | Steps its own host from the start packet, turns taps / items / pause into inputs, sends batches + 10 Hz heartbeats, Studio test bindable (stats, rate, freeze, raw). |
| `src/shared/BoardRoundSim.lua` | both | + `finish(host)` (timeout end; same outcome code as the field end). |

## Protocol (reliable RemoteEvent `Remotes.BoardClientSim`)

- Server to client: `("start", {version, resetId, run, spec = publicSpec minus descriptor.seed, queueLength,
  reveal})`, `("reveal", {resetId, run, from, tiers, stars})`, `("stop", {resetId, run})`.
  Reveal = drop indices `[revealed, drops + 5)` (Next plus 4), topped up after every server step batch.
  The client fills unrevealed slots with tier 1 / no star and refuses a drop (or swap) whose slot is
  not revealed yet (local, never sent). Never the seed or the full queue.
- Client to server: `{resetId, run, tick, inputs = {{n, tick, kind, aim?, item?}...}}`, at once when an
  input is accepted, and every 0.1 s as a heartbeat (`inputs` empty; 1 s after the round end).
- The client sends an input only when its own host accepted it, or refused it with `Full`/`Spawn`
  (those take the drop-interval latch, so the server must see them). Any other refusal restores the
  host's input counters (`lastN`, `inputCount`, `tickInputsAt`, `tickInputs`), so refused taps never
  reach the server, its hash or `MaxInputs`.

## Server guards (refuse and count, never error; a refused batch changes nothing)

Order: message budget 30/s (`Rate`), `readBatch` (`Malformed`, `Size` > 16 inputs, `Order` inside the
batch, `Future` = input tick > batch tick), `Stale` (resetId/run), `Order` (batch tick below the last
report), `Ahead` (batch tick > server tick + 3 s), `Duplicate` (n not above the last queued), `Late`
(input tick below the server tick or the last queued tick), `Busy` (> 64 queued).
Clock: a credit bucket refilled at wall dt x 156 ticks/s x 1.05, capped at 156 (1 s lead). Each server
step costs 1; reports beyond the credit wait (counted `throttled`), so a sped-up client is stepped at
real time and its inputs still land on their ticks (no desync, no faster rewards). Stall: in Board mode,
not paused, not over, no tick progress for 3 s = stalled (counted; like a disconnect: nothing steps).
Timeouts: stalled in `Settling` -> the server drives the settle itself (resumes a paused host with its
own input); no progress for 300 s in Board mode (paused or stalled) -> Settling: server-driven, Playing:
`RoundSim.finish` (outcome from goals met). Room mode never counts (as today, a field waits there).
Steps per board per Heartbeat <= 60; steps only in Board mode and not closing.

## Server integration (`init.server.lua`)

- `reset()`: `board.sim = ClientSim.begin(board, preset, serial, field and descriptor, itemsOn) or Simulation.new(...)`.
  `begin` builds `RoundSim.fieldSpec` (today's seed/bag/heat/items), the host, and a **mirror** shaped like
  `BoardSimulation`'s board (`eggs` with `position` Vector2, `drops`, `queue`, sparse `stars`, `armed`,
  `fallingId`, gate via `contactGate`) so `publishState`, `syncVisuals`, `BoardItems.publish`,
  `BoardNet.publish`, `RunReturn`, `HeatRequest` read it unchanged. After each advance the mirror,
  `board.round` (score, clears, over, danger, graceLeft), `board.field` (phase, stage, progress, outcome),
  merges/chain/peakChain/maxTier/belt/itemSeq/itemKinds are copied from the host.
- Heartbeat: lockstep boards skip the fixed-step loop; once per Heartbeat `ClientSim.advance` runs with
  hooks that are the old loop's consumers: drop (RunDay, firstSession 2 / roundStarted), item used event,
  merge (Progress.recordScore / recordTrials with the running score, firstSession 3, `BoardMerge`
  feedback with Vector2s, grant events), bursts, `BoardNet.stepped` per step, round over.
- Round over: `settleReward` at once when `canProgress`, else the reward is held (`payoutPending` true,
  RewardStatus Saving) and settled on the first Heartbeat with `canProgress`; `closeBoard` settles a held
  reward so `CloseProgress.drain` saves it. The board itself never waits for the save.
- `BoardRequest` `drop` / `item` are refused on a lockstep round (drop acked `ClientSim`); `pause` keeps
  setting `menuPaused`; the Studio round hook refuses lockstep rounds. Recorder skips lockstep rounds.
- Spectators: unchanged path, `syncVisuals` moves the shared Parts at 8 Hz from the mirror.

## Client integration (`init.client.lua`, no new locals)

`clientUI.clientSim = ClientRoundDriver.start()` (pcall). `dropEgg`: when `clientSim.drop(aim)` is not
nil (a lockstep round is live) the tap goes there. `useItem` and `syncPause` likewise.

## Specs

- `scripts/ClientSimLockstep.spec.lua` (Client): override on, after a Studio tidy win (items on):
  real field rounds through the game's driver at lag 0, 0.6 s and jitter 0.1-0.8 s. Asserts: server
  final hash = client final hash, per-60-tick hashes equal, server result = client result, payout
  summary/amount = host result (server checks), server refusals 0 (except echoed Full/Spawn), sent =
  applied. Exploits on a live round: 2x speed for 3 s (server rate <= 1.05x + 1 s, throttled > 0, round
  ends with matching hash), 5 s freeze (stall counted, round resumes, hash matches), raw batches
  (duplicate n, out-of-order tick, future input, 3 s ahead, 40 inputs, wrong resetId/run, garbage, a
  60-message flood) all refused by reason and the round still ends with matching hashes.
- Flag-off regressions: GhostDrops, GhostFlight, DropIntent, BoardSnapshots, BoardSimDeterminism,
  BoardRoundDeterminism (digest `bb0570e589372cea` unchanged), BoardRoundParity.

## Architect review (Software Architect agent): 6 blockers, applied

1. A refused batch lost inputs for good. Now the server acks the last queued `n` (`ack` message), every
   client message carries all unacked inputs (at most 16; a truncated batch reports the tick of the first
   input left out), the server skips `n` it already queued and needs the next one to be `lastN + 1`
   (`Gap`). Refusing any message is now safe for an honest client. The client holds at most 64 unacked.
2. The 1 s credit cap never caught up after a hitch. Now a running allowance: `allow` grows by
   wall dt x 156 x 1.05 while the server's host is not paused, clamped to `reported + 3 s` (the stall
   rule: more than 3 s behind banks nothing, like a disconnect). Steps go to `min(reported, allow + 1 s)`;
   `Ahead` refuses a report beyond `allow + 1 s + 3 s`.
3. Room mode stops the server, not the client: the driver now sends `pause` when the deck leaves Board
   mode (and when a menu pauses), `resume` on return; the server does not gate lockstep steps on mode.
4. A server takeover broke the session: the server now sends `stop` and closes the session first (later
   messages `Stale`), then drives the settle with its own inputs. `RoundSim.finish` (idle timeout in
   Playing) pays 0 (no win, no tidy), so stalling can never win without the overflow risk.
5. Mirror names: values are copied onto the real `Round` (`maxClears`, `graceLeft` = (grace - overflow
   ticks) x FixedStep) and `FieldRun` (`rootStage`, `goalProgress`, `outcome`) objects, and the mirror's
   `serial` follows the host every Heartbeat (`begin` also reads the old host's serial).
6. The hash mask depends on host state only: queue slots after `board.drops` are masked on both sides.
   `begin` asserts `budget <= #queue` and reveals never go past the queue end, so indices never wrap.
Suggestions applied: reveal counts up to 2 queued (not yet stepped) drops; message budget 60 burst, 30/s;
per-merge `Progress.recordScore/recordTrials` run only while `canProgress`, and once more with the round's
final values at settle (both only rise); specs add a 2 s and a 5 s send blackout and a Room round trip.
Known and accepted: a client reporting slower than real time plays in slow motion (pause exists anyway).

## Code review (Code Reviewer agent): 2 blockers, applied

1. The stall flag never cleared: `allow` ran 5% ahead of an honest client, hit the 3 s clamp after
   about 55 s and stayed "stalled", so every Settling phase was taken over at once. A stall is now
   wall time since the reported tick last advanced (3 s, while the host runs).
2. The Welcome branch of `reset()` kept an old lockstep round (frozen Welcome board). It now calls
   `ClientSim.begin(board)`, which stops and clears it.
Also applied: `closeBoard` records the final best score / trials before settling a held reward; a
menu pause times out after 30 min (stalled: 5 min), not 5; `sync` stops after the round end. Found in
Studio before the review: the server's pending queue used `#` over consumed (nil) slots, so inputs
were written behind the head (7 of 15 applied, board stuck); now an explicit head/tail queue.
Found by the speed-up spec: `allow` at 1.05x banked up to 3 s past an honest client, so a cheater could
then burst about 4 s ahead. Now a 1.0x wall estimate (`wall`, running time x 156 while the host runs)
caps it: steps never pass `wall + 1 s`; `allow` regrows at 1.05x only after a stall clamp.
Not fixed (noted for B3): a client whose driver fails to start cannot play a lockstep round (drops are
refused) until the 5 min idle timeout; a hostile client can see 2 more queue slots by queueing drops.

## Results (Studio Play, 2026-11-17)

`scripts/ClientSimLockstep.spec.lua`, override on, after one Studio tidy win (items on), one real field
round per scenario through the game's driver (every 4th tap through the deck's own `dropEgg`):

| Scenario | Final hash (client = server) | 60-tick hashes | Result / payout | Refusals |
|---|---|---|---|---|
| lag 0 | `6918a75b5c282417` | 48/48 | same, payoutMatch, reward 8 | none, 28/28 applied |
| lag 0.6 s | `2fe98ac46e711ce8` | 44/44 | same, payoutMatch, reward 8 | none, 28/28 (344 resends) |
| jitter 0.1-0.8 s | `ba2a79cb41e91f62` | 50/50 | same, payoutMatch, reward 6 | none, 28/28 |
| speed-up 2x 2.6 s | `d50f4be83dd5a20a` | 59/59 | same, payoutMatch | throttled 76 frames, server +586 ticks (client +855), lead over wall 156 = 1 s, overLead 0 |
| stall (freeze 5 s) | `31e1d20c2837c258` | 42/42 | same, payoutMatch | stalled flagged, 1 stall, round resumed |
| blackout 2 s + 5 s, Room trip | `19211d4b693b980e` | 52/52 | same, payoutMatch | none; Room paused the host; 79 throttled frames while catching up |
| raw exploits | `e1e144706eb0eb62` | 52/52 | same, payoutMatch | Order, Future, Ahead, Size, Gap, Late, Stale x2, Malformed x2 each refused; duplicate n skipped (applied +0); 90-message flood: Rate 31 |

Honest rounds: 0 server refusals, 0 rule refusals, 0 throttled frames. Shared Parts present and moving
from the host (spectators). Flag-off regressions (override off): GhostDrops 7, GhostFlight 11, DropIntent
12, BoardSnapshots 13 pass; BoardSimDeterminism `05a4e5ecb8ad2f44` and BoardRoundDeterminism
`bb0570e589372cea` unchanged on Server and Client; BoardRoundParity on 3 new live rounds on today's
path: log on today's sim = live 3/3, host = today's rules 3/3, spec 3/3 (live vs host drift as in B1).

## What B3 needs

Draw the deck from the client's own host (positions, merges, items, score provisional, server values
settle it) and retire own-board ghosts and the owner's snapshot stream on lockstep rounds; impacts and
merge sounds from local events; a fallback to today's path when the driver cannot start (or a server
`hello` resend of `start`); the hash stream and rollback stay B4.

## Out of scope (B3+)

Client rendering from its own host, provisional score, hash stream + rollback (B4), rejoining a live
lockstep round (a reload restarts nothing; the stall/timeout ends it), impact sounds from lockstep rounds.
