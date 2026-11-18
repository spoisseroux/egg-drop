# B4 plan: verify, rollback and rejoin for the client-run board (2026-11-17)

Slice B4 of "Option B, revised" (`client-sim-plan.md`). Still behind `FeatureFlags.DeckClientSim` (false),
`DeckClientSimTesters` (Spencer's accounts, private v922) and the Studio override `ServerStorage.DeckClientSim`.
Flag off: no lockstep round starts, nothing below runs. Goal: a lockstep round that drifts (a phone that does
not match, a bug) corrects itself mid-round with no visible pop; a driver that loses its round mid-round gets
it back; a round that keeps drifting finishes on the server (today's presentation path) with the same rewards.

## Wire additions (`BoardLockstep`, reliable `BoardClientSim`, ordered with reveal / ack / stop)

| Direction | Message | Body |
|---|---|---|
| server -> client | `hash` | `{resetId, run, tick, hash}`: the comparison hash (`L.hash`) right after the step that reached `tick`, `tick % L.HashTicks == 0` (32 ticks = 0.205 s), the latest one per Heartbeat |
| client -> server | batch `want` (new optional key) | the mismatching checkpoint tick: "send me your state" |
| server -> client | `state` | `{resetId, run, tick, hash, n, revealed, join?, data}`: the host at the end of the server's advance (every queued input at `tick` applied), `data` = `L.encodeState` buffer |
| client -> server | `{join = resetId, run = run}` | the driver has no round for the open session (rejoin / late start) |
| server -> client | `start` + `state` with `join = true` | answer to a join |

- `L.encodeState(host, revealed)`: a generic tagged binary encoding of the plain host table (false/true, i32
  for integers, f64 `"<d"` for every other number so every double is bit-exact, interned strings, tables as key
  / value pairs), into a `buffer`. Queue and star slots past `revealed` are masked (`Placeholder` / false),
  so the state never shows more of the queue than the reveals did. Bounded: depth 8, `L.MaxStateBytes`
  (12 KB; a full board is about 3-4 KB); a larger state is never sent (counted, treated as a failure).
- `L.decodeState(buffer)` (pcall on the client). After restore the client checks `L.hash(restored) == hash`
  (an encoding bug is a counted failure, never a silent wrong board).

## Client (`ClientRoundDriver`)

- **Hash ring.** After each live step with `tick % HashTicks == 0`, `ring[tick] = L.hash(host)`; entries older
  than 3 s are dropped. A `hash` packet is compared with `ring[tick]`: equal = verified; missing = skipped;
  different = mismatch (counter), then one `want` request (one in flight, re-asked after 5 s). Checks are
  skipped while a request or a replay is open.
- **Input log.** Every input sent this round (`state.log`, at most `RoundSim.MaxInputs`), kept after its ack
  (an acked input may still be unapplied on the server). `submit` numbers inputs from `state.nextN` (the
  highest n sent), never from the host's `lastN`, so a corrected host can never reuse a sent n.
- **Rollback.** On `state`: decode, check the hash, then a replay job: the restored host applies every logged
  input with `n > restored.lastN` at its tick and steps toward the live tick, at most `L.ReplayStepsPerFrame`
  (48) steps per Heartbeat (the architect's ~470 steps x 32 balls would hitch a phone in one frame). The live
  host keeps stepping and taking taps meanwhile (they land in the log, so the replay applies them too). Ring
  entries the replay passes are rewritten. Done when the replay reaches the live tick with the log consumed
  (or its round ends first): the replay host becomes `state.host`, `final` / `result` are recomputed, the view
  gets `rollback(state, oldHost)`. A replay that cannot advance (paused with no input left) is abandoned
  (counted). Replay steps never play juice; their merges go to the mirror's Studio merge log only.
- **Join.** The server publishes the folder attribute `ClientSimRound = resetId` while a session is open.
  With that equal to `ResetId` and no driver round for it for 1 s, the driver sends `join` (every 2 s at most).
  A `start` with `join = true` builds the round but holds it (`joining`: no steps, no sends, taps refused,
  `Driver.round()` nil) until its `state` restores the host; then the log and unacked list start empty,
  `nextN = lastN`, `hello = true`, and it continues in lockstep.
- **Fallback.** `stop` with reason `Desync`: the round ends locally (as a takeover), the mirror releases and
  the deck draws the server again; taps go to today's path.
- Studio knobs on `EggDropClientSim`: `perturb(dx)` (moves the live host's newest ball by dx studs, once),
  `perturbEvery(dx)` (each Heartbeat: repeated desync), `forget` (drops the round as a reload would).

## Mirror (`ClientBoardMirror`)

- `rollback(state, oldHost)`: for every drawn ball that the new host also has, `prev` = the new position and a
  visual offset = drawn - new, so the swap frame draws exactly what the last frame drew. Each render step the
  offset shrinks by `max(35 %, 0.02 studs)`, never more than `L.MaxCorrection` = 0.5 studs a frame (a 3-stud
  correction eases over about 0.15 s). Balls only in the old host leave, balls only in the new host appear
  (counted as pops: a correction that changes a merge cannot ease). Provisional HUD values read the new host,
  and the change notifications fire as usual. Stats: corrections, largest offset, largest per-frame correction,
  pops.

## Server (`ClientSimHost`)

- Checkpoint hash in the stepping loop (`hb.tick % HashTicks == 0`), the latest sent at the end of `advance`
  while the session is open.
- `want`: counted; the state is sent at the end of the next `advance`, at most one per `L.ResyncSeconds` (1 s),
  at most `L.MaxResyncs` (3) per round. A request past that falls back.
- **Desync fallback (`serverRun`).** The session closes (`stop` "Desync", pending inputs cleared,
  `ClientSimRound` cleared, snapshot stream back on), and the server steps the host in wall time from its tick
  (`runTick += dt x 156`, paused while `board.mode ~= "Board"` or `board.menuPaused`). Today's `drop` and `item`
  requests become host inputs at the server's tick (`Host.serverInput`), acked with today's drop token (ghost
  handoff on the ball's `dropToken`). Same hooks, same settle, same payout as a lockstep round.
- **Join.** Open session, round not over, at most 5 per round, 2 s apart: pending inputs dropped (the client
  that sent them is gone), `lastN = ackedN = host.lastN`, `reported = wall = allow = hb.tick`, timers reset; send
  `start` (with `join = true` and a reveal of every slot revealed so far), the `state`, and an ack.
- **Goal 4.** The owner's `BoardMerge` events on a live lockstep session were only the Studio merge counter:
  now sent only in Studio or while `Host.streaming(board)` (before the hello, after a takeover / fallback,
  where the released round needs them).

## Specs (`scripts/ClientSimRollback.spec.lua`, Client, override on)

1. `desync`: lag 0, mid-round `perturb(1.5)`: recovered (mismatch seen, state restored, replay swapped) within
   0.5 s of the perturb; largest drawn correction per frame <= 0.5 studs; final hash client = server, payout
   match. Also at lag 0.6 s (time reported).
2. `repeated`: `perturbEvery(0.4)`: after 3 resyncs the 4th request falls back (`stop Desync`), the round
   finishes on the server with taps through today's path, payout = the host's result.
3. `rejoin`: `forget` mid-round: join, restore, continue; final hash equal, payout match, joins 1.
4. `soak`: full lockstep rounds at lag 0, 0.6 s, jitter 0.1-0.8 with 1 % and 5 % loss-like spikes (each 0.1 s,
   with that chance, +0.5 s incoming lag for 0.2 s): 0 mismatches, final hash equal, payout match.
5. Regressions: flag off GhostDrops, GhostFlight, DropIntent, BoardSnapshots; BoardSimDeterminism
   `05a4e5ecb8ad2f44`, BoardRoundDeterminism `bb0570e589372cea`; override on ClientSimLockstep (all 7) and
   ClientBoardMirror (lag 0 / 0.6 / jitter).

## Out of scope (B5)

Soak on Spencer's phone and PC, real reloads (a new client session gets a new board today), flipping the flag.

## Architect review (Software Architect agent): 6 blockers, applied

1. A reveal that arrives during a replay went only to the live host: it is now applied to the replay host
   too (a replayed drop would spawn a placeholder tier and desync again).
2. `-0 % 1 == 0` sent -0 down the i32 path (decoded +0, hash differs): -0 is sent as f64.
3. The round end was never compared (checkpoints only every 32 ticks): the server sends a round-end hash
   (`over = true`), and a client whose host ended at a tick the server reached without ending says so
   (`over` in its batch); either way the server's state follows.
4. Join dropped the inputs still queued on the server (and `queuedDrops`): they are kept and sent in the
   join state; the new client logs them and applies them at their ticks (taps wait until they have).
5. The desync fallback cleared acked inputs and never resumed a paused host: pending inputs stay and apply
   at their ticks; server-run pauses follow `board.mode` / `menuPaused`.
6. `readBatch` allowed exactly 4 keys: now `want` and `over` (checked), and `{join, run}` is read before it,
   after the token bucket.
Suggestions applied: a tier change at rollback is a pop (the Part is rebuilt), offsets past 4 studs too;
`want` inside the rate window is deferred (sent when allowed); decode / hash failure = ask again at the next
mismatch; the encoder refuses repeated tables and functions, arrays in index order, 32-ball size checked;
server-run accepts the client's inputs made before it saw the stop.

## Code review (Code Reviewer agent): 1 blocker, applied

1. Server-run accepted lockstep batches forever at the client's tick: a far-future tick held every later
   input back and soft-locked the round (no idle timeout in server-run). Now only within
   `L.LateInputSeconds` (2 s) of the stop and before the first server-run request, ticks clamped to the
   server's tick + 1 s.
Notes applied: the replay never applies inputs into a host that already ended; a round-end hash that arrives
during a replay is checked after the swap; `WantRetrySeconds` 2 (a want refused for Rate); a finished round
never falls back; joins no longer push the idle timeout back; queued server-run drops are acked false at the
round end. Not changed (failure path only): a server-run drop refused by the interval is not held for a
retry as today's `pendingDrop` is, and `board.welcome:input()` is not called (no Welcome lockstep round).
Also added: in Studio every player passes `SimCheck.isOwner`, so `ServerStorage.DeckClientSim = false`
(explicit) now turns lockstep off there for today's-path checks.

## Results (Studio Play, 2026-11-17, after both reviews)

`scripts/ClientSimRollback.spec.lua` (Client; in Studio every round is lockstep, SimCheck.isOwner):

| Scenario | Result |
|---|---|
| desync, lag 0 (`perturb(1.5)` at drop 6) | PASS: mismatch at the next checkpoint, 1 state (1.9 KB), replay 10 steps in 1 frame; perturb to swap 199 ms (183 / 166 ms in earlier runs), mismatch to swap 50 ms; drawn offset 1.50 studs eased at 0.500 studs/frame max over 10 frames, 0 pops; final `83fafa4cc056e3f5` client = server, 47 hashes, payoutMatch, reward 8 |
| desync, lag 0.6 s | PASS: perturb to swap 2634 ms (two round trips: the server's hash out, the request back, then the state), mismatch to swap 1301 ms, replay 205 steps over 5 frames (48 a frame); offset 0.22 eased at 0.077/frame, 3 balls added / 1 removed (the correction changed a merge); final client = server, payoutMatch |
| repeated (`perturbEvery(0.4)`) | PASS: 4 mismatches, 3 states (2 deferred by the 1 s rate), the 4th request fell back (`stop Desync`, `serverRun`); 19 drops through today's BoardRequest became host inputs; round finished on the server, payoutMatch, reward 6 |
| rejoin (`forget` at drop 7) | PASS: joined 1.07 s later (1 s wait + 1 join), continued in lockstep, 86/86 checks matched, final `6dd33d598a439368` client = server, payoutMatch, reward 8 |
| soak lag 0 / 0.6 s / jitter 0.1-0.8, 1 % and 5 % spikes (+0.5 s for 0.2 s) | 7 rounds PASS (incl. a re-run of lag 0 at 5 %): 0 mismatches, 0 rollbacks, 80-91 checks matched per round, final hash and payout equal |

State size: 1.7-1.9 KB in play, 5.2 KB with 32 balls (limit 12 KB); encode/decode round trip hash-exact
(also -0 and 2^40), and a decoded host steps on bit-identical to the original.

Regressions (same build): `ClientSimLockstep` lag 0, 0.6, jitter, speed-up, stall, blackout + Room, raw
exploits all PASS (client = server hashes, payout match, exploits refused by reason); `ClientBoardMirror`
lag 0 / 0.6 / jitter PASS (tap to ball 0 frames, merge delay 0 frames, frame time 16.67 / p99 19.1 ms,
mirror sync 42-43 us, settle and merge diffs 0); GhostDrops 7, GhostFlight 11, DropIntent 12,
BoardSnapshots 13 pass; BoardSimDeterminism `05a4e5ecb8ad2f44` and BoardRoundDeterminism
`bb0570e589372cea` on Server and Client; SimCheck match. Console: no errors.

## What B5 needs

Spencer's phone and PC with the testers build (real cross-device hashes: `mismatches` should stay 0; a
phone that drifts now corrects or falls back instead of diverging). Recovery at lag is two round trips by
design; if that is too slow on a poor link, the client can put its checkpoint hash in its batches so the
server pushes the state after one. Then the soak under real loss and the `FeatureFlags.DeckClientSim` flip.
A real reload makes a new board today (the join path covers a driver that loses its round).
