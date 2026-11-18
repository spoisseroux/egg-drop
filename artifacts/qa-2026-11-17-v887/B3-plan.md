# B3 plan: the owner's deck draws its own round host (2026-11-17)

Slice B3 of "Option B, revised" (`client-sim-plan.md`). Still behind `FeatureFlags.DeckClientSim`
(false) and the Studio override `ServerStorage.DeckClientSim`. Flag off: no lockstep round starts, the
mirror never owns a serial, every new branch below is skipped, today's path is byte-for-byte the same
behaviour. Goal (Spencer: "the pocket deck still feels so laggy", "a pause right before merging"): on a
lockstep round the owner's deck draws the client's own `BoardRoundSim`, so a tap shows its ball the same
frame and merges, impacts, grants and HUD numbers play when the local sim makes them, on any connection.

## Modules

| File | Side | What |
|---|---|---|
| `src/client/ClientBoardMirror.lua` (new) | client | Draws the driver's round: one local, unparented source Part per host ball (`Mirror_<id>`, attributes `Tier`, `EggId` (the real id), `BoardSerial`, `PowerUp`, `ItemMark`), positions interpolated between the last two fixed steps with the driver's render alpha, fed to the deck's own `addView`/`removeView`. Queues the host's step events (merges, impacts, grants, drops) and plays them through the deck's presentation hooks. Serves provisional HUD values (reader, below). Settle and desync counters (Studio stats). RenderStep bound at `First + 1` (after BoardNetClient, before the deck's RenderStepped loop). |
| `src/client/ClientRoundDriver.lua` | client | + `attach(view)` (step hooks: `beforeStep`, `afterStep(events, impacts)`, `input`, `stop`), `round()`, `alpha()` (1 while paused or over), `sentCount()`; a drop / item before the server's hello ack or after the round's end returns `false` (never falls to today's path); the impacts scratch is passed to `RoundSim.step` only with a view. |
| `src/shared/BoardRoundSim.lua` | both | `step(host, impacts?)`: forwards an optional impacts table to `Sim.step` (write-only, outside the hash and the state; B0/B1 digests unchanged). |
| `src/shared/BoardLockstep.lua` | both | `L.HelloSeconds = 5`. |
| `src/server/ClientSimHost.lua` | server | `hello` (first accepted batch, acked with `n = 0`), no-hello fallback, `Host.streaming(board)`. |
| `src/server/init.server.lua` | server | passes a today's-path factory to `begin` (sim + round recorder), skips `BoardNet.publish` while a lockstep session is open and has said hello. |
| `src/client/init.client.lua` | client | No new top-level locals. Merge and impact juice move into `clientUI.playMerge` / `clientUI.playImpacts` (same code, called by today's handlers and by the mirror). Gates: `addView` skips server Parts the mirror hides; the BoardMerge, BoardImpact, ItemEvent (granted/full) and Drops handlers return early on a serial the mirror owns (the mirror played them); the ResetId handler calls `mirror:reattach()`; overlay-name reads go through `clientUI.attr`; the impact plop accepts a mirror Part (it is unparented); `useItem` shows the local refusal note; the Studio tap hook also counts lockstep sends. |

## Drawing

- Each Heartbeat the driver steps the host (B2). Before each step the mirror stores every ball's x, y
  (`prev`); after it, the step's merges and grants and the step's impacts (strongest per ball) are
  queued with the step's wall time and frame number.
- RenderStep (`First + 1`): adopt / release the driver's round; for each host ball make or reuse its Part
  and its view (retry `addView` until the deck accepts its `BoardSerial`), set `Position = prev + (cur -
  prev) * alpha` (alpha = driver accumulator / FixedStep), keep `PowerUp` / `ItemMark` (`magnet` only
  while pulling, as `syncVisuals`); remove views and Parts of balls the host no longer has. Then flush the
  queued events, then the change notifications. So a tap (input runs before render) is drawn the same frame, and a
  merge's blob and sound play in the frame that first draws the merged ball (0 frames).
- Events older than 0.25 s (LateLimit, a hidden or throttled deck) keep the face state and skip the juice
  (as today). Queue capped at 64.
- Server Parts of an owned serial get no view (`addView` gate); they still replicate for other players.
  Ghosts never spawn on lockstep rounds (the tap goes to the driver first, B2), the drop intent is not
  used, and the server stops the owner's snapshot stream while the session is open and has said hello,
  so `BoardNetClient` falls back to replication (no render clock, `schedule` runs at once).

## Presentation (same code as today)

- Merge: `clientUI.playMerge(position, tier, chain, first, second, id, cleared, serial)`: blob, burst,
  score popup (the client's chain), jolt, merge and chain sounds, faces, pet cheer. Today's BoardMerge
  handler calls the same function from its clock schedule.
- Impacts: per frame, the strongest per ball, 0.12 s per-ball cooldown (as the server), to
  `clientUI.playImpacts(batch, serial)` (squash, plop sound, impact ring). Today's handler calls it too.
- Drop: the host's drop count rising plays the drop sound and the drop jolt and notes the hint (the Drops
  attribute handler is skipped for an owned serial, so no double sound).
- Grants: `granted` shows the belt grant and its sound, `full` the full note (the server's ItemEvent
  granted / full are skipped for an owned serial). Local item refusals show the same notes as today.
- Bursts and pops: no juice today (the balls just leave), so none here either.
- Round end: the host's end freezes the drawn board at once; the results (rewards) stay the server's:
  `RoundOver` is not overlaid. Taps after the local end are refused locally.

## Provisional HUD values (reader, after the architect review)

The replicated board folder is never written by the client. `clientUI.attr(name)` returns the mirror's
provisional value for the round's published names while the mirror owns the serial and the server has
not ended the round, else `board:GetAttribute(name)`: `Drops, NextTier, PreviewTier1, PreviewTier2,
NextPowerUp, PreviewPowerUp1, PreviewPowerUp2, ItemBelt, ItemSeq, ItemArmed, Merges, Chain, PeakChain,
MaxClears, Score, FieldPhase, FieldStage, FieldObjective, FieldReady, OverflowPressure,
OverflowGraceLeft` (computed from the host on demand; `FieldObjective` = the server's JSON with
`step/progress/target/complete` from the host, cached; a preview slot not revealed yet reads the
server's value). init.client.lua's reads of these names go through `clientUI.attr` (mechanical), and
`FieldQuestText.read` / `DeckScreen:stepNext` get `clientUI.boardView` (a `GetAttribute` proxy).
Readers keyed on attribute signals are fed by the mirror: after each sync it compares the provisional
values with the last notified ones: score / chain only -> `netScoreKick` (the cheap `setScore` path);
anything else -> `netHudKick`; belt -> `refreshItems`; objective / stage -> `layout`; a drop -> the drop
cue. While owned, the board `AttributeChanged` HUD refresh, the Drops cue and the FieldObjective layout
skip the server's (lagged) writes of these names. `drawAim` / `canPlay` read `FieldReady` through the
reader, so drop readiness is the host's own.
Settle: when the server's `RoundOver` arrives for the owned round, the mirror compares the server's
`Score, Merges, PeakChain, MaxClears, Drops, FieldStage, FieldPhase` with its host (Studio counter
`settle.diffs`) and stops serving provisional values (the results and rewards are the server's; the
drawn board stays the mirror's until the reset). The server's merge events are compared with the local
merge log by result id (tier, chain, cleared, pair) (`mergeDiffs`). Nothing is ever corrected mid-round
(B4 adds the hash stream and rollback).

## Fallback

- No hello: the server marks the session live on the first accepted batch and acks it (`n = 0`); the
  client refuses drops until that ack (a first RTT at most), so a fallback never takes a ball the player
  saw. With no batch after `HelloSeconds` (5 s) and the host still at tick 0 with nothing queued, the
  server closes the session (`stop`, reason `Fallback`), sets `board.sim` from today's factory (same preset, serial and simOptions as
  `reset` would have used) and drops `board.lockstep`, so the round plays on today's path (drops accepted,
  stream on). Covers a driver that cannot build its host, a missing remote handler and a loading client.
- Takeover (B2 stall / idle): `stop`; the mirror releases (mirror views removed first, then the server
  Part views added, so `viewsById` never loses a ball); the stream resumes (session closed).
- No mirror (construction failed, pcall): the driver still plays the round (taps work); the owner draws
  the server Parts at replication rate. Logged; never a board you cannot drop on.

## Verification (Studio, override on)

`scripts/ClientBoardMirror.spec.lua` (Client): after `H.setup()` and a tidy win (items on), real field
rounds through the deck's own `dropEgg` (Studio tap hook) at lag 0, `IncomingReplicationLag` 0.6 and
jitter 0.1-0.8, phone viewport (`H.phone(true)`, 812x354). Per round: tap-to-ball (frames and ms, input
accepted to `addView` of the new ball), merge delay (step to `playMerge`, frames and ms), RenderStepped
frame time (mean, p99, worst) and the mirror's own per-frame cost, client final hash = server final hash,
result and payout match (B2 verdict), settle diffs 0, merge diffs 0, server refusals 0. The same
measurements on today's path (override off, `H.taps`) for frame time and tap-to-ball. Screen captures of
a lockstep round mid-play and at its end to `artifacts/qa-2026-11-17-v887/B3/`. Flag-off regressions:
GhostDrops, GhostFlight, DropIntent, BoardSnapshots, BoardSimDeterminism (`05a4e5ecb8ad2f44`),
BoardRoundDeterminism (`bb0570e589372cea`), ClientSimLockstep (override on, now with the mirror).

## Out of scope (B4/B5)

The hash stream and rollback on mismatch (B4), rejoining a live lockstep round, serving `RoundOver`
and the reward attributes (the results stay server-timed), other players' held decks (unchanged).

## Architect review (Software Architect agent): 7 blockers, applied

1. Writing provisional values onto the replicated folder and writing the server's values back at
   release could strand the next round (deferred signals run the `stop` handler after the same packet's
   new values; a server write equal to the local value fires nothing, so `FieldReady` could stay false).
   Now the folder is never written: readers go through `clientUI.attr` / `clientUI.boardView`, and
   release is simply "stop serving".
2. Readers with side effects fired on the lagged value (`refreshItems` closing the carousel, the
   FieldObjective layout): with the reader they read the provisional value; the layout and HUD refresh
   skip server writes of owned names; the mirror notifies its own changes.
3. The impact plop required `contactSource.Parent`: now a source with a view counts; mirror Parts carry
   `Color` and `Size`.
4. `viewsById` is keyed by ball id, shared by mirror and server Parts: adoption removes server views
   first, release removes every mirror view before adding server views.
5. After the server's round end the drawn board stays the mirror's until the reset (no jump).
6. `boardNet.active()` stays true for `FallbackSeconds` after the stream stops: the BoardMerge gate
   returns before `schedule`, and `updateHud` skips the held-score and round-end clock waits on an
   owned serial.
7. Fallback: the factory also starts the Studio round recorder; drops wait for the hello ack.
Suggestions applied: alpha 1 while paused or over; `prev` maps reused; score / chain changes use the
`setScore` path. Kept: the server's BoardMerge events for the owner (they feed `mergeDiffs`; B5 can drop
them after hello).

## Code review (Code Reviewer agent): 2 blockers, applied

1. The impact plop's new "has a view" test changed today's path (a ball whose Part already left could
   plop): now only a mirror Part skips the `Parent` check.
2. After a takeover the server, behind the client, replays merges and grants the mirror already
   played: the released round keeps its unconfirmed merge pairs and grant count, and the BoardMerge /
   ItemEvent gates skip those.
Notes applied: `FieldReady` ignores a menu pause (as the server's); items also wait for the hello; an
unrevealed preview slot shows the host's placeholder, not the server's older slot; the plan text no
longer claims burst juice.
Found in Studio: one publishState reached the client over two replication batches (RoundOver before
FieldPhase), so the settle waits for the server's Complete phase and compares 0.5 s later; a drop
made before the mirror's first render step lost its cue (the round now starts its count at 0).

## Results (Studio Play, 2026-11-17, phone deck 812x354)

`scripts/ClientBoardMirror.spec.lua`, override on, after a tidy win (items on), one real field round per
lag, every drop but a fresh round's first through the deck's own `dropEgg` (the difficulty picker takes
A until the first drop, so that one goes to the driver):

| Lag | Tap to ball | Merge delay | Frame time (mean / p99 / worst) | Mirror cost | Hash (client = server) | Result / payout | Settle / merge diffs |
|---|---|---|---|---|---|---|---|
| 0 | 0 frames (0.7 ms median, 3.1 max) | 0 frames (0.5 ms), 15 merges | 16.67 / 19.3 / 34.9 ms | 45 us mean | `1da7a64cb952d10a` | same, payoutMatch, reward 8 | 0 / 0 of 15 |
| 0.6 s | 0 frames (0.8 ms, 1.3 max) | 0 frames (0.7 ms), 19 merges | 16.67 / 18.9 / 21.4 ms | 42 us | `8f458056cc0637b4` | same, payoutMatch, reward 8 | 0 / 0 of 19 |
| jitter 0.1-0.8 s | 0 frames (0.9 ms, 1.1 max) | 0 frames (0.7 ms), 16 merges | 16.67 / 19.1 / 20.0 ms | 44 us | `01a653b372c14d70` | same, payoutMatch, reward 8 | 0 / 0 of 16 |

Tap to ball = the driver accepting the tap to the deck's `addView` of its ball (the mirror's frame
counter: the same render step). Merge delay = the fixed step that merged to the merge juice (blob,
sound, jolt, popup): same render step, no late merges. Server refusals 0 (one honest `Stale` heartbeat
across a reset under lag is tolerated), local refusals only the rules' own (Gate, Unrevealed, Budget).

Today's path on the same deck (override off, `S.today`): the ghost ball also shows at once (0.1 ms), but
merges wait for the server's event on the snapshot clock (incoming lag plus a 50-250 ms render delay; no
predicted merges fired in these rounds). Frame time 16.67 / 19.3 / 24.1 (lag 0), 16.67 / 19.7 / 23.3
(0.6 s), 16.67 / 19.2 / 24.0 (jitter): the lockstep path is no worse (Studio is vsync-bound at 60 Hz;
the mirror's own sync costs about 45 us a frame, max 2-3 ms on the frame a round is adopted).

Fallback: with the client's messages held (no hello), the server fell back after 5 s (`takeover
NoHello`, `stop Fallback`), the mirror released, and a server drop and a deck tap (ghost) then played on
today's path. Captures: `B3/lockstep-lag0-midplay.jpg`, `B3/lockstep-lag0-settling.jpg`,
`B3/lockstep-jitter-round-end.jpg` (the Tidy Win results).

Flag-off regressions (override off): GhostDrops 7, GhostFlight 11, DropIntent 12, BoardSnapshots 13
pass; BoardSimDeterminism `05a4e5ecb8ad2f44` and BoardRoundDeterminism `bb0570e589372cea` unchanged on
Server and Client; SimCheck match. `ClientSimLockstep` (override on, now with the mirror drawing):
lag 0, 0.6, jitter, speed-up, stall, blackout + Room, raw exploits all PASS (client = server hashes,
payout match, exploits refused by reason).

## What B4 / B5 need

B4: the server's 0.25 s state hash stream and rollback (restore + replay logged inputs, spread over
frames) so a desync (today only counted: `settle.diffs`, `mergeDiffs`) corrects mid-round with no pop
above 0.5 studs; a rejoin path for a live lockstep round. B5: soak under loss and jitter, Spencer's
phone and PC with the flag on (the mirror's `First + 1` render step on a real phone), drop the owner's
BoardMerge events after hello (only the Studio counter uses them), then flip `FeatureFlags.DeckClientSim`.
