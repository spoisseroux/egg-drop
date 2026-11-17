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
