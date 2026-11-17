# Pocket Deck on a laggy phone: network path and plan (v816, 2026-11-16)

Spencer on v816 (d7af00c included): "is it trying to sync with the server or something? It seems like server lag, shouldn't it be async?"

Short answer: yes. The deck draws only what the server replicates, as it arrives, and nothing happens on the client until the server answers a drop. Removing that is an architecture change, so this is the plan. Nothing is implemented yet.

## How it works today

- **The simulation is server-only.** `src/server/BoardSimulation.lua` steps at 1/120 s (x1.3 pace) in the server Heartbeat. `syncVisuals` writes every ball's anchored `Part.Position` (plus Tier/EggId/PowerUp/ItemMark attributes) in `ReplicatedStorage.EggDropBoards.<userId>` every Heartbeat.
- **The client draws replicated positions directly.** The render loop reads `source.Position` each frame. The only smoothing is `JellySprite`'s exponential lerp (34/s), and the LCD repaints at 30 Hz, not in step with replication. There are no timestamps, no buffer and no interpolation between snapshots.
- **A drop is a full round trip.** `dropEgg` sends `BoardRequest("drop", aim)`, and the client shows nothing (no ball, no drop sound, no dispenser kick) until the server's new Part replicates (`ChildAdded`) and the `Drops` attribute changes. Merges show when the `BoardMerge` remote and the replicated part changes arrive. Impacts come through the `BoardImpact` remote.
- **Every client receives every board.** All players' board folders are in ReplicatedStorage, so each phone downloads every player's ball position stream at Heartbeat rate. `HandheldScreens` (the 3D handhelds) samples the other boards at only 8 Hz. On a full server this multiplies traffic. Spencer's private test was probably solo, so it is not the cause there, but it will matter live.
- Minor: on the server, `syncVisuals` rebuilds `live`, `contentIds`, a sort and a concat signature every Heartbeat for every board (GC churn; it does not stall the client directly).

## Measurements (Studio Play, `settings().Network.IncomingReplicationLag`)

Harness: `H.net` in `src/client/ZZSpecs/DeckPerfHarness.lua` (git-excluded). It runs a fresh round, makes 14 drop attempts 0.9 s apart (6 land), and samples on Heartbeat (Studio was unfocused, so rendering was throttled to 15 fps). "Jitter" redraws the lag at random between 150 and 250 ms every 50 to 150 ms. That reorders arrival timing the way a phone on Wi-Fi or LTE does. A **hitch** is a moving ball that gets no new position for 50 ms or more and then jumps.

| Network | Drop input to first visible ball | Moving-ball frames with no new position | Longest freeze | Hitches >= 50 ms |
|---|---|---|---|---|
| 0 ms | 50 ms (median), 51 max | 50.9% (positions land every 2nd frame, about 30 Hz) | 21 ms | 0 |
| 200 ms constant | 450 ms, 466 max | 17.8% | 21 ms | 0 |
| 150-250 ms jitter | 399 ms, 467 max | 22.2% | **249 ms** | **47 per 6-drop round** |

Even at zero lag, the board gets new positions only every other frame and draws them as they come. With jitter, balls freeze for up to a quarter second and then jump (the stutter Spencer sees), and a tap on Drop takes about 0.4 s to show anything.

## Plan

The server stays the only authority for the simulation, merges, scores, goals, items and rewards. Every change below is presentation, except an opaque drop token the server echoes back.

### Phase 1: snapshot interpolation (the stutter)

1. Server: after `syncVisuals`, stamp the board folder with `SimTime` (simulation seconds) in the same Heartbeat, after the positions, so each replication packet carries its own timestamp. Add it to `hudQuietAttributes`. Better still, send the owner one `UnreliableRemoteEvent` snapshot per Heartbeat at 30 Hz (`simTime`, ids, x, y as a buffer) and keep the Parts for membership, tier and attributes.
2. Client: a new `BoardSnapshots` module keeps a short ring buffer per ball and renders at `renderTime = newest simTime - delay`. `delay` adapts to measured arrival spacing and jitter (p95, clamped 60 to 150 ms). Positions between snapshots are interpolated linearly; on starvation the module extrapolates up to 50 ms, then holds. The render clock runs on local `dt` and is eased toward its target (rate 0.95 to 1.05), never snapped.
3. Every event plays on the same clock. `BoardMerge` and `BoardImpact` carry their `simTime` and are queued until `renderTime` reaches them, so the merge blob, jolt, sound and faces fire where the balls visibly are. New and removed parts appear or disappear at their own snapshot time.
4. The LCD and sprite fallback read the interpolated position instead of `source.Position`. `JellySprite`'s lerp stays for the squash only.

Expected: hitches drop from 47 to about 0 per jittered round; the longest freeze falls under 50 ms (the extrapolation cap); motion is even at 0 lag too.

### Phase 2: the drop shows at once (prediction)

1. On input, if the client-side checks pass (`FieldReady`, `DropInterval`, round live, no sheet open), spawn a **predicted ball** at `Config.launchPosition()` with `Config.launchVelocity(aim)`. Advance it with `Config.advanceFlight`, the same shared integration the server uses for the unobstructed flight. Play the drop sound and dispenser kick in the same frame.
2. `BoardRequest("drop", aim, token)`: the server ignores the token for validation (rate, readiness and aim range are checked exactly as today) and writes it onto the new Part (`DropToken`). The client matches its prediction to that Part.
3. Handover: the predicted ball owns the drawing until the authoritative ball's first contact, which is deterministic free flight in sim time, so both agree. Then it blends to the interpolated position over about 120 ms.
4. Refused or lost (no matching Part within RTT + 300 ms, or the board resets): the predicted ball fades out. Rewards and counts never come from it.

Expected: drop input to first visible motion falls from about 400 ms to the next frame at 200 ms lag. Merges still need the server, but under Phase 1 they play in sync with what is shown.

### Phase 3: bandwidth

1. The owner's high-rate board stream goes only to the owner (the Phase 1 unreliable snapshot to that player, or the folder moved under the player's PlayerGui). Other players get an 8 Hz summary for the handhelds.
2. `syncVisuals` reuses its tables and rebuilds the content signature only when the ball set changes.

### Not recommended now: full client-side simulation

Running `BoardSimulation` on the client with server reconciliation would make merges instant as well, but it needs bit-identical determinism across devices, plus the items, Welcome seed and field rules on both sides, and a rollback path. The risk is much higher than Phases 1 and 2.

## Cost and touch points

- Phase 1: about a day. Server `init.server.lua` (stamp or snapshot remote), a new `src/client/BoardSnapshots.lua`, and the render loop, merge, impact, ChildAdded and ChildRemoved paths in `init.client.lua`. The 219 column-0 local budget is already full, so new state goes on `clientUI` or in a new module.
- Phase 2: about a day. `dropEgg`, the dispenser and audio triggers, the server drop handler (token echo), and a predicted-ball view.
- Specs to extend or update: JellyRenderOwner (already stale on tier marks), FieldFeedbackOwner, DeckMergeJolt, JellyOverflow, BoardContentGate, RoundEndPresentation, plus new BoardSnapshots and DropPrediction specs.
- Acceptance: the same `H.net` rounds at 0, 200 and 150 to 250 ms; zero hitches over 50 ms under jitter; one-frame drop feedback; server specs unchanged; no change in rewards or round outcomes.

Waiting for a go-ahead before implementing.

## Architect review (Opus, 2026-11-16)

Read against `src/server/BoardSimulation.lua`, `src/server/init.server.lua` (`syncVisuals`, `acceptedDrop`, the Heartbeat loop, `BoardRequest`/`BoardMerge`/`BoardImpact`), `src/shared/BoardConfig.lua`, `src/client/init.client.lua` (`dropEgg`, `canPlay`, `addView`/`removeView`, the merge and impact handlers, the render loop) and `src/client/HandheldScreens.lua`.

**Verdict: approve the direction, with changes.** Snapshot interpolation plus prediction of only the dropped ball is the right model. Fix the Phase 2 handoff before building it; it does not work as written. Add a server-side drop queue, a proper sim tick and pause signal, and resolve the Part/stream overlap in Phase 1, not Phase 3.

### 1. Interpolation vs client simulation

Keep interpolation. The board is not Roblox physics. It is our own Luau fixed-step solver, so in principle determinism is possible, but:

- It uses `Vector2` (float32), `.Magnitude` and `.Unit` from engine C++ on a Linux x86 server and ARM phones. Nothing guarantees bit-identical results, and a 32-ball pile is chaotic: a 1-ulp difference becomes a different merge within seconds.
- Reconciliation means rollback plus re-simulating about 30 steps (200 ms x 156 steps/s) of a 32-ball O(n^2) solver on every correction, on the weakest phones.
- Most importantly for a tactile merge game: a predicted merge that the server does not confirm has to be visibly undone (blob, sound and score). That is worse than a merge that is 100 ms late. Merges are the reward moment; they must never roll back.
- The client would need items, magnets, bombs, the Welcome seed refresh, field rules and the contact gate, all duplicated.

The one piece that is deterministic and cheap is the dropped ball's free flight (`Config.advanceFlight`). Predict only that.

### 2. Merges, score, juice and sound: confirmed events, played on the render clock

- **Local at tap (never rolled back, never repeated by the server):** drop sound, dispenser kick, aim feedback, the ghost ball.
- **Server-confirmed, scheduled at their tick on the render clock:** merges (blob, jolt, faces, merge and chain sounds, pet cheer), impacts and plops, item events (`ItemEvent` pop, burst, used: these also remove balls, so they need a tick too), and goal and phase changes.
- **The HUD score must follow the render clock too.** Today the `Score` attribute lands about one render delay before the merge it pays for. Show `Score` minus the sum of queued, unplayed merge scores (`Config.mergeScore(tier, chain, cleared)`, which the client already computes for the fx). Do the same for `Chain` and goal progress.
- **Round end:** add `RoundOverTick`. The round-end presentation waits until the render clock passes it, so the last merge plays before the recap.
- **Late reliable events** (loss forces a retransmit and the event arrives after its tick was rendered): play on arrival if under about 250 ms late, otherwise drop the juice but keep the state. The pixels are already right from the snapshots.
- **The ghost plays no contact sounds.** The landing plop comes from the server impact at handoff. Otherwise one landing sounds twice.

### 3. The optimistic drop handoff is not safe as written

**The timing flaw.** The plan hands over "at the authoritative ball's first contact ... so both agree". They agree on the path, not on the time. The ghost starts at tap; the authoritative ball, seen through interpolation, starts about RTT/2 + one-way lag + render delay later (about 300-450 ms at 200 ms lag). Free flight from `SpawnY` 17.8 to a mid-height pile is about 0.53 sim-s, or 0.41 real seconds at Pace 1.3, and shorter on a full board. So the ghost **always reaches the pile before the server ball is even visible.** The ghost has no collision, so it would fly through the stack.

**The fix.** The ghost runs on local present time. It collides only against the balls as currently drawn and the tray (circle tests, no impulses). On first contact it stops and rests with a small squash. When the bound authoritative ball reaches the same contact on the render clock, the ghost blends to it (about 120 ms) and hides. Expect a ghost resting next to a same-tier ball to wait up to about RTT before the merge plays. That is acceptable, and it is honest.

**Reject.** Today a refused drop is silent (`acceptedDrop` returns false). Add a reliable `BoardDropAck(token, ok, eggId, tick, reason)` instead of only `DropToken` on the Part:
- `ok`: binds the ghost to `eggId` and to the spawn tick.
- `not ok`: fades the ghost at once with a soft "bonk".
- Keep the RTT + 300 ms timeout only as a backstop.
- Sanitize the token on the server: a number, an integer, 0 to 65535. It is never used for validation.

**Double tap and jitter: the real risk.** The server checks `DropInterval` (0.2 s) and the contact gate against *arrival* time. With 150-250 ms jitter, two taps 0.25 s apart can arrive 0.15 s apart, and the second is refused. `FieldReady` on the client is also up to RTT stale, so a second tap during the gate gets a ghost the server will refuse. Prediction turns these silent refusals into visible fizzles. Two required changes:
- **Server:** a 1-deep drop queue. A drop that fails only on the interval or the contact gate is held for up to about 150 ms real time and applied when it opens; anything else is refused. The rate stays bounded (queue depth 1, the same interval).
- **Client:** its own `DropInterval` throttle (`dropEgg` has none today). Latch "not ready" after a predicted drop until the ack arrives and a *newer* `FieldReady` follows. With the contact gate on, open the latch on the ghost's local contact or after `ContactGateSeconds / Pace`.

**Reconnect, reset and pause.** Roblox has no in-place reconnect; a rejoin is a new client, so ghosts die with it. Inside a session, kill every ghost on a `ResetId` change, on `RoundOver`, on a mode change, when the menu or a sheet opens, and on any rejected ack. Never spawn a ghost for the server's Welcome demo drop (it has no token). The ghost should show the next tier, star (`powerUpAt`) and armed Bomb or Magnet mark from the replicated attributes; if unsure, draw it plain.

**A cheaper first step (2a).** Play the drop sound and dispenser kick at tap, with no ghost, and add the ack and the server queue. That delivers most of the "it responded" feel for about a quarter of the cost. The ghost flight is 2b.

### 4. Per-owner replication

**Others' boards are used.** `HandheldScreens` draws every tagged `EggDropHandheld` (each player's held `PocketDeck`, `BoardUserId`) within 34 studs, sampled at 8 Hz, wherever the avatar stands. Moving the folder under `PlayerGui` would blank other players' handhelds. Nothing else reads other boards: `trays` is used only in `init.client.lua` (own board) and `HandheldScreens`.

**Recommended:**
- The owner gets the unreliable snapshot stream (`UnreliableRemoteEvent:FireClient(owner, ...)`).
- The Parts stay in `ReplicatedStorage.EggDropBoards` for membership, attributes and spectators, but **`Part.Position` is written at most 8 Hz, plus once when a ball is created** (HandheldScreens samples at 8 Hz anyway).
- This must ship *with* the switch to snapshots. If Parts keep replicating at 30 Hz alongside the stream, every client gets double traffic and nothing is saved, so it belongs in Phase 1, not Phase 3.
- The ~40 board attributes still go to everyone. Leave them for now; moving them is a large refactor with little payoff.

**Membership across two channels.** Parts are reliable and the stream is unreliable, so either can arrive first:
- Key views by `EggId`.
- Create a view only when both the Part and a sample at or before the render tick exist.
- On `ChildRemoved`, keep the view detached until the render clock passes that ball's last sample, so balls vanish at their own tick, not on arrival.
- Flush everything on a new `ResetId`.

### 5. Format, rate, delta and server cost

**The sim clock.** Use an integer `simTick` per board, incremented per `FixedStep` and never reset across rounds, not float `playTime` (which resets per round). Stamp every snapshot, merge, impact batch, `ItemEvent` and ack with it. Steps run at 120 x 1.3 = 156 ticks/s.

**Pause.** The server stops stepping a board when the menu is paused, the round is over or the board is not ready. Keep sending snapshots at a low rate (4 Hz) with the same tick and a `paused` flag. The client freezes the render clock when packets arrive but the tick is still. Otherwise the 50 ms extrapolation runs on and snaps back.

**Format.** One `buffer` per send:
- Header: `u16 resetId`, `u32 tick`, `u8 flags`, `u8 count`.
- Per ball: `u16 id`, `i16 x`, `i16 y`, quantized at 1/1000 stud (range +/-32.7, the board is 11 x 19).
- That is 6 bytes per ball: at most 8 + 32 x 6 = 200 bytes, well under the 900-byte unreliable limit.

**Rate and bandwidth.** 30 Hz (every other Heartbeat; that is the effective rate today). At worst about 6 KB/s for the owner only, and about 0 for other clients beyond 8 Hz Parts.

**Delta compression.** Do not delta-encode against unreliable packets. If you want savings, omit resting balls (no movement for 3 consecutive sends) and send a full keyframe every 0.25 s. The client treats "absent" as "unchanged" and drops an id only when a keyframe or `ChildRemoved` says so. That is optional; 200 bytes is fine.

**Ordering.** Discard any snapshot older than the newest tick seen (unreliable packets can arrive out of order and duplicated).

**The render clock.** Estimate the server-tick-to-local-time offset as the minimum `(arrival - tick/156)` over a 2 s window, not "newest minus delay", which jumps with every packet. Set the delay to the p95 arrival jitter, clamped to 50-200 ms; at 150 ms the measured jitter can still starve the buffer. Ease the rate between 0.95 and 1.05, **but re-sync hard when the error is over 250 ms** (a 1 s spike would otherwise take 20 s to absorb at 1.05).

**Server `syncVisuals`** allocates `live`, `contentIds`, a sort and a concat per board per Heartbeat. To fix:
- Have `BoardSimulation` bump `board.membershipVersion` in `addEgg` and every `table.remove`.
- Rebuild the id list and the `BoardContent` signature only when it changes.
- Reuse a scratch table for `live`.
- Write `BoardSerial`, `PowerUp` and `ItemMark` only on change (already done).

The snapshot encode reuses one `buffer` per board. Profile with `debug.profilebegin` and 8 boards.

### 6. Missing from the test plan

- **Check that `IncomingReplicationLag` delays `UnreliableRemoteEvent` and `RemoteEvent` traffic as it delays replication.** If it does not, the harness will report false wins. Measure the arrival delay of a stamped event once before trusting any number.
- **A pure `BoardSnapshots` spec with synthetic arrival schedules:** constant lag, jitter, reorder, duplicates, 5/15/30% loss, a 1 s spike then a burst, a pause (same tick), a `ResetId` change mid-buffer, and a stream that starts before the Parts arrive. Assert monotonic render ticks, the largest per-frame position step, hitch count, and no backwards motion.
- **Packet loss in Studio.** There is no loss knob, so add a Studio-only drop-rate hook in the client receiver (and a delay hook for reliable events) for `H.net`.
- **Prediction specs:**
  - accept
  - reject (ack and timeout)
  - double tap at 0.21 and 0.25 s under jitter (must land, not fizzle, with the server queue)
  - tap during the contact gate
  - tap at round end
  - the Welcome demo drop (no ghost)
  - an armed Bomb or Magnet
  - star balls
  - `MaxEggs`
  - a ball resting near the spawn (refused spawn overlap)
  - a ghost resting against a same-tier ball (no merge until the server's)
- **One sound per event:** count `audio:play` calls per drop and per merge across a jittered round. No duplicate land, merge or chain sounds.
- **Low-end CPU:** run `H.net` with Studio's FPS cap at 30 and 20, plus injected 100 ms frame spikes. Render dt jumps must not break the clock or the ghost. MicroProfiler on Spencer's phone for the deck render loop before and after.
- **Bandwidth:** `Stats.DataReceiveKbps` with a 4-client local server, before and after, on a non-owner client and the owner.
- **Server cost:** Heartbeat time with 8 boards, before and after.
- **A real phone on LTE** with a debug overlay (hitches, buffer depth, delay, rejects). Studio lag is not phone radio jitter.
- **Unchanged:** server specs, rewards and round outcomes (already listed).

### 7. Slices, in shipping order

Each slice sits behind a `FeatureFlags.DeckNet*` flag and falls back to today's path.

1. **S0, instrumentation, no behaviour change.**
   - Server: `simTick`; stamp the tick on `BoardMerge`, `BoardImpact`, `ItemEvent` and `RoundOverTick`.
   - Client: a hitch and latency overlay in the harness.
   - Check how the lag setting covers remotes.
2. **S1, the stream in shadow mode.**
   - Server: the 30 Hz owner snapshot.
   - Client: `BoardSnapshots` consumes it and reports the hitches it *would* have, while still drawing Parts.
   - Proves the clock on a real phone with no visual risk.
3. **S2, draw from snapshots.**
   - Interpolated positions in the render loop, the LCD and the faces.
   - Events, HUD score and round end on the render clock.
   - In the same slice, throttle `Part.Position` to 8 Hz.
   - Fall back to Part positions if no snapshot for 1 s.
4. **S3, `syncVisuals` cleanup.** The membership version, reused tables (server only, small).
5. **S4, drop ack and server drop queue.**
   - Server: the ack remote and the 1-deep queue.
   - Client: its own throttle and the not-ready latch.
   - Plus 2a: the sound and dispenser kick at tap.
   - Fewer silent refusals, an instant response.
6. **S5, the ghost ball.** Local-present flight, stop on contact against drawn balls, ack binding, blend at the render-tick contact, fade on refusal.

S0-S2 fix the stutter Spencer reported. S4 fixes most of the "nothing happens when I tap". S5 is polish and the highest risk, so it ships last and can slip without blocking the rest.

## Build log

### S0-S2, code only (2026-11-16, Studio not yet available)

All of it is behind `FeatureFlags.DeckNetTicks` (on: stamps only), `DeckNetStream` (off) and `DeckNetRender` (off).

- **S0, ticks.**
  - `src/server/BoardNet.lua`: `board.simTick`, one per fixed step, never reset across rounds.
  - `BoardMerge` gains a 9th argument (the tick) and `BoardImpact` a 3rd; `ItemEvent` JSON gains `tick`; `RoundOverTick` is set with `RoundOver`.
  - Old clients ignore the extra arguments.
  - Studio-only echo remotes: `DeckNetEcho` and `DeckNetEchoUnreliable`.
  - `scripts/DeckNetHarness.lua`: `H.echo(lag)` checks whether `IncomingReplicationLag` delays remotes. `H.net(...)` reports drop latency, Part hitches and the stream stats, with loss and delay hooks.
- **S1, shadow stream.**
  - `src/shared/BoardSnapshotCodec.lua`: the buffer format of section 5.
  - Server `BoardNet.publish`: 30 Hz to the owner only, 4 Hz with the paused flag, only in Board mode.
  - `src/client/BoardSnapshots.lua`: pure. It holds the ring buffer, the min-offset clock, the p95 delay, ease plus hard re-sync, the pause freeze, a 50 ms extrapolation cap and removal at the ball's own tick.
  - `src/client/BoardNetClient.lua`: receiver with the Studio loss and delay hooks (`PlayerGui` attributes `DeckNetLoss` and `DeckNetDelay`). It runs the clock and keeps shadow stats (stream max step, today's Part hitches), published to the `PlayerGui` attribute `DeckNetStats` in Studio.
  - It is started by a separate LocalScript, `src/client/DeckNet.client.lua`, so `init.client.lua` stays untouched.
- **S2a, draw from snapshots.**
  - With `DeckNetRender`, `BoardNetClient` binds a render step at `RenderPriority.First`. It moves this board's Parts locally to their interpolated position before the deck's render loop, so the LCD, sprites, faces and match hints all draw the clock's positions without any change to the renderer.
  - No packet for 1 s: it stops writing and the Parts fall back to replication.
  - Server `syncVisuals` writes `Part.Position` at most 8 Hz plus at creation (the 8 Hz window opens per Heartbeat).
- **Specs.**
  - `scripts/BoardSnapshots.spec.lua` runs in Studio as `(client, gui)` and offline with `build/luau-cli/luau.exe scripts/run_pure_spec.luau`. It passes all 12 cases: the codec; constant lag; 150-250 ms jitter with reorder and duplicates; 5, 15 and 30% loss; a 1 s spike then a burst; a pause; a ResetId change mid-buffer; early and gone balls; a stream with no Parts.
  - A control case proves the hitch metric catches today's draw-as-it-lands path (5 or more hitches on the same schedule).

**S2b, still to wire (needs `init.client.lua`, which has another agent's uncommitted edits).** `BoardNetClient` already provides `schedule(tick, fn, fields)`, `pending(key)`, `flush()`, `renderTick()` and `active()`. Wiring, with no new column-0 locals (`clientUI.boardNet`):

1. The merge handler: wrap its body in `clientUI.boardNet.schedule(tick, function(late) ... end, {score=Config.mergeScore(tier,chain,cleared)})`. With `late > LateLimit`, skip the audio and fx but keep `ballFaces:merged`.
2. The impact handler: schedule by its tick, and drop it if late.
3. `ItemEvent`: schedule by `event.tick`.
4. `updateHud`: show `score - clientUI.boardNet.pending("score")`; do the same for chain.
5. `RoundOver` / recap: open `recap:show` once `renderTick() >= RoundOverTick`; poll in the render loop while waiting.
6. `addView` and `removeView`: create on `ChildAdded` only once `sample(id)` is not `"early"`. On `ChildRemoved`, keep the view drawn until the clock passes the ball's removal tick, then destroy it.

Until S2b, S2a draws positions about one render delay (50-200 ms) behind the merge, impact and removal moments, which still arrive on receipt. That is why `DeckNetRender` stays off until S2b is wired and measured.

**Studio checks before turning the flags on.**
- Whether `BindToRenderStep` at `First` runs before the deck's `RenderStepped:Connect` loop. If it does not, move the position write to `RunService.PreRender` with an earlier connection, or to the end of `Heartbeat`.
- Whether the lag setting covers remotes (`H.echo`).
- The before/after `H.net` numbers with lag, jitter and loss.

### S2b, S3 and S4, measured in Studio (2026-11-16, place v823 and later)

**The lag setting covers remotes.** `H.echo`: the RemoteEvent round trip is 49 ms at 0 lag and 451 ms at 200 ms; the UnreliableRemoteEvent is 49 ms and 448 ms. `IncomingReplicationLag` delays both, in both directions, so the remote numbers below are real.

**What changed.**
- **S2b** (`init.client.lua`, still 219 column-0 locals):
  - Merges, impacts and power-up grants are scheduled on the render clock with `BoardNetClient.schedule`. An event more than 250 ms late keeps its face state but skips the juice.
  - The HUD score holds back queued merges (`pending("score")`), and chain follows the last merge shown.
  - The recap waits for `RoundOverTick`.
  - Ball views appear at the clock's first sample (`afterSpawn`) and leave at its last (`afterRemoval`, with the Part still driven).
  - Clock fixes from the measurement:
    - The delay is now the worst jitter in the window plus 1.25 send intervals, with a small feedback margin that grows only while starved. A jitter-only delay starved 21% of frames at 0 lag: the clock ran past the data between 30 Hz packets.
    - `DelayMax` is 0.25 s.
- **S3**: `syncVisuals` reuses its `live` set and rebuilds the content list, sort and signature only when a ball joins or leaves (or the run changes).
- **S4**:
  - New `BoardDropAck(token, ok, eggId, tick, reason)`, and a one-deep server queue (150 ms) for drops refused only by the interval or the contact gate. `reset` clears it.
  - `DropIntent` on the client: its own 0.2 s throttle, a not-ready latch (cleared by the ack plus FieldReady, or after 1.5 s), and the drop sound and dispenser kick at the tap. The Drops attribute no longer replays the tap's sound, and a refusal plays the soft "aim" note and resets the dispenser.
  - The Welcome demo drop has no token and is unchanged.
- **Flags on by default**: `DeckNetTicks`, `DeckNetStream`, `DeckNetRender` and `DeckNetDrop`. `DeckNetGhost` (S5) is not built and stays off.

**Measurements.** `H.draw`, 14 drop attempts per round. The draw is read at `RenderPriority.Last`, after the driver at `First`; both run before the deck's RenderStepped loop (order checked in Studio).
- A **freeze snap** is a moving ball that freezes for 50 ms or more and then jumps more than 0.08 stud: a late update caught up.
- Hitches over 50 ms also include balls at rest being pushed again (the physics floor).
- Off = `DeckNetRender` off with the stream on, which is today's 30 Hz Parts.
- The fps rows burn CPU per frame (Studio has no fps cap through MCP); the runs measured about 36 and 21 fps.

| Network, client | Off: snaps / hitches / longest freeze | On: snaps / hitches / longest freeze |
|---|---|---|
| 0 ms | 0 / 3 / 150 ms | 0 / 0 / 50 ms |
| 200 ms | 0 / 5 / 234 ms | 1 / 1 / 100 ms |
| 150-250 ms jitter | 10-11 / 27-31 / 316-399 ms | 2 / 3 / 183 ms |
| jitter + 15% stream loss | (no loss knob for replication) | 1 / 8 / 166 ms |
| jitter, about 36 fps | 26 / 46 / 369 ms | 0 / 9 / 274 ms |
| jitter, about 21 fps | 10 / 21 / 257 ms | 0 / 1 / 216 ms |

**Drop response.**
- The sound and dispenser kick now play in the tap's own frame (0 ms, built into the tap handler, not measured; the harness cannot press the game's own button).
- The ball still appears after the round trip: 230-450 ms at 200 ms lag and with jitter (S5 is the ghost ball).

**Server drop queue under jitter**: of 5 pairs of tokened taps 0.21 s apart, all first taps landed and 1 second tap landed. The other second taps fell inside the 0.46 s contact gate, which the client latch now stops before they are sent.

**Specs.**
- `BoardSnapshots` 12 and `DropIntent` 9 pass, offline and in Play.
- Deck and live specs pass, including JellyOverflow and FieldFeedbackOwner with (gui, board).
- Client suite: 145 of 163 pass. The 18 failures are the 14 known plus 4 that need other arguments.
- Server suite: 63 of 63 pass with their own arguments. A first run showed 60 because of harness argument mistakes, not the deck-net code. ParkMount got `ReplicatedStorage.Shared` as its `parent`, so its room was built outside Workspace and the ground rays missed. PersonalToyGardenTimeline got Shared as `client` ("PetFollow is not a valid member of ... Shared"). ToyFeatureProgress had no fixture ("pass exact fixtures/FrozenV370HatchProgress.lua as argument two").
  - Re-run correctly, all three pass: `(server)`, `(server, StarterPlayerScripts.Client)`, and `(server, FixtureFrozenV370, FixtureFrozenDaily)`.

**Still to check**:
- A real phone on LTE.
- `Stats.DataReceiveKbps` with a 4-client server.
- Server Heartbeat time with 8 boards.
- An `audio:play` count per merge across a jittered round.
- The 20 fps longest freeze (216 ms) is still high.

### Code review changes (GO WITH CHANGES, 2026-11-16, place v832)

1. **Waits.** `init.client.lua` waits for `BoardDropAck` inside `task.spawn` (30 s timeout, with a warning; the 1.5 s latch timeout keeps taps working without it). `DeckNet.client.lua` waits for the board folder with 30 s timeouts and falls back to the replicated Parts.
2. **A reset on a paused board.**
   - `BoardSnapshots:push` now accepts a new ResetId at the same tick when the packet is Paused.
   - Run ids already left are retired, so a late packet of the old run cannot switch back.
   - Same tick without Paused is still dropped.
   - New spec case; BoardSnapshots now has 13 cases.
3. **Silent refusals.**
   - The server acks tokened drops refused while closing (`Closing`), by `canProgress` (`Unavailable`) and outside Board (`NotBoard`).
   - Acks are capped at 20 per player per second (checked: 30 spammed drops gave 20 acks, plus 1 `NotBoard` from Room).
   - The `DropIntent` latch timeout also drops the predicted count, with a spec assert.
4. **Shadow stats** are on only in Studio unless asked, so production has no per-frame `GetChildren` for stats.

**Nits.**
- `clientUI.netChain` clears on ResetId.
- `FireClient` copies the buffer at call time. A Studio check fired 11 to 15 and overwrote the buffer with 99 after each call; the client received 11, 12, 13, 14, 15.

**Verification.**
- Jitter run with 150-250 ms lag: 0 freeze snaps, 1 hitch, longest freeze 84 ms (no regression).
- Server suite: 64 of 64 runs pass with their own arguments (63 specs, ToyFeatureHost run as toy and as feature).
- Client suite: 144 of 163 pass. The 18 failures are the known set plus argument misses. CustomizeNewItem (line 46, "lands on the Toys cards, got palette / hue") now fails after the UI agent's db7b23e changed HueEggView and that spec; it is not deck-net code and is not touched here.
- JellyOverflow and FieldFeedbackOwner pass with (gui, board).
- Console: only fixture noise from the specs.
